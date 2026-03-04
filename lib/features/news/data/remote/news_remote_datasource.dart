// lib/features/news/data/remote/news_remote_datasource.dart

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';

class NewsRemoteDataSource {
  NewsRemoteDataSource({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  /// Fetches articles from the FastAPI backend.
  /// [offset] enables remote pagination: skip the first [offset] rows.
  Future<List<NewsArticle>> fetchArticles({
    NewsCategory? category,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/feed';
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };

      if (category != null) {
        queryParams['category'] = category.name;
      }

      // Pass the Supabase JWT to authenticate the feed request asymmetrically
      final session = Supabase.instance.client.auth.currentSession;
      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      final response =
          await _dio.get(url, queryParameters: queryParams, options: options);

      final data = response.data as List<dynamic>;
      return data
          .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        'API request failed: ${e.message}',
      );
    }
  }

  /// Records that the user has seen this article.
  Future<void> trackArticleView(String articleId) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/feed/view';
      final session = Supabase.instance.client.auth.currentSession;

      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      await _dio.post(url,
          queryParameters: {'article_id': articleId}, options: options);
    } catch (e) {
      // Slurp error — view tracking is non-critical for the user
      print('[Remote] Failed to track view for $articleId: $e');
    }
  }
}
