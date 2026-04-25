import 'package:shared_preferences/shared_preferences.dart';

class LocalPersistenceRepository {
  LocalPersistenceRepository({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _kCurrentArticleId = 'current_article_id';
  static const _kLastForYouArticleId = 'last_for_you_article_id';
  static const _kHasSeenFeedOnboarding = 'has_seen_feed_onboarding';
  static const _kHasSeenPersonalizationOnboarding = 'has_seen_personalization_onboarding';
  static const _kNeedsFeedRefresh = 'needs_feed_refresh';
  static const _kLastRefreshAt = 'last_refresh_at';

  Future<void> saveCurrentArticleId(String? articleId) async {
    if (articleId == null) {
      await _prefs.remove(_kCurrentArticleId);
    } else {
      await _prefs.setString(_kCurrentArticleId, articleId);
    }
  }

  String? getCurrentArticleId() {
    return _prefs.getString(_kCurrentArticleId);
  }

  Future<void> saveLastRefreshTime(DateTime? time) async {
    if (time == null) {
      await _prefs.remove(_kLastRefreshAt);
    } else {
      await _prefs.setString(_kLastRefreshAt, time.toIso8601String());
    }
  }

  DateTime? getLastRefreshTime() {
    final iso = _prefs.getString(_kLastRefreshAt);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  Future<void> saveLastForYouArticleId(String? articleId) async {
    if (articleId == null) {
      await _prefs.remove(_kLastForYouArticleId);
    } else {
      await _prefs.setString(_kLastForYouArticleId, articleId);
    }
  }

  String? getLastForYouArticleId() {
    return _prefs.getString(_kLastForYouArticleId);
  }

  bool hasSeenFeedOnboarding() {
    return _prefs.getBool(_kHasSeenFeedOnboarding) ?? false;
  }

  Future<void> setHasSeenFeedOnboarding(bool value) async {
    await _prefs.setBool(_kHasSeenFeedOnboarding, value);
  }

  bool hasSeenPersonalizationOnboarding() =>
      _prefs.getBool(_kHasSeenPersonalizationOnboarding) ?? false;

  Future<void> setHasSeenPersonalizationOnboarding(bool value) =>
      _prefs.setBool(_kHasSeenPersonalizationOnboarding, value);

  bool needsFeedRefresh() => _prefs.getBool(_kNeedsFeedRefresh) ?? false;

  Future<void> setNeedsFeedRefresh(bool value) =>
      _prefs.setBool(_kNeedsFeedRefresh, value);
}
