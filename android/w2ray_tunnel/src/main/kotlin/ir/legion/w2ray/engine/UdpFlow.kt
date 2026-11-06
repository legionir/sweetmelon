package ir.legion.w2ray.engine

import org.json.JSONObject
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/**
 * UDP over the tunnel (server side: `src/tunnel/udp.js` of the w2ray project).
 *
 * One extra WebSocket is a "UDP session": after `auth` the client sends `{t:"udp"}`, the server answers `udp_ok`,
 * and every binary message is a frame `TYPE(1) FLAGS(1) FLOWID(4, big endian) LEN(2) PAYLOAD`. The TCP path (one
 * WebSocket per connection) is untouched.
 */
object UdpFrames {
    const val OPEN = 1
    const val DATA = 2
    const val CLOSE = 3
    const val ERROR = 4
    const val RESET = 5
    const val HEADER = 8
    const val MAX_PAYLOAD = 65507
    const val VERSION = 1

    class Frame(val type: Int, val flags: Int, val flowId: Int, val payload: ByteArray)

    fun frame(type: Int, flowId: Int, payload: ByteArray = ByteArray(0)): ByteArray {
        val b = ByteArray(HEADER + payload.size)
        b[0] = type.toByte()
        b[2] = (flowId ushr 24).toByte(); b[3] = (flowId ushr 16).toByte(); b[4] = (flowId ushr 8).toByte(); b[5] = flowId.toByte()
        b[6] = (payload.size ushr 8).toByte(); b[7] = payload.size.toByte()
        System.arraycopy(payload, 0, b, HEADER, payload.size)
        return b
    }

    /** Null when the frame is shorter than its header or its length field does not match. */
    fun parse(b: ByteArray): Frame? {
        if (b.size < HEADER) return null
        val len = ((b[6].toInt() and 255) shl 8) or (b[7].toInt() and 255)
        if (b.size != HEADER + len) return null
        val id = ((b[2].toInt() and 255) shl 24) or ((b[3].toInt() and 255) shl 16) or ((b[4].toInt() and 255) shl 8) or (b[5].toInt() and 255)
        return Frame(b[0].toInt() and 255, b[1].toInt() and 255, id, b.copyOfRange(HEADER, b.size))
    }

    /** `ATYP ADDR PORT` of an OPEN frame: 1 = IPv4, 4 = IPv6, 3 = host name. */
    fun address(host: String, port: Int): ByteArray {
        val h = host.trim('[', ']')
        val addr: ByteArray = when {
            IpUtil.isIpv4(h) -> byteArrayOf(1) + InetAddress.getByName(h).address
            IpUtil.isIpv6(h) -> {
                val a = InetAddress.getByName(h).address // 4 bytes for an IPv4-mapped address
                if (a.size == 4) byteArrayOf(1) + a else byteArrayOf(4) + a
            }
            else -> {
                val n = h.toByteArray(Charsets.UTF_8)
                require(n.size in 1..255) { "bad host name" }
                byteArrayOf(3, n.size.toByte()) + n
            }
        }
        return addr + byteArrayOf((port ushr 8).toByte(), port.toByte())
    }

    /** Idle time after which a flow to [port] is dropped (the server uses the same numbers). */
    fun idleMs(port: Int): Long = when (port) {
        53 -> 10_000L
        123 -> 30_000L
        443 -> 120_000L
        else -> 60_000L
    }
}

/** The WebSocket of one UDP session. */
internal class UdpLink(private val manager: UdpFlowManager) : WsListener {
    private val lock = Object()

    @Volatile
    private var authed = false

    @Volatile
    var ready = false
        private set

    @Volatile
    var dead = false
        private set
    private var failure: TunnelException? = null

    lateinit var ws: WsClient

    /** The server accepted the password but never answered `udp`: an older w2ray server without UDP. */
    class Unsupported(message: String) : Exception(message)

    fun hello(password: String) {
        ws.sendText(JSONObject().put("t", "auth").put("p", JSONObject().put("password", password)).put("ts", System.currentTimeMillis()).toString())
        ws.sendText(JSONObject().put("t", "udp").put("p", JSONObject().put("v", UdpFrames.VERSION)).put("ts", System.currentTimeMillis()).toString())
    }

    /** Waits for `udp_ok`. Throws [Unsupported] when the server is up but does not speak UDP. */
    fun awaitReady(timeoutMs: Long, unsupportedAfterMs: Long) {
        val start = System.currentTimeMillis()
        val end = start + timeoutMs
        synchronized(lock) {
            var authAt = 0L
            while (!ready && !dead) {
                val now = System.currentTimeMillis()
                if (authed && authAt == 0L) authAt = now
                if (authAt != 0L && now - authAt >= unsupportedAfterMs) throw Unsupported("The server does not support UDP")
                val left = end - now
                if (left <= 0) throw TunnelException("Timed out waiting for the server", FailKind.TRANSPORT)
                lock.wait(minOf(left, 100))
            }
            failure?.let { throw it }
            if (!ready) throw TunnelException("Tunnel closed", FailKind.TRANSPORT)
        }
    }

    fun close() {
        ws.close(1000, "")
    }

    override fun onText(text: String) {
        val msg = try {
            JSONObject(text)
        } catch (e: Exception) {
            return
        }
        synchronized(lock) {
            when (msg.optString("t")) {
                "auth_ok" -> authed = true
                "udp_ok" -> ready = true
                "error" -> {
                    failure = TunnelException(msg.optJSONObject("p")?.optString("message").orEmpty().ifEmpty { "Server error" }, FailKind.TARGET)
                    dead = true
                }
            }
            lock.notifyAll()
        }
    }

    override fun onBinary(data: ByteArray) {
        if (ready) manager.onFrame(this, data)
    }

    override fun onClosed(code: Int, reason: String) {
        synchronized(lock) {
            if (failure == null && !ready) {
                failure = when (code) {
                    4001 -> TunnelException("Server timed out waiting for the password", FailKind.AUTH)
                    4002 -> TunnelException("The server refused the password", FailKind.AUTH)
                    4003 -> TunnelException("The server banned this device for too many wrong passwords. Try again in 15 minutes", FailKind.AUTH)
                    else -> TunnelException("Tunnel closed ($code${if (reason.isNotEmpty()) ": $reason" else ""})", FailKind.TRANSPORT)
                }
            }
            dead = true
            lock.notifyAll()
        }
        manager.onLinkDown(this)
    }
}

/**
 * Turns UDP datagrams of the SOCKS5 listener into flows on a UDP session.
 *
 * A flow is `(owner, source address, destination)`: the same app talking to two servers, or two apps talking to one
 * server, never share a flow. Flow ids come from a counter that never repeats, so a late reply of a closed flow
 * cannot reach a new one. Everything is bounded: flows, datagrams waiting for the session, the write queue.
 * Datagrams that cannot be carried are dropped (it is UDP), never queued without limit.
 */
class UdpFlowManager internal constructor(private val engine: Engine) {
    private class Key(val owner: Any, val src: String, val host: String, val port: Int) {
        override fun equals(other: Any?) = other is Key && other.owner === owner && other.src == src && other.host == host && other.port == port
        override fun hashCode() = ((System.identityHashCode(owner) * 31 + src.hashCode()) * 31 + host.hashCode()) * 31 + port
    }

    private class Flow(val id: Int, val key: Key, val reply: (ByteArray) -> Unit, val unavailable: (ByteArray) -> Unit) {
        @Volatile
        var last = System.currentTimeMillis()
        var opened = false
        val pending = ArrayList<ByteArray>()
    }

    private val lock = Any()
    private val flows = HashMap<Key, Flow>()
    private val byId = ConcurrentHashMap<Int, Flow>()
    private var nextId = 1
    private var link: UdpLink? = null
    private var connecting = false
    private var unsupportedUntil = 0L
    private var retryAt = 0L
    @Volatile
    private var closed = false
    private var idleSince = 0L

    private val writes = LinkedBlockingQueue<Pair<UdpLink, ByteArray>>(WRITE_QUEUE)
    private var writer: Thread? = null

    val sent = AtomicLong()
    val received = AtomicLong()
    val dropped = AtomicLong()

    val activeFlows: Int get() = synchronized(lock) { flows.size }

    /** UDP can be tried: a w2ray server is configured and it did not just prove to be without UDP. */
    fun available(): Boolean = engine.udpServer() != null && System.currentTimeMillis() >= unsupportedUntil

    /**
     * Sends [payload] to [host]:[port] for [owner] (the SOCKS5 association) and [src] (the app's address).
     * Answers arrive on [reply]. When UDP cannot be used, [unavailable] gets the datagram back.
     */
    fun send(owner: Any, src: String, host: String, port: Int, payload: ByteArray, reply: (ByteArray) -> Unit, unavailable: (ByteArray) -> Unit) {
        if (payload.isEmpty() || payload.size > UdpFrames.MAX_PAYLOAD) {
            dropped.incrementAndGet()
            return
        }
        var refused = false
        synchronized(lock) {
            val now = System.currentTimeMillis()
            if (closed || engine.udpServer() == null || now < unsupportedUntil || now < retryAt) {
                refused = true
                return@synchronized
            }
            val key = Key(owner, src, host, port)
            var f = flows[key]
            if (f == null) {
                if (flows.size >= MAX_FLOWS) {
                    dropped.incrementAndGet()
                    return
                }
                f = Flow(nextId++, key, reply, unavailable)
                flows[key] = f
                byId[f.id] = f
            }
            f.last = now
            val l = link
            if (l != null && l.ready && !l.dead) {
                if (!f.opened) open(l, f)
                enqueue(l, UdpFrames.frame(UdpFrames.DATA, f.id, payload))
                sent.incrementAndGet()
            } else {
                if (f.pending.size < MAX_PENDING) f.pending.add(payload) else dropped.incrementAndGet()
                ensureConnecting()
            }
        }
        if (refused) unavailable(payload)
    }

    private fun open(l: UdpLink, f: Flow) {
        f.opened = true
        try {
            enqueue(l, UdpFrames.frame(UdpFrames.OPEN, f.id, UdpFrames.address(f.key.host, f.key.port)))
        } catch (e: IllegalArgumentException) {
            remove(f, notify = false)
        }
    }

    private fun enqueue(l: UdpLink, frame: ByteArray) {
        if (!writes.offer(l to frame)) dropped.incrementAndGet() // the connection is slower than the apps: drop
    }

    private fun ensureConnecting() {
        if (connecting || closed) return
        connecting = true
        engine.execute { connectLink() }
    }

    private fun connectLink() {
        val srv = engine.udpServer()
        var l: UdpLink? = null
        try {
            if (srv == null) throw TunnelException("No server is configured", FailKind.TRANSPORT)
            l = UdpLink(this)
            val ws = try {
                engine.connectWs(srv)
            } catch (e: WsException) {
                throw TunnelException(e.message ?: "Cannot connect", FailKind.TRANSPORT, cause = e)
            }
            l.ws = ws
            ws.start(l) { r -> engine.newThread(r) }
            l.hello(srv.password)
            l.awaitReady(srv.handshakeTimeoutMs.toLong(), UNSUPPORTED_AFTER_MS)
            synchronized(lock) {
                if (closed) {
                    l.close()
                    return
                }
                link = l
                ensureWriter()
                for (f in flows.values.toList()) {
                    if (!f.opened) open(l, f)
                    for (p in f.pending) {
                        enqueue(l, UdpFrames.frame(UdpFrames.DATA, f.id, p))
                        sent.incrementAndGet()
                    }
                    f.pending.clear()
                }
                retryAt = 0
                idleSince = System.currentTimeMillis()
            }
            engine.logUdp('I', "UDP session ready")
        } catch (e: UdpLink.Unsupported) {
            l?.close()
            synchronized(lock) { unsupportedUntil = System.currentTimeMillis() + UNSUPPORTED_MS }
            engine.logUdp('W', "The server has no UDP support (update w2ray); UDP stays off for a while")
            failPending()
        } catch (e: TunnelException) {
            l?.close()
            if (e.kind == FailKind.TARGET) {
                // The server answered with an error to `udp`: UDP is switched off there.
                synchronized(lock) { unsupportedUntil = System.currentTimeMillis() + UNSUPPORTED_MS }
                engine.logUdp('W', "The server refuses UDP (${e.message})")
                failPending()
                return
            }
            engine.noteUdpFailure(e)
            synchronized(lock) { retryAt = System.currentTimeMillis() + RETRY_MS }
            engine.logUdp('W', "UDP session failed: ${e.message}")
            failPending()
        } finally {
            synchronized(lock) { connecting = false }
        }
    }

    /** The datagrams that were waiting for a session that did not come: hand them back and forget the flows. */
    private fun failPending() {
        val give = ArrayList<Pair<Flow, List<ByteArray>>>()
        synchronized(lock) {
            for (f in flows.values.toList()) {
                if (!f.opened) {
                    give.add(f to f.pending.toList())
                    flows.remove(f.key)
                    byId.remove(f.id)
                }
            }
        }
        for ((f, list) in give) for (p in list) f.unavailable(p)
    }

    private fun ensureWriter() {
        if (writer != null) return
        writer = engine.newThread(Runnable {
            while (!closed) {
                val (l, frame) = try {
                    writes.poll(1, TimeUnit.SECONDS)
                } catch (_: InterruptedException) {
                    return@Runnable
                } ?: continue
                if (l.dead) continue
                try {
                    l.ws.sendBinary(frame, 0, frame.size)
                } catch (_: Exception) {
                    l.close()
                }
            }
        }).also {
            it.name = "w2ray-udp-writer"
            it.start()
        }
    }

    internal fun onFrame(l: UdpLink, data: ByteArray) {
        val f = UdpFrames.parse(data) ?: return
        when (f.type) {
            UdpFrames.DATA -> {
                val flow = byId[f.flowId] ?: return
                flow.last = System.currentTimeMillis()
                received.incrementAndGet()
                try {
                    flow.reply(f.payload)
                } catch (_: Exception) {
                }
            }
            UdpFrames.ERROR -> {
                val flow = byId[f.flowId] ?: return
                engine.logUdp('D', "UDP ${flow.key.host}:${flow.key.port}: ${String(f.payload, 1.coerceAtMost(f.payload.size), maxOf(0, f.payload.size - 1), Charsets.UTF_8)}")
                remove(flow, notify = false)
            }
            UdpFrames.CLOSE -> byId[f.flowId]?.let { remove(it, notify = false) }
        }
    }

    internal fun onLinkDown(l: UdpLink) {
        val gone = synchronized(lock) {
            if (link !== l) return
            link = null
            val all = flows.values.toList()
            flows.clear()
            all
        }
        gone.forEach { byId.remove(it.id) }
        writes.removeIf { it.first === l }
        if (gone.isNotEmpty()) engine.logUdp('W', "UDP session ended, ${gone.size} flow(s) dropped")
    }

    private fun remove(f: Flow, notify: Boolean) {
        val l = synchronized(lock) {
            flows.remove(f.key)
            byId.remove(f.id)
            link
        }
        if (notify && l != null && f.opened && !l.dead) enqueue(l, UdpFrames.frame(UdpFrames.CLOSE, f.id))
    }

    /** The SOCKS5 association [owner] ended: release its flows on the server too. */
    fun closeOwner(owner: Any) {
        val mine = synchronized(lock) { flows.values.filter { it.key.owner === owner } }
        mine.forEach { remove(it, notify = true) }
    }

    /** Called every few seconds: drops idle flows and an unused session. */
    internal fun sweep() {
        val now = System.currentTimeMillis()
        val idle = synchronized(lock) { flows.values.filter { now - it.last > UdpFrames.idleMs(it.key.port) } }
        idle.forEach { remove(it, notify = true) }
        val l = synchronized(lock) {
            if (flows.isNotEmpty()) {
                idleSince = now
                null
            } else if (link != null && now - idleSince > SESSION_IDLE_MS) {
                link.also { link = null }
            } else {
                null
            }
        }
        l?.close()
    }

    /** The network changed or the VPN restarts: forget everything. */
    internal fun reset() {
        val l = synchronized(lock) {
            flows.clear()
            link.also { link = null }
        }
        byId.clear()
        writes.clear()
        l?.close()
        synchronized(lock) {
            unsupportedUntil = 0
            retryAt = 0
        }
    }

    internal fun shutdown() {
        synchronized(lock) { closed = true }
        reset()
        writer?.interrupt()
    }

    companion object {
        private const val MAX_FLOWS = 256
        private const val MAX_PENDING = 16
        private const val WRITE_QUEUE = 1024
        private const val UNSUPPORTED_AFTER_MS = 4_000L
        private const val UNSUPPORTED_MS = 5 * 60_000L
        private const val RETRY_MS = 10_000L
        private const val SESSION_IDLE_MS = 60_000L
    }
}
