package ir.legion.w2ray.engine

import java.net.InetAddress

/**
 * The address ranges Cloudflare announces (https://www.cloudflare.com/ips/). A Worker cannot open a TCP
 * connection to them (`connect()` refuses addresses behind Cloudflare), so traffic to a destination in these
 * ranges has to leave through the user's own server instead.
 */
object CloudflareRanges {
    private val V4 = listOf(
        "173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22", "141.101.64.0/18",
        "108.162.192.0/18", "190.93.240.0/20", "188.114.96.0/20", "197.234.240.0/22", "198.41.128.0/17",
        "162.158.0.0/15", "104.16.0.0/13", "104.24.0.0/14", "172.64.0.0/13", "131.0.72.0/22",
    )
    private val V6 = listOf(
        "2400:cb00::/32", "2606:4700::/32", "2803:f800::/32", "2405:b500::/32", "2405:8100::/32",
        "2a06:98c0::/29", "2c0f:f248::/32",
    )

    private class Net(val addr: ByteArray, val bits: Int)

    private val nets: List<Net> = (V4 + V6).map {
        Net(InetAddress.getByName(it.substringBefore('/')).address, it.substringAfter('/').toInt())
    }

    /** True when [host] is an IP literal inside a Cloudflare range. Host names are not resolved here. */
    fun contains(host: String): Boolean {
        val h = host.trim('[', ']').substringBefore('%')
        if (!IpUtil.isIpLiteral(h)) return false
        val a = try {
            InetAddress.getByName(h).address
        } catch (_: Exception) {
            return false
        }
        // ::ffff:a.b.c.d arrives as 4 bytes from InetAddress, which is what we want.
        for (n in nets) {
            if (n.addr.size != a.size) continue
            if (prefixMatches(a, n.addr, n.bits)) return true
        }
        return false
    }

    private fun prefixMatches(a: ByteArray, b: ByteArray, bits: Int): Boolean {
        var left = bits
        var i = 0
        while (left >= 8) {
            if (a[i] != b[i]) return false
            i++; left -= 8
        }
        if (left == 0) return true
        val mask = (0xFF shl (8 - left)) and 0xFF
        return (a[i].toInt() and mask) == (b[i].toInt() and mask)
    }
}
