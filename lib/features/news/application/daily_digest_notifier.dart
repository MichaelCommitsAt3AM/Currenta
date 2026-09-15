// lib/features/news/application/daily_digest_notifier.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/entities/news_article.dart';
import '../domain/entities/news_category.dart';
import '../domain/repositories/news_repository.dart';
import '../data/repositories/local_persistence_repository.dart';
import '../../../core/providers/providers.dart';
import '../../auth/application/auth_notifier.dart';
import 'news_feed_notifier.dart';

part 'daily_digest_notifier.g.dart';

const int _kDigestTotal = 8;
const int _kDigestLocalCount = 3;
const int _kDigestGlobalCount = 5;

// A restart-interrupted digest resumes from its persisted snapshot (same
// articles, same 1..N numbering) if reopened within this window of the
// original fetch. Chosen to match backend/services/trending.py's own
// TREND_SCORE_DECAY_MIN_INTERVAL_SECONDS (1800s) — within that window the
// underlying trending picture genuinely can't have shifted, so resuming the
// same set isn't showing stale content. Once it elapses, that day's digest
// is considered used up (whether the user finished it or not) and won't
// reappear until tomorrow — it does NOT reset to a fresh batch mid-day.
const Duration _kDigestFreshnessWindow = Duration(minutes: 30);

DateTime _todayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool _isSameLocalDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _snapshotStillFresh(DigestSnapshot? snapshot) {
  if (snapshot == null) return false;
  return DateTime.now().difference(snapshot.fetchedAt) <
      _kDigestFreshnessWindow;
}

/// Synchronous eligibility check (no network dependency) — true when the
/// digest either hasn't been issued yet today, or was issued today and is
/// still within its resume window. `FeedScreen` reads this directly (not
/// via the async [dailyDigestNotifierProvider]) so it can pick the right
/// header on the very first frame, instead of flashing the normal category
/// bar while the digest fetch/resume is still in flight.
bool isDigestEligibleNow(LocalPersistenceRepository persistence) {
  if (!persistence.hasSeenFeedOnboarding()) return false;

  final issuedToday =
      _isSameLocalDay(persistence.getLastDigestShownDate(), _todayLocal());
  if (!issuedToday) return true;
  return _snapshotStillFresh(persistence.getDigestSnapshot());
}

/// Synchronous mirror of the resume-index decision in
/// [DailyDigestNotifier._computeState] — used to seed `FeedScreen`'s
/// `PageController` at construction time so the correct page is there from
/// the very first mount. Waiting for `DailyDigestNotifier.setCurrentIndex`
/// to fire asynchronously and jump the controller afterward is a race: if
/// the PageView hasn't mounted yet (still behind the digest-resolution
/// shimmer) when that jump attempt happens, `PageController.hasClients` is
/// false, the jump silently no-ops, and nothing retries it once the
/// PageView finally does mount.
int digestResumeIndexOrZero(LocalPersistenceRepository persistence) {
  if (!isDigestEligibleNow(persistence)) {
    return 0;
  }
  final issuedToday =
      _isSameLocalDay(persistence.getLastDigestShownDate(), _todayLocal());
  if (!issuedToday) return 0;
  final snapshot = persistence.getDigestSnapshot();
  if (!_snapshotStillFresh(snapshot)) return 0;
  return persistence
      .getDigestLastIndex()
      .clamp(0, snapshot!.articles.length - 1);
}

@immutable
class DailyDigestState {
  const DailyDigestState({
    this.articles = const [],
    this.isVisible = false,
    this.dismissedEarly = false,
  });

  /// The digest articles, already merged onto the front of the "For You"
  /// feed (see [DailyDigestNotifier._computeState]) by the time this state
  /// resolves. `FeedScreen` uses `articles.length` to know how many of the
  /// leading items in the feed are digest items.
  final List<NewsArticle> articles;

  final bool isVisible;

  /// True once the user manually toggles off the digest header before
  /// scrolling past it. Forces the header back to the normal category bar
  /// immediately, without affecting the merged feed content itself.
  final bool dismissedEarly;

  DailyDigestState copyWith({
    List<NewsArticle>? articles,
    bool? isVisible,
    bool? dismissedEarly,
  }) {
    return DailyDigestState(
      articles: articles ?? this.articles,
      isVisible: isVisible ?? this.isVisible,
      dismissedEarly: dismissedEarly ?? this.dismissedEarly,
    );
  }
}

@Riverpod(keepAlive: true)
class DailyDigestNotifier extends _$DailyDigestNotifier {
  NewsRepository get _repo => ref.read(newsRepositoryProvider);

  DateTime? _lastEvaluatedDay;

  @override
  Future<DailyDigestState> build() async {
    final computed = await _computeState();
    _lastEvaluatedDay = _todayLocal();
    return computed;
  }

  Future<DailyDigestState> _computeState() async {
    final persistence = ref.read(localPersistenceRepositoryProvider);

    if (!persistence.hasSeenFeedOnboarding()) {
      return const DailyDigestState();
    }

    final issuedToday =
        _isSameLocalDay(persistence.getLastDigestShownDate(), _todayLocal());

    if (issuedToday) {
      // Already issued today: either resume the exact same snapshot within
      // its freshness window (e.g. the app was restarted mid-digest and the
      // in-memory merge was lost), or it's used up for today regardless of
      // how far the user got — no second fresh batch until tomorrow.
      final snapshot = persistence.getDigestSnapshot();
      if (!_snapshotStillFresh(snapshot)) {
        return const DailyDigestState();
      }
      final feedNotifier = ref.read(newsFeedNotifierProvider.notifier);
      await feedNotifier.pinArticlesToFront(snapshot!.articles);

      // Resume at the saved reading position instead of NewsFeedNotifier's
      // usual cold-start "always start at top" reset.
      final resumeIndex = persistence
          .getDigestLastIndex()
          .clamp(0, snapshot.articles.length - 1);
      feedNotifier.setCurrentIndex(resumeIndex, category: null);

      return DailyDigestState(articles: snapshot.articles, isVisible: true);
    }

    // read, not watch: this helper is also called from refreshIfNewCalendarDay(),
    // outside build(), where ref.watch is not permitted.
    final authState = ref.read(authNotifierProvider);
    final deviceCountry = PlatformDispatcher.instance.locale.countryCode;
    final userCountry = authState.preferredCountry ??
        authState.detectedCountry ??
        (deviceCountry != null && deviceCountry.isNotEmpty
            ? deviceCountry
            : null);

    final includeLocal = userCountry != null &&
        authState.selectedInterests.contains(NewsCategory.local.name) &&
        NewsCategory.local.isSupported(userCountry);

    try {
      final articles = includeLocal
          ? await _fetchBlended(userCountry)
          : await _repo.fetchTrending(
              limit: _kDigestTotal,
              country: null,
              hours: 24,
            );

      if (articles.isEmpty) {
        return const DailyDigestState();
      }

      // Merge onto the front of "For You" before this state resolves, so
      // FeedScreen only ever reveals feed content with the digest already
      // in place — never an unmerged list that suddenly grows underneath
      // whatever the user is currently reading.
      await ref
          .read(newsFeedNotifierProvider.notifier)
          .pinArticlesToFront(articles);

      final now = DateTime.now();
      unawaited(persistence.setLastDigestShownDate(now));
      unawaited(persistence.saveDigestSnapshot(
          DigestSnapshot(articles: articles, fetchedAt: now)));
      unawaited(persistence.saveDigestLastIndex(0));

      return DailyDigestState(articles: articles, isVisible: true);
    } catch (e) {
      debugPrint('[DailyDigest] Error fetching digest: $e');
      return const DailyDigestState();
    }
  }

  Future<List<NewsArticle>> _fetchBlended(String userCountry) async {
    final results = await Future.wait([
      _repo.fetchTrending(
          limit: _kDigestLocalCount + 2, country: userCountry, hours: 24),
      _repo.fetchTrending(
          limit: _kDigestGlobalCount + 2, country: null, hours: 24),
    ]);

    final local = results[0];
    final global = results[1].where((a) => a.countryCode == null).toList();

    final combined = <NewsArticle>[];
    combined.addAll(local.take(_kDigestLocalCount));
    combined.addAll(global.take(_kDigestGlobalCount));

    if (combined.length < _kDigestTotal) {
      final remaining = _kDigestTotal - combined.length;
      final moreGlobal = global.skip(_kDigestGlobalCount).take(remaining);
      combined.addAll(moreGlobal);
    }

    if (combined.length < _kDigestTotal) {
      final remaining = _kDigestTotal - combined.length;
      final moreLocal = local.skip(_kDigestLocalCount).take(remaining);
      combined.addAll(moreLocal);
    }

    return combined.take(_kDigestTotal).toList();
  }

  /// Manual "skip the digest chrome now" shortcut — the merged content
  /// stays exactly where it is, only the header stops treating the
  /// remaining leading articles as "digest" ones.
  void dismiss() {
    final current = state.valueOrNull;
    if (current == null || !current.isVisible || current.dismissedEarly) {
      return;
    }
    state = AsyncData(current.copyWith(dismissedEarly: true));
  }

  /// Persists the current scroll position within the digest, so a restart
  /// within the freshness window resumes here instead of at article 1.
  /// Fire-and-forget — called from FeedScreen on every page change while
  /// still within the digest's leading articles.
  void recordViewedIndex(int index) {
    unawaited(ref
        .read(localPersistenceRepositoryProvider)
        .saveDigestLastIndex(index));
  }

  Future<void> refreshIfNewCalendarDay() async {
    final today = _todayLocal();
    if (_lastEvaluatedDay != null &&
        _isSameLocalDay(_lastEvaluatedDay, today)) {
      return;
    }
    final next = await _computeState();
    _lastEvaluatedDay = today;
    state = AsyncData(next);
  }
}
