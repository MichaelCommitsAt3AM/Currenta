// lib/core/config/app_config.template.dart

/// Central configuration template for Currenta.
/// Copy this file to app_config.dart and fill in your credentials.
class AppConfig {
  AppConfig._();

  // ── Supabase ────────────────────────────────────────────────────
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';


  // ── Cache / Performance ─────────────────────────────────────────
  static const int cacheMaxAgeHours = 48;
  static const int backgroundPrefetchCount = 20;
  static const int backgroundFetchIntervalHours = 1;

  // ── Deduplication ───────────────────────────────────────────────
  static const double deduplicationThreshold = 0.92;
}
