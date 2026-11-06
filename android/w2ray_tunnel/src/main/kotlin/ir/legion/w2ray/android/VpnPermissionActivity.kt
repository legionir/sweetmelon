package ir.legion.w2ray.android

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle

/**
 * Shows the system "connection request" dialog for a VPN and reports the answer. It has no UI of its own
 * (translucent) and finishes at once, so the app's screen stays as it was.
 */
class VpnPermissionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) return // the dialog is already showing
        val intent: Intent? = try {
            VpnService.prepare(this)
        } catch (e: Exception) {
            null
        }
        if (intent == null) {
            finishWith(true)
            return
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQUEST)
        } catch (e: Exception) {
            finishWith(false)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST) finishWith(resultCode == RESULT_OK)
    }

    private fun finishWith(granted: Boolean) {
        val cb = callback
        callback = null
        finish()
        cb?.invoke(granted)
    }

    companion object {
        private const val REQUEST = 7101

        @Volatile
        var callback: ((Boolean) -> Unit)? = null
    }
}
