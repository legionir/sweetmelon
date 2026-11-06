package ir.legion.w2ray.engine

import java.net.InetAddress

/** Address helpers that never touch DNS. */
object IpUtil {
    fun isIpv4(s: String): Boolean {
        val parts = s.split('.')
        if (parts.size != 4) return false
        return parts.all { p -> p.isNotEmpty() && p.length <= 3 && p.all { it in '0'..'9' } && p.toInt() in 0..255 }
    }

    fun isIpv6(s: String): Boolean {
        val t = s.substringBefore('%')
        if (!t.contains(':')) return false
        if (t.any { !(it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' || it == ':' || it == '.') }) return false
        return try {
            InetAddress.getByName(t) // literals only: the characters were checked above, so no lookup happens
            true
        } catch (e: Exception) {
            false
        }
    }

    fun isIpLiteral(s: String) = isIpv4(s) || isIpv6(s)

    /** `255.192.0.0` -> 10. -1 when [mask] is not a contiguous netmask. */
    fun netmaskToPrefix(mask: String): Int {
        if (!isIpv4(mask)) return -1
        val v = ipv4ToLong(mask)
        var bits = 0
        var seenZero = false
        for (i in 31 downTo 0) {
            val one = (v shr i) and 1L == 1L
            if (one) {
                if (seenZero) return -1
                bits++
            } else {
                seenZero = true
            }
        }
        return bits
    }

    fun ipv4ToLong(s: String): Long {
        var v = 0L
        for (p in s.split('.')) v = (v shl 8) or p.toLong()
        return v
    }

    fun longToIpv4(v: Long): String =
        "${(v shr 24) and 255}.${(v shr 16) and 255}.${(v shr 8) and 255}.${v and 255}"

    /** True for destinations a shared proxy must not reach: loopback, wildcard, link-local, private ranges. */
    fun isPrivateOrLocal(host: String, includePrivate: Boolean): Boolean {
        val h = host.trim('[', ']').lowercase()
        if (h == "localhost" || h.endsWith(".localhost")) return true
        if (isIpv4(h)) {
            val v = ipv4ToLong(h)
            val a = (v shr 24).toInt()
            val b = ((v shr 16) and 255).toInt()
            if (a == 127 || a == 0) return true
            if (a >= 224) return true
            if (a == 169 && b == 254) return true
            if (!includePrivate) return false
            return a == 10 || (a == 172 && b in 16..31) || (a == 192 && b == 168) || (a == 100 && b in 64..127)
        }
        if (isIpv6(h)) {
            val bytes = try {
                InetAddress.getByName(h.substringBefore('%')).address
            } catch (e: Exception) {
                return true
            }
            if (bytes.size == 4) return isPrivateOrLocal(longToIpv4(bytes.fold(0L) { acc, b -> (acc shl 8) or (b.toLong() and 255) }), includePrivate)
            val allZeroPrefix = (0 until 15).all { bytes[it].toInt() == 0 }
            if (allZeroPrefix && (bytes[15].toInt() == 0 || bytes[15].toInt() == 1)) return true // :: and ::1
            val first = bytes[0].toInt() and 255
            val second = bytes[1].toInt() and 255
            if (first == 0xfe && (second and 0xc0) == 0x80) return true // fe80::/10
            if (first == 0xff) return true // multicast
            // ::ffff:a.b.c.d
            val mapped = (0 until 10).all { bytes[it].toInt() == 0 } && bytes[10].toInt() == -1 && bytes[11].toInt() == -1
            if (mapped) {
                val v4 = bytes.copyOfRange(12, 16).fold(0L) { acc, b -> (acc shl 8) or (b.toLong() and 255) }
                return isPrivateOrLocal(longToIpv4(v4), includePrivate)
            }
            if (!includePrivate) return false
            return (first and 0xfe) == 0xfc // fc00::/7
        }
        return false
    }
}

/** An IPv4 prefix. */
data class Prefix(val address: Long, val length: Int) {
    val first: Long get() = address and mask()
    val last: Long get() = first or (mask().inv() and 0xffffffffL)

    private fun mask(): Long = if (length == 0) 0L else (0xffffffffL shl (32 - length)) and 0xffffffffL

    fun overlaps(o: Prefix) = first <= o.last && o.first <= last
    fun contains(o: Prefix) = first <= o.first && o.last <= last
    override fun toString() = "${IpUtil.longToIpv4(first)}/$length"

    companion object {
        fun parse(cidr: String): Prefix {
            val (ip, len) = cidr.split('/')
            return Prefix(IpUtil.ipv4ToLong(ip), len.toInt())
        }
    }
}

object Routes {
    /** Private, link-local, multicast and broadcast ranges: what "bypass LAN" keeps out of the VPN. */
    val LAN: List<Prefix> = listOf(
        "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "224.0.0.0/4", "255.255.255.255/32",
    ).map { Prefix.parse(it) }

    /**
     * 0.0.0.0/0 without [excluded], as a list of prefixes. Android before 13 cannot exclude a route, so the
     * complement is routed instead.
     */
    fun complement(excluded: List<Prefix>): List<Prefix> {
        val out = ArrayList<Prefix>()
        fun walk(p: Prefix) {
            if (excluded.none { it.overlaps(p) }) {
                out.add(p)
                return
            }
            if (excluded.any { it.contains(p) }) return
            // p is split further; a /32 always lands in one of the two cases above.
            val len = p.length + 1
            walk(Prefix(p.first, len))
            walk(Prefix(p.first or (1L shl (32 - len)), len))
        }
        walk(Prefix(0, 0))
        return out
    }
}

/** Builds the YAML of hev-socks5-tunnel (https://github.com/heiher/hev-socks5-tunnel, "Config"). */
object HevConfig {
    fun build(
        vpn: VpnSettings,
        socksPort: Int,
        username: String,
        password: String,
        connectTimeoutMs: Int,
        idleTimeoutMs: Int,
        logFile: String,
    ): String {
        val sb = StringBuilder()
        sb.append("tunnel:\n")
        sb.append("  name: tun0\n")
        sb.append("  mtu: ${vpn.mtu}\n")
        sb.append("  multi-queue: false\n")
        if (vpn.enableIpv4) sb.append("  ipv4: ${vpn.tunnelIpv4}\n")
        if (vpn.enableIpv6) sb.append("  ipv6: ${q(vpn.tunnelIpv6)}\n")
        sb.append("  icmp: ${q(if (vpn.icmpReply) "reply" else "off")}\n")

        sb.append("\nsocks5:\n")
        sb.append("  port: $socksPort\n")
        sb.append("  address: 127.0.0.1\n")
        sb.append("  udp: 'udp'\n")
        if (username.isNotEmpty()) {
            sb.append("  username: ${q(username)}\n")
            sb.append("  password: ${q(password)}\n")
        }

        if (vpn.remoteDns) {
            sb.append("\nmapdns:\n")
            sb.append("  address: ${vpn.mapDnsAddress}\n")
            sb.append("  port: ${vpn.mapDnsPort}\n")
            sb.append("  network: ${vpn.mapDnsNetwork}\n")
            sb.append("  netmask: ${vpn.mapDnsNetmask}\n")
            sb.append("  cache-size: ${vpn.mapDnsCacheSize}\n")
        }

        sb.append("\nmisc:\n")
        sb.append("  task-stack-size: ${vpn.taskStackSize}\n")
        sb.append("  tcp-buffer-size: ${vpn.tcpBufferSize}\n")
        if (vpn.maxSessionCount > 0) sb.append("  max-session-count: ${vpn.maxSessionCount}\n")
        sb.append("  connect-timeout: $connectTimeoutMs\n")
        sb.append("  tcp-read-write-timeout: ${if (idleTimeoutMs > 0) idleTimeoutMs else 86_400_000}\n")
        sb.append("  udp-read-write-timeout: 60000\n")
        sb.append("  log-file: ${q(logFile)}\n")
        sb.append("  log-level: ${vpn.logLevel}\n")
        return sb.toString()
    }

    /** Single-quoted YAML scalar. */
    private fun q(s: String) = "'" + s.replace("'", "''") + "'"
}
