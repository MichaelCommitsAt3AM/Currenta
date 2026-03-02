// lib/core/ai/gemini_provider.dart
// Production provider — swap AppConfig.llmProvider to 'gemini' to enable.

import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'llm_provider.dart';

class GeminiProvider implements LlmProvider {
  GeminiProvider({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl:
                  'https://generativelanguage.googleapis.com/v1beta/models',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            ));

  final Dio _dio;

  static const String _model = 'gemini-2.5-flash-lite';
  static const String _embeddingModel = 'text-embedding-004';

  static const String _summarizationPrompt = '''
Summarize the following news article in EXACTLY 64 words or fewer using the 5Ws framework.
Cover: Who is involved, What happened, Where it occurred, When it happened, and Why it matters.
Write as one tight, factual paragraph. No bullet points or markdown.

Article:
''';

  // ── Rate Limiting (15 RPM = ~4s per request) ────────────────────
  static Future<void> _rateLimitLock = Future.value();
  static const _minGap = Duration(milliseconds: 4100);

  Future<T> _throttled<T>(Future<T> Function() action) async {
    final completer = Completer<T>();

    // Chain the task to the lock, but keep the lock as Future<void>
    _rateLimitLock = _rateLimitLock.then((_) async {
      final startTime = DateTime.now();
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, s) {
        completer.completeError(e, s);
      } finally {
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < _minGap) {
          await Future.delayed(_minGap - elapsed);
        }
      }
    });

    return completer.future;
  }

  @override
  Future<String> summarize(String articleText) async {
    return _throttled(() async {
      try {
        final response = await _dio.post(
          '/$_model:generateContent',
          queryParameters: {'key': AppConfig.geminiApiKey},
          data: {
            'contents': [
              {
                'parts': [
                  {'text': '$_summarizationPrompt$articleText'}
                ]
              }
            ],
            'generationConfig': {
              'maxOutputTokens': 120,
              'temperature': 0.3,
            }
          },
        );

        final content = response.data['candidates'][0]['content']['parts'][0]
            ['text'] as String?;
        if (content == null || content.isEmpty) {
          throw const LlmException('Empty response from Gemini.');
        }
        return content.trim();
      } on DioException catch (e) {
        throw LlmException('Gemini request failed: ${e.message}');
      }
    });
  }

  @override
  Future<List<double>> embed(String text) async {
    return _throttled(() async {
      try {
        final response = await _dio.post(
          '/$_embeddingModel:embedContent',
          queryParameters: {'key': AppConfig.geminiApiKey},
          data: {
            'model': 'models/$_embeddingModel',
            'content': {
              'parts': [
                {'text': text}
              ]
            }
          },
        );

        final raw = response.data['embedding']['values'] as List<dynamic>;
        return raw.map((e) => (e as num).toDouble()).toList();
      } on DioException catch (e) {
        throw LlmException('Gemini embedding failed: ${e.message}');
      }
    });
  }
}
