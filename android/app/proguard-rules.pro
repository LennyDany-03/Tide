# Tide — release shrinking rules.
#
# Nothing here is needed while `isMinifyEnabled` is false, which is how this
# app builds today. It is here because the day somebody turns shrinking on for
# a Play release is the day a payment SDK starts failing in release and
# working in debug, and that is a miserable thing to diagnose from a crash
# report. The rules cost nothing until they are needed.

# Razorpay's checkout reflects over its own model classes and is driven from
# JavaScript inside its WebView, so R8 has no way to see that any of it is
# reachable and strips the lot.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }

# ProGuard's own annotation classes, referenced by the rules above.
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
