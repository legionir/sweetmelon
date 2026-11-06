package ir.legion.w2ray.engine

import org.json.JSONObject
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class CloudflareFallbackTest {
    private val closers = ArrayList<AutoCloseable>()

    @AfterTest
    fun cleanup() {
        closers.reversed().forEach { runCatching { it.close() } }
    }

    private fun cfg(worker: FakeW2rayServer, server: FakeW2rayServer?, extra: String = ""): ServerConfig {
        val fb = if (server != null) {
            ""","fallback":{"serverHost":"127.0.0.1","serverPort":${server.port},"useTls":false,"password":"pw","wsPath":"/api/stream"}"""
        } else {
            ""
        }
        return ServerConfig.fromJson(
            JSONObject(
                """{"transport":"worker","serverHost":"127.0.0.1","serverPort":${worker.port},"useTls":false,"password":"tok","wsPath":"/",
                   "connectTimeoutMs":5000,"handshakeTimeoutMs":5000$fb$extra}""",
            ),
        )
    }

    private fun engine(c: ServerConfig) = Engine(c, { Socket() }, { _, _ -> }).also { e -> closers.add(AutoCloseable { e.shutdown() }) }

    private fun echo(): ServerSocket {
        val s = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        closers.add(s)
        Thread {
            while (!s.isClosed) {
                val c = try { s.accept() } catch (e: Exception) { break }
                Thread {
                    try {
                        val b = ByteArray(4096)
                        while (true) {
                            val n = c.getInputStream().read(b)
                            if (n < 0) break
                            c.getOutputStream().write(b, 0, n)
                        }
                    } catch (_: Exception) {
                    } finally {
                        runCatching { c.close() }
                    }
                }.also { it.isDaemon = true }.start()
            }
        }.also { it.isDaemon = true }.start()
        return s
    }

    private fun roundTrip(link: Link, text: String): String {
        val q = java.util.concurrent.LinkedBlockingQueue<ByteArray>()
        link.setSink(object : Sink {
            override fun onData(data: ByteArray) { q.put(data) }
            override fun onEnd() {}
        })
        val b = text.toByteArray()
        link.send(b, 0, b.size)
        val got = java.io.ByteArrayOutputStream()
        while (got.size() < b.size) got.write(q.poll(3, java.util.concurrent.TimeUnit.SECONDS) ?: break)
        link.close()
        return String(got.toByteArray())
    }

    @Test
    fun rangesCoverTheKnownCloudflareNetworks() {
        for (ip in listOf("104.16.0.1", "104.20.5.5", "172.67.1.1", "162.159.200.1", "188.114.97.3", "[2606:4700::1111]", "2606:4700:4700::1111", "1.1.1.1".takeIf { false } ?: "173.245.48.9")) {
            assertTrue(CloudflareRanges.contains(ip), ip)
        }
        for (host in listOf("8.8.8.8", "104.15.255.255", "104.32.0.0", "172.63.255.255", "2001:4860:4860::8888", "example.com", "")) {
            assertFalse(CloudflareRanges.contains(host), host)
        }
    }

    @Test
    fun cloudflareDestinationsGoStraightToTheServer() {
        val worker = FakeW2rayServer("-", "/", workerToken = "tok").also { closers.add(it) }
        val server = FakeW2rayServer("pw").also { closers.add(it) }
        val eng = engine(cfg(worker, server))
        // Whether the server can reach that address from the test machine does not matter, only who was asked.
        runCatching { eng.openLink("104.16.1.1", 443, 2000).close() }
        assertTrue(worker.targets.isEmpty(), "the Worker must not be asked: ${worker.targets}")
        assertTrue(server.connections.get() >= 1)
    }

    @Test
    fun workerFailureFallsBackAndIsRemembered() {
        val worker = FakeW2rayServer("-", "/", workerToken = "tok").also { closers.add(it) }
        val server = FakeW2rayServer("pw").also { closers.add(it) }
        val echo = echo()
        worker.rejectTargets.add("127.0.0.1:${echo.localPort}")
        val eng = engine(cfg(worker, server))

        assertEquals("one", roundTrip(eng.openLink("127.0.0.1", echo.localPort), "one"))
        assertEquals(1, worker.targets.size)
        // The second connection does not try the Worker again.
        assertEquals("two", roundTrip(eng.openLink("127.0.0.1", echo.localPort), "two"))
        assertEquals(1, worker.targets.size)
        // Other destinations still use the Worker.
        val other = echo()
        assertEquals("three", roundTrip(eng.openLink("127.0.0.1", other.localPort), "three"))
        assertEquals(2, worker.targets.size)
    }

    @Test
    fun withoutAFallbackTheWorkerErrorIsFinal() {
        val worker = FakeW2rayServer("-", "/", workerToken = "tok").also { closers.add(it) }
        val echo = echo()
        worker.rejectTargets.add("127.0.0.1:${echo.localPort}")
        val e = assertFailsWith<TunnelException> { engine(cfg(worker, null)).openLink("127.0.0.1", echo.localPort) }
        assertEquals(FailKind.TARGET, e.kind)

        // Fallback configured but switched off: same.
        val server = FakeW2rayServer("pw").also { closers.add(it) }
        val off = engine(cfg(worker, server, ""","cloudflareFallback":false"""))
        assertFailsWith<TunnelException> { off.openLink("127.0.0.1", echo.localPort) }
        assertEquals(0, server.connections.get())
    }

    @Test
    fun aBadTokenDoesNotFallBack() {
        val worker = FakeW2rayServer("-", "/", workerToken = "other").also { closers.add(it) }
        val server = FakeW2rayServer("pw").also { closers.add(it) }
        val e = assertFailsWith<TunnelException> { engine(cfg(worker, server)).openLink("127.0.0.1", echo().localPort) }
        assertEquals(FailKind.AUTH, e.kind)
        assertEquals(0, server.connections.get())
    }

    @Test
    fun serverExitIgnoresTheWorker() {
        val worker = FakeW2rayServer("-", "/", workerToken = "tok").also { closers.add(it) }
        val server = FakeW2rayServer("pw").also { closers.add(it) }
        val c = cfg(worker, server, ""","exit":"server"""")
        assertFalse(c.isWorker)
        assertEquals(server.port, c.port)
        assertEquals("pw", c.password)
        assertNull(c.fallback)
        assertEquals("pong", roundTrip(engine(c).openLink("127.0.0.1", echo().localPort), "pong"))
        assertEquals(0, worker.connections.get())
        assertFailsWith<ConfigException> { cfg(worker, null, ""","exit":"server"""") }
        assertNotNull(cfg(worker, server).fallback)
    }
}
