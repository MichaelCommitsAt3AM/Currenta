// lib/features/news/presentation/screens/feed_screen.dart
// Full-screen vertical PageView feed — one story per screen,
// swipe down (upward gesture) advances to the next story.
// Loads the next batch of 10 articles when the user is within 5 pages of the end.

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../application/news_feed_notifier.dart';
import '../../domain/entities/news_category.dart';
import '../widgets/news_card.dart';
import '../widgets/shimmer_feed.dart';
import '../widgets/sidebar.dart';
import '../../../auth/application/auth_notifier.dart';
import '../widgets/ai_quick_chat_sheet.dart';
import 'empty_state_screen.dart';
import 'error_state_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/utils/browser_service.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  NewsCategory? _selectedCategory;
  late final PageController _pageController;
  int _currentIndex = 0;
  final Set<String> _viewedIdsInSession = {};
  bool _hasWarmedUpBrowser = false;
  Timer? _viewTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final initialIndex =
        ref.read(newsFeedNotifierProvider).valueOrNull?.currentIndex ?? 0;
    _pageController = PageController(initialPage: initialIndex);
    _currentIndex = initialIndex;
    _selectedCategory =
        ref.read(newsFeedNotifierProvider).valueOrNull?.selectedCategory;
    _pageController.addListener(_onPageScroll);

    // Mark the very first article as viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackPageView(0);
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _viewTimer?.cancel();
    super.dispose();
  }

  int _lastTriggeredPage = -1;

  void _maybeLoadMore({int? pageHint}) {
    final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
    if (feed == null || feed.isLoadingMore || !feed.hasMore) return;

    final totalPages = feed.articles.length;
    if (totalPages <= 0) return;

    final currentPage = pageHint ??
        (_pageController.hasClients ? (_pageController.page?.round() ?? 0) : 0);
    final nearEnd = currentPage >= totalPages - 5;
    if (!nearEnd) return;

    // Deduplicate by page index, but allow fresh triggers when category/feed resets
    // by resetting _lastTriggeredPage in the relevant state transitions.
    if (currentPage == _lastTriggeredPage) return;

    _lastTriggeredPage = currentPage;
    ref.read(newsFeedNotifierProvider.notifier).loadNextPage();
  }

  /// Triggers next-page load when we are within 5 pages of the end.
  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    _maybeLoadMore();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    ref.read(newsFeedNotifierProvider.notifier).updateCurrentIndex(index);

    final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
    if (feed == null) return;

    // 1. Preload images for next 5 articles to ensure smooth scrolling
    for (var ahead = 1; ahead <= 5; ahead++) {
      final nextIndex = index + ahead;
      if (nextIndex < feed.articles.length) {
        final article = feed.articles[nextIndex];

        // Image preloading
        final imageUrl = article.imageUrl;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(imageUrl), context);
        }
      }
    }

    // 2. Track view
    _trackPageView(index);

    // 3. Double-check load-more on discrete page changes.
    // This prevents missing pagination when the scroll listener doesn't produce
    // a new rounded page value near the list end.
    _maybeLoadMore(pageHint: index);
  }

  void _trackPageView(int index) {
    _viewTimer?.cancel();
    final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
    if (feed != null && index < feed.articles.length) {
      final article = feed.articles[index];
      // Only track if we haven't tracked it this session
      if (!_viewedIdsInSession.contains(article.id)) {
        _viewTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          _viewedIdsInSession.add(article.id);
          ref
              .read(newsFeedNotifierProvider.notifier)
              .markArticleAsViewed(article.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(newsFeedNotifierProvider, (previous, next) {
      final nextFeed = next.valueOrNull;
      if (nextFeed == null) return;

      // 1. Keep local chip state aligned with notifier state across relaunch/restoration.
      if (nextFeed.selectedCategory != _selectedCategory && mounted) {
        setState(() {
          _selectedCategory = nextFeed.selectedCategory;
        });
        // Reset pagination trigger marker when feed scope changes.
        _lastTriggeredPage = -1;
      }

      // 2. Sync PageController if state changed index independently (e.g., restoration or refresh)
      final prevIndex = previous?.valueOrNull?.currentIndex;
      final nextIndex = nextFeed.currentIndex;
      final controllerPage =
          _pageController.hasClients ? _pageController.page?.round() : null;

      if (nextIndex != prevIndex && nextIndex != controllerPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            // If it's the very first load (prevFeed == null), jump immediately.
            // Otherwise, animate to provide visual context of the "shift".
            if (previous?.valueOrNull == null) {
              _pageController.jumpToPage(nextIndex);
            } else {
              _pageController.animateToPage(
                nextIndex,
                duration: const Duration(milliseconds: 600),
                curve: Curves.fastOutSlowIn,
              );
            }
            if (_currentIndex != nextIndex) {
              setState(() => _currentIndex = nextIndex);
            }
          }
        });
      }

      // 2. Handle AI Chat sheet
      if (nextFeed.showChatForArticleId != null) {
        final articleId = nextFeed.showChatForArticleId!;
        final article = nextFeed.articles.firstWhere((a) => a.id == articleId);

        // Clear immediately so it doesn't re-open on next rebuild
        ref.read(newsFeedNotifierProvider.notifier).clearPendingChat();

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AiQuickChatSheet(article: article),
        );
      }
    });

    final feedAsync = ref.watch(newsFeedNotifierProvider);
    final feed = feedAsync.valueOrNull;

    // Determine the color of the current article for the sidebar
    final articles = feed?.articles ?? [];
    final currentArticle =
        (_currentIndex >= 0 && _currentIndex < articles.length)
            ? articles[_currentIndex]
            : null;
    final primaryCategory = currentArticle?.categories.isNotEmpty == true
        ? currentArticle!.categories.first
        : null;
    final catColor = AppTheme.categoryColor(primaryCategory?.name ?? 'world');

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0A0C14),
      drawer: Sidebar(catColor: catColor),
      body: Stack(
        children: [
          // ── Main content ─────────────────────────────────────────
          feedAsync.when(
            loading: () => const ShimmerFeed(),
            error: (e, _) => ErrorStateScreen(
              error: e,
              onRetry: () =>
                  ref.read(newsFeedNotifierProvider.notifier).refresh(),
            ),
            data: (feed) {
              // ── Conditional UI: Shimmer vs Empty vs Articles ──
              // If we have no articles, show shimmer if we are still loading,
              // or empty state if we are truly done and have nothing.
              if (feed.articles.isEmpty) {
                if (feed.isLoadingMore || feedAsync.isLoading) {
                  return const ShimmerFeed();
                }
                return EmptyStateScreen(
                  onRetry: () =>
                      ref.read(newsFeedNotifierProvider.notifier).refresh(),
                );
              }

              // ── Performance: Browser Pre-warming ──
              // We only warmup once articles are successfully loaded.
              if (!_hasWarmedUpBrowser && feed.articles.isNotEmpty) {
                _hasWarmedUpBrowser = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final browser = ref.read(browserServiceProvider);
                  browser.warmup();
                });
              }

              // Total items = articles + optional loading sentinel at the end
              final itemCount =
                  feed.articles.length + (feed.isLoadingMore ? 1 : 0);

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                itemCount: itemCount,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, i) {
                  // ── Loading sentinel (last slot while fetching) ──
                  if (i >= feed.articles.length) {
                    return const _LoadingMorePage();
                  }

                  final article = feed.articles[i];

                  return RepaintBoundary(
                    child: NewsCard(
                      article: article,
                      index: i,
                      total: feed.articles.length,
                    ),
                  );
                },
              );
            },
          ),

          // ── Category filter bar ──────────────────────────────────
          _CategoryBar(
            selectedCategory: _selectedCategory,
            onCategoryChanged: (cat) {
              if (_selectedCategory == cat) return;

              // Sync UI state immediately for instant feedback
              setState(() {
                _selectedCategory = cat;
              });
              _lastTriggeredPage = -1;

              // Trigger feed loading immediately
              ref.read(newsFeedNotifierProvider.notifier).filterByCategory(cat);
            },
            onRefresh: () =>
                ref.read(newsFeedNotifierProvider.notifier).refresh(),
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          ),

          // ── New Stories Badge ─────────────────────────────────────
          if (feed != null && feed.newArticlesCount > 0)
            _NewStoriesBadge(
              count: feed.newArticlesCount,
              onTap: () {
                // Notifier handles list reconstruction and index shift (Current @ 0, New @ 1)
                ref
                    .read(newsFeedNotifierProvider.notifier)
                    .applyPendingArticles();
              },
            ),
        ],
      ),
    );
  }
}

// ── New Stories Badge ─────────────────────────────────────────────────────────

class _NewStoriesBadge extends StatelessWidget {
  const _NewStoriesBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top + 60;

    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  '$count new ${count == 1 ? 'story' : 'stories'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading-more sentinel page ────────────────────────────────────────────────

class _LoadingMorePage extends StatelessWidget {
  const _LoadingMorePage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Loading more…',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category filter bar ───────────────────────────────────────────────────────

class _CategoryBar extends ConsumerStatefulWidget {
  const _CategoryBar({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onRefresh,
    required this.onOpenDrawer,
  });

  final NewsCategory? selectedCategory;
  final ValueChanged<NewsCategory?> onCategoryChanged;
  final VoidCallback onRefresh;
  final VoidCallback onOpenDrawer;

  @override
  ConsumerState<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends ConsumerState<_CategoryBar> {
  final ScrollController _scrollController = ScrollController();
  final Map<NewsCategory?, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollToSelected(animated: false);
  }

  @override
  void didUpdateWidget(_CategoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      _scrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final key = _itemKeys[widget.selectedCategory];
      if (key?.currentContext == null) return;

      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: animated ? const Duration(milliseconds: 400) : Duration.zero,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    // Ensure we have keys for all categories + null
    _itemKeys.putIfAbsent(null, () => GlobalKey());
    for (final cat in NewsCategory.values) {
      _itemKeys.putIfAbsent(cat, () => GlobalKey());
    }

    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0C14).withValues(alpha: 0.95),
            const Color(0xFF0A0C14).withValues(alpha: 0.70),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            // Fixed Sidebar Menu Button (Left)
            GestureDetector(
              onTap: widget.onOpenDrawer,
              child: Container(
                height: 32,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(100),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.20)),
                ),
                child: const Icon(Icons.menu_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 8),

            // Scrollable Chips area
            Expanded(
              child: SizedBox(
                height: 32,
                child: ListView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FilterChip(
                      key: _itemKeys[null],
                      label: '✨ For You',
                      isSelected: widget.selectedCategory == null,
                      onTap: () => widget.onCategoryChanged(null),
                    ),
                    const SizedBox(width: 8),
                    ..._getSortedCategories(ref)
                        .where((cat) => cat.isSupported(
                            ref.watch(authNotifierProvider).preferredCountry ??
                                View.of(context)
                                    .platformDispatcher
                                    .locale
                                    .countryCode))
                        .map((cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterChip(
                                key: _itemKeys[cat],
                                label: '${cat.emoji}  ${cat.displayName}',
                                isSelected: widget.selectedCategory == cat,
                                onTap: () => widget.onCategoryChanged(cat),
                              ),
                            )),
                    // Refresh button at the very end of chip row
                    GestureDetector(
                      onTap: widget.onRefresh,
                      child: Container(
                        height: 32,
                        width: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20)),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NewsCategory> _getSortedCategories(WidgetRef ref) {
    final selectedInterests = ref.watch(authNotifierProvider).selectedInterests;
    if (selectedInterests.isEmpty) return NewsCategory.values;

    final sorted = List<NewsCategory>.from(NewsCategory.values);
    sorted.sort((a, b) {
      final aSelected = selectedInterests.contains(a.name);
      final bSelected = selectedInterests.contains(b.name);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return 0;
    });
    return sorted;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInCirc,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C63FF)
              : Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : Colors.white.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
