package hev.htproxy

/**
 * JNI binding of hev-socks5-tunnel (https://github.com/heiher/hev-socks5-tunnel). The library registers
 * these natives for `hev/htproxy/TProxyService` by name, so neither the package nor the class may change.
 */
object TProxyService {
    private external fun TProxyStartService(configPath: String, fd: Int): Boolean
    private external fun TProxyStopService(): Boolean
    private external fun TProxyIsRunning(): Boolean
    private external fun TProxyGetStats(): LongArray

    @Volatile
    private var loaded: Throwable? = null

    init {
        try {
            System.loadLibrary("hev-socks5-tunnel")
        } catch (t: Throwable) {
            loaded = t
        }
    }

    /** Null when the native library is loaded, else the reason it is not. */
    fun loadError(): String? = loaded?.let { it.message ?: it.javaClass.simpleName }

    /** Starts the tunnel on its own thread. [fd] is the TUN descriptor; the caller keeps it open. */
    fun start(configPath: String, fd: Int): Boolean {
        loaded?.let { throw IllegalStateException("hev-socks5-tunnel is not available: ${it.message}") }
        return TProxyStartService(configPath, fd)
    }

    /** Stops the tunnel and waits for its thread. */
    fun stop(): Boolean = loaded == null && TProxyStopService()

    val isRunning: Boolean get() = loaded == null && TProxyIsRunning()

    /** `[tx_packets, tx_bytes, rx_packets, rx_bytes]`: tx is what the device sent, rx what it received. */
    fun stats(): LongArray? = if (loaded == null && TProxyIsRunning()) TProxyGetStats() else null
}
