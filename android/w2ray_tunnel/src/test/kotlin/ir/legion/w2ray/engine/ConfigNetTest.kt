package ir.legion.w2ray.engine

import org.json.JSONObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ConfigNetTest {
    private fun server(extra: String = "") =
        JSONObject("""{"serverHost":"example.com","serverPort":4431,"password":"secret","wsPath":"/api/stream"$extra}""")

    @Test
    fun serverDefaultsAndHostHeader() {
        val c = ServerConfig.fromJson(server())
        assertTrue(c.useTls)
        assertEquals("example.com:4431", c.hostHeaderValue)
        assertEquals("wss://example.com:4431/api/stream", c.describe())
        val d = ServerConfig.fromJson(JSONObject("""{"serverHost":"example.com","password":"x"}"""))
        assertEquals(443, d.port)
        assertEquals("/", d.path)
        assertEquals("example.com", d.hostHeaderValue)
    }

    @Test
    fun sniAndHostHeaderOverrides() {
        val c = ServerConfig.fromJson(server(",\"sni\":\"front.example.net\",\"hostHeader\":\"real.example.org\""))
        assertEquals("front.example.net", c.tlsName)
        assertEquals("real.example.org", c.hostHeaderValue)
        val d = ServerConfig.fromJson(server(",\"sni\":\"front.example.net\""))
        assertEquals("front.example.net:4431", d.hostHeaderValue)
    }

    @Test
    fun urlForm() {
        val c = ServerConfig.fromJson(JSONObject("""{"url":"wss://tun.example.com:4431/api/stream","password":"p"}"""))
        assertEquals("tun.example.com", c.host)
        assertEquals(4431, c.port)
        assertEquals("/api/stream", c.path)
        assertTrue(c.useTls)
        val p = ServerConfig.fromJson(JSONObject("""{"url":"ws://10.0.0.5/x?y=1","password":"p"}"""))
        assertFalse(p.useTls)
        assertEquals(80, p.port)
        assertEquals("/x?y=1", p.path)
    }

    @Test
    fun serverValidation() {
        assertFailsWith<ConfigException> { ServerConfig.fromJson(JSONObject("""{"password":"p"}""")) }
        assertFailsWith<ConfigException> { ServerConfig.fromJson(JSONObject("""{"serverHost":"a.b"}""")) }
        assertFailsWith<ConfigException> { ServerConfig.fromJson(JSONObject("""{"serverHost":"a b","password":"p"}""")) }
        assertFailsWith<ConfigException> { ServerConfig.fromJson(JSONObject("""{"serverHost":"a.b","serverPort":70000,"password":"p"}""")) }
        assertFailsWith<ConfigException> { ServerConfig.fromJson(JSONObject("""{"url":"ftp://a.b/x","password":"p"}""")) }
    }

    @Test
    fun startRequestModes() {
        val r = StartRequest.parse("""{"serverHost":"a.b","password":"p","share":{"enabled":true,"port":1081}}""")
        assertEquals(StartRequest.Mode.VPN, r.mode)
        assertEquals(1081, r.share.port)
        assertFailsWith<ConfigException> { StartRequest.parse("""{"mode":"proxy","serverHost":"a.b","password":"p"}""") }
        val p = StartRequest.parse("""{"mode":"proxy","serverHost":"a.b","password":"p","share":{"enabled":true}}""")
        assertEquals(StartRequest.Mode.PROXY, p.mode)
        assertFailsWith<ConfigException> { StartRequest.parse("not json") }
        assertFailsWith<ConfigException> {
            StartRequest.parse("""{"serverHost":"a.b","password":"p","share":{"enabled":true,"authEnabled":true}}""")
        }
    }

    @Test
    fun vpnSettingsValidation() {
        assertFailsWith<ConfigException> { VpnSettings.fromJson(JSONObject("""{"splitMode":"include"}""")) }
        assertFailsWith<ConfigException> { VpnSettings.fromJson(JSONObject("""{"enableIpv4":false,"enableIpv6":false}""")) }
        assertFailsWith<ConfigException> { VpnSettings.fromJson(JSONObject("""{"mapDnsNetmask":"255.0.255.0"}""")) }
        val v = VpnSettings.fromJson(JSONObject("""{"tcpBufferSize":8192,"taskStackSize":100}"""))
        assertEquals(20480 + 8192, v.taskStackSize)
        assertEquals(8500, v.mtu)
        assertTrue(v.killSwitch)
    }

    @Test
    fun netmaskPrefix() {
        assertEquals(10, IpUtil.netmaskToPrefix("255.192.0.0"))
        assertEquals(0, IpUtil.netmaskToPrefix("0.0.0.0"))
        assertEquals(32, IpUtil.netmaskToPrefix("255.255.255.255"))
        assertEquals(-1, IpUtil.netmaskToPrefix("255.0.255.0"))
        assertEquals(-1, IpUtil.netmaskToPrefix("nope"))
    }

    @Test
    fun ipLiterals() {
        assertTrue(IpUtil.isIpv4("10.0.0.1"))
        assertFalse(IpUtil.isIpv4("10.0.0.256"))
        assertFalse(IpUtil.isIpv4("example.com"))
        assertTrue(IpUtil.isIpv6("fc00::1"))
        assertTrue(IpUtil.isIpv6("::1"))
        assertFalse(IpUtil.isIpv6("example.com"))
        assertFalse(IpUtil.isIpv6("1234"))
    }

    @Test
    fun privateDestinations() {
        // includePrivate = true refuses private ranges too
        assertTrue(IpUtil.isPrivateOrLocal("127.0.0.1", false), "127.0.0.1/false")
        assertTrue(IpUtil.isPrivateOrLocal("localhost", false), "localhost/false")
        assertTrue(IpUtil.isPrivateOrLocal("::1", false), "::1/false")
        assertTrue(IpUtil.isPrivateOrLocal("169.254.1.1", false), "169.254.1.1/false")
        assertFalse(IpUtil.isPrivateOrLocal("192.168.1.1", false), "192.168.1.1/false")
        assertTrue(IpUtil.isPrivateOrLocal("192.168.1.1", true), "192.168.1.1/true")
        assertTrue(IpUtil.isPrivateOrLocal("10.1.2.3", true), "10.1.2.3/true")
        assertTrue(IpUtil.isPrivateOrLocal("172.20.0.1", true), "172.20.0.1/true")
        assertFalse(IpUtil.isPrivateOrLocal("172.32.0.1", true), "172.32.0.1/true")
        assertTrue(IpUtil.isPrivateOrLocal("fd00::1", true), "fd00::1/true")
        assertTrue(IpUtil.isPrivateOrLocal("::ffff:192.168.0.1", true), "::ffff:192.168.0.1/true")
        assertFalse(IpUtil.isPrivateOrLocal("8.8.8.8", true), "8.8.8.8/true")
        assertFalse(IpUtil.isPrivateOrLocal("example.com", true), "example.com/true")
        assertFalse(IpUtil.isPrivateOrLocal("2001:4860:4860::8888", true), "2001:4860:4860::8888/true")
    }

    @Test
    fun routeComplement() {
        val none = Routes.complement(emptyList())
        assertEquals(listOf("0.0.0.0/0"), none.map { it.toString() })

        val ex = Routes.LAN
        val routes = Routes.complement(ex)
        // No route may overlap an excluded range, and every other address must be covered.
        for (r in routes) for (e in ex) assertFalse(r.overlaps(e), "$r overlaps $e")
        val samples = listOf("1.1.1.1", "8.8.8.8", "9.255.255.255", "11.0.0.0", "100.64.0.1", "172.15.255.255", "172.32.0.0",
            "192.167.255.255", "192.169.0.0", "169.253.255.255", "169.255.0.0", "223.255.255.255", "240.0.0.1", "255.255.255.254")
        for (s in samples) {
            val v = IpUtil.ipv4ToLong(s)
            assertTrue(routes.any { v in it.first..it.last }, "$s is not routed")
        }
        for (s in listOf("10.1.1.1", "172.16.0.1", "172.31.255.255", "192.168.5.5", "169.254.9.9", "224.0.0.1", "239.1.1.1", "255.255.255.255")) {
            val v = IpUtil.ipv4ToLong(s)
            assertFalse(routes.any { v in it.first..it.last }, "$s is routed")
        }
        // The routes are disjoint.
        for (i in routes.indices) for (j in i + 1 until routes.size) assertFalse(routes[i].overlaps(routes[j]))
    }

    @Test
    fun hevConfig() {
        val v = VpnSettings.fromJson(JSONObject("""{"enableIpv6":true,"icmpReply":true}"""))
        val y = HevConfig.build(v, 4321, "user'x", "pw", 35000, 900000, "/data/it's.log")
        assertTrue(y.contains("  mtu: 8500\n"))
        assertTrue(y.contains("  ipv4: 198.18.0.1\n"))
        assertTrue(y.contains("  ipv6: 'fc00::1'\n"))
        assertTrue(y.contains("  icmp: 'reply'\n"))
        assertTrue(y.contains("  port: 4321\n"))
        assertTrue(y.contains("  username: 'user''x'\n"))
        assertTrue(y.contains("mapdns:\n  address: 198.18.0.2\n"))
        assertTrue(y.contains("  task-stack-size: 86016\n"))
        assertTrue(y.contains("  connect-timeout: 35000\n"))
        assertTrue(y.contains("  tcp-read-write-timeout: 900000\n"))
        assertTrue(y.contains("  log-file: '/data/it''s.log'\n"))
        assertFalse(y.contains("max-session-count"))

        val noDns = HevConfig.build(VpnSettings.fromJson(JSONObject("""{"remoteDns":false,"enableIpv6":false}""")), 1, "", "", 1000, 0, "x")
        assertFalse(noDns.contains("mapdns"))
        assertFalse(noDns.contains("ipv6"))
        assertFalse(noDns.contains("username"))
        assertTrue(noDns.contains("tcp-read-write-timeout: 86400000"))
    }

    @Test
    fun base64() {
        assertEquals("", WsClient.base64(ByteArray(0)))
        assertEquals("Zg==", WsClient.base64("f".toByteArray()))
        assertEquals("Zm8=", WsClient.base64("fo".toByteArray()))
        assertEquals("Zm9v", WsClient.base64("foo".toByteArray()))
        assertEquals("Zm9vYg==", WsClient.base64("foob".toByteArray()))
        assertEquals("Zm9vYmE=", WsClient.base64("fooba".toByteArray()))
        assertEquals("Zm9vYmFy", WsClient.base64("foobar".toByteArray()))
    }

    @Test
    fun serverErrorReplies() {
        assertEquals(0x05, Link.replyFor("Socks5 proxy rejected connection - ConnectionRefused"))
        assertEquals(0x04, Link.replyFor("Socks5 proxy rejected connection - HostUnreachable"))
        assertEquals(0x03, Link.replyFor("Socks5 proxy rejected connection - NetworkUnreachable"))
        assertEquals(0x06, Link.replyFor("Proxy connection timed out"))
        assertEquals(0x02, Link.replyFor("Invalid destination"))
        assertEquals(0x01, Link.replyFor("something else"))
    }
}
