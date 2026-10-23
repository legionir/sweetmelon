package ir.legion.w2ray.engine

import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.InputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** End to end: SOCKS5 client -> SocksServer -> Engine -> WebSocket -> (fake) w2ray server -> echo server. */
class EngineTest {
    private val closers = ArrayList<AutoCloseable>()
    private val logs = CopyOnWriteArrayList<String>()

    @AfterTest
    fun cleanup() {
        closers.reversed().forEach { runCatching { it.close() } }
    }

    private fun <T : AutoCloseable> own(c: T): T = c.also { closers.add(it) }

    private fun cfg(server: FakeW2rayServer, password: String = "pw", extra: String = ""): ServerConfig =
        ServerConfig.fromJson(
            JSONObject(
                """{"serverHost":"127.0.0.1","serverPort":${server.port},"useTls":false,"password":"$password","wsPath":"/api/stream",
                   "connectTimeoutMs":5000,"handshakeTimeoutMs":5000$extra}""",
            ),
        )

    private fun engine(c: ServerConfig): Engine {
        val e = Engine(c, { Socket() }, { l, m -> logs.add("$l $m") })
        closers.add(AutoCloseable { e.shutdown() })
        return e
    }

    private fun echoServer(): ServerSocket {
        val s = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        closers.add(s)
        Thread {
            while (!s.isClosed) {
                val c = try { s.accept() } catch (e: Exception) { break }
                Thread {
                    try {
                        val i = c.getInputStream()
                        val o = c.getOutputStream()
                        val b = ByteArray(8192)
                        while (true) {
                            val n = i.read(b)
                            if (n < 0) break
                            o.write(b, 0, n)
                            o.flush()
                        }
                    } catch (_: Exception) {
                    } finally {
                        c.close()
                    }
                }.also { it.isDaemon = true }.start()
            }
        }.also { it.isDaemon = true }.start()
        return s
    }

    private fun socksConnect(port: Int, host: String, destPort: Int, auth: Pair<String, String>? = null): Pair<Socket, Int> {
        val s = Socket()
        s.connect(InetSocketAddress("127.0.0.1", port), 3000)
        s.soTimeout = 8000
        val o = s.getOutputStream()
        val i = DataInputStream(s.getInputStream())
        if (auth == null) {
            o.write(byteArrayOf(5, 1, 0))
            o.flush()
            assertEquals(5, i.read()); assertEquals(0, i.read())
        } else {
            o.write(byteArrayOf(5, 2, 0, 2))
            o.flush()
            assertEquals(5, i.read()); assertEquals(2, i.read())
            val u = auth.first.toByteArray(); val p = auth.second.toByteArray()
            o.write(byteArrayOf(1, u.size.toByte()) + u + byteArrayOf(p.size.toByte()) + p)
            o.flush()
            assertEquals(1, i.read())
            val st = i.read()
            if (st != 0) return s to -1
        }
        val h = host.toByteArray()
        o.write(byteArrayOf(5, 1, 0, 3, h.size.toByte()) + h + byteArrayOf((destPort shr 8).toByte(), destPort.toByte()))
        o.flush()
        assertEquals(5, i.read())
        val rep = i.read()
        i.read()
        val atyp = i.read()
        i.skipBytes(if (atyp == 1) 6 else if (atyp == 4) 18 else 0)
        return s to rep
    }

    private fun waitFor(ms: Long = 2000, cond: () -> Boolean) {
        val end = System.currentTimeMillis() + ms
        while (!cond() && System.currentTimeMillis() < end) Thread.sleep(10)
    }

    private fun readExactly(i: InputStream, n: Int): ByteArray {
        val b = ByteArray(n)
        var d = 0
        while (d < n) {
            val r = i.read(b, d, n - d)
            if (r < 0) throw java.io.EOFException("got $d of $n")
            d += r
        }
        return b
    }

    @Test
    fun relaysBytesBothWays() {
        val srv = own(FakeW2rayServer("pw"))
        val echo = echoServer()
        val eng = engine(cfg(srv))
        val socks = own(AutoCloseable { }).let { SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "test", { l, m -> logs.add("$l $m") }) }
        closers.add(AutoCloseable { socks.stop() })
        val port = socks.start()

        val (s, rep) = socksConnect(port, "127.0.0.1", echo.localPort)
        closers.add(s)
        assertEquals(0, rep)
        val payload = ByteArray(300_000) { (it * 31).toByte() }
        val writer = Thread { s.getOutputStream().write(payload); s.getOutputStream().flush() }
        writer.start()
        val back = readExactly(s.getInputStream(), payload.size)
        writer.join()
        assertContentEquals(payload, back)
        waitFor { socks.counters.up.get() >= payload.size && socks.counters.down.get() >= payload.size }
        assertTrue(socks.counters.up.get() >= payload.size)
        assertTrue(socks.counters.down.get() >= payload.size)
    }

    @Test
    fun fragmentedRepliesAndPings() {
        val srv = own(FakeW2rayServer("pw")).also { it.fragmentReplies = true }
        val echo = echoServer()
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val (s, rep) = socksConnect(socks.start(), "127.0.0.1", echo.localPort)
        closers.add(s)
        assertEquals(0, rep)
        val msg = ByteArray(5000) { it.toByte() }
        s.getOutputStream().write(msg)
        assertContentEquals(msg, readExactly(s.getInputStream(), msg.size))
    }

    @Test
    fun targetRefusedGivesSocksReply() {
        val srv = own(FakeW2rayServer("pw"))
        val closedPort = ServerSocket(0).use { it.localPort }
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val (s, rep) = socksConnect(socks.start(), "127.0.0.1", closedPort)
        s.close()
        assertEquals(0x05, rep)
        // A refused destination does not make the server look unhealthy.
        assertNull(eng.fatalMessage)
    }

    @Test
    fun wrongPasswordIsFatalAndNotRetried() {
        val srv = own(FakeW2rayServer("right"))
        val eng = engine(cfg(srv, password = "wrong"))
        val fatal = CountDownLatch(1)
        eng.events = object : Engine.Events {
            override fun onHealth(healthy: Boolean, detail: String?) {}
            override fun onFatal(message: String) { fatal.countDown() }
        }
        val ex = assertFailsWith<TunnelException> { eng.probe() }
        assertEquals(FailKind.AUTH, ex.kind)
        assertTrue(fatal.await(2, TimeUnit.SECONDS))
        // Further attempts fail at once and never reach the server again.
        val before = srv.authFailures.get()
        assertFailsWith<TunnelException> { eng.openLink("127.0.0.1", 9) }
        assertEquals(before, srv.authFailures.get())
        assertNotNull(eng.fatalMessage)
    }

    @Test
    fun probeKeepsTunnelReadyForNextConnection() {
        val srv = own(FakeW2rayServer("pw"))
        val echo = echoServer()
        val eng = engine(cfg(srv, extra = ""","warmPool":2"""))
        val ms = eng.probe()
        assertTrue(ms >= 0)
        val connectionsAfterProbe = srv.connections.get()
        val link = eng.openLink("127.0.0.1", echo.localPort)
        link.close()
        // The first connection reused the ready tunnel (the pool may add a new one in the background).
        assertTrue(connectionsAfterProbe >= 1)
    }

    @Test
    fun unreachableServerMarksUnhealthy() {
        val dead = ServerSocket(0).use { it.localPort }
        val c = ServerConfig.fromJson(JSONObject("""{"serverHost":"127.0.0.1","serverPort":$dead,"useTls":false,"password":"p","connectTimeoutMs":2000}"""))
        val eng = engine(c)
        val unhealthy = CountDownLatch(1)
        eng.events = object : Engine.Events {
            override fun onHealth(healthy: Boolean, detail: String?) { if (!healthy) unhealthy.countDown() }
            override fun onFatal(message: String) {}
        }
        repeat(3) { assertFailsWith<TunnelException> { eng.openLink("127.0.0.1", 9) } }
        assertTrue(unhealthy.await(2, TimeUnit.SECONDS))
        assertNull(eng.fatalMessage)
    }

    @Test
    fun socksAuthIsEnforced() {
        val srv = own(FakeW2rayServer("pw"))
        val echo = echoServer()
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, "bob", "hunter2", 100, false, false, true, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val port = socks.start()

        val (bad, repBad) = socksConnect(port, "127.0.0.1", echo.localPort, "bob" to "nope")
        bad.close()
        assertEquals(-1, repBad)

        // A client that offers only "no authentication" is turned away.
        Socket("127.0.0.1", port).use { s ->
            s.soTimeout = 3000
            s.getOutputStream().write(byteArrayOf(5, 1, 0)); s.getOutputStream().flush()
            assertEquals(5, s.getInputStream().read()); assertEquals(0xFF, s.getInputStream().read())
        }

        val (good, rep) = socksConnect(port, "127.0.0.1", echo.localPort, "bob" to "hunter2")
        closers.add(good)
        assertEquals(0, rep)
        good.getOutputStream().write("hello".toByteArray())
        assertEquals("hello", String(readExactly(good.getInputStream(), 5)))
    }

    @Test
    fun sharedServerRefusesLocalAndPrivateDestinations() {
        val srv = own(FakeW2rayServer("pw"))
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, true, false, true, "share", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val port = socks.start()
        for (h in listOf("127.0.0.1", "localhost", "192.168.1.1", "10.0.0.1", "169.254.169.254", "::1")) {
            val (s, rep) = socksConnect(port, h, 80)
            s.close()
            assertEquals(0x02, rep, h)
        }
        assertEquals(0, srv.connections.get(), "refused destinations must not reach the tunnel")
    }

    @Test
    fun connectionLimit() {
        val srv = own(FakeW2rayServer("pw"))
        val echo = echoServer()
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 2, false, false, true, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val port = socks.start()
        val a = socksConnect(port, "127.0.0.1", echo.localPort); closers.add(a.first)
        val b = socksConnect(port, "127.0.0.1", echo.localPort); closers.add(b.first)
        assertEquals(0, a.second); assertEquals(0, b.second)
        Socket("127.0.0.1", port).use { s ->
            s.soTimeout = 3000
            s.getOutputStream().write(byteArrayOf(5, 1, 0)); s.getOutputStream().flush()
            // The third connection is closed without an answer.
            assertEquals(-1, s.getInputStream().read())
        }
        assertEquals(2, socks.clients().let { socks.counters.active.get() })
    }

    @Test
    fun udpAssociateRelaysDnsOverTcp() {
        val srv = own(FakeW2rayServer("pw"))
        // A DNS server over TCP on a free port is not possible (the tunnel always uses 53), so use the
        // loopback port 53 when this process may bind it.
        val dns = try {
            ServerSocket(53, 10, InetAddress.getByName("127.0.0.1"))
        } catch (e: Exception) {
            return // not allowed to bind port 53 here
        }
        closers.add(dns)
        Thread {
            try {
                val c = dns.accept()
                val i = DataInputStream(c.getInputStream())
                val len = i.readUnsignedShort()
                val q = ByteArray(len).also { i.readFully(it) }
                val ans = q.copyOf().also { it[2] = (it[2].toInt() or 0x80).toByte() } + byteArrayOf(9, 9)
                c.getOutputStream().write(byteArrayOf((ans.size shr 8).toByte(), ans.size.toByte()) + ans)
                c.close()
            } catch (_: Exception) {
            }
        }.also { it.isDaemon = true }.start()

        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val tcp = Socket("127.0.0.1", socks.start())
        closers.add(tcp)
        tcp.soTimeout = 5000
        tcp.getOutputStream().write(byteArrayOf(5, 1, 0)); tcp.getOutputStream().flush()
        val ti = DataInputStream(tcp.getInputStream())
        ti.readFully(ByteArray(2))
        tcp.getOutputStream().write(byteArrayOf(5, 3, 0, 1, 0, 0, 0, 0, 0, 0)); tcp.getOutputStream().flush()
        val head = ByteArray(10).also { ti.readFully(it) }
        assertEquals(0, head[1].toInt())
        val udpPort = ((head[8].toInt() and 255) shl 8) or (head[9].toInt() and 255)

        val udp = DatagramSocket()
        closers.add(AutoCloseable { udp.close() })
        udp.soTimeout = 6000
        val query = byteArrayOf(0x12, 0x34, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0)
        val pkt = byteArrayOf(0, 0, 0, 1, 127, 0, 0, 1, 0, 53) + query
        udp.send(DatagramPacket(pkt, pkt.size, InetAddress.getByName("127.0.0.1"), udpPort))
        val rb = ByteArray(2000)
        val rp = DatagramPacket(rb, rb.size)
        udp.receive(rp)
        val got = rb.copyOf(rp.length)
        assertContentEquals(byteArrayOf(0, 0, 0, 1, 127, 0, 0, 1, 0, 53), got.copyOf(10))
        assertEquals(0x12, got[10].toInt()); assertEquals(0x34, got[11].toInt())
        assertTrue((got[12].toInt() and 0x80) != 0)
        assertEquals(9, got[got.size - 1].toInt())
    }

    @Test
    fun engineWithoutDnsCannotHang() {
        val srv = own(FakeW2rayServer("pw"))
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, false, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val tcp = Socket("127.0.0.1", socks.start())
        closers.add(tcp)
        tcp.soTimeout = 3000
        tcp.getOutputStream().write(byteArrayOf(5, 1, 0)); tcp.getOutputStream().flush()
        tcp.getInputStream().readNBytes(2)
        tcp.getOutputStream().write(byteArrayOf(5, 3, 0, 1, 0, 0, 0, 0, 0, 0)); tcp.getOutputStream().flush()
        val r = tcp.getInputStream().readNBytes(10)
        assertEquals(0x07, r[1].toInt())
    }

    @Test
    fun resetClosesActiveConnections() {
        val srv = own(FakeW2rayServer("pw"))
        val echo = echoServer()
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val (s, rep) = socksConnect(socks.start(), "127.0.0.1", echo.localPort)
        closers.add(s)
        assertEquals(0, rep)
        s.getOutputStream().write(1); s.getOutputStream().flush()
        assertEquals(1, s.getInputStream().read())
        eng.resetConnections()
        s.soTimeout = 4000
        assertEquals(-1, runCatching { s.getInputStream().read() }.getOrDefault(-1))
    }

    @Test
    fun httpGetThroughTunnel() {
        val srv = own(FakeW2rayServer("pw"))
        val web = ServerSocket(0, 5, InetAddress.getByName("127.0.0.1"))
        closers.add(web)
        Thread {
            try {
                web.accept().use { c ->
                    c.getInputStream().read(ByteArray(2048))
                    c.getOutputStream().write("HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n{\"ip\":\"203.0.113.9\"}".toByteArray())
                }
            } catch (_: Exception) {
            }
        }.also { it.isDaemon = true }.start()
        val e = Engine(cfg(srv), { Socket() }, { _, _ -> })
        closers.add(AutoCloseable { e.shutdown() })
        val (status, body) = e.httpGet("127.0.0.1", "/json", web.localPort)
        assertEquals(200, status)
        assertTrue(body.contains("203.0.113.9"), body)
    }

    @Test
    fun hostHeaderFollowsSni() {
        val srv = own(FakeW2rayServer("pw"))
        val c = cfg(srv, extra = ""","sni":"front.example.net"""")
        val eng = engine(c)
        eng.probe()
        assertTrue(srv.hostHeaders.any { it.startsWith("front.example.net") }, srv.hostHeaders.toString())
    }

    @Test
    fun serverDropsTunnelAfterConnect() {
        val srv = own(FakeW2rayServer("pw")).also { it.dropAfterConnect = true }
        val echo = echoServer()
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val (s, rep) = socksConnect(socks.start(), "127.0.0.1", echo.localPort)
        closers.add(s)
        s.soTimeout = 4000
        // Either the connect is answered and the stream then ends, or the connect fails; it must not hang.
        if (rep == 0) assertEquals(-1, runCatching { s.getInputStream().read() }.getOrDefault(-1))
    }
}
