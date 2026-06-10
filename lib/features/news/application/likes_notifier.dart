// lib/features/news/application/likes_notifier.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/repositories/news_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';
import 'dart:async';

part 'likes_notifier.g.dart';

class LikesState {
  final List<NewsArticle> articles;
  final bool hasMore;
  final bool isLoadingMore;

  const LikesState({
    this.articles = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  LikesState copyWith({
    List<NewsArticle>? articles,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return LikesState(
      articles: articles ?? this.articles,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class LikesNotifier extends _$LikesNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);
  StreamSubscription<List<NewsArticle>>? _subscription;
  int _currentOffset = 0;
  bool _hasMoreRemote = true;

  @override
  Future<LikesState> build() async {
    // Refresh if user logs in/out
    ref.watch(authNotifierProvider);

    // Initial sync from remote
    _currentOffset = 0;
    try {
      _hasMoreRemote = await _repo.syncLikedArticles(limit: 30, offset: 0);
    } catch (e) {
      // Ignore initial sync error, we might have local data
    }

    // Subscribe to local DB changes
    final stream = _repo.watchLikes();
    
    // We need to return the initial state and then listen for updates.
    // However, AsyncNotifier works best by updating 'state'.
    
    _subscription?.cancel();
    _subscription = stream.listen((articles) {
      if (state.hasValue) {
        state = AsyncData(state.value!.copyWith(articles: articles));
      }
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    final initialArticles = await stream.first;
    return LikesState(
      articles: initialArticles,
      hasMore: _hasMoreRemote,
      isLoadingMore: false,
    );
  }

  Future<void> loadMore() async {
    final current = state.hasValue ? state.value : null;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      _currentOffset += 30;
      final hasMore = await _repo.syncLikedArticles(
        limit: 30,
        offset: _currentOffset,
      );
      _hasMoreRemote = hasMore;
      
      // The stream subscription will automatically update the 'articles' list
      // once the local DB is updated by syncLikedArticles.
      // We just need to update the flags.
      if (state.hasValue) {
        state = AsyncData(state.value!.copyWith(
          isLoadingMore: false,
          hasMore: _hasMoreRemote,
        ));
      }
    } catch (e) {
      if (state.hasValue) {
        state = AsyncData(state.value!.copyWith(isLoadingMore: false));
      }
      rethrow;
    }
  }

  Future<void> toggleLike(String articleId) async {
    await _repo.toggleLike(articleId);
  }
}
