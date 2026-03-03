// ignore_for_file: invalid_annotation_target
// lib/features/news/domain/entities/news_article.dart

import 'package:freezed_annotation/freezed_annotation.dart';
import 'news_category.dart';

part 'news_article.freezed.dart';
part 'news_article.g.dart';

// ── JSON helpers (top-level, as required by Freezed) ─────────────────────────

List<NewsCategory> _categoriesFromJson(dynamic raw) {
  if (raw == null) return [NewsCategory.world];
  final List<dynamic> list = raw is List ? raw : [raw];
  final result = list
      .map((e) => e?.toString() ?? '')
      .map((s) => NewsCategory.values.firstWhere(
            (c) => c.name == s,
            orElse: () => NewsCategory.world,
          ))
      .toList();
  return result.isEmpty ? [NewsCategory.world] : result;
}

List<String> _categoriesToJson(List<NewsCategory> categories) =>
    categories.map((c) => c.name).toList();

// ── Entity ────────────────────────────────────────────────────────────────────

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

    /// Cover image URL
    @JsonKey(name: 'image_url') String? imageUrl,

    /// Publisher name, e.g. "BBC News"
    @JsonKey(name: 'source_name') required String sourceName,

    /// URL to the publisher's favicon / logo
    @JsonKey(name: 'source_favicon_url') String? sourceFaviconUrl,

    /// When the article was published
    @JsonKey(name: 'published_at') required DateTime publishedAt,

    /// News categories (multi-label). First element is primary display category.
    @JsonKey(
      name: 'categories',
      fromJson: _categoriesFromJson,
      toJson: _categoriesToJson,
    )
    @Default([NewsCategory.world])
    List<NewsCategory> categories,

    /// Whether this article is behind a paywall
    @JsonKey(name: 'is_paywalled') @Default(false) bool isPaywalled,

    /// Semantic cluster ID — articles with the same cluster cover the same story
    @JsonKey(name: 'cluster_id') String? clusterId,
  }) = _NewsArticle;

  factory NewsArticle.fromJson(Map<String, dynamic> json) =>
      _$NewsArticleFromJson(json);
}
