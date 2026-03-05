// lib/core/config/news_sources.dart

import '../../features/news/domain/entities/news_category.dart';

/// Represents a single RSS feed configuration.
class FeedConfig {
  final String url;
  final String categoryBias; // 'strong' or 'neutral'

  const FeedConfig({
    required this.url,
    this.categoryBias = 'neutral',
  });
}

/// Central registry of RSS feeds for the ingestion pipeline.
class NewsSources {
  NewsSources._();

  /// A map of categories to their high-quality RSS feed URLs and bias configs.
  static const Map<NewsCategory, List<FeedConfig>> feeds = {
    NewsCategory.world: [
      FeedConfig(
          url: 'http://feeds.bbci.co.uk/news/rss.xml', categoryBias: 'neutral'),
      FeedConfig(
          url: 'http://feeds.bbci.co.uk/news/world/rss.xml',
          categoryBias: 'neutral'),
      FeedConfig(
          url:
              'https://www.reutersagency.com/feed/?best-topics=political-general&post_type=best',
          categoryBias: 'neutral'),
      FeedConfig(
          url: 'https://www.aljazeera.com/xml/rss/all.xml',
          categoryBias: 'neutral'),
      FeedConfig(
          url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
          categoryBias: 'neutral'),
      FeedConfig(
          url: 'https://feeds.a.dj.com/rss/RSSWorldNews.xml',
          categoryBias: 'neutral'),
      FeedConfig(
          url: 'https://www.dw.com/xml/rss-en-all', categoryBias: 'neutral'),
      FeedConfig(
          url: 'https://www.france24.com/en/rss', categoryBias: 'neutral'),
    ],
    NewsCategory.tech: [
      FeedConfig(
          url: 'https://www.theverge.com/rss/index.xml',
          categoryBias: 'strong'),
      FeedConfig(url: 'https://techcrunch.com/feed/', categoryBias: 'strong'),
      FeedConfig(url: 'https://www.wired.com/feed/rss', categoryBias: 'strong'),
      FeedConfig(url: 'https://www.cnet.com/rss/news/', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://feeds.arstechnica.com/arstechnica/index',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.engadget.com/rss.xml', categoryBias: 'strong'),
      FeedConfig(url: 'https://9to5mac.com/feed/', categoryBias: 'strong'),
      FeedConfig(url: 'https://www.gizmodo.com/rss', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://mashable.com/feeds/rss/all', categoryBias: 'strong'),
    ],
    NewsCategory.politics: [
      FeedConfig(
          url: 'https://www.politico.com/rss/politicopicks.xml',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://thehill.com/homenews/feed/', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://rss.nytimes.com/services/xml/rss/nyt/Politics.xml',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.huffpost.com/section/politics/feed',
          categoryBias: 'strong'),
    ],
    NewsCategory.science: [
      FeedConfig(
          url: 'https://www.sciencedaily.com/rss/all.xml',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.sciencedaily.com/rss/top/science.xml',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.nature.com/nature.rss', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.scientificamerican.com/section/all/feed/',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.newscientist.com/feed/home/',
          categoryBias: 'strong'),
    ],
    NewsCategory.sports: [
      FeedConfig(
          url: 'https://www.skysports.com/rss/12040', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://feeds.bbci.co.uk/sport/rss.xml',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.espn.com/espn/rss/news', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.cbssports.com/rss/headlines/',
          categoryBias: 'strong'),
    ],
    NewsCategory.entertainment: [
      FeedConfig(url: 'https://variety.com/feed/', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.hollywoodreporter.com/feed/',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.billboard.com/feed/', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.rollingstone.com/feed/', categoryBias: 'strong'),
    ],
    NewsCategory.business: [
      FeedConfig(
          url: 'https://www.ft.com/news-feed.rss', categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.cnbc.com/id/100003114/device/rss/rss.html',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://feeds.a.dj.com/rss/WSJcomUSBusiness.xml',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.bloomberg.com/feeds/podcasts/pfe_itunes.xml',
          categoryBias:
              'strong'), // Note: Bloomberg is tough with RSS, using podcast feed as fallback
    ],
    NewsCategory.health: [
      FeedConfig(
          url: 'https://www.who.int/rss-feeds/news-english.xml',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.healthline.com/rss/all-news.xml',
          categoryBias: 'strong'),
      FeedConfig(
          url: 'https://www.mayoclinic.org/rss/all-news-topics.xml',
          categoryBias: 'strong'),
    ],
    NewsCategory.environment: [
      FeedConfig(
          url: 'https://www.theguardian.com/environment/rss',
          categoryBias: 'strong'),
      FeedConfig(
          url:
              'https://www.sciencedaily.com/rss/earth_climate/environmental_issues.xml',
          categoryBias: 'strong'),
    ],
  };

  /// Flattened list of all feed URLs.
  static List<String> get all =>
      feeds.values.expand((f) => f).map((config) => config.url).toList();
}
