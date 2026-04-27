// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_article.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NewsArticle _$NewsArticleFromJson(Map<String, dynamic> json) => _NewsArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      originalUrl: json['original_url'] as String,
      imageUrl: json['image_url'] as String?,
      sourceName: json['source_name'] as String,
      sourceFaviconUrl: json['source_favicon_url'] as String?,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      categories: json['categories'] == null
          ? const [NewsCategory.world]
          : _categoriesFromJson(json['categories']),
      subCategories: json['sub_categories'] == null
          ? const []
          : _subCategoriesFromJson(json['sub_categories']),
      isPaywalled: json['is_paywalled'] as bool? ?? false,
      isLiked: json['is_liked'] as bool? ?? false,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      isFavorited: json['is_favorited'] as bool? ?? false,
      isViewed: json['is_viewed'] as bool? ?? false,
      clusterId: json['cluster_id'] as String?,
      countryCode: json['country_code'] as String?,
      rankingScore: (json['ranking_score'] as num?)?.toDouble() ?? 0.0,
      isMajorSource: json['is_major_source'] as bool? ?? false,
      itemType: json['item_type'] as String? ?? 'article',
    );

Map<String, dynamic> _$NewsArticleToJson(_NewsArticle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'summary': instance.summary,
      'original_url': instance.originalUrl,
      'image_url': instance.imageUrl,
      'source_name': instance.sourceName,
      'source_favicon_url': instance.sourceFaviconUrl,
      'published_at': instance.publishedAt.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'categories': _categoriesToJson(instance.categories),
      'sub_categories': _subCategoriesToJson(instance.subCategories),
      'is_paywalled': instance.isPaywalled,
      'is_liked': instance.isLiked,
      'likes_count': instance.likesCount,
      'is_favorited': instance.isFavorited,
      'is_viewed': instance.isViewed,
      'cluster_id': instance.clusterId,
      'country_code': instance.countryCode,
      'ranking_score': instance.rankingScore,
      'is_major_source': instance.isMajorSource,
      'item_type': instance.itemType,
    };
