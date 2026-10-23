package ir.legion.w2ray.android

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import hev.htproxy.TProxyService
import ir.legion.w2ray.engine.ConfigException
import ir.legion.w2ray.engine.Engine
import ir.legion.w2ray.engine.ServerConfig
import ir.legion.w2ray.engine.ShareConfig
import ir.legion.w2ray.engine.StartRequest
import ir.legion.w2ray.engine.TunnelException
import org.json.JSONObject
import java.net.Socket
import java.util.concurrent.Executors

/**
 * The only door of this module. The host app calls it by reflection (so the app compiles without the
 * module) with plain values: strings, numbers, booleans, lists and maps.
 *
 * Every call ends with [done] exactly once: `done(result, null, null)` or `done(null, code, message)`.
 */
object W2rayApi {
    const val VERSION = "1.0.0"

    private val worker = Executors.newCachedThreadPool { r -> Thread(r, "w2ray-api").also { it.isDaemon = true } }
    private val main = Handler(Looper.getMainLooper())

    /** Receives state, log and stats events. Called on arbitrary threads. */
    @JvmStatic
    fun setEventListener(listener: ((Map<String, Any?>) -> Unit)?) {
        Hub.listener = listener
    }

    @JvmStatic
    fun call(context: Context, method: String, args: Map<*, *>?, done: (Any?, String?, String?) -> Unit) {
        val ctx = context.applicationContext
        val a = args ?: emptyMap<Any, Any>()
        val reply = Once(done)
        worker.execute {
            try {
                dispatch(ctx, method, a, reply)
            } catch (e: ConfigException) {
                reply.fail("CONFIG", e.message ?: "Invalid settings")
            } catch (e: TunnelException) {
                reply.fail("TUNNEL", e.message ?: "Connection failed")
            } catch (e: Throwable) {
                reply.fail("ERROR", e.message ?: e.javaClass.simpleName)
            }
        }
    }

    private fun dispatch(ctx: Context, method: String, a: Map<*, *>, reply: Once) {
        when (method) {
            "info" -> reply.ok(
                mapOf(
                    "version" to VERSION,
                    "sdk" to Build.VERSION.SDK_INT,
                    "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
                    "nativeLoaded" to (TProxyService.loadError() == null),
                    "nativeError" to TProxyService.loadError(),
                ),
            )

            "status" -> reply.ok(Hub.snapshot())

            "logs" -> reply.ok(Hub.logs())

            "clearLogs" -> {
                Hub.clearLogs()
                reply.ok(true)
            }

            // Asks for the VPN permission. true when granted (or already granted).
            "prepare" -> {
                val needs = try {
                    VpnService.prepare(ctx) != null
                } catch (e: Exception) {
                    true
                }
                if (!needs) {
                    reply.ok(true)
                    return
                }
                VpnPermissionActivity.callback = { granted -> reply.ok(granted) }
                main.post {
                    try {
                        ctx.startActivity(
                            Intent(ctx, VpnPermissionActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (e: Exception) {
                        VpnPermissionActivity.callback = null
                        reply.fail("PERMISSION", e.message ?: "Cannot ask for the VPN permission")
                    }
                }
            }

            "start" -> {
                val json = configJson(a)
                val req = StartRequest.parse(json)
                if (req.mode == StartRequest.Mode.VPN && VpnService.prepare(ctx) != null) {
                    reply.fail("PERMISSION", "The VPN permission has not been granted")
                    return
                }
                W2rayVpnService.start(ctx, req)
                reply.ok(true)
            }

            "stop" -> {
                if (Hub.state == Hub.IDLE || Hub.state == Hub.ERROR) {
                    reply.ok(true)
                } else {
                    W2rayVpnService.stop(ctx)
                    reply.ok(true)
                }
            }

            // Shares (or stops sharing) the connection while the tunnel runs.
            "setShare" -> {
                val svc = W2rayVpnService.current
                if (svc == null) {
                    reply.fail("NOT_RUNNING", "The tunnel is not running")
                    return
                }
                val o = shareJson(a)
                val share = ShareConfig.fromJson(o)
                svc.reconfigureShare(share) { err ->
                    if (err == null) reply.ok(Hub.snapshot()) else reply.fail("SHARE", err)
                }
            }

            "addresses" -> reply.ok(Apps.addresses())

            "apps" -> reply.ok(Apps.list(ctx))

            "appIcon" -> {
                val pkg = a["packageName"] as? String
                if (pkg.isNullOrEmpty()) {
                    reply.fail("ARGUMENT", "packageName is required")
                    return
                }
                reply.ok(Apps.icon(ctx, pkg, (a["size"] as? Number)?.toInt() ?: 48))
            }

            // Reaches the server with the given settings without starting a VPN. Returns milliseconds.
            "test" -> {
                val cfg = ServerConfig.fromJson(JSONObject(configJson(a)))
                val engine = Engine(cfg, { Socket() }) { _, _ -> }
                try {
                    val auth = engine.probe()
                    val result = HashMap<String, Any?>()
                    result["serverMs"] = auth
                    if (a["deep"] == true) {
                        result["targetMs"] = try {
                            engine.testTarget("connectivitycheck.gstatic.com", 80)
                        } catch (e: TunnelException) {
                            -1L
                        }
                    }
                    reply.ok(result)
                } finally {
                    engine.shutdown()
                }
            }

            // Public IP, location and latency as seen from the server's side. Needs a running tunnel.
            "netInfo" -> {
                val eng = W2rayVpnService.current?.engineOrNull()
                if (eng == null) {
                    reply.fail("NOT_RUNNING", "The tunnel is not running")
                    return
                }
                reply.ok(netInfo(eng))
            }

            "openVpnSettings" -> {
                main.post {
                    try {
                        ctx.startActivity(Intent(Settings.ACTION_VPN_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        reply.ok(true)
                    } catch (e: Exception) {
                        reply.fail("ERROR", e.message ?: "Cannot open the settings")
                    }
                }
            }

            else -> reply.fail("UNKNOWN_METHOD", "Unknown method: $method")
        }
    }

    private fun netInfo(eng: Engine): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        out["serverMs"] = -1L
        out["targetMs"] = -1L
        val threads = listOf(
            Thread {
                try {
                    val (status, body) = eng.httpGet(
                        "ip-api.com",
                        "/json/?fields=status,country,countryCode,regionName,city,isp,org,timezone,query",
                    )
                    if (status == 200) {
                        val j = JSONObject(body)
                        if (j.optString("status") == "success") {
                            out["ip"] = j.optString("query")
                            out["country"] = j.optString("country")
                            out["countryCode"] = j.optString("countryCode")
                            out["region"] = j.optString("regionName")
                            out["city"] = j.optString("city")
                            out["isp"] = j.optString("isp")
                            out["org"] = j.optString("org")
                            out["timezone"] = j.optString("timezone")
                        }
                    }
                } catch (_: Exception) {
                }
            },
            Thread {
                try {
                    out["serverMs"] = eng.probe()
                } catch (_: Exception) {
                }
            },
            Thread {
                try {
                    out["targetMs"] = eng.testTarget("connectivitycheck.gstatic.com", 80)
                } catch (_: Exception) {
                }
            },
        )
        threads.forEach { it.isDaemon = true; it.start() }
        threads.forEach { it.join(15000) }
        return out
    }

    private fun configJson(a: Map<*, *>): String = when (val c = a["config"]) {
        is String -> c
        is Map<*, *> -> JSONObject(c).toString()
        else -> throw ConfigException("config is required")
    }

    private fun shareJson(a: Map<*, *>): JSONObject = when (val c = a["share"]) {
        is String -> JSONObject(c)
        is Map<*, *> -> JSONObject(c)
        else -> throw ConfigException("share is required")
    }

    /** Guards against answering twice. */
    private class Once(private val done: (Any?, String?, String?) -> Unit) {
        private val answered = java.util.concurrent.atomic.AtomicBoolean(false)

        fun ok(value: Any?) {
            if (answered.compareAndSet(false, true)) done(value, null, null)
        }

        fun fail(code: String, message: String) {
            if (answered.compareAndSet(false, true)) done(null, code, message)
        }
    }
}
