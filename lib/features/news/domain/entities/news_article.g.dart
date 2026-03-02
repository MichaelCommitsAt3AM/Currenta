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
      category: $enumDecodeNullable(_$NewsCategoryEnumMap, json['category']) ??
          NewsCategory.world,
      isPaywalled: json['is_paywalled'] as bool? ?? false,
      clusterId: json['cluster_id'] as String?,
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
      'category': _$NewsCategoryEnumMap[instance.category]!,
      'is_paywalled': instance.isPaywalled,
      'cluster_id': instance.clusterId,
    };

const _$NewsCategoryEnumMap = {
  NewsCategory.politics: 'politics',
  NewsCategory.tech: 'tech',
  NewsCategory.science: 'science',
  NewsCategory.business: 'business',
  NewsCategory.sports: 'sports',
  NewsCategory.entertainment: 'entertainment',
  NewsCategory.health: 'health',
  NewsCategory.world: 'world',
};
