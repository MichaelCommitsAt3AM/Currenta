// lib/core/config/news_sources.dart

import '../../features/news/domain/entities/news_category.dart';

/// Central registry of RSS feeds for the ingestion pipeline.
class NewsSources {
  NewsSources._();

  /// A map of categories to their high-quality RSS feed URLs.
  static const Map<NewsCategory, List<String>> feeds = {
    NewsCategory.world: [
      'http://feeds.bbci.co.uk/news/rss.xml',
      'http://feeds.bbci.co.uk/news/world/rss.xml',
      'https://www.reutersagency.com/feed/?best-topics=political-general&post_type=best',
      'https://www.aljazeera.com/xml/rss/all.xml',
    ],
    NewsCategory.tech: [
      'https://www.theverge.com/rss/index.xml',
      'https://techcrunch.com/feed/',
      'https://www.wired.com/feed/rss',
      'https://www.cnet.com/rss/news/',
      'https://feeds.arstechnica.com/arstechnica/index',
    ],
    NewsCategory.politics: [
      'https://www.politico.com/rss/politicopicks.xml',
      'https://thehill.com/homenews/feed/',
    ],
    NewsCategory.science: [
      'https://www.sciencedaily.com/rss/all.xml',
      'https://www.sciencedaily.com/rss/top/science.xml',
      'https://www.nature.com/nature.rss',
      'https://www.nasa.gov/rss/dyn/breaking_news.rss',
    ],
    NewsCategory.sports: [
      'https://www.skysports.com/rss/12040',
      'https://feeds.bbci.co.uk/sport/rss.xml',
    ],
    NewsCategory.entertainment: [
      'https://variety.com/feed/',
      'https://www.hollywoodreporter.com/feed/',
    ],
    NewsCategory.business: [
      'https://www.ft.com/news-feed.rss', // Replaced with FT for quality
      'https://www.cnbc.com/id/100003114/device/rss/rss.html', // Replaced with CNBC
    ],
    NewsCategory.health: [
      'https://www.who.int/rss-feeds/news-english.xml', // Added for completeness
    ],
  };

  /// Flattened list of all feed URLs.
  static List<String> get all => feeds.values.expand((f) => f).toList();
}
