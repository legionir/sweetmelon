# The app reaches the module only by reflection (W2rayApi) and the native library registers its methods
# by class name: none of this may be renamed or removed.
-keep class ir.legion.w2ray.** { *; }
-keep class hev.htproxy.** { *; }
-keepclassmembers class * {
    native <methods>;
}
