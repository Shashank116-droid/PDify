# Google Mobile Ads SDK
-keep public class com.google.android.gms.ads.** {
   public *;
}

# For App Measurement and other dependencies
-keep class com.google.android.gms.measurement.** { *; }
-keep interface com.google.android.gms.measurement.** { *; }
-keep class com.google.android.ims.** { *; }

# For various dependencies that might be stripped
-keep class com.google.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Prevent obfuscation of AdMob's Javascript interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Handle other common Flutter/Android minification issues
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
