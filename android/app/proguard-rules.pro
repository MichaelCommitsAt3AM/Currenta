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

# Flutter Custom Tabs
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
