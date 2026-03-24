import 'package:shared_preferences/shared_preferences.dart';

class LocalPersistenceRepository {
  LocalPersistenceRepository({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _kCurrentArticleId = 'current_article_id';

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
}
