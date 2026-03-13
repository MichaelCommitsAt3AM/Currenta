// lib/features/news/application/likes_notifier.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';

part 'likes_notifier.g.dart';

@riverpod
class LikesNotifier extends _$LikesNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);

  @override
  Stream<List<NewsArticle>> build() {
    // Refresh the stream if user logs in/out.
    ref.watch(authNotifierProvider);
    return _repo.watchLikes();
  }

  Future<void> toggleLike(String articleId) async {
    await _repo.toggleLike(articleId);
  }
}
