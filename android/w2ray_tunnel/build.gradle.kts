// Optional module of the Sweetmelon core: the `w2rayTunnel` plugin (a VPN / SOCKS5 client for the w2ray
// WebSocket tunnel). It is included only when the plugin is enabled in sweetmelon.yaml (see
// android/settings.gradle.kts), so apps that do not use it get no native library and no VPN service.
//
// The module has no Flutter dependency: the app talks to it through ir.legion.w2ray.android.W2rayApi.
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// `flutter build apk --target-platform android-arm64` passes -Ptarget-platform: build the native library only
// for those ABIs, not for all four.
val abis: List<String> = (findProperty("target-platform") as String?)
    ?.split(',')
    ?.mapNotNull {
        when (it.trim()) {
            "android-arm" -> "armeabi-v7a"
            "android-arm64" -> "arm64-v8a"
            "android-x86" -> "x86"
            "android-x64" -> "x86_64"
            else -> null
        }
    }
    ?.takeIf { it.isNotEmpty() }
    ?: listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")

android {
    namespace = "ir.legion.w2ray"
    compileSdk = 37

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
        ndk {
            abiFilters += abis
        }
        externalNativeBuild {
            ndkBuild {
                // hev-socks5-tunnel is plain C: warnings of its third-party code are not ours.
                cFlags("-w")
            }
        }
    }

    externalNativeBuild {
        ndkBuild {
            path = file("src/main/jni/Android.mk")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    // Android's own org.json is a stub in local unit tests; this one runs there.
    testImplementation("org.json:json:20240303")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5:2.2.20")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher:1.10.2")
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
}
