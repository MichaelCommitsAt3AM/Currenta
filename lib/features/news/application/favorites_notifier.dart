// lib/features/news/application/favorites_notifier.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';

part 'favorites_notifier.g.dart';

@riverpod
class FavoritesNotifier extends _$FavoritesNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);

  @override
  Stream<List<NewsArticle>> build() {
    // Refresh the stream if user logs in/out.
    ref.watch(authNotifierProvider);
    return _repo.watchFavorites();
  }

  Future<void> toggleFavorite(String articleId) async {
    await _repo.toggleFavorite(articleId);
  }
}
