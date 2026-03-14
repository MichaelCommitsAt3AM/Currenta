import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/news_category.dart';

class LocalPersistenceRepository {
  LocalPersistenceRepository({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _kCurrentArticleId = 'current_article_id';
  static const _kCurrentCategory = 'current_category';

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

  Future<void> saveCurrentCategory(NewsCategory? category) async {
    if (category == null) {
      await _prefs.remove(_kCurrentCategory);
    } else {
      await _prefs.setString(_kCurrentCategory, category.name);
    }
  }

  NewsCategory? getCurrentCategory() {
    final name = _prefs.getString(_kCurrentCategory);
    if (name == null) return null;
    try {
      return NewsCategory.values.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }
}
