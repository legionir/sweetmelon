package ir.legion.w2ray.engine

import org.json.JSONArray
import org.json.JSONObject
import java.net.URI

/** Thrown when a configuration from JavaScript is unusable. The message is shown to the user. */
class ConfigException(message: String) : Exception(message)

/** Connection to a w2ray tunnel server (see `src/tunnel` in the w2ray project). */
data class ServerConfig(
    val host: String,
    val port: Int,
    val useTls: Boolean,
    val password: String,
    val path: String,
    /** TLS server name. Empty: [host]. */
    val sni: String,
    /** HTTP `Host` header of the upgrade request. Empty: [sni], then [host]. */
    val hostHeader: String,
    val allowInsecure: Boolean,
    val connectTimeoutMs: Int,
    val handshakeTimeoutMs: Int,
    val pingIntervalSec: Int,
    val idleTimeoutMs: Int,
    val bufferSize: Int,
    /** Authenticated tunnels kept ready so a new connection skips TLS + upgrade + auth. */
    val warmPool: Int,
    val maxConnections: Int,
    val preferIpv6: Boolean,
) {
    val tlsName: String get() = sni.ifEmpty { host }

    /** Value of the `Host` header: [hostHeader] as given, else [sni] or [host] with the port when it is not the default. */
    val hostHeaderValue: String
        get() {
            if (hostHeader.isNotEmpty()) return hostHeader
            val name = sni.ifEmpty { host }
            val defaultPort = if (useTls) 443 else 80
            val bare = if (name.contains(':') && !name.startsWith("[")) "[$name]" else name
            return if (port == defaultPort) bare else "$bare:$port"
        }

    fun describe(): String = "${if (useTls) "wss" else "ws"}://$host:$port$path"

    companion object {
        const val DEFAULT_UA =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

        fun fromJson(o: JSONObject): ServerConfig {
            var host = o.optString("serverHost", "").trim()
            var port = o.optInt("serverPort", 0)
            var tls = if (o.has("useTls")) o.optBoolean("useTls", true) else o.optBoolean("useSSL", true)
            var path = o.optString("wsPath", "").trim()
            val url = o.optString("url", "").trim()
            if (url.isNotEmpty()) {
                val u = parseUrl(url)
                host = u.host; tls = u.useTls; path = u.path
                if (u.port > 0) port = u.port
            }
            if (port <= 0) port = if (tls) 443 else 80
            if (path.isEmpty()) path = "/"
            if (!path.startsWith("/")) path = "/$path"
            val cfg = ServerConfig(
                host = host,
                port = port,
                useTls = tls,
                password = o.optString("password", ""),
                path = path,
                sni = o.optString("sni", "").trim(),
                hostHeader = o.optString("hostHeader", "").trim(),
                allowInsecure = o.optBoolean("allowInsecure", false),
                connectTimeoutMs = o.optInt("connectTimeoutMs", 15000).coerceIn(1000, 120000),
                handshakeTimeoutMs = o.optInt("handshakeTimeoutMs", 15000).coerceIn(1000, 120000),
                pingIntervalSec = o.optInt("pingIntervalSec", 25).coerceIn(0, 600),
                idleTimeoutMs = o.optInt("idleTimeoutMs", 900000).coerceIn(0, 86_400_000),
                bufferSize = o.optInt("bufferSize", 32768).coerceIn(4096, 262144),
                warmPool = o.optInt("warmPool", 2).coerceIn(0, 16),
                maxConnections = o.optInt("maxConnections", 1024).coerceIn(8, 8192),
                preferIpv6 = o.optBoolean("preferIpv6", false),
            )
            cfg.validate()
            return cfg
        }

        data class ParsedUrl(val host: String, val port: Int, val useTls: Boolean, val path: String)

        /** Parses `wss://host:4431/api/stream` (the `TUNNEL_URL` of the w2ray tunnel client). */
        fun parseUrl(url: String): ParsedUrl {
            val u = try {
                URI(url)
            } catch (e: Exception) {
                throw ConfigException("Invalid server URL")
            }
            val scheme = (u.scheme ?: "").lowercase()
            if (scheme != "ws" && scheme != "wss" && scheme != "https" && scheme != "http") {
                throw ConfigException("Server URL must start with wss:// or ws://")
            }
            val host = (u.host ?: "").trim('[', ']')
            if (host.isEmpty()) throw ConfigException("Server URL has no host")
            val tls = scheme == "wss" || scheme == "https"
            val rawPath = u.rawPath.orEmpty()
            val query = u.rawQuery?.let { "?$it" }.orEmpty()
            return ParsedUrl(host, u.port, tls, (if (rawPath.isEmpty()) "/" else rawPath) + query)
        }
    }

    fun validate() {
        if (host.isEmpty()) throw ConfigException("Server address is required")
        if (port !in 1..65535) throw ConfigException("Server port must be between 1 and 65535")
        if (password.isEmpty()) throw ConfigException("Password is required")
        if (host.any { it.isWhitespace() || it == '/' } || sni.any { it.isWhitespace() }) {
            throw ConfigException("Server address or SNI contains invalid characters")
        }
        if (path.any { it.code < 0x21 || it.code > 0x7e }) {
            throw ConfigException("WebSocket path contains invalid characters")
        }
        if (hostHeader.any { it.code < 0x21 || it.code > 0x7e }) {
            throw ConfigException("Host header contains invalid characters")
        }
    }
}

/** A SOCKS5 listener other devices can use (hotspot / Wi-Fi sharing). */
data class ShareConfig(
    val enabled: Boolean,
    val bind: String,
    val port: Int,
    val authEnabled: Boolean,
    val username: String,
    val password: String,
    val maxConnections: Int,
    /** Allow destinations on private networks. Off: they are refused. */
    val allowPrivate: Boolean,
) {
    fun validate() {
        if (!enabled) return
        if (port !in 1..65535) throw ConfigException("Share port must be between 1 and 65535")
        if (authEnabled && (username.isEmpty() || password.isEmpty())) {
            throw ConfigException("Share username and password are required when authentication is on")
        }
        if (authEnabled && (username.length > 255 || password.length > 255)) {
            throw ConfigException("Share username and password are limited to 255 bytes")
        }
        if (bind.isEmpty()) throw ConfigException("Share bind address is required")
    }

    companion object {
        val DISABLED = ShareConfig(false, "0.0.0.0", 1080, false, "", "", 256, false)

        fun fromJson(o: JSONObject?): ShareConfig {
            if (o == null) return DISABLED
            val cfg = ShareConfig(
                enabled = o.optBoolean("enabled", false),
                bind = o.optString("bind", "0.0.0.0").trim().ifEmpty { "0.0.0.0" },
                port = o.optInt("port", 1080),
                authEnabled = o.optBoolean("authEnabled", false),
                username = o.optString("username", ""),
                password = o.optString("password", ""),
                maxConnections = o.optInt("maxConnections", 256).coerceIn(1, 4096),
                allowPrivate = o.optBoolean("allowPrivate", false),
            )
            cfg.validate()
            return cfg
        }
    }
}

enum class SplitMode { OFF, EXCLUDE, INCLUDE }

/** Settings of the Android VPN interface and of hev-socks5-tunnel. */
data class VpnSettings(
    val mtu: Int,
    val enableIpv4: Boolean,
    val enableIpv6: Boolean,
    /** IPv6 off: still route ::/0 into the tunnel and drop it, so apps cannot leak around the VPN. */
    val blockIpv6: Boolean,
    val tunnelIpv4: String,
    val tunnelIpv6: String,
    /** All traffic (`true`) or only the DNS-mapped range (`false`). */
    val globalMode: Boolean,
    val bypassLan: Boolean,
    val remoteDns: Boolean,
    val mapDnsAddress: String,
    val mapDnsPort: Int,
    val mapDnsNetwork: String,
    val mapDnsNetmask: String,
    val mapDnsCacheSize: Int,
    val dnsIpv4: String,
    val dnsIpv6: String,
    /** Relay UDP datagrams to port 53 as DNS-over-TCP through the tunnel. */
    val udpDns: Boolean,
    val icmpReply: Boolean,
    val tcpBufferSize: Int,
    val taskStackSize: Int,
    val maxSessionCount: Int,
    val logLevel: String,
    val splitMode: SplitMode,
    val apps: List<String>,
    val excludeGoogleServices: Boolean,
    val killSwitch: Boolean,
    val autoReconnect: Boolean,
) {
    companion object {
        fun fromJson(o: JSONObject): VpnSettings {
            val tcpBuf = o.optInt("tcpBufferSize", 65536).coerceIn(4096, 1 shl 20)
            val minStack = 20480 + tcpBuf
            val split = when (o.optString("splitMode", "off").lowercase()) {
                "exclude" -> SplitMode.EXCLUDE
                "include" -> SplitMode.INCLUDE
                else -> SplitMode.OFF
            }
            val mtu = o.optInt("tunnelMtu", 8500).coerceIn(576, 65535)
            val s = VpnSettings(
                mtu = mtu,
                enableIpv4 = o.optBoolean("enableIpv4", true),
                enableIpv6 = o.optBoolean("enableIpv6", false),
                blockIpv6 = o.optBoolean("blockIpv6", true),
                tunnelIpv4 = o.optString("tunnelIpv4", "198.18.0.1"),
                tunnelIpv6 = o.optString("tunnelIpv6", "fc00::1"),
                globalMode = o.optBoolean("globalMode", true),
                bypassLan = o.optBoolean("bypassLan", false),
                remoteDns = o.optBoolean("remoteDns", true),
                mapDnsAddress = o.optString("mapDnsAddress", "198.18.0.2"),
                mapDnsPort = o.optInt("mapDnsPort", 53),
                mapDnsNetwork = o.optString("mapDnsNetwork", "100.64.0.0"),
                mapDnsNetmask = o.optString("mapDnsNetmask", "255.192.0.0"),
                mapDnsCacheSize = o.optInt("mapDnsCacheSize", 10000).coerceIn(16, 1_000_000),
                dnsIpv4 = o.optString("dnsIpv4", "8.8.8.8"),
                dnsIpv6 = o.optString("dnsIpv6", "2001:4860:4860::8888"),
                udpDns = o.optBoolean("udpDns", true),
                icmpReply = o.optBoolean("icmpReply", false),
                tcpBufferSize = tcpBuf,
                taskStackSize = o.optInt("taskStackSize", minStack).coerceAtLeast(minStack),
                maxSessionCount = o.optInt("maxSessionCount", 0).coerceAtLeast(0),
                logLevel = o.optString("logLevel", "warn").lowercase().let {
                    if (it in setOf("debug", "info", "warn", "error")) it else "warn"
                },
                splitMode = split,
                apps = stringList(o.optJSONArray("apps")),
                excludeGoogleServices = o.optBoolean("excludeGoogleServices", false),
                killSwitch = o.optBoolean("killSwitch", true),
                autoReconnect = o.optBoolean("autoReconnect", true),
            )
            s.validate()
            return s
        }

        private fun stringList(a: JSONArray?): List<String> {
            if (a == null) return emptyList()
            val out = LinkedHashSet<String>()
            for (i in 0 until a.length()) {
                val v = a.optString(i, "").trim()
                if (v.isNotEmpty()) out.add(v)
            }
            return out.toList()
        }
    }

    fun validate() {
        if (!enableIpv4 && !enableIpv6) throw ConfigException("Enable IPv4 or IPv6")
        if (enableIpv4 && !IpUtil.isIpv4(tunnelIpv4)) throw ConfigException("Invalid tunnel IPv4 address")
        if (!IpUtil.isIpv4(mapDnsAddress)) throw ConfigException("Invalid mapped DNS address")
        if (!IpUtil.isIpv4(mapDnsNetwork) || !IpUtil.isIpv4(mapDnsNetmask)) {
            throw ConfigException("Invalid mapped DNS network")
        }
        if (IpUtil.netmaskToPrefix(mapDnsNetmask) < 0) throw ConfigException("Invalid mapped DNS netmask")
        if (!remoteDns && !IpUtil.isIpv4(dnsIpv4)) throw ConfigException("Invalid DNS server")
        if (splitMode == SplitMode.INCLUDE && apps.isEmpty()) {
            throw ConfigException("Select at least one app, or turn split tunnelling off")
        }
    }
}

/** What the service is asked to run. */
data class StartRequest(
    val mode: Mode,
    val server: ServerConfig,
    val share: ShareConfig,
    val vpn: VpnSettings,
    /** Shown in the notification. */
    val label: String,
    /** Whole request as received, for the stats/status reply. */
    val raw: JSONObject,
) {
    enum class Mode { VPN, PROXY }

    companion object {
        fun parse(json: String): StartRequest {
            val o = try {
                JSONObject(json)
            } catch (e: Exception) {
                throw ConfigException("Configuration is not valid JSON")
            }
            val mode = when (o.optString("mode", "vpn").lowercase()) {
                "proxy" -> Mode.PROXY
                else -> Mode.VPN
            }
            val server = ServerConfig.fromJson(o)
            val share = ShareConfig.fromJson(o.optJSONObject("share"))
            if (mode == Mode.PROXY && !share.enabled) {
                throw ConfigException("Proxy-only mode needs sharing to be turned on")
            }
            // Proxy-only mode has no interface, so VPN settings are not validated.
            val vpn = if (mode == Mode.VPN) {
                VpnSettings.fromJson(o)
            } else {
                runCatching { VpnSettings.fromJson(o) }.getOrElse { VpnSettings.fromJson(JSONObject()) }
            }
            val label = o.optString("label", "").ifEmpty { server.host }
            return StartRequest(mode, server, share, vpn, label, o)
        }
    }
}
