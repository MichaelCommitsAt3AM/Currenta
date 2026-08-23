# Flutter-specific ProGuard rules

# Keep the Flutter wrapper and plugin registrant classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

# Drift / SQLCipher rules (if using custom SQLCipher)
# -keep class net.sqlcipher.** { *; }

# Supabase and Networking (Serialization)
# If you see issues with JSON parsing in release mode, add @Keep annotations 
# to your data models or add keep rules here.
# -keep class com.currenta.app.models.** { *; }

# Workmanager
-keep class com.be2ps.workmanager.** { *; }

# WorkManager's WorkDatabase (and any Room database) is instantiated via
# reflection (Room.getGeneratedImplementation -> getDeclaredConstructor()),
# so R8 full mode doesn't see it as used and strips the no-arg constructor
# off the generated *_Impl class, crashing with NoSuchMethodException at
# startup. Keep the constructor so reflection can find it.
-keep class * extends androidx.room.RoomDatabase
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}

# Flutter Custom Tabs
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }

# Google Play Core (referenced by Flutter embedding for deferred components)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.internal.play_billing.**

# Google Play Services & Auth
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.ApiException { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**
