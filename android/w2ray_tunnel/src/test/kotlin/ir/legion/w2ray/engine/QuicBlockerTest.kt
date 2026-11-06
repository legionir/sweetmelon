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
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class QuicBlockerTest {
    private val closers = ArrayList<AutoCloseable>()

    @AfterTest
    fun cleanup() {
        closers.reversed().forEach { runCatching { it.close() } }
    }

    /** A client Initial: long header, version 1, 8-byte DCID, 4-byte SCID, padded to 1200 bytes. */
    private fun initial(version: Int = 1, size: Int = 1200): ByteArray {
        val d = ByteArray(size)
        d[0] = 0xC3.toByte()
        d[1] = (version ushr 24).toByte(); d[2] = (version ushr 16).toByte(); d[3] = (version ushr 8).toByte(); d[4] = version.toByte()
        d[5] = 8
        for (i in 0 until 8) d[6 + i] = (0x10 + i).toByte()
        d[14] = 4
        for (i in 0 until 4) d[15 + i] = (0x20 + i).toByte()
        return d
    }

    @Test
    fun answersInitialWithVersionNegotiation() {
        val vn = assertNotNull(QuicBlocker.versionNegotiation(initial()))
        assertTrue((vn[0].toInt() and 0x80) != 0)
        assertContentEquals(byteArrayOf(0, 0, 0, 0), vn.copyOfRange(1, 5))
        // DCID of the answer = the client's SCID, SCID of the answer = the client's DCID.
        assertEquals(4, vn[5].toInt())
        assertContentEquals(byteArrayOf(0x20, 0x21, 0x22, 0x23), vn.copyOfRange(6, 10))
        assertEquals(8, vn[10].toInt())
        assertContentEquals(ByteArray(8) { (0x10 + it).toByte() }, vn.copyOfRange(11, 19))
        // One listed version, not QUIC v1 (1), v2 (0x6b3343cf) or a draft.
        assertEquals(23, vn.size)
        assertContentEquals(byteArrayOf(0x1a, 0x2a, 0x3a, 0x4a), vn.copyOfRange(19, 23))
    }

    @Test
    fun ignoresWhatIsNotAnInitial() {
        assertNull(QuicBlocker.versionNegotiation(initial(size = 300))) // too small
        assertNull(QuicBlocker.versionNegotiation(initial(version = 0))) // a Version Negotiation packet
        assertNull(QuicBlocker.versionNegotiation(ByteArray(1300).also { it[0] = 0x40 })) // short header
        assertNull(QuicBlocker.versionNegotiation(ByteArray(0)))
        // Odd id lengths must not throw: the lengths are only trusted as far as the datagram goes.
        val odd = ByteArray(1200).also { it[0] = 0xC3.toByte(); it[4] = 1; it[5] = 255.toByte() }
        assertEquals(1 + 4 + 1 + 0 + 1 + 255 + 4, QuicBlocker.versionNegotiation(odd)?.size)
    }

    @Test
    fun socksAnswersQuicAndStaysSilentOtherwise() {
        val srv = FakeW2rayServer("pw").also { closers.add(it) }
        val cfg = ServerConfig.fromJson(
            JSONObject("""{"serverHost":"127.0.0.1","serverPort":${srv.port},"useTls":false,"password":"pw","wsPath":"/api/stream"}"""),
        )
        val eng = Engine(cfg, { Socket() }, { _, _ -> }).also { e -> closers.add(AutoCloseable { e.shutdown() }) }
        val socks = SocksServer(eng, "127.0.0.1", 0, null, null, 100, false, false, true, "t", { _, _ -> })
        socks.blockQuic = true
        closers.add(AutoCloseable { socks.stop() })
        val tcp = Socket("127.0.0.1", socks.start()).also { closers.add(it) }
        tcp.soTimeout = 5000
        tcp.getOutputStream().write(byteArrayOf(5, 1, 0)); tcp.getOutputStream().flush()
        val ti = DataInputStream(tcp.getInputStream())
        ti.readFully(ByteArray(2))
        tcp.getOutputStream().write(byteArrayOf(5, 3, 0, 1, 0, 0, 0, 0, 0, 0)); tcp.getOutputStream().flush()
        val head = ByteArray(10).also { ti.readFully(it) }
        val udpPort = ((head[8].toInt() and 255) shl 8) or (head[9].toInt() and 255)

        val udp = DatagramSocket().also { u -> closers.add(AutoCloseable { u.close() }) }
        udp.soTimeout = 3000
        val to = InetAddress.getByName("127.0.0.1")
        val hdr = byteArrayOf(0, 0, 0, 1, 142.toByte(), 250.toByte(), 185.toByte(), 100, 1, 0xBB.toByte())
        val pkt = hdr + initial()
        udp.send(DatagramPacket(pkt, pkt.size, to, udpPort))
        val rb = ByteArray(2000)
        val rp = DatagramPacket(rb, rb.size)
        udp.receive(rp)
        assertContentEquals(hdr, rb.copyOf(10)) // SOCKS5 header names the QUIC server the packet "came from"
        assertEquals(0, rb[10 + 1].toInt() or rb[10 + 2].toInt() or rb[10 + 3].toInt() or rb[10 + 4].toInt())

        // Short-header QUIC and other ports get nothing.
        val other = hdr + ByteArray(1300).also { it[0] = 0x40 }
        udp.send(DatagramPacket(other, other.size, to, udpPort))
        udp.soTimeout = 500
        val none = runCatching { udp.receive(DatagramPacket(ByteArray(2000), 2000)) }
        assertTrue(none.isFailure)
    }
}
