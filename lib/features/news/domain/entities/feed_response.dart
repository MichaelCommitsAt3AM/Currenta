// lib/features/news/domain/entities/feed_response.dart

import 'news_article.dart';

class FeedResponse {
  final List<NewsArticle> articles;
  final String? sessionId;
  final String? nextCursor;
  final bool hasMore;
  final DateTime? expiresAt;

  const FeedResponse({
    this.articles = const [],
    this.sessionId,
    this.nextCursor,
    this.hasMore = false,
    this.expiresAt,
  });

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    return FeedResponse(
      articles: (json['articles'] as List? ?? [])
          .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
          .toList(),
      sessionId: json['session_id'] as String?,
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
      expiresAt: json['expires_at'] != null 
          ? DateTime.tryParse(json['expires_at'] as String) 
          : null,
    );
  }

  FeedResponse copyWith({
    List<NewsArticle>? articles,
    String? sessionId,
    String? nextCursor,
    bool? hasMore,
    DateTime? expiresAt,
  }) {
    return FeedResponse(
      articles: articles ?? this.articles,
      sessionId: sessionId ?? this.sessionId,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
