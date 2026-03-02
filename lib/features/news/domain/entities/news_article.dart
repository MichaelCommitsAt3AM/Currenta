// ignore_for_file: invalid_annotation_target
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
    @JsonKey(name: 'original_url') required String originalUrl,

    /// Publisher name, e.g. "BBC News"
    @JsonKey(name: 'source_name') required String sourceName,

    /// URL to the publisher's favicon / logo
    @JsonKey(name: 'source_favicon_url') String? sourceFaviconUrl,

    /// When the article was published
    @JsonKey(name: 'published_at') required DateTime publishedAt,

    /// News category
    @Default(NewsCategory.world) NewsCategory category,

    /// Whether this article is behind a paywall
    @JsonKey(name: 'is_paywalled') @Default(false) bool isPaywalled,

    /// Semantic cluster ID — articles with the same cluster cover the same story
    @JsonKey(name: 'cluster_id') String? clusterId,
  }) = _NewsArticle;

  factory NewsArticle.fromJson(Map<String, dynamic> json) =>
      _$NewsArticleFromJson(json);
}
