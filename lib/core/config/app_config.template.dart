// lib/core/config/app_config.template.dart

/// Central configuration template for Currenta.
/// Copy this file to app_config.dart and fill in your credentials.
class AppConfig {
  AppConfig._();

  // ── Supabase ────────────────────────────────────────────────────
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // ── LLM Provider ────────────────────────────────────────────────
  /// One of: 'local' | 'gemini' | 'groq'
  static const String llmProvider = 'local';

  /// Ollama / LM Studio base URL (used when llmProvider == 'local')
  static const String localLlmBaseUrl = 'http://localhost:11434/v1';

  /// Model name sent to local Ollama server
  static const String localLlmModel = 'llama';

  /// Gemini API key (used when llmProvider == 'gemini')
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';

  /// Groq API key (used when llmProvider == 'groq')
  static const String groqApiKey = 'YOUR_GROQ_API_KEY';

  // ── Cache / Performance ─────────────────────────────────────────
  static const int cacheMaxAgeHours = 48;
  static const int backgroundPrefetchCount = 20;
  static const int backgroundFetchIntervalHours = 1;

  // ── Deduplication ───────────────────────────────────────────────
  static const double deduplicationThreshold = 0.92;
}
