package ir.legion.w2ray.engine

import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.EOFException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.cert.CertificateParsingException
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantLock
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLPeerUnverifiedException
import javax.net.ssl.SSLSession
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class WsException(message: String, val closeCode: Int = 1006, cause: Throwable? = null) : IOException(message, cause)

interface WsListener {
    fun onText(text: String)
    fun onBinary(data: ByteArray)

    /** Called once when the connection ends, for any reason. */
    fun onClosed(code: Int, reason: String)
}

/**
 * Minimal RFC 6455 client over a (TLS) socket: text and binary messages, ping/pong, close.
 *
 * It exists instead of a library so that the TLS server name, the `Host` header and the socket that is
 * protected from the VPN are under our control, and so a slow reader pushes back on the peer through TCP
 * (the reader thread blocks in [WsListener.onBinary]).
 */
class WsClient private constructor(
    private val socket: Socket,
    private val input: InputStream,
    private val output: OutputStream,
    private val maxMessage: Int,
) {
    @Volatile
    var lastRxMs: Long = System.currentTimeMillis()
        private set

    private val writeLock = ReentrantLock()
    private var sendBuf = ByteArray(1024)
    private val maskBytes = ByteArray(4)
    private val closing = AtomicBoolean(false)
    private val notified = AtomicBoolean(false)
    private var listener: WsListener? = null

    @Volatile
    private var localCode = 0

    @Volatile
    private var localReason = ""

    val isOpen: Boolean get() = !closing.get() && !socket.isClosed

    fun start(l: WsListener, factory: (Runnable) -> Thread) {
        listener = l
        factory(Runnable { readLoop() }).start()
    }

    fun sendText(text: String) = sendFrame(OP_TEXT, text.toByteArray(Charsets.UTF_8), 0, -1)

    fun sendBinary(data: ByteArray, off: Int = 0, len: Int = data.size - off) = sendFrame(OP_BINARY, data, off, len)

    fun sendPing() = sendFrame(OP_PING, EMPTY, 0, 0)

    /** Sends a close frame (best effort) and closes the socket. [WsListener.onClosed] follows from the reader. */
    fun close(code: Int = 1000, reason: String = "") {
        if (!closing.compareAndSet(false, true)) return
        localCode = code
        localReason = reason
        try {
            val r = reason.toByteArray(Charsets.UTF_8).let { if (it.size > 120) it.copyOf(120) else it }
            val payload = ByteArray(2 + r.size)
            payload[0] = (code shr 8).toByte()
            payload[1] = code.toByte()
            System.arraycopy(r, 0, payload, 2, r.size)
            // A sender stuck on a stalled socket holds the lock; do not wait for it.
            sendFrameRaw(OP_CLOSE, payload, 0, payload.size, waitMs = 250)
        } catch (_: Exception) {
        }
        closeSocket()
    }

    /** Closes the socket without a close frame. */
    fun abort() {
        closing.set(true)
        closeSocket()
    }

    private fun closeSocket() {
        try {
            socket.close()
        } catch (_: Exception) {
        }
    }

    private fun sendFrame(op: Int, data: ByteArray, off: Int, len: Int) {
        if (closing.get()) throw WsException("WebSocket is closed")
        val n = if (len < 0) data.size else len
        val o = if (len < 0) 0 else off
        sendFrameRaw(op, data, o, n)
    }

    private fun sendFrameRaw(op: Int, data: ByteArray, off: Int, len: Int, waitMs: Long = -1) {
        if (waitMs >= 0) {
            if (!writeLock.tryLock(waitMs, TimeUnit.MILLISECONDS)) return
        } else {
            writeLock.lock()
        }
        try {
            val header = when {
                len < 126 -> 2
                len <= 0xFFFF -> 4
                else -> 10
            }
            val total = header + 4 + len
            if (sendBuf.size < total) sendBuf = ByteArray(maxOf(total, sendBuf.size * 2))
            val b = sendBuf
            b[0] = (0x80 or op).toByte()
            when {
                len < 126 -> b[1] = (0x80 or len).toByte()
                len <= 0xFFFF -> {
                    b[1] = (0x80 or 126).toByte()
                    b[2] = (len shr 8).toByte()
                    b[3] = len.toByte()
                }
                else -> {
                    b[1] = (0x80 or 127).toByte()
                    for (i in 0 until 8) b[2 + i] = (len.toLong() shr (56 - 8 * i)).toByte()
                }
            }
            val mask = maskBytes
            RANDOM.nextBytes(mask)
            System.arraycopy(mask, 0, b, header, 4)
            val p = header + 4
            for (i in 0 until len) b[p + i] = (data[off + i].toInt() xor mask[i and 3].toInt()).toByte()
            try {
                output.write(b, 0, total)
                output.flush()
            } catch (e: IOException) {
                closeSocket()
                throw WsException(e.message ?: "write failed", cause = e)
            }
        } finally {
            writeLock.unlock()
        }
    }

    private fun readLoop() {
        var code = 1006
        var reason = ""
        try {
            val frag = ByteArrayOutputStream()
            var fragOp = 0
            while (true) {
                val b0 = input.read()
                if (b0 < 0) throw EOFException("connection closed")
                val b1 = input.read()
                if (b1 < 0) throw EOFException("connection closed")
                val fin = (b0 and 0x80) != 0
                val op = b0 and 0x0f
                if ((b0 and 0x70) != 0) throw WsException("reserved bits set", 1002)
                val masked = (b1 and 0x80) != 0
                var len = (b1 and 0x7f).toLong()
                if (len == 126L) {
                    len = (readByte() shl 8 or readByte()).toLong()
                } else if (len == 127L) {
                    len = 0
                    for (i in 0 until 8) len = (len shl 8) or readByte().toLong()
                    if (len < 0) throw WsException("bad frame length", 1002)
                }
                if (len > maxMessage) throw WsException("message too big", 1009)
                val mask = if (masked) ByteArray(4).also { readFully(it, 4) } else null
                val payload = ByteArray(len.toInt())
                readFully(payload, payload.size)
                if (mask != null) for (i in payload.indices) payload[i] = (payload[i].toInt() xor mask[i and 3].toInt()).toByte()
                lastRxMs = System.currentTimeMillis()

                when (op) {
                    OP_CLOSE -> {
                        code = if (payload.size >= 2) ((payload[0].toInt() and 255) shl 8) or (payload[1].toInt() and 255) else 1005
                        reason = if (payload.size > 2) String(payload, 2, payload.size - 2, Charsets.UTF_8) else ""
                        if (closing.compareAndSet(false, true)) {
                            try {
                                sendFrameRaw(OP_CLOSE, if (payload.size >= 2) payload.copyOf(2) else EMPTY, 0, if (payload.size >= 2) 2 else 0)
                            } catch (_: Exception) {
                            }
                        }
                        break
                    }
                    OP_PING -> {
                        if (!fin || payload.size > 125) throw WsException("bad control frame", 1002)
                        try {
                            sendFrameRaw(OP_PONG, payload, 0, payload.size)
                        } catch (_: Exception) {
                        }
                    }
                    OP_PONG -> {
                        if (!fin || payload.size > 125) throw WsException("bad control frame", 1002)
                    }
                    OP_TEXT, OP_BINARY, OP_CONT -> {
                        if (op != OP_CONT) {
                            if (fragOp != 0) throw WsException("unexpected data frame", 1002)
                            fragOp = op
                        } else if (fragOp == 0) {
                            throw WsException("unexpected continuation", 1002)
                        }
                        if (fin && frag.size() == 0) {
                            deliver(fragOp, payload)
                            fragOp = 0
                        } else {
                            if (frag.size() + payload.size > maxMessage) throw WsException("message too big", 1009)
                            frag.write(payload)
                            if (fin) {
                                val whole = frag.toByteArray()
                                frag.reset()
                                val o = fragOp
                                fragOp = 0
                                deliver(o, whole)
                            }
                        }
                    }
                    else -> throw WsException("unknown opcode $op", 1002)
                }
            }
        } catch (e: Exception) {
            if (closing.get() && localCode != 0) {
                code = localCode
                reason = localReason
            } else {
                code = (e as? WsException)?.closeCode ?: 1006
                reason = e.message ?: e.javaClass.simpleName
            }
        } finally {
            closing.set(true)
            closeSocket()
            if (notified.compareAndSet(false, true)) {
                try {
                    listener?.onClosed(code, reason)
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun deliver(op: Int, payload: ByteArray) {
        val l = listener ?: return
        if (op == OP_TEXT) l.onText(String(payload, Charsets.UTF_8)) else l.onBinary(payload)
    }

    private fun readByte(): Int {
        val v = input.read()
        if (v < 0) throw EOFException("connection closed")
        return v
    }

    private fun readFully(buf: ByteArray, n: Int) {
        var done = 0
        while (done < n) {
            val r = input.read(buf, done, n - done)
            if (r < 0) throw EOFException("connection closed")
            done += r
        }
    }

    companion object {
        const val OP_CONT = 0x0
        const val OP_TEXT = 0x1
        const val OP_BINARY = 0x2
        const val OP_CLOSE = 0x8
        const val OP_PING = 0x9
        const val OP_PONG = 0xA
        private val EMPTY = ByteArray(0)
        private val RANDOM = SecureRandom()
        private const val GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        private const val MAX_HEADER_BYTES = 16 * 1024

        /**
         * Opens a socket, optionally TLS, and performs the HTTP upgrade. Blocks. [newSocket] returns an
         * unconnected socket (on Android: one that is protected from the VPN).
         */
        fun connect(cfg: ServerConfig, newSocket: () -> Socket): WsClient {
            val deadline = System.currentTimeMillis() + cfg.connectTimeoutMs
            val plain = connectTcp(cfg, newSocket, deadline)
            try {
                plain.tcpNoDelay = true
                try {
                    plain.keepAlive = true
                } catch (_: Exception) {
                }
                plain.soTimeout = cfg.handshakeTimeoutMs
                val sock: Socket = if (cfg.useTls) tls(plain, cfg) else plain
                val rawIn = BufferedInputStream(sock.getInputStream(), 16 * 1024)
                val out = sock.getOutputStream()

                val keyBytes = ByteArray(16).also { RANDOM.nextBytes(it) }
                val key = base64(keyBytes)
                val req = StringBuilder()
                req.append("GET ${cfg.path} HTTP/1.1\r\n")
                req.append("Host: ${cfg.hostHeaderValue}\r\n")
                req.append("Upgrade: websocket\r\n")
                req.append("Connection: Upgrade\r\n")
                req.append("Sec-WebSocket-Key: $key\r\n")
                req.append("Sec-WebSocket-Version: 13\r\n")
                req.append("User-Agent: ${ServerConfig.DEFAULT_UA}\r\n")
                req.append("Accept-Language: en-US,en;q=0.9\r\n")
                req.append("Cache-Control: no-cache\r\n")
                req.append("Pragma: no-cache\r\n")
                req.append("\r\n")
                out.write(req.toString().toByteArray(Charsets.ISO_8859_1))
                out.flush()

                val head = readHead(rawIn)
                val lines = head.split("\r\n")
                val status = lines.firstOrNull().orEmpty()
                val statusCode = status.split(' ').getOrNull(1)?.toIntOrNull() ?: 0
                if (statusCode != 101) {
                    throw WsException(
                        if (statusCode == 0) "Server did not answer with HTTP" else "Server refused the WebSocket upgrade (HTTP $statusCode)",
                        closeCode = 1006,
                    )
                }
                val headers = HashMap<String, String>()
                for (l in lines.drop(1)) {
                    val i = l.indexOf(':')
                    if (i > 0) headers[l.substring(0, i).trim().lowercase()] = l.substring(i + 1).trim()
                }
                val expected = base64(
                    MessageDigest.getInstance("SHA-1").digest((key + GUID).toByteArray(Charsets.ISO_8859_1)),
                )
                if (headers["sec-websocket-accept"] != expected) throw WsException("Bad WebSocket handshake answer")
                sock.soTimeout = 0
                return WsClient(sock, rawIn, out, 16 * 1024 * 1024)
            } catch (e: Exception) {
                try {
                    plain.close()
                } catch (_: Exception) {
                }
                throw if (e is WsException) e else WsException(describe(e), cause = e)
            }
        }

        /** Standard Base64 with padding (java.util.Base64 needs API 26). */
        internal fun base64(data: ByteArray): String {
            val table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            val sb = StringBuilder((data.size + 2) / 3 * 4)
            var i = 0
            while (i < data.size) {
                val b0 = data[i].toInt() and 255
                val b1 = if (i + 1 < data.size) data[i + 1].toInt() and 255 else 0
                val b2 = if (i + 2 < data.size) data[i + 2].toInt() and 255 else 0
                sb.append(table[b0 shr 2])
                sb.append(table[((b0 and 3) shl 4) or (b1 shr 4)])
                sb.append(if (i + 1 < data.size) table[((b1 and 15) shl 2) or (b2 shr 6)] else '=')
                sb.append(if (i + 2 < data.size) table[b2 and 63] else '=')
                i += 3
            }
            return sb.toString()
        }

        private fun describe(e: Exception): String = when (e) {
            is SocketTimeoutException -> "Timed out"
            else -> e.message?.takeIf { it.isNotBlank() } ?: e.javaClass.simpleName
        }

        private fun connectTcp(cfg: ServerConfig, newSocket: () -> Socket, deadline: Long): Socket {
            val addrs = try {
                InetAddress.getAllByName(cfg.host).toList()
            } catch (e: Exception) {
                throw WsException("Cannot resolve ${cfg.host}", cause = e)
            }
            val ordered = addrs.sortedBy { if ((it is java.net.Inet6Address) == cfg.preferIpv6) 0 else 1 }
            var last: Exception? = null
            for ((i, a) in ordered.withIndex()) {
                val left = (deadline - System.currentTimeMillis()).toInt()
                if (left <= 0) break
                // Leave time for the next address when there is one.
                val budget = if (i < ordered.size - 1) maxOf(2000, left / 2) else left
                val s = newSocket()
                try {
                    s.connect(InetSocketAddress(a, cfg.port), minOf(budget, left))
                    return s
                } catch (e: Exception) {
                    last = e
                    try {
                        s.close()
                    } catch (_: Exception) {
                    }
                }
            }
            throw WsException(
                if (last is SocketTimeoutException || last == null) "Connection to ${cfg.host}:${cfg.port} timed out"
                else "Cannot connect to ${cfg.host}:${cfg.port} (${describe(last)})",
                cause = last,
            )
        }

        private fun tls(plain: Socket, cfg: ServerConfig): SSLSocket {
            val ctx = if (cfg.allowInsecure) {
                SSLContext.getInstance("TLS").also { it.init(null, arrayOf<TrustManager>(TrustAll), SecureRandom()) }
            } else {
                SSLContext.getDefault()
            }
            val name = cfg.tlsName
            val ssl = ctx.socketFactory.createSocket(plain, name, cfg.port, true) as SSLSocket
            val params = ssl.sslParameters
            if (!IpUtil.isIpLiteral(name)) {
                try {
                    params.serverNames = listOf(SNIHostName(name))
                } catch (_: Exception) {
                }
            }
            ssl.sslParameters = params
            try {
                ssl.startHandshake()
            } catch (e: IOException) {
                try {
                    ssl.close()
                } catch (_: Exception) {
                }
                throw WsException("TLS handshake failed: ${describe(e)}", cause = e)
            }
            if (!cfg.allowInsecure && !CertNames.verify(name, ssl.session)) {
                try {
                    ssl.close()
                } catch (_: Exception) {
                }
                throw WsException("The server certificate does not match $name")
            }
            return ssl
        }

        private fun readHead(inp: InputStream): String {
            val sb = StringBuilder()
            var state = 0
            while (sb.length < MAX_HEADER_BYTES) {
                val c = inp.read()
                if (c < 0) throw EOFException("connection closed during handshake")
                sb.append(c.toChar())
                state = when {
                    c == '\r'.code && (state == 0 || state == 2) -> state + 1
                    c == '\n'.code && (state == 1 || state == 3) -> state + 1
                    else -> 0
                }
                if (state == 4) return sb.substring(0, sb.length - 4)
            }
            throw WsException("Handshake answer is too long")
        }
    }

    private object TrustAll : X509TrustManager {
        override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
        override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
        override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
    }
}

/** RFC 2818 host name check against the leaf certificate (subject alternative names, then common name). */
object CertNames {
    fun verify(host: String, session: SSLSession?): Boolean {
        val leaf = try {
            session?.peerCertificates?.firstOrNull() as? X509Certificate
        } catch (e: SSLPeerUnverifiedException) {
            null
        } ?: return false
        return matches(host, leaf)
    }

    fun matches(host: String, cert: X509Certificate): Boolean {
        val h = host.lowercase().trim('[', ']')
        val ip = IpUtil.isIpLiteral(h)
        val sans = try {
            cert.subjectAlternativeNames
        } catch (e: CertificateParsingException) {
            null
        }
        if (sans != null) {
            var anyDns = false
            for (entry in sans) {
                val type = entry[0] as? Int ?: continue
                val value = entry[1] as? String ?: continue
                if (type == 7 && ip) {
                    if (sameIp(value, h)) return true
                } else if (type == 2) {
                    anyDns = true
                    if (!ip && dnsMatch(value.lowercase(), h)) return true
                }
            }
            if (anyDns || ip) return false
        }
        if (ip) return false
        val cn = Regex("CN=([^,]+)").find(cert.subjectX500Principal.getName("RFC2253"))?.groupValues?.get(1) ?: return false
        return dnsMatch(cn.lowercase(), h)
    }

    private fun sameIp(a: String, b: String): Boolean = try {
        InetAddress.getByName(a) == InetAddress.getByName(b)
    } catch (e: Exception) {
        false
    }

    private fun dnsMatch(pattern: String, host: String): Boolean {
        if (pattern == host) return true
        if (!pattern.startsWith("*.")) return false
        val suffix = pattern.substring(1) // ".example.com"
        if (!host.endsWith(suffix)) return false
        val label = host.substring(0, host.length - suffix.length)
        return label.isNotEmpty() && !label.contains('.')
    }
}
