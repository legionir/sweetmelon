package ir.legion.w2ray.engine

import org.json.JSONObject
import java.io.IOException

enum class FailKind {
    /** Network, TLS, upgrade or timeout problems: the server could not be used. */
    TRANSPORT,

    /** The server refused the password or banned this address. Retrying makes it worse. */
    AUTH,

    /** The server worked, but the destination did not. */
    TARGET,
}

class TunnelException(message: String, val kind: FailKind, val socksReply: Int = 0x01, cause: Throwable? = null) :
    IOException(message, cause)

/** Receiver of the bytes that come back from the destination. */
interface Sink {
    fun onData(data: ByteArray)

    /** The tunnel ended (destination closed it, or the connection broke). */
    fun onEnd()
}

/**
 * One WebSocket tunnel to the w2ray server, speaking its protocol (src/tunnel/protocol.js):
 * JSON text frames `{t, p, ts}` for control (`auth`, `auth_ok`, `connect`, `connected`, `error`) and raw
 * binary frames for the byte stream. One link carries one destination.
 */
class Link internal constructor(val createdAt: Long) : WsListener {
    private enum class Phase { AUTH, READY, CONNECTING, OPEN, DEAD }

    private val lock = Object()
    private var phase = Phase.AUTH
    private var failure: TunnelException? = null
    private var sink: Sink? = null
    private val early = ArrayList<ByteArray>()
    private var endPending = false

    lateinit var ws: WsClient
        internal set

    /** Milliseconds of the `auth` -> `auth_ok` round trip, 0 until known. */
    @Volatile
    var authMs: Long = 0
        private set
    private var authSentAt = 0L

    /** Still usable for a new destination. */
    val isFresh: Boolean
        get() = synchronized(lock) { (phase == Phase.AUTH || phase == Phase.READY) && ws.isOpen }

    val isOpen: Boolean get() = synchronized(lock) { phase == Phase.OPEN && ws.isOpen }

    internal fun sendAuth(password: String) {
        authSentAt = System.currentTimeMillis()
        ws.sendText(message("auth", JSONObject().put("password", password)))
    }

    /** Waits until the server accepted the password. */
    fun awaitReady(timeoutMs: Long) {
        val end = System.currentTimeMillis() + timeoutMs
        synchronized(lock) {
            while (phase == Phase.AUTH) {
                val left = end - System.currentTimeMillis()
                if (left <= 0) throw TunnelException("Timed out waiting for the server", FailKind.TRANSPORT)
                lock.wait(left)
            }
            failure?.let { throw it }
            if (phase == Phase.DEAD) throw TunnelException("Tunnel closed", FailKind.TRANSPORT)
        }
    }

    /**
     * Asks the server to connect to [host]:[port] and waits for the answer. Sent right after `auth` without
     * waiting for `auth_ok`: the server handles messages in order, so one round trip is saved.
     */
    fun connect(host: String, port: Int, timeoutMs: Long) {
        synchronized(lock) {
            if (phase != Phase.AUTH && phase != Phase.READY) throw TunnelException("Tunnel is not ready", FailKind.TRANSPORT)
            if (phase == Phase.READY) phase = Phase.CONNECTING
        }
        try {
            ws.sendText(message("connect", JSONObject().put("host", host).put("port", port)))
        } catch (e: WsException) {
            fail(TunnelException(e.message ?: "send failed", FailKind.TRANSPORT, cause = e))
        }
        val end = System.currentTimeMillis() + timeoutMs
        var error: TunnelException? = null
        synchronized(lock) {
            while (phase != Phase.OPEN && phase != Phase.DEAD) {
                val left = end - System.currentTimeMillis()
                if (left <= 0) {
                    failure = failure ?: TunnelException("Timed out connecting to $host:$port", FailKind.TARGET, 0x06)
                    phase = Phase.DEAD
                    lock.notifyAll()
                    break
                }
                lock.wait(left)
            }
            if (phase != Phase.OPEN) {
                error = failure ?: TunnelException("Tunnel closed", FailKind.TRANSPORT)
            }
        }
        error?.let {
            close()
            throw it
        }
    }

    /** Sets the receiver. Bytes that arrived before it was set are delivered first, in order. */
    fun setSink(s: Sink) {
        val pending: List<ByteArray>
        val ended: Boolean
        synchronized(lock) {
            pending = ArrayList(early)
            early.clear()
            ended = endPending
            sink = s
        }
        for (b in pending) s.onData(b)
        if (ended) s.onEnd()
    }

    @Throws(IOException::class)
    fun send(data: ByteArray, off: Int, len: Int) {
        try {
            ws.sendBinary(data, off, len)
        } catch (e: WsException) {
            throw IOException(e.message, e)
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
        val p = msg.optJSONObject("p")
        when (msg.optString("t")) {
            "auth_ok" -> synchronized(lock) {
                if (phase == Phase.AUTH) {
                    phase = Phase.READY
                    authMs = System.currentTimeMillis() - authSentAt
                }
                lock.notifyAll()
            }
            "connected" -> synchronized(lock) {
                if (phase == Phase.AUTH || phase == Phase.READY || phase == Phase.CONNECTING) {
                    if (authMs == 0L) authMs = System.currentTimeMillis() - authSentAt
                    phase = Phase.OPEN
                }
                lock.notifyAll()
            }
            "error" -> {
                val m = p?.optString("message", "") ?: ""
                fail(TunnelException(m.ifEmpty { "Server error" }, FailKind.TARGET, replyFor(m)))
                ws.close(1000, "")
            }
        }
    }

    override fun onBinary(data: ByteArray) {
        var target: Sink? = null
        synchronized(lock) {
            if (phase != Phase.OPEN) return
            target = sink
            if (target == null) {
                early.add(data)
                return
            }
        }
        target?.onData(data)
    }

    override fun onClosed(code: Int, reason: String) {
        var target: Sink? = null
        synchronized(lock) {
            if (failure == null && phase != Phase.OPEN) {
                failure = when (code) {
                    4001 -> TunnelException("Server timed out waiting for the password", FailKind.AUTH)
                    4002 -> TunnelException("The server refused the password", FailKind.AUTH)
                    4003 -> TunnelException("The server banned this device for too many wrong passwords. Try again in 15 minutes", FailKind.AUTH)
                    else -> TunnelException("Tunnel closed ($code${if (reason.isNotEmpty()) ": $reason" else ""})", FailKind.TRANSPORT)
                }
            }
            val wasOpen = phase == Phase.OPEN
            phase = Phase.DEAD
            lock.notifyAll()
            target = sink
            if (target == null && wasOpen) endPending = true
        }
        target?.onEnd()
    }

    private fun fail(e: TunnelException) {
        synchronized(lock) {
            if (failure == null) failure = e
            if (phase != Phase.OPEN) phase = Phase.DEAD
            lock.notifyAll()
        }
    }

    companion object {
        private fun message(type: String, payload: JSONObject) =
            JSONObject().put("t", type).put("p", payload).put("ts", System.currentTimeMillis()).toString()

        /** Maps the text of a server error to a SOCKS5 reply code. */
        internal fun replyFor(m: String): Int {
            val t = m.lowercase()
            return when {
                "refused" in t -> 0x05
                "networkunreachable" in t || "network unreachable" in t -> 0x03
                "hostunreachable" in t || "unreachable" in t || "enotfound" in t || "not found" in t -> 0x04
                "timed out" in t || "timeout" in t || "ttl" in t -> 0x06
                "notallowed" in t || "not allowed" in t || "invalid destination" in t -> 0x02
                else -> 0x01
            }
        }
    }
}
