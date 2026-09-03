# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Facebook
-keep class com.facebook.** { *; }

# Keep app package
-keep class com.ppdeli.market.** { *; }

# Strip log calls
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
}

# Crashlytics
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile