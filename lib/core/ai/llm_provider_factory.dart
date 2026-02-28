// lib/core/ai/llm_provider_factory.dart

import '../config/app_config.dart';
import 'llm_provider.dart';
import 'local_llm_provider.dart';
import 'gemini_provider.dart';
import 'groq_provider.dart';

/// Returns the correct [LlmProvider] based on [AppConfig.llmProvider].
/// To switch providers at build time, change the single constant in AppConfig.
class LlmProviderFactory {
  LlmProviderFactory._();

  static LlmProvider create() {
    return switch (AppConfig.llmProvider) {
      'gemini' => GeminiProvider(),
      'groq' => GroqProvider(),
      'local' => LocalLlmProvider(),
      final unknown => throw ArgumentError(
          'Unknown LLM provider: "$unknown". '
          'Valid values: "local", "gemini", "groq".',
        ),
    };
  }
}
