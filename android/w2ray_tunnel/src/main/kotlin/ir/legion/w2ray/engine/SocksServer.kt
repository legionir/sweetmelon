package ir.legion.w2ray.engine

import java.io.BufferedInputStream
import java.io.EOFException
import java.io.IOException
import java.io.InputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Semaphore
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * SOCKS5 listener (RFC 1928, RFC 1929) in front of an [Engine].
 *
 * - `CONNECT` goes through the tunnel.
 * - `UDP ASSOCIATE` relays DNS only (datagrams to port 53 become DNS over TCP through the tunnel);
 *   other datagrams are dropped because the tunnel protocol carries TCP only.
 *
 * Two uses: a loopback listener with random credentials for hev-socks5-tunnel, and the listener the user
 * shares with other devices ([restrictDestinations]).
 */
class SocksServer(
    private val engine: Engine,
    private val bindAddress: String,
    private val requestedPort: Int,
    private val username: String?,
    private val password: String?,
    private val maxConnections: Int,
    /** Refuse loopback, link-local and multicast destinations, and private ones unless [allowPrivate]. */
    private val restrictDestinations: Boolean,
    private val allowPrivate: Boolean,
    private val udpDns: Boolean,
    private val name: String,
    private val log: (Char, String) -> Unit,
) {
    val counters = Counters()

    @Volatile
    var port: Int = 0
        private set

    private var server: ServerSocket? = null
    private val running = AtomicBoolean(false)
    private val open = ConcurrentHashMap.newKeySet<Socket>()
    private val perClient = ConcurrentHashMap<String, AtomicInteger>()
    private val guard = FailGuard()
    private val dnsSlots = Semaphore(32)

    /** Addresses of the devices that have connections open now. */
    fun clients(): List<String> = perClient.filter { it.value.get() > 0 }.keys.sorted()

    /** Starts listening. Returns the port (the real one when 0 was requested). */
    fun start(): Int {
        if (!running.compareAndSet(false, true)) return port
        val s = ServerSocket()
        try {
            s.reuseAddress = true
            s.bind(InetSocketAddress(InetAddress.getByName(bindAddress), requestedPort), 256)
        } catch (e: Exception) {
            running.set(false)
            try {
                s.close()
            } catch (_: Exception) {
            }
            throw IOException("Cannot listen on $bindAddress:$requestedPort (${e.message})", e)
        }
        server = s
        port = s.localPort
        engine.newThread(Runnable { acceptLoop(s) }).also { it.name = "w2ray-$name-accept" }.start()
        log('I', "$name listening on $bindAddress:$port")
        return port
    }

    fun stop() {
        if (!running.compareAndSet(true, false)) return
        try {
            server?.close()
        } catch (_: Exception) {
        }
        open.toList().forEach {
            try {
                it.close()
            } catch (_: Exception) {
            }
        }
        open.clear()
        log('I', "$name stopped")
    }

    private fun acceptLoop(s: ServerSocket) {
        while (running.get()) {
            val c = try {
                s.accept()
            } catch (e: Exception) {
                if (running.get()) log('W', "$name accept failed: ${e.message}")
                break
            }
            val ip = c.inetAddress?.hostAddress.orEmpty()
            if (guard.banned(ip) || counters.active.get() + pendingHandshakes.get() >= maxConnections) {
                try {
                    c.close()
                } catch (_: Exception) {
                }
                continue
            }
            open.add(c)
            pendingHandshakes.incrementAndGet()
            engine.execute { serve(c, ip) }
        }
    }

    private val pendingHandshakes = AtomicInteger()

    private fun serve(sock: Socket, ip: String) {
        var counted = false
        try {
            sock.tcpNoDelay = true
            sock.soTimeout = HANDSHAKE_TIMEOUT_MS
            val input = BufferedInputStream(sock.getInputStream(), 4096)
            val out = sock.getOutputStream()

            // Greeting
            if (input.read() != 5) return
            val n = readByte(input)
            val methods = ByteArray(n).also { readFully(input, it) }
            val needAuth = username != null
            val want = if (needAuth) 0x02 else 0x00
            if (methods.none { it.toInt() == want }) {
                out.write(byteArrayOf(5, 0xFF.toByte()))
                return
            }
            out.write(byteArrayOf(5, want.toByte()))
            out.flush()
            if (needAuth) {
                if (readByte(input) != 1) return
                val u = ByteArray(readByte(input)).also { readFully(input, it) }
                val p = ByteArray(readByte(input)).also { readFully(input, it) }
                val ok = constantTimeEquals(u, username!!.toByteArray(Charsets.UTF_8)) and
                    constantTimeEquals(p, password!!.toByteArray(Charsets.UTF_8))
                if (!ok) {
                    guard.fail(ip)
                    out.write(byteArrayOf(1, 1))
                    out.flush()
                    log('W', "$name: wrong credentials from $ip")
                    return
                }
                out.write(byteArrayOf(1, 0))
                out.flush()
            }

            // Request
            if (readByte(input) != 5) return
            val cmd = readByte(input)
            readByte(input) // reserved
            val dest = readAddress(input) ?: run {
                reply(out, 0x08)
                return
            }
            val host = dest.first
            val destPort = dest.second

            when (cmd) {
                1 -> {
                    if (destPort == 0 || (restrictDestinations && IpUtil.isPrivateOrLocal(host, !allowPrivate))) {
                        reply(out, 0x02)
                        log('W', "$name: refused $host:$destPort for $ip")
                        return
                    }
                    val link = try {
                        engine.openLink(host, destPort)
                    } catch (e: TunnelException) {
                        reply(out, if (e.kind == FailKind.TRANSPORT || e.kind == FailKind.AUTH) 0x01 else e.socksReply)
                        log('D', "$name: $host:$destPort failed: ${e.message}")
                        return
                    }
                    reply(out, 0x00)
                    sock.soTimeout = 0
                    perClient.computeIfAbsent(ip) { AtomicInteger() }.incrementAndGet()
                    pendingHandshakes.decrementAndGet()
                    counted = true
                    try {
                        engine.relay(link, sock, input, counters)
                    } finally {
                        perClient[ip]?.decrementAndGet()
                    }
                }
                3 -> {
                    if (!udpDns) {
                        reply(out, 0x07)
                        return
                    }
                    udpAssociate(sock, input, out, ip)
                }
                else -> reply(out, 0x07)
            }
        } catch (e: EOFException) {
            // client went away
        } catch (e: IOException) {
            // reset, timeout, closed
        } catch (e: Exception) {
            log('W', "$name: ${e.javaClass.simpleName}: ${e.message}")
        } finally {
            if (!counted) pendingHandshakes.decrementAndGet()
            open.remove(sock)
            try {
                sock.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun udpAssociate(sock: Socket, input: InputStream, out: java.io.OutputStream, ip: String) {
        val udp = DatagramSocket(null)
        try {
            udp.reuseAddress = true
            udp.bind(InetSocketAddress(0))
            val local = sock.localAddress
            val reply = ArrayList<Byte>()
            reply.addAll(listOf(5, 0, 0))
            if (local is Inet6Address) {
                reply.add(4); local.address.forEach { reply.add(it) }
            } else {
                reply.add(1); local.address.forEach { reply.add(it) }
            }
            reply.add((udp.localPort shr 8).toByte()); reply.add(udp.localPort.toByte())
            out.write(reply.toByteArray())
            out.flush()
            sock.soTimeout = 0

            val clientIp = sock.inetAddress
            val relay = engine.newThread(Runnable { udpLoop(udp, clientIp) })
            relay.name = "w2ray-$name-udp"
            relay.start()
            // The association lives as long as this TCP connection.
            while (input.read() >= 0) {
                // anything the client sends here is ignored
            }
        } finally {
            udp.close()
        }
    }

    private fun udpLoop(udp: DatagramSocket, clientIp: InetAddress) {
        val buf = ByteArray(65535)
        var warned = false
        while (!udp.isClosed) {
            val pkt = DatagramPacket(buf, buf.size)
            try {
                udp.receive(pkt)
            } catch (e: Exception) {
                return
            }
            if (pkt.address != clientIp) continue
            val data = pkt.data.copyOfRange(pkt.offset, pkt.offset + pkt.length)
            val parsed = parseUdp(data) ?: continue
            if (parsed.port != 53) {
                if (!warned) {
                    warned = true
                    log('I', "$name: UDP to port ${parsed.port} dropped (only DNS is relayed)")
                }
                continue
            }
            val from = InetSocketAddress(pkt.address, pkt.port)
            if (!dnsSlots.tryAcquire()) continue
            engine.execute {
                try {
                    val answer = engine.dnsQuery(parsed.host, parsed.payload) ?: return@execute
                    val head = data.copyOfRange(0, parsed.headerLength)
                    val resp = head + answer
                    if (!udp.isClosed) udp.send(DatagramPacket(resp, resp.size, from))
                } catch (_: Exception) {
                } finally {
                    dnsSlots.release()
                }
            }
        }
    }

    internal class UdpPacket(val host: String, val port: Int, val headerLength: Int, val payload: ByteArray)

    private fun parseUdp(d: ByteArray): UdpPacket? {
        if (d.size < 10 || d[0].toInt() != 0 || d[1].toInt() != 0 || d[2].toInt() != 0) return null
        var i = 4
        val host: String
        when (d[3].toInt()) {
            1 -> {
                if (d.size < 10) return null
                host = "${d[4].toInt() and 255}.${d[5].toInt() and 255}.${d[6].toInt() and 255}.${d[7].toInt() and 255}"
                i = 8
            }
            3 -> {
                val l = d[4].toInt() and 255
                if (d.size < 5 + l + 2) return null
                host = String(d, 5, l, Charsets.ISO_8859_1)
                i = 5 + l
            }
            4 -> {
                if (d.size < 22) return null
                host = InetAddress.getByAddress(d.copyOfRange(4, 20)).hostAddress.orEmpty().substringBefore('%')
                i = 20
            }
            else -> return null
        }
        val port = ((d[i].toInt() and 255) shl 8) or (d[i + 1].toInt() and 255)
        val head = i + 2
        return UdpPacket(host, port, head, d.copyOfRange(head, d.size))
    }

    /** Reads ATYP, address and port. Null for an unknown address type. */
    private fun readAddress(input: InputStream): Pair<String, Int>? {
        val host = when (readByte(input)) {
            1 -> ByteArray(4).also { readFully(input, it) }.joinToString(".") { (it.toInt() and 255).toString() }
            3 -> {
                val b = ByteArray(readByte(input)).also { readFully(input, it) }
                String(b, Charsets.ISO_8859_1)
            }
            4 -> InetAddress.getByAddress(ByteArray(16).also { readFully(input, it) }).hostAddress.orEmpty().substringBefore('%')
            else -> return null
        }
        val port = (readByte(input) shl 8) or readByte(input)
        return host to port
    }

    private fun reply(out: java.io.OutputStream, code: Int) {
        out.write(byteArrayOf(5, code.toByte(), 0, 1, 0, 0, 0, 0, 0, 0))
        out.flush()
    }

    private fun readByte(input: InputStream): Int {
        val v = input.read()
        if (v < 0) throw EOFException()
        return v
    }

    private fun readFully(input: InputStream, b: ByteArray) {
        var n = 0
        while (n < b.size) {
            val r = input.read(b, n, b.size - n)
            if (r < 0) throw EOFException()
            n += r
        }
    }

    private fun constantTimeEquals(a: ByteArray, b: ByteArray): Boolean = MessageDigest.isEqual(a, b)

    /** Remembers wrong passwords per address; a few of them in a row ban the address for a while. */
    private class FailGuard {
        private class Entry(var count: Int, var first: Long, var until: Long)

        private val map = ConcurrentHashMap<String, Entry>()

        fun banned(ip: String): Boolean {
            val e = map[ip] ?: return false
            return e.until > System.currentTimeMillis()
        }

        fun fail(ip: String) {
            val now = System.currentTimeMillis()
            val e = map.computeIfAbsent(ip) { Entry(0, now, 0) }
            synchronized(e) {
                if (now - e.first > 60_000) {
                    e.count = 0
                    e.first = now
                }
                e.count++
                if (e.count >= 5) e.until = now + 5 * 60_000
            }
            if (map.size > 4096) map.entries.removeIf { it.value.until < now && now - it.value.first > 60_000 }
        }
    }

    companion object {
        private const val HANDSHAKE_TIMEOUT_MS = 20_000
    }
}
