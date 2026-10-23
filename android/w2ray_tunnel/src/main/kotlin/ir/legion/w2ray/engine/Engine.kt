package ir.legion.w2ray.engine

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ThreadFactory
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/** Byte and connection counters of one listener. */
class Counters {
    val up = AtomicLong()
    val down = AtomicLong()
    val active = AtomicInteger()
    val total = AtomicLong()
}

/**
 * Opens tunnels to the w2ray server and moves bytes between them and local sockets.
 *
 * Nothing here knows about Android; [newSocket] is where the service protects sockets from the VPN.
 */
class Engine(
    val cfg: ServerConfig,
    private val newSocket: () -> Socket,
    private val log: (level: Char, message: String) -> Unit,
) {
    interface Events {
        /** The server cannot be used (several tunnels in a row failed) or works again. */
        fun onHealth(healthy: Boolean, detail: String?)

        /** The server refused the password or banned this device: stop, do not retry. */
        fun onFatal(message: String)
    }

    @Volatile
    var events: Events? = null

    private val threadIds = AtomicInteger()
    private val threads = ThreadFactory { r ->
        Thread(null, r, "w2ray-${threadIds.incrementAndGet()}", 512 * 1024).also { it.isDaemon = true }
    }
    private val pool = ThreadPoolExecutor(0, Int.MAX_VALUE, 30, TimeUnit.SECONDS, SynchronousQueue(), threads)
    private val timer: ScheduledExecutorService = Executors.newScheduledThreadPool(1) { r ->
        Thread(null, r, "w2ray-timer", 256 * 1024).also { it.isDaemon = true }
    }

    private val stopped = AtomicBoolean(false)
    private val warm = ArrayList<Link>()
    private val sessions: MutableSet<Session> = ConcurrentHashMap.newKeySet()
    private val refilling = AtomicBoolean(false)

    @Volatile
    private var lastDemandMs = 0L

    @Volatile
    var fatalMessage: String? = null
        private set

    @Volatile
    private var healthy = true
    private val failStreak = AtomicInteger()

    /** Everything that went through [relay] (proxy traffic, not the TUN interface). */
    val total = Counters()

    val activeSessions: Int get() = sessions.size

    init {
        timer.scheduleWithFixedDelay({ safely { maintain() } }, 5, 5, TimeUnit.SECONDS)
    }

    fun execute(r: Runnable) {
        if (!stopped.get()) pool.execute(r)
    }

    fun newThread(r: Runnable): Thread = threads.newThread(r)

    fun schedule(delayMs: Long, r: Runnable) {
        if (!stopped.get()) timer.schedule({ safely { r.run() } }, delayMs, TimeUnit.MILLISECONDS)
    }

    // ── Opening tunnels ─────────────────────────────────────────────

    /** A tunnel connected to [host]:[port]. Throws [TunnelException]. */
    fun openLink(host: String, port: Int, timeoutMs: Long = cfg.connectTimeoutMs.toLong()): Link {
        fatalMessage?.let { throw TunnelException(it, FailKind.AUTH) }
        if (stopped.get()) throw TunnelException("Stopped", FailKind.TRANSPORT)
        lastDemandMs = System.currentTimeMillis()
        val ready = takeWarm()
        var link = ready ?: newLink()
        try {
            link.connect(host, port, timeoutMs)
        } catch (e: TunnelException) {
            if (ready != null && e.kind == FailKind.TRANSPORT && !stopped.get()) {
                // A ready tunnel can have been dropped by a middlebox while it waited: use a new one.
                link = newLink()
                try {
                    link.connect(host, port, timeoutMs)
                } catch (e2: TunnelException) {
                    handleFailure(e2)
                    throw e2
                }
            } else {
                handleFailure(e)
                throw e
            }
        }
        noteSuccess()
        topUpAsync()
        return link
    }

    /**
     * Opens a tunnel, waits for the password check and closes it again. Returns the round trip in ms.
     * This is the "ping" of the server and the first check before a VPN starts.
     */
    fun probe(): Long {
        val t0 = System.currentTimeMillis()
        val link = newLink()
        try {
            link.awaitReady(cfg.handshakeTimeoutMs.toLong())
        } catch (e: TunnelException) {
            link.close()
            handleFailure(e)
            throw e
        }
        val ms = System.currentTimeMillis() - t0
        // Keep it: it is a ready tunnel for the first connection.
        synchronized(warm) {
            if (warm.size < cfg.warmPool) warm.add(link) else link.close()
        }
        noteSuccess()
        return ms
    }

    /** Time to reach [host]:[port] through the tunnel, in ms. */
    fun testTarget(host: String, port: Int): Long {
        val t0 = System.currentTimeMillis()
        val link = openLink(host, port)
        val ms = System.currentTimeMillis() - t0
        link.close()
        return ms
    }

    private fun newLink(): Link {
        var last: TunnelException? = null
        for (attempt in 1..2) {
            val started = System.currentTimeMillis()
            try {
                return createLink()
            } catch (e: TunnelException) {
                last = e
                handleFailure(e)
                if (e.kind == FailKind.AUTH || stopped.get()) throw e
                if (System.currentTimeMillis() - started > cfg.connectTimeoutMs / 2) throw e
            }
        }
        throw last!!
    }

    private fun createLink(): Link {
        val ws = try {
            WsClient.connect(cfg, newSocket)
        } catch (e: WsException) {
            throw TunnelException(e.message ?: "Cannot connect", FailKind.TRANSPORT, cause = e)
        }
        val link = Link(System.currentTimeMillis())
        link.ws = ws
        ws.start(link) { r -> newThread(r) }
        try {
            link.sendAuth(cfg.password)
        } catch (e: WsException) {
            ws.abort()
            throw TunnelException(e.message ?: "Cannot connect", FailKind.TRANSPORT, cause = e)
        }
        return link
    }

    private fun takeWarm(): Link? {
        while (true) {
            val l = synchronized(warm) { if (warm.isEmpty()) null else warm.removeAt(warm.size - 1) } ?: return null
            if (l.isFresh && System.currentTimeMillis() - l.createdAt < WARM_MAX_AGE_MS) return l
            l.close()
        }
    }

    private fun topUpAsync() {
        if (cfg.warmPool <= 0 || stopped.get()) return
        if (!refilling.compareAndSet(false, true)) return
        execute {
            try {
                while (!stopped.get() && fatalMessage == null &&
                    System.currentTimeMillis() - lastDemandMs < DEMAND_WINDOW_MS
                ) {
                    val need = synchronized(warm) { warm.size } < cfg.warmPool
                    if (!need) break
                    val l = try {
                        createLink()
                    } catch (e: TunnelException) {
                        handleFailure(e)
                        break
                    }
                    synchronized(warm) { warm.add(l) }
                }
            } finally {
                refilling.set(false)
            }
        }
    }

    // ── Health ──────────────────────────────────────────────────────

    private fun handleFailure(e: TunnelException) {
        when (e.kind) {
            FailKind.AUTH -> {
                if (fatalMessage == null) {
                    fatalMessage = e.message
                    log('E', "Server: ${e.message}")
                    events?.onFatal(e.message ?: "Authentication failed")
                }
            }
            FailKind.TRANSPORT -> {
                log('W', "Tunnel failed: ${e.message}")
                if (failStreak.incrementAndGet() >= 3 && healthy) {
                    healthy = false
                    events?.onHealth(false, e.message)
                }
            }
            FailKind.TARGET -> Unit
        }
    }

    private fun noteSuccess() {
        failStreak.set(0)
        if (!healthy) {
            healthy = true
            events?.onHealth(true, null)
        }
    }

    // ── Relay ───────────────────────────────────────────────────────

    /**
     * Moves bytes both ways until either side ends. Blocks the calling thread (it carries the
     * client -> server direction). [input] is the client's stream, which may hold bytes already buffered.
     */
    fun relay(link: Link, client: Socket, input: InputStream, counters: Counters) {
        val s = Session(link, client, counters)
        sessions.add(s)
        counters.active.incrementAndGet()
        counters.total.incrementAndGet()
        link.setSink(s)
        val buf = ByteArray(cfg.bufferSize)
        try {
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                link.send(buf, 0, n)
                s.touch()
                counters.up.addAndGet(n.toLong())
                total.up.addAndGet(n.toLong())
            }
        } catch (_: IOException) {
        } finally {
            s.close()
        }
    }

    private inner class Session(val link: Link, val client: Socket, val counters: Counters) : Sink {
        @Volatile
        var lastActivity = System.currentTimeMillis()
        private val closed = AtomicBoolean(false)

        fun touch() {
            lastActivity = System.currentTimeMillis()
        }

        override fun onData(data: ByteArray) {
            try {
                val out = client.getOutputStream()
                out.write(data)
                out.flush()
            } catch (e: IOException) {
                close()
                return
            }
            touch()
            counters.down.addAndGet(data.size.toLong())
            total.down.addAndGet(data.size.toLong())
        }

        override fun onEnd() {
            // The destination is done. Let the client read what was sent, then end it.
            try {
                client.shutdownOutput()
            } catch (_: Exception) {
            }
            schedule(3000) { close() }
        }

        fun close() {
            if (!closed.compareAndSet(false, true)) return
            sessions.remove(this)
            counters.active.decrementAndGet()
            link.close()
            try {
                client.close()
            } catch (_: Exception) {
            }
        }
    }

    /** Closes every connection and the ready tunnels, e.g. after the network changed. */
    fun resetConnections() {
        val list = synchronized(warm) { warm.toList().also { warm.clear() } }
        list.forEach { it.close() }
        sessions.toList().forEach { it.close() }
        failStreak.set(0)
    }

    // ── DNS ─────────────────────────────────────────────────────────

    /** DNS over TCP through the tunnel: sends [query] (a UDP DNS message) to [host]:53, returns the answer or null. */
    fun dnsQuery(host: String, query: ByteArray, timeoutMs: Long = 6000): ByteArray? {
        if (query.size > 65535) return null
        val end = System.currentTimeMillis() + timeoutMs
        val link = openLink(host, 53, minOf(timeoutMs, cfg.connectTimeoutMs.toLong()))
        val q = LinkedBlockingQueue<ByteArray>()
        val endMark = ByteArray(0)
        link.setSink(object : Sink {
            override fun onData(data: ByteArray) {
                q.put(data)
            }

            override fun onEnd() {
                q.put(endMark)
            }
        })
        try {
            val framed = ByteArray(query.size + 2)
            framed[0] = (query.size shr 8).toByte()
            framed[1] = query.size.toByte()
            System.arraycopy(query, 0, framed, 2, query.size)
            link.send(framed, 0, framed.size)
            val acc = ByteArrayOutputStream()
            while (true) {
                val left = end - System.currentTimeMillis()
                if (left <= 0) return null
                val chunk = q.poll(left, TimeUnit.MILLISECONDS) ?: return null
                if (chunk === endMark) return null
                acc.write(chunk)
                val b = acc.toByteArray()
                if (b.size >= 2) {
                    val len = ((b[0].toInt() and 255) shl 8) or (b[1].toInt() and 255)
                    if (b.size >= 2 + len) return b.copyOfRange(2, 2 + len)
                }
            }
        } catch (_: IOException) {
            return null
        } finally {
            link.close()
        }
    }

    // ── HTTP through the tunnel ─────────────────────────────────────

    /**
     * A plain HTTP/1.0 GET of [host][path] through the tunnel. Returns the status code and the body (at most
     * 256 KB). Used for "what is my IP" checks that must leave through the server, not through the phone.
     */
    fun httpGet(host: String, path: String, port: Int = 80, timeoutMs: Long = 12000): Pair<Int, String> {
        val end = System.currentTimeMillis() + timeoutMs
        val link = openLink(host, port, minOf(timeoutMs, cfg.connectTimeoutMs.toLong()))
        val q = LinkedBlockingQueue<ByteArray>()
        val endMark = ByteArray(0)
        link.setSink(object : Sink {
            override fun onData(data: ByteArray) {
                q.put(data)
            }

            override fun onEnd() {
                q.put(endMark)
            }
        })
        try {
            val req = "GET $path HTTP/1.0\r\nHost: ${if (port == 80) host else "$host:$port"}\r\nUser-Agent: curl/8.5.0\r\nAccept: */*\r\nConnection: close\r\n\r\n"
            val b = req.toByteArray(Charsets.ISO_8859_1)
            link.send(b, 0, b.size)
            val acc = ByteArrayOutputStream()
            while (acc.size() < 256 * 1024) {
                val left = end - System.currentTimeMillis()
                if (left <= 0) throw TunnelException("Timed out", FailKind.TARGET, 0x06)
                val chunk = q.poll(left, TimeUnit.MILLISECONDS) ?: throw TunnelException("Timed out", FailKind.TARGET, 0x06)
                if (chunk === endMark) break
                acc.write(chunk)
            }
            val text = String(acc.toByteArray(), Charsets.UTF_8)
            val split = text.indexOf("\r\n\r\n")
            if (split < 0) throw TunnelException("Bad HTTP answer", FailKind.TARGET)
            val status = text.substring(0, text.indexOf("\r\n")).split(' ').getOrNull(1)?.toIntOrNull() ?: 0
            return status to text.substring(split + 4)
        } catch (e: IOException) {
            if (e is TunnelException) throw e
            throw TunnelException(e.message ?: "I/O error", FailKind.TARGET, cause = e)
        } finally {
            link.close()
        }
    }

    // ── Upkeep ──────────────────────────────────────────────────────

    private fun maintain() {
        val now = System.currentTimeMillis()

        // Ready tunnels that are old or dead go away; they are replaced when the proxy is in use.
        val old = synchronized(warm) {
            val gone = warm.filter { !it.isFresh || now - it.createdAt >= WARM_MAX_AGE_MS }
            warm.removeAll(gone.toSet())
            gone
        }
        old.forEach { it.close() }
        if (now - lastDemandMs < DEMAND_WINDOW_MS) topUpAsync()

        val ping = cfg.pingIntervalSec * 1000L
        val dead = maxOf(90_000L, ping * 2)
        for (s in sessions) {
            val idle = cfg.idleTimeoutMs
            if (idle > 0 && now - s.lastActivity > idle) {
                log('I', "Closing an idle connection")
                s.close()
                continue
            }
            if (ping > 0) {
                val ws = s.link.ws
                val silent = now - ws.lastRxMs
                if (silent > dead) {
                    log('W', "Tunnel went silent, closing it")
                    s.close()
                } else if (silent > ping) {
                    try {
                        ws.sendPing()
                    } catch (_: Exception) {
                        s.close()
                    }
                }
            }
        }
    }

    private inline fun safely(block: () -> Unit) {
        try {
            block()
        } catch (e: Throwable) {
            log('W', "Internal error: ${e.message}")
        }
    }

    fun shutdown() {
        if (!stopped.compareAndSet(false, true)) return
        resetConnections()
        timer.shutdownNow()
        pool.shutdownNow()
    }

    companion object {
        private const val WARM_MAX_AGE_MS = 40_000L
        private const val DEMAND_WINDOW_MS = 60_000L
    }
}
