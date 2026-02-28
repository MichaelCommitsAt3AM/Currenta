// lib/core/ai/local_llm_provider.dart

import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'llm_provider.dart';

/// OpenAI-compatible provider for local Ollama servers.
/// Works with any model pulled via `ollama pull <model>`.
class LocalLlmProvider implements LlmProvider {
  LocalLlmProvider({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.localLlmBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 120),
            ));

  final Dio _dio;

  static const String _summarizationPrompt = '''
Summarize the following news article in EXACTLY 64 words or fewer using the 5Ws framework.
Cover: Who is involved, What happened, Where it occurred, When it happened, and Why it matters.
Write as one tight, factual paragraph. Do NOT use bullet points or markdown formatting.

Article:
''';

  @override
  Future<String> summarize(String articleText) async {
    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': AppConfig.localLlmModel,
          'messages': [
            {
              'role': 'user',
              'content': '$_summarizationPrompt$articleText',
            }
          ],
          'max_tokens': 120,
          'temperature': 0.3,
        },
      );

      final content =
          response.data['choices'][0]['message']['content'] as String?;
      if (content == null || content.isEmpty) {
        throw const LlmException('Empty response from local LLM.');
      }
      return content.trim();
    } on DioException catch (e) {
      throw LlmException('Local LLM request failed: ${e.message}');
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    try {
      final response = await _dio.post(
        '/embeddings',
        data: {
          'model': AppConfig.localLlmModel,
          'input': text,
        },
      );

      final raw = response.data['data'][0]['embedding'] as List<dynamic>;
      return raw.map((e) => (e as num).toDouble()).toList();
    } on DioException catch (e) {
      throw LlmException('Embedding request failed: ${e.message}');
    }
  }
}
