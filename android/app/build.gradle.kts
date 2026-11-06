plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.core.sweetmelon"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications (and other plugins) use core library
        // APIs that require desugaring on minSdk < 26.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Placeholder Application ID from the Flutter template. Replace it with
        // your own unique ID before publishing (see README, "Before release").
        applicationId = "com.core.sweetmelon"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing is read from environment variables (CI secrets or a
    // local shell). The debug key is never used for release builds (SEC-006).
    // Without a release keystore the release APK is left unsigned.
    val releaseKeystorePath: String? = System.getenv("SWEETMELON_KEYSTORE_PATH")
    signingConfigs {
        if (releaseKeystorePath != null) {
            create("release") {
                storeFile = file(releaseKeystorePath)
                storePassword = System.getenv("SWEETMELON_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("SWEETMELON_KEY_ALIAS")
                keyPassword = System.getenv("SWEETMELON_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseKeystorePath != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications on minSdk < 26.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Present only when the w2rayTunnel plugin is enabled (android/settings.gradle.kts).
    if (rootProject.findProject(":w2ray_tunnel") != null) {
        implementation(project(":w2ray_tunnel"))
    }
}
