// lib/features/news/data/remote/news_remote_datasource.dart

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import '../../../../core/errors/app_exception.dart';

class NewsRemoteDataSource {
  NewsRemoteDataSource({
    required SupabaseClient supabase,
    required Dio dio,
  })  : _supabase = supabase,
        _dio = dio;

  final SupabaseClient _supabase;
  // ignore: unused_field
  final Dio _dio; // reserved for future direct HTTP calls / interceptors

  /// Fetches articles from Supabase PostgREST, ordered newest-first.
  /// Apply filters BEFORE transform operations (order/limit) — required by supabase-flutter v2.
  Future<List<NewsArticle>> fetchArticles({
    NewsCategory? category,
    int limit = 30,
  }) async {
    try {
      // Start with the filter builder
      var filterQuery = _supabase.from('articles').select();

      // Apply category filter on the FilterBuilder (before order/limit)
      if (category != null) {
        filterQuery = filterQuery.eq('category', category.name);
      }

      // Now apply transform operations
      final data = await filterQuery
          .order('published_at', ascending: false)
          .limit(limit);

      return (data as List<dynamic>)
          .map((json) => NewsArticle.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(
        'Supabase query failed: ${e.message}',
        statusCode: int.tryParse(e.code ?? ''),
      );
    } catch (e) {
      throw ServerException('Unexpected remote error: $e');
    }
  }

  /// Triggers the Supabase Edge Function to ingest news from an RSS feed.
  Future<void> triggerIngestion({required String feedUrl}) async {
    try {
      await _supabase.functions.invoke(
        'ingest-news',
        body: {'feedUrl': feedUrl},
      );
    } on FunctionException catch (e) {
      throw ServerException(
        'Edge function error: ${e.details}',
        statusCode: e.status,
      );
    }
  }
}
