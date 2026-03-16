// lib/features/news/data/remote/news_remote_datasource.dart

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import 'package:flutter/widgets.dart';
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
    String? country,
    int limit = 30,
    int offset = 0,
    DateTime? before,
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

      if (country != null) {
        queryParams['country'] = country;
      } else {
        // Signal backend to use IP-based detection or stored preference
        queryParams['country'] = 'auto';
      }

      if (before != null) {
        queryParams['before'] = before.toUtc().toIso8601String();
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
      final articles = data
          .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
          .toList();

      // Backend local feed is country-filtered; ensure local-tab cache queries can
      // retrieve these articles by including the virtual `local` category marker.
      if (category == NewsCategory.local) {
        return articles.map((article) {
          if (article.categories.contains(NewsCategory.local)) return article;
          return article.copyWith(
            categories: [
              NewsCategory.local,
              ...article.categories.where((c) => c != NewsCategory.local),
            ],
          );
        }).toList();
      }

      return articles;
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
      debugPrint('[Remote] Failed to track view for $articleId: $e');
    }
  }
  /// Records that the user has favorited this article.
  Future<void> toggleArticleFavorite(String articleId) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/feed/favorite';
      final session = Supabase.instance.client.auth.currentSession;

      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      await _dio.post(url,
          queryParameters: {'article_id': articleId}, options: options);
    } catch (e) {
      debugPrint('[Remote] Failed to toggle favorite for $articleId: $e');
      rethrow;
    }
  }

  /// Fetches global trending articles.
  Future<List<NewsArticle>> fetchTrendingArticles({int limit = 20}) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/trending';
      final queryParams = {'limit': limit};

      final session = Supabase.instance.client.auth.currentSession;
      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      final response = await _dio.get(url, queryParameters: queryParams, options: options);
      final data = response.data as List<dynamic>;
      return data
          .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException('Failed to fetch trending: ${e.message}');
    }
  }
}
