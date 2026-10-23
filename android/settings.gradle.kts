pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("com.android.library") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

// The w2rayTunnel plugin brings a native module (VPN service + hev-socks5-tunnel). It is part of the build
// only when the plugin is enabled in sweetmelon.yaml, so other apps carry neither its code nor its library.
// Same rule as `setPluginEnabled` in lib/cli/project_settings.dart.
val sweetmelonYaml = file("../sweetmelon.yaml")
val w2rayTunnelEnabled = sweetmelonYaml.exists() && Regex(
    "(?m)^  w2ray_tunnel:[ \\t]*(?:#.*)?\\r?\\n(?:[ \\t]*(?:#.*)?\\r?\\n)*?    enabled:[ \\t]*true",
).containsMatchIn(sweetmelonYaml.readText())
if (w2rayTunnelEnabled) {
    include(":w2ray_tunnel")
}
