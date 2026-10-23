package ir.legion.w2ray.android

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.NetworkInterface
import java.util.Collections

/** Installed apps (for split tunnelling) and the device's own addresses (for sharing). */
internal object Apps {
    fun list(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val out = ArrayList<Map<String, Any?>>()
        val apps = try {
            pm.getInstalledApplications(0)
        } catch (e: Exception) {
            emptyList()
        }
        for (a in apps) {
            if (a.packageName == context.packageName) continue
            val system = (a.flags and ApplicationInfo.FLAG_SYSTEM) != 0 && (a.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
            val launchable = pm.getLaunchIntentForPackage(a.packageName) != null
            // System components without a screen (providers, overlays) only clutter the list.
            if (system && !launchable) continue
            val label = try {
                pm.getApplicationLabel(a).toString()
            } catch (e: Exception) {
                a.packageName
            }
            out.add(mapOf("packageName" to a.packageName, "appName" to label, "isSystem" to system))
        }
        out.sortBy { (it["appName"] as String).lowercase() }
        return out
    }

    private val iconCache = object : LinkedHashMap<String, String>(64, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?) = size > 300
    }

    /** PNG of the app icon as Base64, square, [sizePx] wide. Null when the app has none. */
    fun icon(context: Context, pkg: String, sizePx: Int): String? {
        val key = "$pkg@$sizePx"
        synchronized(iconCache) { iconCache[key]?.let { return it } }
        return try {
            val d = context.packageManager.getApplicationIcon(pkg)
            val png = toPng(d, sizePx.coerceIn(16, 256))
            val b64 = Base64.encodeToString(png, Base64.NO_WRAP)
            synchronized(iconCache) { iconCache[key] = b64 }
            b64
        } catch (e: PackageManager.NameNotFoundException) {
            null
        } catch (e: Exception) {
            null
        }
    }

    private fun toPng(d: Drawable, size: Int): ByteArray {
        val bmp = if (d is BitmapDrawable && d.bitmap != null) {
            Bitmap.createScaledBitmap(d.bitmap, size, size, true)
        } else {
            Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).also {
                val c = Canvas(it)
                d.setBounds(0, 0, size, size)
                d.draw(c)
            }
        }
        val s = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 90, s)
        return s.toByteArray()
    }

    /** Addresses of this device that other devices could reach, with a guess of the kind of network. */
    fun addresses(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val ifs = try {
            Collections.list(NetworkInterface.getNetworkInterfaces())
        } catch (e: Exception) {
            return out
        }
        for (nif in ifs) {
            try {
                if (!nif.isUp || nif.isLoopback) continue
            } catch (e: Exception) {
                continue
            }
            val name = nif.name.orEmpty()
            if (name.startsWith("tun") || name.startsWith("dummy") || name.startsWith("lo")) continue
            val kind = when {
                name.startsWith("ap") || name.startsWith("swlan") || name.startsWith("softap") -> "hotspot"
                name.startsWith("wlan") || name.startsWith("eth") -> "wifi"
                name.startsWith("rndis") || name.startsWith("usb") -> "usb"
                name.startsWith("bt-pan") || name.startsWith("bnep") -> "bluetooth"
                name.startsWith("rmnet") || name.startsWith("ccmni") || name.startsWith("pdp") -> "mobile"
                else -> "other"
            }
            for (a in Collections.list(nif.inetAddresses)) {
                if (a.isLoopbackAddress || a.isLinkLocalAddress || a.isMulticastAddress) continue
                val v6 = a is Inet6Address
                if (!v6 && a !is Inet4Address) continue
                out.add(
                    mapOf(
                        "interface" to name,
                        "address" to (a.hostAddress ?: continue).substringBefore('%'),
                        "ipv6" to v6,
                        "kind" to kind,
                    ),
                )
            }
        }
        return out
    }
}
