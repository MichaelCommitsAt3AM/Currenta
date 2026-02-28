// lib/core/ai/llm_provider.dart

/// Abstract contract for all LLM backends.
/// Implement this for local Ollama, Gemini, or Groq — zero structural changes needed.
abstract class LlmProvider {
  /// Generates a 64-word AI summary using the 5Ws framework.
  Future<String> summarize(String articleText);

  /// Generates a vector embedding for the given [text].
  /// Used for semantic deduplication via cosine similarity.
  Future<List<double>> embed(String text);
}
