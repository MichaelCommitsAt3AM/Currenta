// lib/features/news/presentation/screens/feed_screen.dart
// Full-screen vertical PageView feed — one story per screen,
// swipe down (upward gesture) advances to the next story.
// Loads the next batch of 10 articles when the user is within 5 pages of the end.

import 'dart:async';
import 'package:currenta/features/news/domain/entities/news_article.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../application/news_feed_notifier.dart';
import '../../domain/entities/news_category.dart';
import '../widgets/news_card.dart';
import '../widgets/native_ad_card.dart';
import '../../application/ad_manager.dart';
import '../widgets/shimmer_feed.dart';
import '../widgets/sidebar.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../auth/presentation/widgets/location_update_popup.dart';
import '../widgets/ai_quick_chat_sheet.dart';
import '../widgets/feed_onboarding_overlay.dart';
import '../../application/onboarding_notifier.dart';
import 'empty_state_screen.dart';
import 'error_state_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/utils/browser_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/navigation/app_route_observer.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with WidgetsBindingObserver, RouteAware {
  NewsCategory? _selectedCategory;
  late final PageController _pageController;
  int _currentIndex = 0;
  final Set<String> _viewedIdsInSession = {};
  bool _hasWarmedUpBrowser = false;
  Timer? _viewTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasScrolledOnce = false;
  bool _isManualShimmering = false;
  bool _didSubscribeRouteAware = false;
  bool _isRouteVisible = false;
  bool _isShowingRefreshAck = false;
  final GlobalKey _onboardingCategoryKey = GlobalKey();

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
    WidgetsBinding.instance.addObserver(this);

    // Mark the very first article as viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackPageView(0);
    });

    // Eagerly trigger ad preloading pool
    ref.read(adManagerProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didSubscribeRouteAware) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
      _didSubscribeRouteAware = true;
      _isRouteVisible = route.isCurrent;
      _maybeShowPendingRefreshAck();
    }
  }

  void _checkOnboarding() {
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    if (!notifier.hasSeenFeedOnboarding) {
      debugPrint('[FeedScreen] Triggering onboarding');
      // Mark as seen immediately to prevent it from re-triggering
      // on next app start even if they don't finish the steps.
      notifier.markFeedOnboardingSeen();
      _runScrollNudge();
    }
  }

  void _runScrollNudge() async {
    // Initial wait before first nudge
    await Future.delayed(const Duration(milliseconds: 2500));

    // Cycle the nudge every 3 seconds
    while (mounted && !_hasScrolledOnce) {
      final currentStep = ref.read(onboardingNotifierProvider);

      // If we've moved past the scroll step or onboarding is hidden, stop the loop
      if (currentStep != OnboardingStep.none &&
          currentStep != OnboardingStep.scroll) break;

      // Ensure step is set to scroll
      if (currentStep == OnboardingStep.none) {
        ref
            .read(onboardingNotifierProvider.notifier)
            .setStep(OnboardingStep.scroll);
      }

      if (!_pageController.hasClients || _hasScrolledOnce) break;

      // 1. Perform Nudge Down (1s)
      await _pageController.animateTo(
        MediaQuery.sizeOf(context).height * 0.15,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutQuart,
      );

      if (!mounted || !_pageController.hasClients || _hasScrolledOnce) break;

      // 2. Return to 0 (0.8s)
      await _pageController.animateTo(
        0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
      );

      // 3. Wait 3 seconds before starting the next animation cycle
      await Future.delayed(const Duration(seconds: 3));

      // Stop if user dismissed via "Got it" or scrolled
      if (ref.read(onboardingNotifierProvider) != OnboardingStep.scroll ||
          _hasScrolledOnce) break;
    }
  }

  void _dismissOnboarding() {
    final step = ref.read(onboardingNotifierProvider);
    if (step == OnboardingStep.none) return;

    ref.read(onboardingNotifierProvider.notifier).dismiss();
  }

  @override
  void dispose() {
    if (_didSubscribeRouteAware) {
      appRouteObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _viewTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for staleness and refresh if needed when app comes back to foreground
      ref.read(newsFeedNotifierProvider.notifier).refreshIfStale();
      _maybeShowPendingRefreshAck();
    }
  }

  @override
  void didPush() {
    _isRouteVisible = true;
    _maybeShowPendingRefreshAck();
  }

  @override
  void didPopNext() {
    _isRouteVisible = true;
    _maybeShowPendingRefreshAck();
  }

  @override
  void didPushNext() {
    _isRouteVisible = false;
  }

  @override
  void didPop() {
    _isRouteVisible = false;
  }

  Future<void> _maybeShowPendingRefreshAck() async {
    if (!mounted || !_isRouteVisible || _isShowingRefreshAck) return;

    final needsRefresh = ref.read(needsFeedRefreshProvider);
    if (!needsRefresh) return;

    _isShowingRefreshAck = true;
    try {
      debugPrint(
          '[FeedScreen] Route visible. Showing manual shimmer for 1s...');

      // Enter manual shimmer and clear pending flag immediately.
      setState(() => _isManualShimmering = true);
      ref.read(needsFeedRefreshProvider.notifier).state = false;

      // Reset local scroll index to the top for the fresh session.
      // Ensure we are back at the start of the feed
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
        setState(() => _currentIndex = 0);
      }

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() => _isManualShimmering = false);
      }
    } finally {
      _isShowingRefreshAck = false;
    }
  }

  List<NewsArticle> _getDisplayArticles(FeedState feed) {
    final adsAvailable = ref.read(adManagerProvider).adsAvailable;
    return adsAvailable
        ? feed.articles
        : feed.articles.where((a) => a.itemType != 'ad').toList();
  }

  int _lastTriggeredPage = -1;

  void _maybeLoadMore({int? pageHint}) {
    final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
    if (feed == null || feed.isLoadingMore || !feed.hasMore) return;

    final displayArticles = _getDisplayArticles(feed);
    final totalPages = displayArticles.length;
    if (totalPages <= 0) return;

    final currentPage = pageHint ??
        (_pageController.hasClients ? (_pageController.page?.round() ?? 0) : 0);
    final nearEnd = currentPage >= totalPages - 5;
    if (!nearEnd) return;

    // Deduplicate by page index, but allow fresh triggers when category/feed resets
    // by resetting _lastTriggeredPage in the relevant state transitions.
    if (currentPage == _lastTriggeredPage) return;

    _lastTriggeredPage = currentPage;
    debugPrint(
        '[FeedScreen] Triggering loadNextPage (currentPage: $currentPage, totalPages: $totalPages, hasMore: ${feed.hasMore}, isLoadingMore: ${feed.isLoadingMore})');
    ref.read(newsFeedNotifierProvider.notifier).loadNextPage();
  }

  /// Triggers next-page load when we are within 5 pages of the end.
  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    _maybeLoadMore();
  }

  void _onPageChanged(int index) {
    if (!_hasScrolledOnce && index > 0) {
      _hasScrolledOnce = true;
      // If scroll onboarding was visible, hide it
      final notifier = ref.read(onboardingNotifierProvider.notifier);
      final step = ref.read(onboardingNotifierProvider);

      if (step == OnboardingStep.scroll) {
        notifier.dismiss();
      }

      // Wait 1 second before showing category hint if they haven't seen it yet
      if (!notifier.hasSeenExploreTopics) {
        // Mark as seen immediately so it doesn't re-trigger
        notifier.markExploreTopicsSeen();

        Timer(const Duration(seconds: 1), () {
          if (mounted) {
            notifier.setStep(OnboardingStep.categories);
          }
        });
      }
    }

    setState(() {
      _currentIndex = index;
    });

    final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
    if (feed == null) return;

    final displayArticles = _getDisplayArticles(feed);
    final targetArticleId =
        index < displayArticles.length ? displayArticles[index].id : null;
    ref
        .read(newsFeedNotifierProvider.notifier)
        .updateCurrentIndex(index, articleId: targetArticleId);

    // 1. Preload images for next 2 articles to ensure smooth scrolling
    // Defer pre-caching slightly to allow the swipe animation to finish smoothly
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;

      final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
      if (feed == null) return;

      final displayArticles = _getDisplayArticles(feed);
      for (var ahead = 1; ahead <= 2; ahead++) {
        final nextIndex = index + ahead;
        if (nextIndex < displayArticles.length) {
          final article = displayArticles[nextIndex];

          // Image preloading
          final imageUrl = article.imageUrl;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            precacheImage(
              CachedNetworkImageProvider(imageUrl),
              context,
              onError: (error, stackTrace) {
                debugPrint(
                    '[FeedScreen] Precache failed for $imageUrl: $error');
              },
            );
          }
        }
      }
    });

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
    if (feed != null) {
      final displayArticles = _getDisplayArticles(feed);
      if (index < displayArticles.length) {
        final article = displayArticles[index];
        // Only track real articles if we haven't tracked them this session
        if (article.itemType == 'article' &&
            !_viewedIdsInSession.contains(article.id)) {
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
  }

  Future<bool?> _showExitConfirmation() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF161B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: Color(0xFF6C63FF),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Exit Currenta?',
              style: TextStyle(
                fontFamily: 'Outfit',
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Are you sure you want to close the app?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Stay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Exit Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(newsFeedNotifierProvider, (previous, next) {
      final prevFeed = previous?.valueOrNull;
      final nextFeed = next.valueOrNull;
      if (nextFeed == null) return;

      // Reset pagination trigger when the underlying feed content is rebuilt
      // (e.g. after personalization changes/invalidation) even if category is unchanged.
      final prevHeadId = prevFeed?.articles.firstOrNull?.id;
      final nextHeadId = nextFeed.articles.firstOrNull?.id;
      final didFeedReset = prevFeed == null ||
          nextFeed.currentIndex == 0 ||
          nextFeed.articles.length < (prevFeed.articles.length) ||
          prevHeadId != nextHeadId;
      if (didFeedReset) {
        _lastTriggeredPage = -1;
      }

      // 1. Keep local chip state aligned with notifier state across relaunch/restoration.
      final nextCategory = next.valueOrNull?.selectedCategory;
      if (nextCategory != _selectedCategory && mounted) {
        setState(() {
          _selectedCategory = nextCategory;
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
            _pageController.jumpToPage(nextIndex);
            if (_currentIndex != nextIndex) {
              setState(() => _currentIndex = nextIndex);
            }
          }
        });
      }

      // 2. Handle AI Chat sheet
      if (nextFeed.showChatForArticleId != null) {
        final articleId = nextFeed.showChatForArticleId!;
        final article =
            nextFeed.articles.where((a) => a.id == articleId).firstOrNull;

        // Clear immediately so it doesn't re-open on next rebuild
        ref.read(newsFeedNotifierProvider.notifier).clearPendingChat();

        if (article != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AiQuickChatSheet(article: article),
          );
        }
      }

      // 3. Trigger onboarding when feed is first loaded
      final onboardingStep = ref.read(onboardingNotifierProvider);
      if (nextFeed.articles.isNotEmpty &&
          onboardingStep == OnboardingStep.none &&
          !_hasScrolledOnce) {
        final hasSeen =
            ref.read(onboardingNotifierProvider.notifier).hasSeenFeedOnboarding;
        if (!hasSeen) {
          _checkOnboarding();
        }
      }
    });

    ref.listen<bool>(needsFeedRefreshProvider, (previous, next) {
      if (!next) return;
      _maybeShowPendingRefreshAck();
    });

    // ── Listen for Location Update Popup ──
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.showLocationUpdatePopup &&
          !(previous?.showLocationUpdatePopup ?? false)) {
        final detected = next.detectedCountry;
        final current = next.preferredCountry;

        if (detected != null && current != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => LocationUpdatePopup(
              detectedCountry: detected,
              currentCountry: current,
            ),
          );
        }
      }
    });

    debugPrint(
        '[FeedScreen] Building with _selectedCategory: ${_selectedCategory?.name}');
    final feedAsync = ref.watch(newsFeedNotifierProvider);
    final feed = feedAsync.valueOrNull;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _showExitConfirmation();
        if (shouldPop ?? false) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0A0C14),
        drawer: const _ThemedSidebar(),
        body: Stack(
          children: [
            // ── Main content ─────────────────────────────────────────
            _isManualShimmering
                ? const ShimmerFeed()
                : feedAsync.when(
                    // Skip loading on reload so we can see stale data while fetching fresh content
                    skipLoadingOnReload: true,
                    loading: () => const ShimmerFeed(),
                    error: (e, _) => ErrorStateScreen(
                      error: e,
                      onRetry: () =>
                          ref.read(newsFeedNotifierProvider.notifier).refresh(),
                    ),
                    data: (feed) {
                      // Category Mismatch Guard: Only shimmer if the category is GENUINELY different.
                      // If we are in transition (isLoading), we trust the notifier's intended category.
                      if (feed.selectedCategory != _selectedCategory &&
                          !feedAsync.isLoading) {
                        return const ShimmerFeed();
                      }

                      // If we are loading and have no articles (e.g. switching categories), show shimmer
                      if (feed.articles.isEmpty && feedAsync.isLoading) {
                        return const ShimmerFeed();
                      }

                      // Restoration Guard: If the controller hasn't jumped to the restored index yet,
                      // keep shimmering to avoid showing the wrong article (index 0) briefly.
                      if (feed.currentIndex != _currentIndex &&
                          feed.currentIndex != 0) {
                        return const ShimmerFeed();
                      }

                      return _buildFeedContent(feed);
                    },
                  ),

            // ── Category filter bar ──────────────────────────────────
            _ThemedCategoryBar(
              onboardingCategoryKey: _onboardingCategoryKey,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onCategoryChanged: (cat) {
                debugPrint('[FeedScreen] onCategoryChanged: ${cat?.name}');
                if (_selectedCategory == cat) {
                  debugPrint(
                      '[FeedScreen] Category already selected: ${cat?.name}');
                  return;
                }

                // Trigger feed loading immediately. The Notifier will update its state
                // synchronously to reflect the new category, which will update our UI.
                ref
                    .read(newsFeedNotifierProvider.notifier)
                    .filterByCategory(cat);
              },
            ),

            // ── Refresh Badge (Twitter Style) ──────────────────────────
            _RefreshBadge(
              isVisible: !_isManualShimmering &&
                  (feed?.articles.isNotEmpty ?? false) &&
                  ((feed?.isStale ?? false) || (feed?.isRefreshing ?? false)),
              isRefreshing: feed?.isRefreshing ?? false,
              onTap: () =>
                  ref.read(newsFeedNotifierProvider.notifier).refresh(),
            ),

            if (ref.watch(onboardingNotifierProvider) != OnboardingStep.none)
              FeedOnboardingOverlay(
                step: ref.watch(onboardingNotifierProvider),
                onDismiss: _dismissOnboarding,
                targetKey: _onboardingCategoryKey,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedContent(FeedState feed) {
    if (feed.articles.isEmpty) {
      return EmptyStateScreen(
        onRetry: () => ref.read(newsFeedNotifierProvider.notifier).refresh(),
      );
    }

    // ── Performance: Browser Pre-warming ──
    if (!_hasWarmedUpBrowser) {
      _hasWarmedUpBrowser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final browser = ref.read(browserServiceProvider);
        browser.warmup();
      });
    }

    // Reactively trigger rebuild when ads become available for the first time
    ref.watch(adManagerProvider.select((s) => s.adsAvailable));
    final displayArticles = _getDisplayArticles(feed);

    final itemCount = displayArticles.length + (feed.isLoadingMore ? 1 : 0);

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      allowImplicitScrolling:
          true, // Pre-warms adjacent pages (native ad views) silently before touch drag
      itemCount: itemCount,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, i) {
        if (i >= displayArticles.length) {
          return const _LoadingMorePage();
        }

        final article = displayArticles[i];

        if (article.itemType == 'exhaustion_marker') {
          return const ExhaustionMarkerCard();
        }

        if (article.itemType == 'ad') {
          return const RepaintBoundary(child: NativeAdCard());
        }

        return RepaintBoundary(
          child: NewsCard(
            article: article,
            index: i,
            total: displayArticles.length,
          ),
        );
      },
    );
  }
}

class _ThemedSidebar extends ConsumerWidget {
  const _ThemedSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(newsFeedNotifierProvider
        .select((s) => s.valueOrNull?.currentIndex ?? 0));
    final articles = ref.watch(
        newsFeedNotifierProvider.select((s) => s.valueOrNull?.articles ?? []));

    final currentArticle = (currentIndex >= 0 && currentIndex < articles.length)
        ? articles[currentIndex]
        : null;
    final primaryCategory = currentArticle?.categories.isNotEmpty == true
        ? currentArticle!.categories.first
        : null;
    final catColor = AppTheme.categoryColor(primaryCategory?.name ?? 'world');

    return Sidebar(catColor: catColor);
  }
}

class _ThemedCategoryBar extends ConsumerWidget {
  final GlobalKey onboardingCategoryKey;
  final ValueChanged<NewsCategory?> onCategoryChanged;
  final VoidCallback onOpenDrawer;

  const _ThemedCategoryBar({
    required this.onboardingCategoryKey,
    required this.onCategoryChanged,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(newsFeedNotifierProvider
        .select((s) => s.valueOrNull?.selectedCategory));

    return _CategoryBar(
      selectedCategory: selectedCategory,
      onboardingCategoryKey: onboardingCategoryKey,
      onCategoryChanged: onCategoryChanged,
      onOpenDrawer: onOpenDrawer,
    );
  }
}

// ── New Stories Badge ─────────────────────────────────────────────────────────

// ── Refresh Badge (Twitter Style) ────────────────────────────────────────────

class _RefreshBadge extends StatefulWidget {
  const _RefreshBadge({
    required this.isVisible,
    required this.isRefreshing,
    required this.onTap,
  });

  final bool isVisible;
  final bool isRefreshing;
  final VoidCallback onTap;

  @override
  State<_RefreshBadge> createState() => _RefreshBadgeState();
}

class _RefreshBadgeState extends State<_RefreshBadge> {
  bool _wasRefreshing = false;

  @override
  void didUpdateWidget(_RefreshBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing && !widget.isRefreshing) {
      _wasRefreshing = true;
      // Keep the 'refreshing' state look for the duration of the exit animation
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _wasRefreshing = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top + 64;
    // Keep the refreshing look if we are currently refreshing OR if we are in the middle of hiding after a refresh
    final effectivelyRefreshing =
        widget.isRefreshing || (!widget.isVisible && _wasRefreshing);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      top: widget.isVisible ? topPadding : topPadding - 80,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: widget.isVisible ? 1.0 : 0.0,
        child: Center(
          child: GestureDetector(
            onTap:
                widget.isVisible && !widget.isRefreshing ? widget.onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                horizontal: effectivelyRefreshing ? 12 : 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: effectivelyRefreshing
                      ? [const Color(0xFF161B2E), const Color(0xFF1E2643)]
                      : [const Color(0xFF6C63FF), const Color(0xFF8A84FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(100),
                border: effectivelyRefreshing
                    ? Border.all(color: Colors.white.withValues(alpha: 0.1))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: (effectivelyRefreshing
                            ? Colors.black
                            : const Color(0xFF6C63FF))
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: effectivelyRefreshing
                    ? const SizedBox(
                        key: ValueKey('spinner'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                        ),
                      )
                    : const Row(
                        key: ValueKey('refresh'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Refresh',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
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
    required this.onboardingCategoryKey,
    required this.onCategoryChanged,
    required this.onOpenDrawer,
  });

  final NewsCategory? selectedCategory;
  final GlobalKey onboardingCategoryKey;
  final ValueChanged<NewsCategory?> onCategoryChanged;
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
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onOpenDrawer,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  height: 40,
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Scrollable Chips area
            Expanded(
              child: SizedBox(
                height: 40,
                child: ListView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: () {
                    final sortedCats = _getSortedCategories(ref)
                        .where((cat) => cat.isSupported(
                            ref.watch(authNotifierProvider).preferredCountry ??
                                View.of(context)
                                    .platformDispatcher
                                    .locale
                                    .countryCode))
                        .toList();

                    return [
                      _FilterChip(
                        key: _itemKeys[null],
                        label: '✨ For You',
                        isSelected: widget.selectedCategory == null,
                        onTap: () => widget.onCategoryChanged(null),
                      ),
                      const SizedBox(width: 8),
                      ...sortedCats.asMap().entries.map((entry) {
                        final i = entry.key;
                        final cat = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            key: i == 0
                                ? widget.onboardingCategoryKey
                                : _itemKeys[cat],
                            label: '${cat.emoji}  ${cat.displayName}',
                            isSelected: widget.selectedCategory == cat,
                            onTap: () => widget.onCategoryChanged(cat),
                          ),
                        );
                      }),
                    ];
                  }(),
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

    final sorted = List<NewsCategory>.from(NewsCategory.values)
      // If Local is not selected in personalization, hide its tab in feed.
      ..removeWhere((cat) =>
          cat == NewsCategory.local && !selectedInterests.contains(cat.name));

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
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          debugPrint('[FilterChip] Tapped: $label');
          onTap();
        },
        borderRadius: BorderRadius.circular(100),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeInCirc,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ── Exhaustion Marker Card ───────────────────────────────────────────────────

class ExhaustionMarkerCard extends StatelessWidget {
  const ExhaustionMarkerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0A0C14),
      child: Stack(
        children: [
          // Background Gradient Glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Icon Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF6C63FF),
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Text Content
                  const Text(
                    "You're All Caught Up!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You've seen all the latest stories from your selected categories. Keep scrolling to discover what else is happening in the world.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Animated Scroll Indicator
                  const _ScrollNudge(),
                ],
              ),
            ),
          ),

          // Bottom Gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0C14).withValues(alpha: 0),
                      const Color(0xFF0A0C14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollNudge extends StatefulWidget {
  const _ScrollNudge();

  @override
  State<_ScrollNudge> createState() => _ScrollNudgeState();
}

class _ScrollNudgeState extends State<_ScrollNudge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 10)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 10, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Column(
            children: [
              Text(
                "Scroll to discover",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF6C63FF).withValues(alpha: 0.8),
                size: 28,
              ),
            ],
          ),
        );
      },
    );
  }
}
