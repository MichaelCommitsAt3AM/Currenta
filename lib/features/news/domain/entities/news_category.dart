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

  static const supportedCountries = [
    'KE', // Kenya
    'NG', // Nigeria
    'ZA', // South Africa
    'GB', // United Kingdom
    'IN', // India
    'CA', // Canada
    'AU', // Australia
    'DE', // Germany
    'FR', // France
    'JP', // Japan
    'BR', // Brazil
  ];

  static String getCountryName(String code) {
    return switch (code.toUpperCase()) {
      'KE' => 'Kenya',
      'NG' => 'Nigeria',
      'ZA' => 'South Africa',
      'GB' => 'United Kingdom',
      'IN' => 'India',
      'CA' => 'Canada',
      'AU' => 'Australia',
      'DE' => 'Germany',
      'FR' => 'France',
      'JP' => 'Japan',
      'BR' => 'Brazil',
      'US' => 'United States',
      _ => 'Global',
    };
  }

  static String getCountryEmoji(String code) {
    return switch (code.toUpperCase()) {
      'KE' => '🇰🇪',
      'NG' => '🇳🇬',
      'ZA' => '🇿🇦',
      'GB' => '🇬🇧',
      'IN' => '🇮🇳',
      'CA' => '🇨🇦',
      'AU' => '🇦🇺',
      'DE' => '🇩🇪',
      'FR' => '🇫🇷',
      'JP' => '🇯🇵',
      'BR' => '🇧🇷',
      'US' => '🇺🇸',
      _ => '🌐',
    };
  }

  bool isSupported(String? countryCode) {
    if (this != NewsCategory.local) return true;
    final code = countryCode?.toUpperCase();
    if (supportedCountries.contains(code)) return true;

    // Fallback: If country code is missing/generic, check if timezone matches Kenya (UTC+3)
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

  List<NewsSubCategory> get subCategories => switch (this) {
        NewsCategory.politics => [
            NewsSubCategory.elections,
            NewsSubCategory.policy,
            NewsSubCategory.government,
            NewsSubCategory.internationalRelations,
            NewsSubCategory.lawJustice,
            NewsSubCategory.military,
            NewsSubCategory.diplomacy,
          ],
        NewsCategory.tech => [
            NewsSubCategory.aiMl,
            NewsSubCategory.cybersecurity,
            NewsSubCategory.startups,
            NewsSubCategory.gadgets,
            NewsSubCategory.socialMedia,
            NewsSubCategory.software,
            NewsSubCategory.spaceTech,
            NewsSubCategory.crypto,
            NewsSubCategory.semiconductors,
            NewsSubCategory.robotics,
          ],
        NewsCategory.science => [
            NewsSubCategory.space,
            NewsSubCategory.physics,
            NewsSubCategory.biology,
            NewsSubCategory.archaeology,
            NewsSubCategory.psychology,
            NewsSubCategory.astronomy,
            NewsSubCategory.genetics,
            NewsSubCategory.neuroscience,
          ],
        NewsCategory.business => [
            NewsSubCategory.markets,
            NewsSubCategory.economy,
            NewsSubCategory.realEstate,
            NewsSubCategory.retail,
            NewsSubCategory.laborJobs,
            NewsSubCategory.finance,
            NewsSubCategory.investing,
            NewsSubCategory.fintech,
          ],
        NewsCategory.sports => [
            NewsSubCategory.football,
            NewsSubCategory.americanFootball,
            NewsSubCategory.basketball,
            NewsSubCategory.soccer,
            NewsSubCategory.tennis,
            NewsSubCategory.cricket,
            NewsSubCategory.athletics,
            NewsSubCategory.motorsport,
            NewsSubCategory.combatSports,
            NewsSubCategory.olympics,
          ],
        NewsCategory.entertainment => [
            NewsSubCategory.movies,
            NewsSubCategory.music,
            NewsSubCategory.tvStreaming,
            NewsSubCategory.gaming,
            NewsSubCategory.celebrity,
            NewsSubCategory.books,
            NewsSubCategory.art,
            NewsSubCategory.theater,
            NewsSubCategory.anime,
            NewsSubCategory.photography,
          ],
        NewsCategory.health => [
            NewsSubCategory.mentalHealth,
            NewsSubCategory.nutrition,
            NewsSubCategory.fitness,
            NewsSubCategory.medicalResearch,
            NewsSubCategory.publicHealth,
            NewsSubCategory.wellness,
            NewsSubCategory.parenting,
            NewsSubCategory.biohacking,
            NewsSubCategory.longevity,
          ],
        NewsCategory.world => [
            NewsSubCategory.africa,
            NewsSubCategory.asia,
            NewsSubCategory.europe,
            NewsSubCategory.middleEast,
            NewsSubCategory.conflict,
            NewsSubCategory.internationalTrade,
            NewsSubCategory.humanitarianAid,
            NewsSubCategory.globalSummits,
            NewsSubCategory.northAmerica,
            NewsSubCategory.latinAmerica,
            NewsSubCategory.oceania,
          ],
        NewsCategory.environment => [
            NewsSubCategory.climateChange,
            NewsSubCategory.energy,
            NewsSubCategory.conservation,
            NewsSubCategory.wildlife,
            NewsSubCategory.naturalDisasters,
            NewsSubCategory.sustainability,
            NewsSubCategory.renewableEnergy,
          ],
        NewsCategory.local => [],
      };
}

enum NewsSubCategory {
  // Politics
  elections,
  policy,
  government,
  internationalRelations,
  lawJustice,
  military,
  diplomacy,

  // Tech
  aiMl,
  cybersecurity,
  startups,
  gadgets,
  socialMedia,
  software,
  spaceTech,
  crypto,
  semiconductors,
  robotics,

  // Science
  space,
  physics,
  biology,
  archaeology,
  psychology,
  astronomy,
  genetics,
  neuroscience,

  // Business
  markets,
  economy,
  realEstate,
  retail,
  laborJobs,
  finance,
  investing,
  fintech,

  // Sports
  football,
  americanFootball,
  basketball,
  soccer,
  tennis,
  cricket,
  athletics,
  motorsport,
  combatSports,
  olympics,

  // Entertainment
  movies,
  music,
  tvStreaming,
  gaming,
  celebrity,
  books,
  art,
  theater,
  anime,
  photography,

  // Health
  mentalHealth,
  nutrition,
  fitness,
  medicalResearch,
  publicHealth,
  wellness,
  parenting,
  biohacking,
  longevity,

  // World
  africa,
  asia,
  europe,
  middleEast,
  conflict,
  internationalTrade,
  humanitarianAid,
  globalSummits,
  northAmerica,
  latinAmerica,
  oceania,

  // Environment
  climateChange,
  energy,
  conservation,
  wildlife,
  naturalDisasters,
  sustainability,
  renewableEnergy,

  // Local
  community,
  events,
  traffic,
  localGovernment;

  String get displayName => switch (this) {
        NewsSubCategory.elections => 'Elections',
        NewsSubCategory.policy => 'Policy',
        NewsSubCategory.government => 'Government',
        NewsSubCategory.internationalRelations => 'International Relations',
        NewsSubCategory.lawJustice => 'Law & Justice',
        NewsSubCategory.military => 'Military',
        NewsSubCategory.diplomacy => 'Diplomacy',
        NewsSubCategory.aiMl => 'AI & ML',
        NewsSubCategory.cybersecurity => 'Cybersecurity',
        NewsSubCategory.startups => 'Startups',
        NewsSubCategory.gadgets => 'Gadgets',
        NewsSubCategory.socialMedia => 'Social Media',
        NewsSubCategory.software => 'Software',
        NewsSubCategory.spaceTech => 'Space Tech',
        NewsSubCategory.crypto => 'Crypto',
        NewsSubCategory.semiconductors => 'Semiconductors',
        NewsSubCategory.robotics => 'Robotics',
        NewsSubCategory.space => 'Space',
        NewsSubCategory.physics => 'Physics',
        NewsSubCategory.biology => 'Biology',
        NewsSubCategory.archaeology => 'Archaeology',
        NewsSubCategory.psychology => 'Psychology',
        NewsSubCategory.astronomy => 'Astronomy',
        NewsSubCategory.genetics => 'Genetics',
        NewsSubCategory.neuroscience => 'Neuroscience',
        NewsSubCategory.markets => 'Markets',
        NewsSubCategory.economy => 'Economy',
        NewsSubCategory.realEstate => 'Real Estate',
        NewsSubCategory.retail => 'Retail',
        NewsSubCategory.laborJobs => 'Labor & Jobs',
        NewsSubCategory.finance => 'Finance',
        NewsSubCategory.investing => 'Investing',
        NewsSubCategory.fintech => 'Fintech',
        NewsSubCategory.football => 'Football',
        NewsSubCategory.americanFootball => 'American Football',
        NewsSubCategory.basketball => 'Basketball',
        NewsSubCategory.soccer => 'Soccer',
        NewsSubCategory.tennis => 'Tennis',
        NewsSubCategory.cricket => 'Cricket',
        NewsSubCategory.athletics => 'Athletics',
        NewsSubCategory.motorsport => 'Motorsport',
        NewsSubCategory.combatSports => 'Combat Sports',
        NewsSubCategory.olympics => 'Olympics',
        NewsSubCategory.movies => 'Movies',
        NewsSubCategory.music => 'Music',
        NewsSubCategory.tvStreaming => 'TV & Streaming',
        NewsSubCategory.gaming => 'Gaming',
        NewsSubCategory.celebrity => 'Celebrity',
        NewsSubCategory.books => 'Books',
        NewsSubCategory.art => 'Art',
        NewsSubCategory.theater => 'Theater',
        NewsSubCategory.anime => 'Anime',
        NewsSubCategory.photography => 'Photography',
        NewsSubCategory.mentalHealth => 'Mental Health',
        NewsSubCategory.nutrition => 'Nutrition',
        NewsSubCategory.fitness => 'Fitness',
        NewsSubCategory.medicalResearch => 'Medical Research',
        NewsSubCategory.publicHealth => 'Public Health',
        NewsSubCategory.wellness => 'Wellness',
        NewsSubCategory.parenting => 'Parenting',
        NewsSubCategory.biohacking => 'Biohacking',
        NewsSubCategory.longevity => 'Longevity',
        NewsSubCategory.africa => 'Africa',
        NewsSubCategory.asia => 'Asia',
        NewsSubCategory.europe => 'Europe',
        NewsSubCategory.middleEast => 'Middle East',
        NewsSubCategory.conflict => 'Conflict',
        NewsSubCategory.internationalTrade => 'International Trade',
        NewsSubCategory.humanitarianAid => 'Humanitarian Aid',
        NewsSubCategory.globalSummits => 'Global Summits',
        NewsSubCategory.northAmerica => 'North America',
        NewsSubCategory.latinAmerica => 'Latin America',
        NewsSubCategory.oceania => 'Oceania',
        NewsSubCategory.climateChange => 'Climate Change',
        NewsSubCategory.energy => 'Energy',
        NewsSubCategory.conservation => 'Conservation',
        NewsSubCategory.wildlife => 'Wildlife',
        NewsSubCategory.naturalDisasters => 'Natural Disasters',
        NewsSubCategory.sustainability => 'Sustainability',
        NewsSubCategory.renewableEnergy => 'Renewable Energy',
        NewsSubCategory.community => 'Community',
        NewsSubCategory.events => 'Events',
        NewsSubCategory.traffic => 'Traffic',
        NewsSubCategory.localGovernment => 'Local Government',
      };
}
