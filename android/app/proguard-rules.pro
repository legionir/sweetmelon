# ──────────────────────────────────────────────────────────────────
# Sweetmelon Native Bridge — ProGuard Rules
# ──────────────────────────────────────────────────────────────────

# ── Flutter ──
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }
-dontwarn io.flutter.**

# ── Kotlin ──
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
-dontwarn kotlin.**

# ── Android Core ──
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# ── Firebase Core ──
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firebase Analytics ──
-keep class com.google.android.gms.measurement.** { *; }

# ── Firebase Crashlytics ──
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.crashlytics.** { *; }
-dontwarn com.crashlytics.**

# ── Firebase Messaging ──
-keep class com.google.firebase.messaging.** { *; }

# ── Firebase Auth ──
-keep class com.google.firebase.auth.** { *; }

# ── Google Sign In ──
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── WebView ──
-keep class android.webkit.** { *; }
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebChromeClient {
    public void *(android.webkit.WebView, java.lang.String);
}

# ── OkHttp ──
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── Geolocator ──
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ── Camera ──
-keep class io.flutter.plugins.camera.** { *; }
-dontwarn io.flutter.plugins.camera.**

# ── Image Picker ──
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ── Biometrics ──
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# ── In-App Purchase ──
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ── Secure Storage ──
-keep class androidx.security.crypto.** { *; }

# ── NFC ──
-keep class android.nfc.** { *; }

# ── Bluetooth ──
-keep class android.bluetooth.** { *; }

# ── SQLite ──
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# ── Gson (if used) ──
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ── Remove debug logging in release ──
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
}

# ── Keep native methods ──
-keepclassmembers class * {
    native <methods>;
}

# ── Keep Parcelable ──
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ── Keep Serializable ──
-keepclassmembers class * implements java.io.Serializable {
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readReadResolve();
}

# ── Keep MainActivity ──
-keep class com.core.sweetmelon.MainActivity { *; }
-keep class com.core.sweetmelon.** { *; }
