package com.core.sweetmelon

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val PRIVACY_CHANNEL = "sweetmelon/privacy_screen"
    private val FOREGROUND_CHANNEL = "sweetmelon/foreground_service"
    private val SIM_CHANNEL = "sweetmelon/sim_info"
    private val INTEGRITY_CHANNEL = "sweetmelon/app_integrity"
    private val VOLUME_CHANNEL = "sweetmelon/volume_buttons"
    private val WAKE_LOCK_CHANNEL = "sweetmelon/wake_lock"
    private val SHARE_TARGET_CHANNEL = "sweetmelon/share_target"

    private var volumeEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Privacy Screen ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PRIVACY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enablePrivacy" -> {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                    result.success(true)
                }
                "disablePrivacy" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Wake Lock ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WAKE_LOCK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                }
                "disable" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Foreground Service ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FOREGROUND_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    // Stub — واقعی نیاز به ForegroundService class داره
                    result.success(true)
                }
                "stopService" -> {
                    result.success(true)
                }
                "updateNotification" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── SIM Info ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SIM_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimInfo" -> {
                    try {
                        val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
                        val info = HashMap<String, Any?>()
                        info["networkOperator"] = tm.networkOperatorName
                        info["networkCountryIso"] = tm.networkCountryIso
                        info["simOperator"] = tm.simOperatorName
                        info["simCountryIso"] = tm.simCountryIso
                        info["simState"] = tm.simState
                        info["phoneType"] = tm.phoneType
                        info["available"] = true

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                            try {
                                val sm = getSystemService(TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                                info["simCount"] = sm.activeSubscriptionInfoCount
                            } catch (e: SecurityException) {
                                info["simCount"] = 1
                            }
                        }

                        result.success(info)
                    } catch (e: Exception) {
                        result.success(hashMapOf("available" to false, "error" to e.message))
                    }
                }
                "getCarrierName" -> {
                    val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
                    result.success(tm.networkOperatorName ?: "unknown")
                }
                "getSimCount" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                        try {
                            val sm = getSystemService(TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                            result.success(sm.activeSubscriptionInfoCount)
                        } catch (e: SecurityException) {
                            result.success(1)
                        }
                    } else {
                        result.success(1)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── App Integrity ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INTEGRITY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGenuineInstall" -> {
                    val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        packageManager.getInstallSourceInfo(packageName).installingPackageName
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getInstallerPackageName(packageName)
                    }
                    val genuine = installer == "com.android.vending" ||
                            installer == "com.google.android.packageinstaller"
                    result.success(genuine)
                }
                "getInstallSource" -> {
                    val info = HashMap<String, Any?>()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        val source = packageManager.getInstallSourceInfo(packageName)
                        info["initiating"] = source.initiatingPackageName
                        info["originating"] = source.originatingPackageName
                        info["source"] = source.installingPackageName
                    } else {
                        @Suppress("DEPRECATION")
                        info["source"] = packageManager.getInstallerPackageName(packageName)
                    }
                    result.success(info)
                }
                "getSigningInfo" -> {
                    val info = HashMap<String, Any?>()
                    info["signed"] = true
                    info["debugBuild"] = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }

        // ── Volume Buttons ──
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOLUME_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                volumeEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                volumeEventSink = null
            }
        })

        // ── Share Target ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_TARGET_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedData" -> {
                    val data = handleShareIntent(intent)
                    result.success(data)
                }
                else -> result.notImplemented()
            }
        }

        // ── w2ray tunnel (optional module, see W2rayTunnelHost) ──
        W2rayTunnelHost.register(this, flutterEngine)
    }

    // Volume button interception: only while the `volume_buttons` plugin is
    // listening. Otherwise the keys go to the system, so they change the
    // volume (and show the volume panel) as in any other app.
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val sink = volumeEventSink
        if (sink != null) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    sink.success("up")
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    sink.success("down")
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    // Share intent handling
    private fun handleShareIntent(intent: Intent?): HashMap<String, Any?>? {
        if (intent == null) return null

        val action = intent.action
        val type = intent.type

        if (Intent.ACTION_SEND == action && type != null) {
            val data = HashMap<String, Any?>()

            if (type.startsWith("text/")) {
                data["type"] = "text"
                data["text"] = intent.getStringExtra(Intent.EXTRA_TEXT)
                data["title"] = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            } else {
                data["type"] = "file"
                data["mimeType"] = type
                val uri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                data["uri"] = uri?.toString()
            }

            return data
        }

        return null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
