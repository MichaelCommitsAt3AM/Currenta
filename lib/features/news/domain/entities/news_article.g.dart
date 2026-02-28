// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_article.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NewsArticle _$NewsArticleFromJson(Map<String, dynamic> json) => _NewsArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      originalUrl: json['originalUrl'] as String,
      sourceName: json['sourceName'] as String,
      sourceFaviconUrl: json['sourceFaviconUrl'] as String?,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      category: $enumDecodeNullable(_$NewsCategoryEnumMap, json['category']) ??
          NewsCategory.world,
      isPaywalled: json['isPaywalled'] as bool? ?? false,
      clusterId: json['clusterId'] as String?,
    );

Map<String, dynamic> _$NewsArticleToJson(_NewsArticle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'summary': instance.summary,
      'originalUrl': instance.originalUrl,
      'sourceName': instance.sourceName,
      'sourceFaviconUrl': instance.sourceFaviconUrl,
      'publishedAt': instance.publishedAt.toIso8601String(),
      'category': _$NewsCategoryEnumMap[instance.category]!,
      'isPaywalled': instance.isPaywalled,
      'clusterId': instance.clusterId,
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
