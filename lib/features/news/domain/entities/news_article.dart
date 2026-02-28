// lib/features/news/domain/entities/news_article.dart

import 'package:freezed_annotation/freezed_annotation.dart';
import 'news_category.dart';

part 'news_article.freezed.dart';
part 'news_article.g.dart';

@freezed
abstract class NewsArticle with _$NewsArticle {
  const factory NewsArticle({
    /// Unique identifier (UUID)
    required String id,

    /// Headline of the article
    required String title,

    /// AI-generated summary (max 64 words, 5Ws framework)
    required String summary,

    /// Link to the original article
    required String originalUrl,

    /// Publisher name, e.g. "BBC News"
    required String sourceName,

    /// URL to the publisher's favicon / logo
    String? sourceFaviconUrl,

    /// When the article was published
    required DateTime publishedAt,

    /// News category
    @Default(NewsCategory.world) NewsCategory category,

    /// Whether this article is behind a paywall
    @Default(false) bool isPaywalled,

    /// Semantic cluster ID — articles with the same cluster cover the same story
    String? clusterId,
  }) = _NewsArticle;

  factory NewsArticle.fromJson(Map<String, dynamic> json) =>
      _$NewsArticleFromJson(json);
}
