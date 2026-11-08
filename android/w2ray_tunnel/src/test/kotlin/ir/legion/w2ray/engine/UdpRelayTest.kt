package ir.legion.w2ray.engine

import org.json.JSONObject
import java.io.DataInputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.Socket
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** UDP flows end to end: app datagram -> SOCKS5 UDP ASSOCIATE -> UdpFlowManager -> WebSocket -> (fake) server -> UDP echo. */
class UdpRelayTest {
    private val closers = ArrayList<AutoCloseable>()

    @AfterTest
    fun cleanup() {
        closers.reversed().forEach { runCatching { it.close() } }
    }

    private class Assoc(val control: Socket, val port: Int)

    private fun setup(mode: Int = 1, blockQuic: Boolean = false, relay: Boolean = true): Triple<FakeW2rayServer, Engine, SocksServer> {
        val srv = FakeW2rayServer("pw").also { it.udpMode = mode; closers.add(it) }
        val cfg = ServerConfig.fromJson(
            JSONObject("""{"serverHost":"127.0.0.1","serverPort":${srv.port},"useTls":false,"password":"pw","wsPath":"/api/stream","connectTimeoutMs":5000,"handshakeTimeoutMs":5000}"""),
        )
        val eng = Engine(cfg, { Socket() }, { _, _ -> }).also { e -> closers.add(AutoCloseable { e.shutdown() }) }
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "t", { _, _ -> })
        socks.blockQuic = blockQuic
        socks.relayUdp = relay
        closers.add(AutoCloseable { socks.stop() })
        return Triple(srv, eng, socks)
    }

    private fun associate(socks: SocksServer): Assoc {
        val tcp = Socket("127.0.0.1", socks.start()).also { closers.add(it) }
        tcp.soTimeout = 5000
        tcp.getOutputStream().write(byteArrayOf(5, 1, 0)); tcp.getOutputStream().flush()
        val ti = DataInputStream(tcp.getInputStream())
        ti.readFully(ByteArray(2))
        tcp.getOutputStream().write(byteArrayOf(5, 3, 0, 1, 0, 0, 0, 0, 0, 0)); tcp.getOutputStream().flush()
        val head = ByteArray(10).also { ti.readFully(it) }
        assertEquals(0, head[1].toInt())
        return Assoc(tcp, ((head[8].toInt() and 255) shl 8) or (head[9].toInt() and 255))
    }

    private fun echo(): DatagramSocket {
        val s = DatagramSocket(0, InetAddress.getByName("127.0.0.1")).also { closers.add(AutoCloseable { it.close() }) }
        Thread {
            val b = ByteArray(65535)
            try {
                while (!s.isClosed) {
                    val p = DatagramPacket(b, b.size)
                    s.receive(p)
                    val r = "echo:".toByteArray() + b.copyOf(p.length)
                    s.send(DatagramPacket(r, r.size, p.address, p.port))
                }
            } catch (_: Exception) {
            }
        }.also { it.isDaemon = true }.start()
        return s
    }

    private fun socksUdp(port: Int, payload: ByteArray): ByteArray =
        byteArrayOf(0, 0, 0, 1, 127, 0, 0, 1, (port shr 8).toByte(), port.toByte()) + payload

    private fun send(client: DatagramSocket, assoc: Assoc, dest: Int, payload: ByteArray) {
        val p = socksUdp(dest, payload)
        client.send(DatagramPacket(p, p.size, InetAddress.getByName("127.0.0.1"), assoc.port))
    }

    private fun receive(client: DatagramSocket, ms: Int = 4000): ByteArray? {
        client.soTimeout = ms
        val b = ByteArray(70000)
        val p = DatagramPacket(b, b.size)
        return try {
            client.receive(p)
            b.copyOf(p.length)
        } catch (_: java.net.SocketTimeoutException) {
            null
        }
    }

    private fun client(): DatagramSocket = DatagramSocket().also { closers.add(AutoCloseable { it.close() }) }

    private fun waitUntil(ms: Long = 3000, f: () -> Boolean): Boolean {
        val end = System.currentTimeMillis() + ms
        while (System.currentTimeMillis() < end) {
            if (f()) return true
            Thread.sleep(20)
        }
        return f()
    }

    @Test
    fun datagramsCrossTheTunnelBothWays() {
        val (srv, _, socks) = setup()
        val e = echo()
        val a = associate(socks)
        val c = client()
        send(c, a, e.localPort, "ntp?".toByteArray())
        val r = assertNotNull(receive(c))
        // The answer carries the SOCKS5 UDP header of the destination and the unchanged payload.
        assertContentEquals(socksUdp(e.localPort, ByteArray(0)), r.copyOf(10))
        assertEquals("echo:ntp?", String(r, 10, r.size - 10))
        // More datagrams on the same (source, destination) are one flow.
        send(c, a, e.localPort, "2".toByteArray()); receive(c)
        send(c, a, e.localPort, "3".toByteArray()); receive(c)
        assertEquals(1, srv.udpOpened.size, srv.udpOpened.toString())
        assertEquals(1, srv.udpSessions.get())
    }

    @Test
    fun flowsOfDifferentAppsAndDestinationsStaySeparate() {
        val (srv, _, socks) = setup()
        val e1 = echo(); val e2 = echo()
        val a = associate(socks)
        val c1 = client(); val c2 = client()
        send(c1, a, e1.localPort, "one".toByteArray())
        send(c2, a, e1.localPort, "two".toByteArray()) // another app, same destination
        send(c1, a, e2.localPort, "three".toByteArray()) // same app, another destination
        // The two answers for c1 come from two different echo servers: their order is not defined.
        val forC1 = setOf(
            String(receive(c1)!!.let { it.copyOfRange(10, it.size) }),
            String(receive(c1)!!.let { it.copyOfRange(10, it.size) }),
        )
        assertEquals(setOf("echo:one", "echo:three"), forC1)
        assertEquals("echo:two", String(receive(c2)!!.let { it.copyOfRange(10, it.size) }))
        assertNull(receive(c2, 300))
        assertEquals(3, srv.udpOpened.size)
        assertEquals(3, srv.udpOpened.map { it.substringAfter('#') }.toSet().size) // three different flow ids
    }

    @Test
    fun associationEndReleasesItsFlows() {
        val (srv, _, socks) = setup()
        val e = echo()
        val a = associate(socks)
        val c = client()
        send(c, a, e.localPort, "x".toByteArray())
        assertNotNull(receive(c))
        a.control.close()
        assertTrue(waitUntil { srv.udpClosed.size == 1 }, "flow was not closed on the server")
    }

    @Test
    fun serverWithoutUdpFallsBackAndStopsTrying() {
        val (srv, eng, socks) = setup(mode = 0)
        val e = echo()
        val a = associate(socks)
        val c = client()
        send(c, a, e.localPort, "x".toByteArray())
        assertNull(receive(c, 6500)) // nothing comes back, nothing crashes
        assertTrue(waitUntil { !eng.udp.available() }, "UDP should be marked unavailable")
        val sessions = srv.connections.get()
        send(c, a, e.localPort, "y".toByteArray())
        Thread.sleep(300)
        assertEquals(sessions, srv.connections.get(), "no new session while UDP is marked unsupported")
        assertEquals(0, srv.udpOpened.size)
    }

    @Test
    fun serverWithUdpDisabledFallsBackAtOnce() {
        val (srv, eng, socks) = setup(mode = 2)
        val e = echo()
        val a = associate(socks)
        val c = client()
        send(c, a, e.localPort, "x".toByteArray())
        assertNull(receive(c, 1500))
        assertTrue(waitUntil { !eng.udp.available() })
        assertEquals(0, srv.udpOpened.size)
    }

    @Test
    fun quicIsBlockedWhileBlockQuicIsOn() {
        val (srv, _, socks) = setup(blockQuic = true)
        val a = associate(socks)
        val c = client()
        val initial = ByteArray(1200).also { it[0] = 0xC3.toByte(); it[4] = 1; it[5] = 4; it[10] = 4 }
        send(c, a, 443, initial)
        val r = assertNotNull(receive(c))
        assertEquals(0, r[11].toInt() or r[12].toInt() or r[13].toInt() or r[14].toInt()) // Version Negotiation
        assertEquals(0, srv.udpOpened.size)
        assertEquals(0, srv.udpSessions.get())
    }

    @Test
    fun refusedQuicIsAnsweredAtOnceSoTheAppUsesTcp() {
        val (srv, _, socks) = setup(blockQuic = false)
        srv.udpRefuse = true
        val a = associate(socks)
        val c = client()
        val initial = ByteArray(1200).also { it[0] = 0xC3.toByte(); it[4] = 1; it[5] = 4; it[10] = 4 }
        send(c, a, 443, initial)
        // The server says "not allowed": the app gets a Version Negotiation packet (version 0) instead of a timeout.
        val r = assertNotNull(receive(c))
        assertEquals(0, r[11].toInt() or r[12].toInt() or r[13].toInt() or r[14].toInt())
        // Later attempts to the same host are answered without asking the server again.
        val opened = srv.udpOpened.size
        send(c, a, 443, initial)
        assertNotNull(receive(c))
        assertEquals(opened, srv.udpOpened.size)
        assertEquals(0, srv.udpOpened.size)
    }

    @Test
    fun relayCanBeTurnedOff() {
        val (srv, _, socks) = setup(relay = false)
        val e = echo()
        val a = associate(socks)
        val c = client()
        send(c, a, e.localPort, "x".toByteArray())
        assertNull(receive(c, 500))
        assertEquals(0, srv.udpSessions.get())
    }

    @Test
    fun resetStartsAFreshSession() {
        val (srv, eng, socks) = setup()
        val e = echo()
        val a = associate(socks)
        val c = client()
        send(c, a, e.localPort, "1".toByteArray())
        assertNotNull(receive(c))
        eng.resetConnections()
        assertEquals(0, eng.udp.activeFlows)
        send(c, a, e.localPort, "2".toByteArray())
        assertEquals("echo:2", String(receive(c)!!.let { it.copyOfRange(10, it.size) }))
        assertEquals(2, srv.udpSessions.get())
        // The new flow never reuses the id of the old one.
        assertEquals(2, srv.udpOpened.map { it.substringAfter('#') }.toSet().size)
    }

    @Test
    fun framesRoundTrip() {
        val f = UdpFrames.frame(UdpFrames.DATA, -2, byteArrayOf(1, 2, 3))
        assertContentEquals(byteArrayOf(2, 0, -1, -1, -1, -2, 0, 3, 1, 2, 3), f)
        val p = assertNotNull(UdpFrames.parse(f))
        assertEquals(-2, p.flowId); assertContentEquals(byteArrayOf(1, 2, 3), p.payload)
        assertNull(UdpFrames.parse(f + byteArrayOf(0)))
        assertNull(UdpFrames.parse(ByteArray(5)))
        assertContentEquals(byteArrayOf(1, 1, 2, 3, 4, 1, 0xBB.toByte()), UdpFrames.address("1.2.3.4", 443))
        assertEquals(19, UdpFrames.address("2001:4860:4860::8888", 53).size)
        assertContentEquals(byteArrayOf(1, 1, 2, 3, 4, 0, 53), UdpFrames.address("::ffff:1.2.3.4", 53))
        assertContentEquals(byteArrayOf(3, 3, 'a'.code.toByte(), '.'.code.toByte(), 'b'.code.toByte(), 0, 80), UdpFrames.address("a.b", 80))
        assertFalse(UdpFrames.idleMs(53) > UdpFrames.idleMs(123))
        assertTrue(UdpFrames.idleMs(443) > UdpFrames.idleMs(123))
    }
}
