package ir.legion.w2ray.engine

import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.EOFException
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.Base64
import java.util.concurrent.atomic.AtomicInteger

/**
 * A stand-in for the w2ray tunnel server (src/tunnel/server.js of the w2ray project): the same WebSocket
 * upgrade, the same JSON control messages and the same close codes, without TLS.
 */
class FakeW2rayServer(
    private val password: String,
    private val path: String = "/api/stream",
    /** Not null: behave like ws-cf-tunnel's worker.js (Bearer token + X-Target on the upgrade, no control frames). */
    private val workerToken: String? = null,
) : AutoCloseable {
    /** `X-Target` values seen in worker mode. */
    val targets = java.util.Collections.synchronizedList(ArrayList<String>())

    /** Worker mode: `X-Target` values answered with 502, like a destination the Worker cannot reach. */
    val rejectTargets: MutableSet<String> = java.util.concurrent.ConcurrentHashMap.newKeySet()

    private val server = ServerSocket().also { it.bind(InetSocketAddress("127.0.0.1", 0)) }
    val port: Int get() = server.localPort
    val connections = AtomicInteger()
    val authFailures = AtomicInteger()
    val hostHeaders = java.util.Collections.synchronizedList(ArrayList<String>())

    /** Send answers as fragments and interleave a ping, to exercise the client's reader. */
    @Volatile
    var fragmentReplies = false

    /** UDP sessions: 1 = supported, 0 = like an older server (the `udp` message is ignored), 2 = answers with an error. */
    @Volatile
    var udpMode = 1

    /** Flows opened / closed by clients (destination as sent, flow id). */
    /** UDP OPEN is answered with an ERROR frame (code 2, NOT_ALLOWED) like a server whose resolver returns a private address. */
    @Volatile
    var udpRefuse = false

    val udpOpened = java.util.Collections.synchronizedList(ArrayList<String>())
    val udpClosed = java.util.Collections.synchronizedList(ArrayList<Int>())
    val udpSessions = AtomicInteger()

    /** Closes the tunnel right after `connected`. */
    @Volatile
    var dropAfterConnect = false

    init {
        Thread {
            while (!server.isClosed) {
                val s = try {
                    server.accept()
                } catch (e: Exception) {
                    break
                }
                Thread { serve(s) }.also { it.isDaemon = true }.start()
            }
        }.also { it.isDaemon = true }.start()
    }

    override fun close() {
        server.close()
    }

    private fun serve(sock: Socket) {
        connections.incrementAndGet()
        var target: Socket? = null
        var udpActive = false
        val udpSocks = java.util.concurrent.ConcurrentHashMap<Int, java.net.DatagramSocket>()
        try {
            val inp = BufferedInputStream(sock.getInputStream())
            val out = sock.getOutputStream()
            val head = readHead(inp)
            val lines = head.split("\r\n")
            val headers = lines.drop(1).associate { it.substringBefore(':').trim().lowercase() to it.substringAfter(':').trim() }
            hostHeaders.add(headers["host"] ?: "")
            if (!lines[0].startsWith("GET $path ")) {
                out.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n".toByteArray())
                return
            }
            if (workerToken != null) {
                acceptWorker(headers, sock, inp, out)
                return
            }
            val accept = Base64.getEncoder().encodeToString(
                MessageDigest.getInstance("SHA-1").digest((headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").toByteArray()),
            )
            out.write(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: $accept\r\n\r\n").toByteArray())
            out.flush()

            var authed = false
            while (true) {
                val (op, payload) = readFrame(inp) ?: break
                when (op) {
                    8 -> {
                        writeFrame(out, 8, payload.copyOf(minOf(2, payload.size)))
                        break
                    }
                    9 -> writeFrame(out, 10, payload)
                    1 -> {
                        val msg = JSONObject(String(payload))
                        val p = msg.optJSONObject("p") ?: JSONObject()
                        when (msg.getString("t")) {
                            "auth" -> {
                                if (p.optString("password") != password) {
                                    authFailures.incrementAndGet()
                                    writeFrame(out, 8, byteArrayOf((4002 shr 8).toByte(), 4002.toByte()) + "Authentication failed".toByteArray())
                                    break
                                }
                                authed = true
                                sendJson(out, "auth_ok", JSONObject().put("id", "test"))
                            }
                            "udp" -> {
                                if (!authed) continue
                                when (udpMode) {
                                    1 -> {
                                        udpActive = true
                                        udpSessions.incrementAndGet()
                                        sendJson(out, "udp_ok", JSONObject().put("v", 1).put("maxFlows", 256).put("maxPayload", 65507))
                                    }
                                    2 -> sendJson(out, "error", JSONObject().put("message", "UDP is disabled"))
                                }
                            }
                            "connect" -> {
                                if (!authed || target != null) continue
                                try {
                                    val t = Socket()
                                    t.connect(InetSocketAddress(p.getString("host"), p.getInt("port")), 3000)
                                    target = t
                                    sendJson(out, "connected", JSONObject().put("host", p.getString("host")).put("port", p.getInt("port")))
                                    if (dropAfterConnect) {
                                        writeFrame(out, 8, byteArrayOf(0x03, 0xE8.toByte()))
                                        break
                                    }
                                    pipeTargetToWs(t, sock, out)
                                } catch (e: Exception) {
                                    sendJson(out, "error", JSONObject().put("message", "Socks5 proxy rejected connection - ${if (e.message?.contains("refused") == true) "ConnectionRefused" else "HostUnreachable"}"))
                                }
                            }
                        }
                    }
                    2 -> if (authed) {
                        if (udpActive) udpFrame(payload, udpSocks, out) else target?.getOutputStream()?.let { it.write(payload); it.flush() }
                    }
                }
            }
        } catch (e: Exception) {
            // connection ended
        } finally {
            udpSocks.values.forEach { runCatching { it.close() } }
            try {
                target?.close()
            } catch (_: Exception) {
            }
            try {
                sock.close()
            } catch (_: Exception) {
            }
        }
    }

    /** One UDP flow frame (src/tunnel/udp.js): OPEN connects a datagram socket, DATA sends, replies come back as DATA. */
    private fun udpFrame(f: ByteArray, socks: java.util.concurrent.ConcurrentHashMap<Int, java.net.DatagramSocket>, out: OutputStream) {
        if (f.size < 8) return
        val type = f[0].toInt() and 255
        val id = ((f[2].toInt() and 255) shl 24) or ((f[3].toInt() and 255) shl 16) or ((f[4].toInt() and 255) shl 8) or (f[5].toInt() and 255)
        val len = ((f[6].toInt() and 255) shl 8) or (f[7].toInt() and 255)
        val payload = f.copyOfRange(8, 8 + len)
        fun frame(t: Int, data: ByteArray): ByteArray = byteArrayOf(t.toByte(), 0, (id ushr 24).toByte(), (id ushr 16).toByte(), (id ushr 8).toByte(), id.toByte(), (data.size shr 8).toByte(), data.size.toByte()) + data
        when (type) {
            1 -> {
                if (udpRefuse) {
                    synchronized(out) { writeRaw(out, 2, true, frame(4, byteArrayOf(2) + "Destination not allowed".toByteArray())) }
                    return
                }
                val host: String
                val port: Int
                when (payload[0].toInt()) {
                    1 -> { host = payload.copyOfRange(1, 5).joinToString(".") { (it.toInt() and 255).toString() }; port = ((payload[5].toInt() and 255) shl 8) or (payload[6].toInt() and 255) }
                    4 -> { host = java.net.InetAddress.getByAddress(payload.copyOfRange(1, 17)).hostAddress.orEmpty(); port = ((payload[17].toInt() and 255) shl 8) or (payload[18].toInt() and 255) }
                    else -> { val n = payload[1].toInt() and 255; host = String(payload, 2, n); port = ((payload[2 + n].toInt() and 255) shl 8) or (payload[3 + n].toInt() and 255) }
                }
                udpOpened.add("$host:$port#$id")
                val d = java.net.DatagramSocket()
                d.connect(java.net.InetAddress.getByName(host), port)
                socks[id] = d
                Thread {
                    val b = ByteArray(65535)
                    try {
                        while (!d.isClosed) {
                            val p = java.net.DatagramPacket(b, b.size)
                            d.receive(p)
                            synchronized(out) { writeRaw(out, 2, true, frame(2, b.copyOf(p.length))) }
                        }
                    } catch (_: Exception) {
                    }
                }.also { it.isDaemon = true }.start()
            }
            2 -> socks[id]?.let { it.send(java.net.DatagramPacket(payload, payload.size)) }
            3 -> {
                udpClosed.add(id)
                socks.remove(id)?.close()
            }
            5 -> {
                if (id == 0) {
                    socks.keys.forEach { udpClosed.add(it) }
                    socks.values.forEach { it.close() }
                    socks.clear()
                } else socks.remove(id)?.close()
            }
        }
    }

    /** The worker.js flow: connect first, answer 502 when that fails, 101 when it works, then relay binary frames. */
    private fun acceptWorker(headers: Map<String, String>, sock: Socket, inp: InputStream, out: OutputStream) {
        fun reply(code: Int, text: String) {
            out.write("HTTP/1.1 $code $text\r\nContent-Length: 0\r\n\r\n".toByteArray())
            out.flush()
        }
        if (headers["authorization"] != "Bearer $workerToken") {
            authFailures.incrementAndGet()
            reply(403, "Forbidden")
            return
        }
        val x = headers["x-target"].orEmpty()
        targets.add(x)
        if (x in rejectTargets) {
            reply(502, "Bad Gateway")
            return
        }
        val host = x.substringBeforeLast(':').trim('[', ']')
        val port = x.substringAfterLast(':').toIntOrNull()
        if (host.isEmpty() || port == null) {
            reply(400, "Bad Request")
            return
        }
        val t = Socket()
        try {
            t.connect(InetSocketAddress(host, port), 3000)
        } catch (e: Exception) {
            reply(502, "Bad Gateway")
            return
        }
        val accept = Base64.getEncoder().encodeToString(
            MessageDigest.getInstance("SHA-1").digest((headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").toByteArray()),
        )
        out.write(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: $accept\r\n\r\n").toByteArray())
        out.flush()
        pipeTargetToWs(t, sock, out)
        try {
            while (true) {
                val (op, payload) = readFrame(inp) ?: break
                when (op) {
                    8 -> break
                    9 -> writeFrame(out, 10, payload)
                    2 -> t.getOutputStream().let { it.write(payload); it.flush() }
                    1 -> if (String(payload) == "fin") t.shutdownOutput()
                }
            }
        } finally {
            t.close()
        }
    }

    private fun pipeTargetToWs(t: Socket, ws: Socket, out: OutputStream) {
        Thread {
            val buf = ByteArray(16384)
            try {
                val i = t.getInputStream()
                while (true) {
                    val n = i.read(buf)
                    if (n < 0) break
                    synchronized(out) {
                        if (fragmentReplies && n > 1) {
                            val h = n / 2
                            writeRaw(out, 0x2, false, buf.copyOfRange(0, h))
                            writeRaw(out, 0x9, true, byteArrayOf(1, 2, 3))
                            writeRaw(out, 0x0, true, buf.copyOfRange(h, n))
                        } else {
                            writeRaw(out, 2, true, buf.copyOf(n))
                        }
                    }
                }
                synchronized(out) { writeRaw(out, 8, true, byteArrayOf(0x03, 0xE8.toByte())) }
            } catch (_: Exception) {
            } finally {
                try {
                    ws.close()
                } catch (_: Exception) {
                }
            }
        }.also { it.isDaemon = true }.start()
    }

    private fun sendJson(out: OutputStream, type: String, p: JSONObject) {
        val s = JSONObject().put("t", type).put("p", p).put("ts", System.currentTimeMillis()).toString().toByteArray()
        synchronized(out) { writeRaw(out, 1, true, s) }
    }

    private fun writeFrame(out: OutputStream, op: Int, payload: ByteArray) = synchronized(out) { writeRaw(out, op, true, payload) }

    private fun writeRaw(out: OutputStream, op: Int, fin: Boolean, payload: ByteArray) {
        val b = java.io.ByteArrayOutputStream()
        b.write((if (fin) 0x80 else 0) or op)
        when {
            payload.size < 126 -> b.write(payload.size)
            payload.size <= 0xFFFF -> {
                b.write(126); b.write(payload.size shr 8); b.write(payload.size and 255)
            }
            else -> {
                b.write(127)
                for (i in 7 downTo 0) b.write((payload.size.toLong() shr (8 * i)).toInt() and 255)
            }
        }
        b.write(payload)
        out.write(b.toByteArray())
        out.flush()
    }

    private fun readHead(inp: InputStream): String {
        val sb = StringBuilder()
        while (!sb.endsWith("\r\n\r\n")) {
            val c = inp.read()
            if (c < 0) throw EOFException()
            sb.append(c.toChar())
        }
        return sb.substring(0, sb.length - 4)
    }

    /** Reads one client frame (masked). Returns (opcode, payload) or null at EOF. */
    private fun readFrame(inp: InputStream): Pair<Int, ByteArray>? {
        val b0 = inp.read()
        if (b0 < 0) return null
        val b1 = inp.read()
        var len = (b1 and 0x7f).toLong()
        if (len == 126L) len = ((inp.read() shl 8) or inp.read()).toLong()
        else if (len == 127L) {
            len = 0
            repeat(8) { len = (len shl 8) or inp.read().toLong() }
        }
        val mask = ByteArray(4)
        if (b1 and 0x80 != 0) readFully(inp, mask) else throw IllegalStateException("client frame not masked")
        val p = ByteArray(len.toInt())
        readFully(inp, p)
        for (i in p.indices) p[i] = (p[i].toInt() xor mask[i and 3].toInt()).toByte()
        return (b0 and 0x0f) to p
    }

    private fun readFully(inp: InputStream, b: ByteArray) {
        var n = 0
        while (n < b.size) {
            val r = inp.read(b, n, b.size - n)
            if (r < 0) throw EOFException()
            n += r
        }
    }
}
