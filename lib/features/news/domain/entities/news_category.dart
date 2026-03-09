// lib/features/news/domain/entities/news_category.dart

enum NewsCategory {
  politics,
  tech,
  science,
  business,
  sports,
  entertainment,
  health,
  world,
  environment,
  local;

  static const supportedCountries = ['KE'];

  bool isSupported(String? countryCode) {
    if (this != NewsCategory.local) return true;
    return supportedCountries.contains(countryCode?.toUpperCase());
  }

  String get displayName => switch (this) {
        NewsCategory.politics => 'Politics',
        NewsCategory.tech => 'Tech',
        NewsCategory.science => 'Science',
        NewsCategory.business => 'Business',
        NewsCategory.sports => 'Sports',
        NewsCategory.entertainment => 'Entertainment',
        NewsCategory.health => 'Health',
        NewsCategory.world => 'World',
        NewsCategory.environment => 'Environment',
        NewsCategory.local => 'Local',
      };

  String get emoji => switch (this) {
        NewsCategory.politics => '🏛️',
        NewsCategory.tech => '💻',
        NewsCategory.science => '🔬',
        NewsCategory.business => '📈',
        NewsCategory.sports => '⚽',
        NewsCategory.entertainment => '🎬',
        NewsCategory.health => '🏥',
        NewsCategory.world => '🌍',
        NewsCategory.environment => '🌱',
        NewsCategory.local => '📍',
      };
}
