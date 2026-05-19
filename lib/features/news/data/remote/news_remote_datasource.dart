// lib/features/news/data/remote/news_remote_datasource.dart

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/feed_response.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class NewsRemoteDataSource {
  NewsRemoteDataSource({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  Future<Session?> _getValidSession() async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return session;

    final expiry =
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true);
    final now = DateTime.now().toUtc();

    if (now.isAfter(expiry.subtract(const Duration(minutes: 1)))) {
      try {
        await auth.refreshSession();
      } catch (e) {
        debugPrint('[Remote] Session refresh failed: $e');
      }
    }

    return auth.currentSession;
  }

  /// Fetches articles from the FastAPI backend using session-based pagination.
  Future<FeedResponse> fetchArticles({
    NewsCategory? category,
    String? country,
    int limit = 30,
    String? sessionId,
    String? cursor,
  }) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/feed';
      final queryParams = <String, dynamic>{
        'limit': limit,
      };

      if (sessionId != null) queryParams['session_id'] = sessionId;
      if (cursor != null) queryParams['cursor'] = cursor;

      if (category != null) {
        queryParams['category'] = category.name;
      }

      if (country != null) {
        queryParams['country'] = country;
      } else {
        // Signal backend to use IP-based detection or stored preference
        queryParams['country'] = 'auto';
      }

      // Pass the Supabase JWT to authenticate the feed request asymmetrically
      final session = await _getValidSession();

      String? appCheckToken;
      if (AppConfig.isProd && kReleaseMode) {
        try {
          // Explicitly prefer cached token to avoid blocking article fetches
          // with sequential network calls for App Check.
          appCheckToken = await FirebaseAppCheck.instance.getToken(false);
          if (kDebugMode) {
            debugPrint('[Remote] App Check token retrieved successfully');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Remote] App Check token retrieval failed: $e');
          }
        }
      }

      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
          if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
        },
      );

      if (kDebugMode) {
        debugPrint('[DIO →] GET $url with params: $queryParams');
      }
      final response =
          await _dio.get(url, queryParameters: queryParams, options: options);

      final responseData = response.data as Map<String, dynamic>;
      if (kDebugMode) {
        debugPrint(
            '[DIO ←] 200 Received articles: ${(responseData['articles'] as List?)?.length}, session_id: ${responseData['session_id']}, has_more: ${responseData['has_more']}');
      }
      final feedResponse = FeedResponse.fromJson(responseData);

      // Backend local feed is country-filtered; ensure local-tab cache queries can
      // retrieve these articles by including the virtual `local` category marker.
      if (category == NewsCategory.local) {
        final transformedArticles = feedResponse.articles.map((article) {
          if (article.categories.contains(NewsCategory.local)) return article;
          return article.copyWith(
            categories: [
              NewsCategory.local,
              ...article.categories.where((c) => c != NewsCategory.local),
            ],
          );
        }).toList();

        return feedResponse.copyWith(articles: transformedArticles);
      }

      return feedResponse;
    } on DioException catch (e) {
      if (e.error is AppException) {
        rethrow;
      }
      final errorType = e.type.toString().split('.').last;
      final statusCode = e.response?.statusCode ?? 'NoStatus';
      final message =
          'API Failure ($errorType, $statusCode): ${e.message ?? e.error ?? 'Unknown error'}';
      debugPrint('[Remote] $message');
      throw ServerException(message);
    }
  }

  /// Records that the user has seen this article.
  Future<void> trackArticleView(String articleId) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/feed/view';
      final session = await _getValidSession();

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
      final session = await _getValidSession();

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

  Future<void> toggleArticleLike(String articleId) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/feed/like';
      final session = await _getValidSession();

      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      await _dio.post(url,
          queryParameters: {'article_id': articleId}, options: options);
    } catch (e) {
      debugPrint('[Remote] Failed to toggle like for $articleId: $e');
      rethrow;
    }
  }

  /// Fetches liked articles from the backend with pagination.
  Future<Map<String, dynamic>> fetchLikedArticles({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/feed/liked';
      final session = await _getValidSession();

      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      final response = await _dio.get(
        url,
        queryParameters: {'limit': limit, 'offset': offset},
        options: options,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerException('Failed to fetch liked articles: ${e.message}');
    }
  }

  /// Fetches global trending articles.
  Future<List<NewsArticle>> fetchTrendingArticles({
    int limit = 20,
    String? country,
    int? hours,
  }) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/trending';
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (country != null) 'country': country,
        if (hours != null) 'hours': hours,
      };

      final session = await _getValidSession();
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
      throw ServerException('Failed to fetch trending: ${e.message}');
    }
  }

  /// Invalidates the user's state (interests, country) on the backend Redis cache.
  Future<void> clearUserState() async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/feed/user-state';
      final session = await _getValidSession();

      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      debugPrint('[DIO →] DELETE $url');
      await _dio.delete(url, options: options);
    } catch (e) {
      // Slurp error — cache invalidation is a best-effort optimization
      debugPrint('[Remote] Failed to clear remote user state: $e');
    }
  }
}
