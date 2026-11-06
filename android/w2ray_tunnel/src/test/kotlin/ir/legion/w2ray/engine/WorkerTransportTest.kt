package ir.legion.w2ray.engine

import org.json.JSONObject
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/** The `transport: "worker"` mode against a stand-in for ws-cf-tunnel's worker.js. */
class WorkerTransportTest {
    private val closers = ArrayList<AutoCloseable>()

    @AfterTest
    fun cleanup() {
        closers.reversed().forEach { runCatching { it.close() } }
    }

    private fun cfg(srv: FakeW2rayServer, token: String = "tok", extra: String = ""): ServerConfig = ServerConfig.fromJson(
        JSONObject(
            """{"transport":"worker","serverHost":"127.0.0.1","serverPort":${srv.port},"useTls":false,"password":"$token",
               "wsPath":"/","connectTimeoutMs":5000,"handshakeTimeoutMs":5000$extra}""",
        ),
    )

    private fun engine(c: ServerConfig): Engine = Engine(c, { Socket() }, { _, _ -> }).also { e -> closers.add(AutoCloseable { e.shutdown() }) }

    private fun echo(): ServerSocket {
        val s = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        closers.add(s)
        Thread {
            while (!s.isClosed) {
                val c = try { s.accept() } catch (e: Exception) { break }
                Thread {
                    try {
                        val i = c.getInputStream()
                        val o = c.getOutputStream()
                        val b = ByteArray(4096)
                        while (true) {
                            val n = i.read(b)
                            if (n < 0) break
                            o.write(b, 0, n); o.flush()
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

    @Test
    fun relaysThroughTheWorker() {
        val srv = FakeW2rayServer("unused", "/", workerToken = "tok").also { closers.add(it) }
        val echo = echo()
        val eng = engine(cfg(srv))
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "t", { _, _ -> })
        closers.add(AutoCloseable { socks.stop() })
        val port = socks.start()
        val s = Socket("127.0.0.1", port).also { closers.add(it) }
        s.soTimeout = 5000
        val o = s.getOutputStream()
        val i = s.getInputStream()
        o.write(byteArrayOf(5, 1, 0)); o.flush(); i.readNBytes(2)
        val ep = echo.localPort
        o.write(byteArrayOf(5, 1, 0, 1, 127, 0, 0, 1, (ep shr 8).toByte(), ep.toByte())); o.flush()
        assertEquals(0, i.readNBytes(10)[1].toInt())
        o.write("hello worker".toByteArray()); o.flush()
        assertEquals("hello worker", String(i.readNBytes(12)))
        assertEquals(listOf("127.0.0.1:$ep"), srv.targets.toList())
        // No w2ray handshake at all: not a single control frame, one WebSocket per destination.
        assertEquals(1, srv.connections.get())
    }

    @Test
    fun badTokenIsFatalAndUnreachableTargetIsNot() {
        val srv = FakeW2rayServer("unused", "/", workerToken = "tok").also { closers.add(it) }
        val bad = engine(cfg(srv, token = "wrong"))
        val e = assertFailsWith<TunnelException> { bad.openLink("127.0.0.1", 9) }
        assertEquals(FailKind.AUTH, e.kind)

        val eng = engine(cfg(srv))
        val closedPort = ServerSocket(0).use { it.localPort }
        val t = assertFailsWith<TunnelException> { eng.openLink("127.0.0.1", closedPort) }
        assertEquals(FailKind.TARGET, t.kind) // HTTP 502 from the Worker
        assertTrue(t.socksReply != 0)
        eng.openLink("127.0.0.1", echo().localPort).close() // the engine is still usable
    }

    @Test
    fun probeToleratesATargetFailure() {
        val srv = FakeW2rayServer("unused", "/", workerToken = "tok").also { closers.add(it) }
        // 8.8.8.8:53 is not reachable from the test machine through the fake: a 502 still proves the Worker answered.
        val ms = engine(cfg(srv)).probe()
        assertTrue(ms >= 0)
        assertFailsWith<TunnelException> { engine(cfg(srv, token = "no")).probe() }
    }

    @Test
    fun workerNeedsAToken() {
        assertFailsWith<ConfigException> {
            ServerConfig.fromJson(JSONObject("""{"transport":"worker","serverHost":"w.example.workers.dev"}"""))
        }
        assertFailsWith<ConfigException> {
            ServerConfig.fromJson(JSONObject("""{"transport":"nope","serverHost":"x","password":"p"}"""))
        }
    }
}
