// lib/core/config/app_config.template.dart

/// Central configuration template for Currenta.
/// Copy this file to app_config.dart and fill in your credentials.
class AppConfig {
  AppConfig._();

  // ── Supabase ────────────────────────────────────────────────────
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // ── Backend API ─────────────────────────────────────────────────
  static const String apiBaseUrl = 'YOUR_API_BASE_URL';

  // ── Environment ─────────────────────────────────────────────────
  static const bool isProd = false;

  /// Sent as X-AppCheck-Bypass in debug builds when non-empty; must match
  /// the backend's APP_CHECK_BYPASS_TOKEN. Leave empty when App Check
  /// enforcement is disabled server-side (DISABLE_APP_CHECK=true).
  static const String appCheckBypassToken = '';

  // ── Auth ────────────────────────────────────────────────────────
  /// Google Sign-In server (web) OAuth client ID. Leave empty to disable
  /// Google Sign-In.
  static const String googleWebClientId = 'YOUR_GOOGLE_WEB_CLIENT_ID';

  // ── Cache / Performance ─────────────────────────────────────────
  static const int cacheMaxAgeHours = 48;
  static const int backgroundPrefetchCount = 20;
  static const int backgroundFetchIntervalHours = 1;
  static const int locationCacheTtlHours = 24;
  static const int softTtlHours = 1;
  static const int hardTtlHours = 6;

  // ── Deduplication ───────────────────────────────────────────────
  static const double deduplicationThreshold = 0.92;

  // ── Support / Legal ─────────────────────────────────────────────
  static const String supportEmail = 'support@currenta.tech';
  static const String privacyPolicyUrl = 'https://currenta.tech/privacy.html';
  static const String termsOfServiceUrl = 'https://currenta.tech/terms.html';

  // ── Sharing ─────────────────────────────────────────────────────
  /// Shown in the article share card's "Get it on Google Play" CTA. If the
  /// app is still in closed testing, this must be the opt-in testing link
  /// (`https://play.google.com/apps/testing/<applicationId>`) rather than
  /// the public listing URL — the listing 404s for anyone not opted in yet.
  static const String playStoreUrl = 'YOUR_PLAY_STORE_URL';
}
