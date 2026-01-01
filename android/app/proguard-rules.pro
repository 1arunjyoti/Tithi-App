# Geolocator - Keep all geolocator classes
-keep class com.baseflow.geolocator.** { *; }

# Android Location classes
-keep class android.location.** { *; }

# OkHttp (used by HTTP clients for API calls)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Nominatim Geocoding
-keep class com.nominatim.** { *; }

# Keep HTTP client classes for API requests
-keep class java.net.** { *; }
-keep class javax.net.** { *; }

# Hive database
-keep class io.flutter.plugins.** { *; }

# General Flutter rule
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Prevent stripping of model classes used in JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Google Play Services / Play Core (Fixes missing class error in release build)
-dontwarn com.google.android.play.core.tasks.**
-keep class com.google.android.play.core.tasks.** { *; }
