package ir.legion.w2ray.android

import android.util.Log
import java.util.ArrayDeque

/**
 * State of the running tunnel and the way it reaches the app. The service writes here; [W2rayApi] reads
 * and forwards events to whoever listens (the Flutter bridge in the host app).
 */
object Hub {
    const val IDLE = "idle"
    const val CONNECTING = "connecting"
    const val CONNECTED = "connected"
    const val RECONNECTING = "reconnecting"
    const val DISCONNECTING = "disconnecting"
    const val ERROR = "error"

    private const val TAG = "W2ray"
    private const val MAX_LOGS = 1000

    @Volatile
    var listener: ((Map<String, Any?>) -> Unit)? = null

    @Volatile
    var state: String = IDLE
        private set

    @Volatile
    var message: String? = null
        private set

    @Volatile
    var mode: String = ""

    @Volatile
    var label: String = ""

    @Volatile
    var server: String = ""

    @Volatile
    var connectedAt: Long = 0

    @Volatile
    var rx: Long = 0

    @Volatile
    var tx: Long = 0

    @Volatile
    var rxRate: Long = 0

    @Volatile
    var txRate: Long = 0

    @Volatile
    var activeConnections: Int = 0

    @Volatile
    var share: Map<String, Any?> = mapOf("enabled" to false)

    private val logs = ArrayDeque<Map<String, Any?>>()
    private val lock = Any()

    fun setState(s: String, msg: String? = null) {
        state = s
        message = msg
        emit(
            mapOf(
                "type" to "state",
                "state" to s,
                "message" to msg,
                "mode" to mode,
                "server" to server,
                "connectedAt" to connectedAt,
            ),
        )
    }

    fun log(level: Char, text: String) {
        val entry = mapOf("type" to "log", "level" to level.toString(), "time" to System.currentTimeMillis(), "message" to text)
        synchronized(lock) {
            if (logs.size >= MAX_LOGS) logs.removeFirst()
            logs.addLast(entry)
        }
        when (level) {
            'E' -> Log.e(TAG, text)
            'W' -> Log.w(TAG, text)
            'D' -> Log.d(TAG, text)
            else -> Log.i(TAG, text)
        }
        emit(entry)
    }

    fun logs(): List<Map<String, Any?>> = synchronized(lock) { logs.toList() }

    fun clearLogs() = synchronized(lock) { logs.clear() }

    fun emitStats() {
        emit(
            mapOf(
                "type" to "stats",
                "rx" to rx,
                "tx" to tx,
                "rxRate" to rxRate,
                "txRate" to txRate,
                "uptime" to if (connectedAt > 0) System.currentTimeMillis() - connectedAt else 0L,
                "connections" to activeConnections,
                "share" to share,
            ),
        )
    }

    fun resetCounters() {
        rx = 0; tx = 0; rxRate = 0; txRate = 0; activeConnections = 0
    }

    fun snapshot(): Map<String, Any?> = mapOf(
        "state" to state,
        "message" to message,
        "mode" to mode,
        "label" to label,
        "server" to server,
        "connectedAt" to connectedAt,
        "rx" to rx,
        "tx" to tx,
        "rxRate" to rxRate,
        "txRate" to txRate,
        "connections" to activeConnections,
        "share" to share,
        "running" to (state == CONNECTING || state == CONNECTED || state == RECONNECTING),
    )

    private fun emit(event: Map<String, Any?>) {
        try {
            listener?.invoke(event)
        } catch (_: Throwable) {
        }
    }
}
