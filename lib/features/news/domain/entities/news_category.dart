// lib/features/news/domain/entities/news_category.dart

enum NewsCategory {
  local,
  politics,
  tech,
  science,
  business,
  sports,
  entertainment,
  health,
  world,
  environment;

  static const supportedCountries = ['KE'];

  bool isSupported(String? countryCode) {
    if (this != NewsCategory.local) return true;
    final code = countryCode?.toUpperCase();
    if (supportedCountries.contains(code)) return true;

    // Fallback: If country code is missing/generic, check if timezone matches Kenya (UTC+3)
    // This handles users in Kenya who have their phone set to en_US/en_GB.
    if (code == null || code.isEmpty || code == 'US' || code == 'GB') {
      if (DateTime.now().timeZoneOffset.inHours == 3) return true;
    }
    return false;
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
