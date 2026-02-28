// lib/core/ai/groq_provider.dart
// Production provider — swap AppConfig.llmProvider to 'groq' to enable.

import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'llm_provider.dart';

class GroqProvider implements LlmProvider {
  GroqProvider({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.groq.com/openai/v1',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Authorization': 'Bearer ${AppConfig.groqApiKey}',
              },
            ));

  final Dio _dio;

  static const String _chatModel = 'llama-3.3-70b-versatile';

  static const String _summarizationPrompt = '''
Summarize the following news article in EXACTLY 64 words or fewer using the 5Ws framework.
Cover: Who is involved, What happened, Where it occurred, When it happened, and Why it matters.
Write as one tight, factual paragraph. No bullet points or markdown.

Article:
''';

  @override
  Future<String> summarize(String articleText) async {
    try {
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': _chatModel,
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
        throw const LlmException('Empty response from Groq.');
      }
      return content.trim();
    } on DioException catch (e) {
      throw LlmException('Groq request failed: ${e.message}');
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    // Groq does not currently offer an embeddings endpoint.
    // Fall back to a simple hash-based placeholder for dedup.
    // In production, point this at OpenAI/Gemini embeddings.
    throw const LlmException(
      'Groq does not support embeddings. Configure a separate embedding provider.',
    );
  }
}
