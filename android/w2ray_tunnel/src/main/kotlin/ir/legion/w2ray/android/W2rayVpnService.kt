package ir.legion.w2ray.android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import hev.htproxy.TProxyService
import ir.legion.w2ray.R
import ir.legion.w2ray.engine.ConfigException
import ir.legion.w2ray.engine.Engine
import ir.legion.w2ray.engine.FailKind
import ir.legion.w2ray.engine.HevConfig
import ir.legion.w2ray.engine.IpUtil
import ir.legion.w2ray.engine.Routes
import ir.legion.w2ray.engine.ShareConfig
import ir.legion.w2ray.engine.SocksServer
import ir.legion.w2ray.engine.SplitMode
import ir.legion.w2ray.engine.StartRequest
import ir.legion.w2ray.engine.TunnelException
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.net.Socket
import java.security.SecureRandom
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runs the tunnel: an [Engine] to the w2ray server, a loopback SOCKS5 listener for hev-socks5-tunnel, the TUN
 * interface (VPN mode) and, when asked, a SOCKS5 listener other devices can use.
 *
 * All changes of state happen on one thread ([control]), so start, stop and recovery never overlap.
 */
class W2rayVpnService : VpnService(), Engine.Events {
    private val control = Executors.newSingleThreadExecutor { r -> Thread(r, "w2ray-control").also { it.isDaemon = true } }
    private val ticker: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor { r ->
        Thread(r, "w2ray-ticker").also { it.isDaemon = true }
    }

    private var request: StartRequest? = null
    private var engine: Engine? = null
    private var proxy: SocksServer? = null
    private var shareServer: SocksServer? = null
    private var tun: ParcelFileDescriptor? = null
    private var hevLog: File? = null
    private var hevLogPos = 0L
    private var tickTask: ScheduledFuture<*>? = null
    private var recoverTask: ScheduledFuture<*>? = null
    private var netCallback: ConnectivityManager.NetworkCallback? = null
    private var netSignature = ""
    private var resetTask: ScheduledFuture<*>? = null
    private var unhealthySince = 0L
    private var lastTick = 0L
    private var lastRx = 0L
    private var lastTx = 0L
    private var ticks = 0
    private val running = AtomicBoolean(false)
    private lateinit var notes: Map<String, String>

    // ── Lifecycle ───────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        current = this
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                control.execute { shutdown(Hub.IDLE, null) }
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val req = pending ?: Store.load(this)
                pending = null
                if (req == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                notes = notesOf(req)
                goForeground(req.label, notes["connecting"]!!)
                control.execute { start(req, restored = false) }
            }
            else -> {
                // The system started the service itself (always-on VPN, or after a crash): use the last request.
                val req = Store.load(this)
                if (req == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                notes = notesOf(req)
                goForeground(req.label, notes["connecting"]!!)
                control.execute { start(req, restored = true) }
            }
        }
        return START_NOT_STICKY
    }

    override fun onRevoke() {
        Hub.log('W', "The VPN permission was taken away (another VPN app started or it was turned off)")
        control.execute { shutdown(Hub.IDLE, null) }
    }

    override fun onDestroy() {
        if (current === this) current = null
        // A destroyed service must not leave sockets or threads behind.
        try {
            cleanup()
        } catch (_: Throwable) {
        }
        ticker.shutdownNow()
        control.shutdown()
        super.onDestroy()
    }

    // ── Start ───────────────────────────────────────────────────────

    private fun start(req: StartRequest, restored: Boolean) {
        if (running.get()) cleanup()
        running.set(true)
        request = req
        Hub.resetCounters()
        Hub.mode = if (req.mode == StartRequest.Mode.VPN) "vpn" else "proxy"
        Hub.label = req.label
        Hub.server = req.server.describe()
        Hub.connectedAt = 0
        Hub.share = mapOf("enabled" to false)
        Hub.setState(Hub.CONNECTING)
        Hub.log('I', "Connecting to ${req.server.describe()} (${Hub.mode})")
        try {
            Store.save(this, req)
            val eng = Engine(req.server, { newProtectedSocket() }) { level, text -> Hub.log(level, text) }
            eng.events = this
            engine = eng

            var offline = false
            try {
                val ms = eng.probe()
                Hub.log('I', "Server answered in $ms ms")
            } catch (e: TunnelException) {
                // After a restart by the system the network may not be up yet: wait for it instead of giving up.
                if (!restored || e.kind == FailKind.AUTH) throw e
                offline = true
                Hub.log('W', "Server not reachable yet: ${e.message}")
            }

            val user = randomToken(12)
            val pass = randomToken(24)
            val loop = SocksServer(
                eng, "127.0.0.1", 0, user, pass, req.server.maxConnections, false, false, req.vpn.udpDns, "socks"
            ) { l, m -> Hub.log(l, m) }
            val port = loop.start()
            proxy = loop

            if (req.share.enabled) startShare(eng, req.share)

            if (req.mode == StartRequest.Mode.VPN) {
                establishVpn(req, port, user, pass)
            }

            watchNetwork()
            Hub.connectedAt = System.currentTimeMillis()
            lastTick = System.currentTimeMillis()
            lastRx = 0; lastTx = 0; ticks = 0
            tickTask = ticker.scheduleWithFixedDelay({ safely { tick() } }, 1, 1, TimeUnit.SECONDS)
            if (offline) {
                onHealth(false, "Server not reachable yet")
            } else {
                Hub.setState(Hub.CONNECTED)
                updateNotification(notes["connected"]!!)
            }
            Hub.log('I', "Ready")
        } catch (e: Exception) {
            val msg = userMessage(e)
            Hub.log('E', msg)
            shutdown(Hub.ERROR, msg)
        }
    }

    private fun startShare(eng: Engine, s: ShareConfig) {
        val server = SocksServer(
            eng, s.bind, s.port, if (s.authEnabled) s.username else null, if (s.authEnabled) s.password else null,
            s.maxConnections, true, s.allowPrivate, request?.vpn?.udpDns ?: true, "share"
        ) { l, m -> Hub.log(l, m) }
        server.start()
        shareServer = server
        publishShare()
    }

    private fun establishVpn(req: StartRequest, socksPort: Int, user: String, pass: String) {
        val v = req.vpn
        val b = Builder()
        b.setSession(req.label)
        b.setMtu(v.mtu)
        if (Build.VERSION.SDK_INT >= 29) b.setMetered(false)

        val v6 = v.enableIpv6 || v.blockIpv6
        if (v.enableIpv4) b.addAddress(v.tunnelIpv4, 30)
        if (v6) b.addAddress(v.tunnelIpv6, 126)

        if (v.globalMode) {
            if (v.enableIpv4) {
                if (v.bypassLan) {
                    for (p in Routes.complement(Routes.LAN)) b.addRoute(IpUtil.longToIpv4(p.first), p.length)
                } else {
                    b.addRoute("0.0.0.0", 0)
                }
            }
            if (v6) b.addRoute("::", 0)
        } else {
            val prefix = IpUtil.netmaskToPrefix(v.mapDnsNetmask)
            b.addRoute(v.mapDnsNetwork, prefix)
        }
        if (v.remoteDns) {
            b.addDnsServer(v.mapDnsAddress)
            if (v.enableIpv4) {
                // The DNS address must reach the tunnel even when it lies outside the interface network.
                try {
                    b.addRoute(v.mapDnsAddress, 32)
                } catch (_: Exception) {
                }
            }
        } else {
            b.addDnsServer(v.dnsIpv4)
            if (v.enableIpv6) b.addDnsServer(v.dnsIpv6)
        }

        applySplitTunnel(b, v.splitMode, v.apps, v.excludeGoogleServices)

        val fd = b.establish() ?: throw IllegalStateException("The VPN permission is missing. Allow the connection request first.")
        tun = fd

        val dir = File(filesDir, "w2ray").also { it.mkdirs() }
        val cfg = File(dir, "hev.yml")
        val log = File(dir, "hev.log")
        try {
            log.writeText("")
        } catch (_: Exception) {
        }
        hevLog = log
        hevLogPos = 0
        cfg.writeText(
            HevConfig.build(v, socksPort, user, pass, req.server.connectTimeoutMs + req.server.handshakeTimeoutMs + 5000, req.server.idleTimeoutMs, log.absolutePath),
        )
        TProxyService.loadError()?.let { throw IllegalStateException("The tunnel engine could not be loaded: $it") }
        if (!TProxyService.start(cfg.absolutePath, fd.fd)) throw IllegalStateException("The tunnel engine did not start")
        Hub.log('I', "Interface up (MTU ${v.mtu}, DNS ${if (v.remoteDns) "mapped" else v.dnsIpv4})")
    }

    private fun applySplitTunnel(b: Builder, mode: SplitMode, apps: List<String>, google: Boolean) {
        val self = packageName
        when (mode) {
            SplitMode.INCLUDE -> {
                var added = 0
                for (pkg in apps) {
                    if (pkg == self) continue
                    try {
                        b.addAllowedApplication(pkg)
                        added++
                    } catch (e: PackageManager.NameNotFoundException) {
                        Hub.log('W', "App $pkg is not installed")
                    }
                }
                if (added == 0) throw ConfigException("None of the selected apps is installed")
                Hub.log('I', "Only $added app(s) use the VPN")
            }
            else -> {
                // This app must stay outside the VPN: its own connections to the server would loop.
                try {
                    b.addDisallowedApplication(self)
                } catch (e: PackageManager.NameNotFoundException) {
                    Hub.log('W', "Could not exclude this app: ${e.message}")
                }
                val skip = LinkedHashSet<String>()
                if (mode == SplitMode.EXCLUDE) skip.addAll(apps)
                if (google) skip.addAll(listOf("com.google.android.gms", "com.google.android.gsf"))
                var n = 0
                for (pkg in skip) {
                    if (pkg == self) continue
                    try {
                        b.addDisallowedApplication(pkg)
                        n++
                    } catch (e: PackageManager.NameNotFoundException) {
                        Hub.log('D', "App $pkg is not installed")
                    }
                }
                if (n > 0) Hub.log('I', "$n app(s) bypass the VPN")
            }
        }
    }

    // ── Engine events ───────────────────────────────────────────────

    override fun onHealth(healthy: Boolean, detail: String?) {
        control.execute {
            if (!running.get()) return@execute
            if (healthy) {
                recoverTask?.cancel(false)
                recoverTask = null
                unhealthySince = 0
                Hub.log('I', "Server is reachable again")
                Hub.setState(Hub.CONNECTED)
                updateNotification(notes["connected"]!!)
            } else {
                if (unhealthySince == 0L) unhealthySince = System.currentTimeMillis()
                Hub.log('W', "Server is not reachable: ${detail ?: "no answer"}")
                Hub.setState(Hub.RECONNECTING, detail)
                updateNotification(notes["reconnecting"]!!)
                scheduleRecovery(0)
            }
        }
    }

    override fun onFatal(message: String) {
        control.execute { if (running.get()) shutdown(Hub.ERROR, message) }
    }

    private fun scheduleRecovery(attempt: Int) {
        recoverTask?.cancel(false)
        val delay = RECOVERY_DELAYS[minOf(attempt, RECOVERY_DELAYS.size - 1)]
        recoverTask = ticker.schedule({
            control.execute {
                val eng = engine ?: return@execute
                if (!running.get() || Hub.state != Hub.RECONNECTING) return@execute
                val req = request ?: return@execute
                if (!req.vpn.killSwitch && unhealthySince > 0 && System.currentTimeMillis() - unhealthySince > OPEN_AFTER_MS) {
                    // Without a kill switch the connection is released instead of blocking all traffic.
                    shutdown(Hub.ERROR, "The server could not be reached")
                    return@execute
                }
                try {
                    val ms = eng.probe()
                    Hub.log('I', "Server answered in $ms ms")
                    // Engine.probe() reports success to onHealth(true).
                } catch (e: TunnelException) {
                    if (e.kind != FailKind.AUTH) scheduleRecovery(attempt + 1)
                }
            }
        }, delay, TimeUnit.SECONDS)
    }

    // ── Network changes ─────────────────────────────────────────────

    private fun watchNetwork() {
        val cm = getSystemService(ConnectivityManager::class.java) ?: return
        netSignature = signature(cm)
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = changed(cm)
            override fun onLost(network: Network) = changed(cm)
        }
        try {
            val rq = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                .build()
            cm.registerNetworkCallback(rq, cb)
            netCallback = cb
        } catch (e: Exception) {
            Hub.log('W', "Cannot watch the network: ${e.message}")
        }
    }

    @Suppress("DEPRECATION")
    private fun signature(cm: ConnectivityManager): String = try {
        cm.allNetworks.filter {
            val c = cm.getNetworkCapabilities(it)
            c != null && c.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) && !c.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        }.map { it.toString() }.sorted().joinToString(",")
    } catch (e: Exception) {
        ""
    }

    private fun changed(cm: ConnectivityManager) {
        resetTask?.cancel(false)
        // Several callbacks arrive together when Wi-Fi joins or leaves: act once.
        resetTask = ticker.schedule({
            control.execute {
                if (!running.get()) return@execute
                val now = signature(cm)
                if (now == netSignature) return@execute
                netSignature = now
                Hub.log('I', "Network changed${if (now.isEmpty()) " (offline)" else ""}: restarting connections")
                engine?.resetConnections()
                if (now.isNotEmpty() && Hub.state == Hub.RECONNECTING) scheduleRecovery(0)
            }
        }, 800, TimeUnit.MILLISECONDS)
    }

    // ── Periodic work ───────────────────────────────────────────────

    private fun tick() {
        val eng = engine ?: return
        val req = request ?: return
        val now = System.currentTimeMillis()
        val dt = (now - lastTick).coerceAtLeast(1)
        lastTick = now

        val rx: Long
        val tx: Long
        if (req.mode == StartRequest.Mode.VPN) {
            if (!TProxyService.isRunning) {
                control.execute { if (running.get()) shutdown(Hub.ERROR, "The tunnel engine stopped") }
                return
            }
            val s = TProxyService.stats()
            tx = s?.getOrNull(1) ?: lastTx
            rx = s?.getOrNull(3) ?: lastRx
        } else {
            tx = eng.total.up.get()
            rx = eng.total.down.get()
        }
        Hub.rxRate = ((rx - lastRx).coerceAtLeast(0)) * 1000 / dt
        Hub.txRate = ((tx - lastTx).coerceAtLeast(0)) * 1000 / dt
        lastRx = rx; lastTx = tx
        Hub.rx = rx; Hub.tx = tx
        Hub.activeConnections = eng.activeSessions
        publishShare()
        Hub.emitStats()

        ticks++
        if (ticks % 2 == 0) tailHevLog()
        if (ticks % 3 == 0 && Hub.state == Hub.CONNECTED) {
            updateNotification("${notes["download"]} ${formatRate(Hub.rxRate)}   ${notes["upload"]} ${formatRate(Hub.txRate)}")
        }
    }

    private fun publishShare() {
        val s = shareServer
        val req = request
        if (s == null || req == null) {
            Hub.share = mapOf("enabled" to false)
            return
        }
        Hub.share = mapOf(
            "enabled" to true,
            "bind" to req.share.bind,
            "port" to s.port,
            "auth" to req.share.authEnabled,
            "username" to if (req.share.authEnabled) req.share.username else "",
            "clients" to s.clients(),
            "connections" to s.counters.active.get(),
            "totalConnections" to s.counters.total.get(),
            "rx" to s.counters.down.get(),
            "tx" to s.counters.up.get(),
        )
    }

    private fun tailHevLog() {
        val f = hevLog ?: return
        try {
            if (!f.exists()) return
            RandomAccessFile(f, "r").use { raf ->
                if (raf.length() < hevLogPos) hevLogPos = 0
                if (raf.length() == hevLogPos) return
                raf.seek(hevLogPos)
                val max = minOf(raf.length() - hevLogPos, 32 * 1024L).toInt()
                val buf = ByteArray(max)
                raf.readFully(buf)
                hevLogPos = raf.filePointer
                for (line in String(buf, Charsets.UTF_8).split('\n')) {
                    val t = line.trim()
                    if (t.isEmpty()) continue
                    val level = when {
                        t.contains("[E]") -> 'E'
                        t.contains("[W]") -> 'W'
                        t.contains("[D]") -> 'D'
                        else -> 'I'
                    }
                    Hub.log(level, "[tun] $t")
                }
            }
            if (f.length() > 4 * 1024 * 1024) {
                RandomAccessFile(f, "rw").use { it.setLength(0) }
                hevLogPos = 0
            }
        } catch (_: Exception) {
        }
    }

    // ── Share (live) ────────────────────────────────────────────────

    /** Starts, changes or stops the shared SOCKS5 listener while the tunnel runs. */
    fun reconfigureShare(share: ShareConfig, done: (String?) -> Unit) {
        control.execute {
            val req = request
            val eng = engine
            if (!running.get() || req == null || eng == null) {
                done("The tunnel is not running")
                return@execute
            }
            try {
                shareServer?.stop()
                shareServer = null
                val raw = JSONObject(req.raw.toString())
                if (share.enabled) {
                    raw.put(
                        "share",
                        JSONObject().put("enabled", true).put("bind", share.bind).put("port", share.port)
                            .put("authEnabled", share.authEnabled).put("username", share.username).put("password", share.password)
                            .put("maxConnections", share.maxConnections).put("allowPrivate", share.allowPrivate),
                    )
                } else if (req.mode == StartRequest.Mode.PROXY) {
                    throw ConfigException("Proxy-only mode needs sharing to be turned on")
                } else {
                    raw.remove("share")
                }
                val updated = StartRequest.parse(raw.toString())
                request = updated
                Store.save(this, updated)
                if (share.enabled) startShare(eng, updated.share)
                publishShare()
                Hub.emitStats()
                done(null)
            } catch (e: Exception) {
                Hub.log('E', userMessage(e))
                publishShare()
                done(userMessage(e))
            }
        }
    }

    // ── Stop ────────────────────────────────────────────────────────

    private fun shutdown(finalState: String, message: String?) {
        if (!running.get() && finalState == Hub.IDLE) {
            stopForegroundCompat()
            stopSelf()
            return
        }
        if (finalState == Hub.IDLE) Hub.setState(Hub.DISCONNECTING)
        cleanup()
        Hub.connectedAt = 0
        Hub.rxRate = 0; Hub.txRate = 0
        Hub.share = mapOf("enabled" to false)
        Hub.setState(finalState, message)
        Hub.log('I', if (finalState == Hub.ERROR) "Stopped: $message" else "Disconnected")
        stopForegroundCompat()
        stopSelf()
    }

    private fun cleanup() {
        running.set(false)
        tickTask?.cancel(false); tickTask = null
        recoverTask?.cancel(false); recoverTask = null
        resetTask?.cancel(false); resetTask = null
        netCallback?.let {
            try {
                getSystemService(ConnectivityManager::class.java)?.unregisterNetworkCallback(it)
            } catch (_: Exception) {
            }
        }
        netCallback = null
        try {
            if (TProxyService.loadError() == null && TProxyService.isRunning) TProxyService.stop()
        } catch (_: Throwable) {
        }
        try {
            tun?.close()
        } catch (_: Exception) {
        }
        tun = null
        try {
            shareServer?.stop()
        } catch (_: Exception) {
        }
        shareServer = null
        try {
            proxy?.stop()
        } catch (_: Exception) {
        }
        proxy = null
        engine?.events = null
        try {
            engine?.shutdown()
        } catch (_: Exception) {
        }
        engine = null
        hevLog?.let { runCatching { File(it.parentFile, "hev.yml").delete() } }
    }

    // ── Helpers ─────────────────────────────────────────────────────

    /** The engine of the running tunnel, for requests that need it (IP lookup, speed checks). */
    internal fun engineOrNull(): Engine? = if (running.get()) engine else null

    private fun newProtectedSocket(): Socket {
        val s = Socket()
        try {
            protect(s)
        } catch (_: Exception) {
        }
        return s
    }

    private fun userMessage(e: Exception): String = when (e) {
        is ConfigException -> e.message ?: "Invalid settings"
        is TunnelException -> e.message ?: "Connection failed"
        is IllegalStateException -> e.message ?: "Cannot start"
        is java.io.IOException -> e.message ?: "Input/output error"
        is SecurityException -> "Not allowed: ${e.message}"
        else -> e.message ?: e.javaClass.simpleName
    }

    private fun safely(block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            Hub.log('W', "Internal error: ${t.message}")
        }
    }

    private fun randomToken(n: Int): String {
        val chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        val r = SecureRandom()
        return String(CharArray(n) { chars[r.nextInt(chars.length)] })
    }

    private fun formatRate(b: Long): String = when {
        b < 1024 -> "$b B/s"
        b < 1024 * 1024 -> "${b / 1024} KB/s"
        else -> String.format("%.1f MB/s", b / 1048576.0)
    }

    private fun notesOf(req: StartRequest): Map<String, String> {
        val m = hashMapOf(
            "connecting" to "Connecting…",
            "connected" to "Connected",
            "reconnecting" to "Reconnecting…",
            "disconnect" to "Disconnect",
            "download" to "↓",
            "upload" to "↑",
        )
        req.raw.optJSONObject("notification")?.let { o ->
            for (k in m.keys.toList()) o.optString(k, "").takeIf { it.isNotEmpty() }?.let { m[k] = it }
        }
        return m
    }

    // ── Notification ────────────────────────────────────────────────

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        val ch = NotificationChannel(CHANNEL, "VPN", NotificationManager.IMPORTANCE_LOW)
        ch.setShowBadge(false)
        nm.createNotificationChannel(ch)
    }

    private fun buildNotification(text: String): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val stop = PendingIntent.getService(
            this, 1, Intent(this, W2rayVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_w2ray_stat)
            .setContentTitle(Hub.label.ifEmpty { "VPN" })
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, R.drawable.ic_w2ray_stat),
                    if (::notes.isInitialized) notes["disconnect"] else "Disconnect",
                    stop,
                ).build(),
            )
        if (open != null) b.setContentIntent(open)
        if (Build.VERSION.SDK_INT >= 31) b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        return b.build()
    }

    private fun goForeground(title: String, text: String) {
        Hub.label = title
        val n = buildNotification(text)
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, n, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
        } catch (e: Exception) {
            Hub.log('W', "Cannot show the notification: ${e.message}")
        }
    }

    private fun updateNotification(text: String) {
        try {
            getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {
        }
    }

    private fun stopForegroundCompat() {
        try {
            if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        } catch (_: Exception) {
        }
    }

    companion object {
        const val ACTION_START = "ir.legion.w2ray.START"
        const val ACTION_STOP = "ir.legion.w2ray.STOP"
        private const val CHANNEL = "w2ray_tunnel"
        private const val NOTIFICATION_ID = 7127
        private val RECOVERY_DELAYS = longArrayOf(2, 4, 8, 15, 30)
        private const val OPEN_AFTER_MS = 45_000L

        @Volatile
        var current: W2rayVpnService? = null

        @Volatile
        internal var pending: StartRequest? = null

        /** Starts the service with [req]. The VPN permission must have been granted for VPN mode. */
        fun start(context: Context, req: StartRequest) {
            pending = req
            val i = Intent(context, W2rayVpnService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
        }

        fun stop(context: Context) {
            val i = Intent(context, W2rayVpnService::class.java).setAction(ACTION_STOP)
            context.startService(i)
        }
    }
}

/** The last request, kept so the system can start the service again (always-on VPN). */
internal object Store {
    private const val PREFS = "w2ray_tunnel"
    private const val KEY = "last_request"

    fun save(context: Context, req: StartRequest) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, req.raw.toString()).apply()
    }

    fun load(context: Context): StartRequest? {
        val s = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return null
        return try {
            StartRequest.parse(s)
        } catch (e: Exception) {
            null
        }
    }
}
