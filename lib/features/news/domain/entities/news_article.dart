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

List<NewsSubCategory> _subCategoriesFromJson(dynamic raw) {
  if (raw == null) return [];
  // Backend currently sends a single free-text `subcategory` string; a future
  // migration moves this to a `subcategories` array. Accept either shape.
  final List<dynamic> list = raw is List ? raw : [raw];
  return list
      .map((e) => e?.toString() ?? '')
      .where((s) => s.isNotEmpty)
      .map((s) => NewsSubCategory.values.where((c) => c.name == s).firstOrNull)
      .whereType<NewsSubCategory>()
      .toList();
}

List<String> _subCategoriesToJson(List<NewsSubCategory> subCategories) =>
    subCategories.map((c) => c.name).toList();

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

    /// When the article was added to our system
    @JsonKey(name: 'created_at') required DateTime createdAt,

    /// News categories (multi-label). First element is primary display category.
    @JsonKey(
      name: 'categories',
      fromJson: _categoriesFromJson,
      toJson: _categoriesToJson,
    )
    @Default([NewsCategory.world])
    List<NewsCategory> categories,

    /// Sub-categories for fine-grained personalization. The backend now sends
    /// canonical taxonomy slugs (e.g. 'artificial_intelligence.ai_research',
    /// see taxonomy/taxonomy.json) here, not [NewsSubCategory] enum names —
    /// they don't match yet, so this always parses to an empty list until the
    /// enum is replaced with the server-driven taxonomy.
    @JsonKey(
      name: 'subcategories',
      fromJson: _subCategoriesFromJson,
      toJson: _subCategoriesToJson,
    )
    @Default([])
    List<NewsSubCategory> subCategories,

    /// The article's primary subcategory as a raw canonical taxonomy slug
    /// (e.g. 'ai_research', or 'artificial_intelligence.ai_research' for an
    /// L3 node — see taxonomy/taxonomy.json). Always just subcategories[0]
    /// server-side (backend/services/ingestion.py). Exists because
    /// [subCategories] above is currently unusable client-side; used for
    /// the "Not interested" mute-this-topic flow — format it for display
    /// rather than showing the raw slug to a user, and pass it through
    /// as-is (not reformatted) when actually muting, since the backend
    /// exclusion filter matches on this exact raw string.
    @JsonKey(name: 'subcategory') String? primarySubcategorySlug,

    /// Whether this article is behind a paywall
    @JsonKey(name: 'is_paywalled') @Default(false) bool isPaywalled,

    /// Whether the current user has liked this article
    @JsonKey(name: 'is_liked') @Default(false) bool isLiked,

    /// Total number of likes
    @JsonKey(name: 'likes_count') @Default(0) int likesCount,

    /// Whether the current user has favorited this article
    @JsonKey(name: 'is_favorited') @Default(false) bool isFavorited,

    /// Whether the current user has viewed this article
    @JsonKey(name: 'is_viewed') @Default(false) bool isViewed,

    /// Semantic cluster ID — articles with the same cluster cover the same story
    @JsonKey(name: 'cluster_id') String? clusterId,

    /// Country code for localized news (e.g. "US", "KE")
    @JsonKey(name: 'country_code') String? countryCode,

    /// Ranking score for For You feed ordering
    @JsonKey(name: 'ranking_score') @Default(0.0) double rankingScore,

    /// Whether this is a major news source (Google News, etc)
    @JsonKey(name: 'is_major_source') @Default(false) bool isMajorSource,

    /// When the article expires (if future event)
    @JsonKey(name: 'expires_at') DateTime? expiresAt,

    /// Type of item (article, exhaustion_marker)
    @JsonKey(name: 'item_type') @Default('article') String itemType,
  }) = _NewsArticle;

  factory NewsArticle.fromJson(Map<String, dynamic> json) =>
      _$NewsArticleFromJson(json);

  factory NewsArticle.adMarker({required String id}) => NewsArticle(
        id: id,
        title: 'Sponsored',
        summary: '',
        originalUrl: '',
        sourceName: 'Sponsored',
        publishedAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
        itemType: 'ad',
      );
}
