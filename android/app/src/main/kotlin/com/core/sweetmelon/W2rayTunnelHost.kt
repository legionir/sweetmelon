package com.core.sweetmelon

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Method

/**
 * Bridge between the `w2rayTunnel` Dart plugin and the optional Gradle module `:w2ray_tunnel`.
 *
 * The module is part of the build only when the plugin is enabled in sweetmelon.yaml, so this class reaches
 * it by reflection: with the module absent every call answers `UNAVAILABLE` and nothing else changes.
 * Values cross as plain maps, lists, strings, numbers and booleans.
 */
object W2rayTunnelHost {
    private const val METHODS = "sweetmelon/w2ray_tunnel"
    private const val EVENTS = "sweetmelon/w2ray_tunnel/events"
    private const val API = "ir.legion.w2ray.android.W2rayApi"

    private val ui = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    fun register(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        val api: Class<*>? = try {
            Class.forName(API)
        } catch (e: Throwable) {
            null
        }
        var call: Method? = null
        var listen: Method? = null
        if (api != null) {
            try {
                call = api.getMethod(
                    "call", Context::class.java, String::class.java, Map::class.java, kotlin.jvm.functions.Function3::class.java,
                )
                listen = api.getMethod("setEventListener", kotlin.jvm.functions.Function1::class.java)
            } catch (e: Throwable) {
                call = null
            }
        }
        val callMethod = call
        val listenMethod = listen

        MethodChannel(engine.dartExecutor.binaryMessenger, METHODS).setMethodCallHandler { c, result ->
            if (callMethod == null) {
                result.error("UNAVAILABLE", "The w2rayTunnel module is not part of this build. Enable w2ray_tunnel in sweetmelon.yaml.", null)
                return@setMethodCallHandler
            }
            val args = c.arguments as? Map<*, *>
            val reply: (Any?, String?, String?) -> Unit = { value, code, message ->
                ui.post {
                    if (code == null) result.success(value) else result.error(code, message, null)
                }
            }
            try {
                callMethod.invoke(null, app, c.method, args, reply)
            } catch (e: Throwable) {
                val cause = e.cause ?: e
                reply(null, "ERROR", cause.message ?: cause.javaClass.simpleName)
            }
        }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                if (listenMethod == null) return
                val l: (Map<String, Any?>) -> Unit = { event -> ui.post { sink?.success(event) } }
                try {
                    listenMethod.invoke(null, l)
                } catch (_: Throwable) {
                }
            }

            override fun onCancel(arguments: Any?) {
                sink = null
                try {
                    listenMethod?.invoke(null, null)
                } catch (_: Throwable) {
                }
            }
        })
    }
}
