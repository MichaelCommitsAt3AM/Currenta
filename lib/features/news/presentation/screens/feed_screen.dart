// lib/features/news/presentation/screens/feed_screen.dart
// Full-screen vertical PageView feed — one story per screen,
// swipe down (upward gesture) advances to the next story.
// Loads the next batch of 10 articles when the user is within 5 pages of the end.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../application/news_feed_notifier.dart';
import '../../domain/entities/news_category.dart';
import '../../../../core/providers/providers.dart';
import '../widgets/news_card.dart';
import '../widgets/shimmer_feed.dart';
import '../widgets/sidebar.dart';
import 'empty_state_screen.dart';
import 'error_state_screen.dart';
import '../../../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
    super.dispose();
  }

  int _lastTriggeredPage = -1;

  /// Triggers next-page load when we are within 5 pages of the end.
  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final feedAsync = ref.read(newsFeedNotifierProvider);
    final feed = feedAsync.valueOrNull;
    if (feed == null || feed.isLoadingMore || !feed.hasMore) return;

    final currentPage = _pageController.page?.round() ?? 0;
    final totalPages = feed.articles.length;

    // Deduplicate: only trigger once for each unique page threshold
    if (currentPage != _lastTriggeredPage &&
        totalPages > 0 &&
        currentPage >= totalPages - 5) {
      _lastTriggeredPage = currentPage;
      ref.read(newsFeedNotifierProvider.notifier).loadNextPage();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
    if (feed == null) return;

    // 1. Preload images for next 5 articles to ensure smooth scrolling
    for (var ahead = 1; ahead <= 5; ahead++) {
      final nextIndex = index + ahead;
      if (nextIndex < feed.articles.length) {
        final article = feed.articles[nextIndex];
        final url = article.imageUrl;
        if (url != null && url.isNotEmpty) {
          // Use CachedNetworkImageProvider to share the same cache as the widgets
          precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
    }

    // 2. Track view
    _trackPageView(index);
  }

  void _trackPageView(int index) {
    final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
    if (feed != null && index < feed.articles.length) {
      final article = feed.articles[index];
      // Only track if we haven't tracked it this session
      if (!_viewedIdsInSession.contains(article.id)) {
        _viewedIdsInSession.add(article.id);
        ref.read(newsRepositoryProvider).markAsViewed(article.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(newsFeedNotifierProvider);
    final feed = feedAsync.valueOrNull;
    
    // Determine the color of the current article for the sidebar
    final articles = feed?.articles ?? [];
    final currentArticle = (_currentIndex >= 0 && _currentIndex < articles.length) 
        ? articles[_currentIndex] 
        : null;
    final primaryCategory = currentArticle?.categories.isNotEmpty == true 
        ? currentArticle!.categories.first 
        : null;
    final catColor = AppTheme.categoryColor(primaryCategory?.name ?? 'world');

    return Scaffold(
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
              if (feed.articles.isEmpty && !feed.isLoadingMore) {
                return EmptyStateScreen(
                  onRetry: () =>
                      ref.read(newsFeedNotifierProvider.notifier).refresh(),
                );
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
          Builder(
            builder: (context) => _CategoryBar(
              selectedCategory: _selectedCategory,
              onCategoryChanged: (cat) {
                setState(() => _selectedCategory = cat);
                ref
                    .read(newsFeedNotifierProvider.notifier)
                    .filterByCategory(cat);
                _pageController.jumpToPage(0);
              },
              onRefresh: () =>
                  ref.read(newsFeedNotifierProvider.notifier).refresh(),
              onOpenDrawer: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
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

class _CategoryBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    
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
              onTap: onOpenDrawer,
              child: Container(
                height: 38,
                width: 40,
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
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FilterChip(
                      label: '🌐 All',
                      isSelected: selectedCategory == null,
                      onTap: () => onCategoryChanged(null),
                    ),
                    const SizedBox(width: 8),
                    ...NewsCategory.values.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: '${cat.emoji}  ${cat.displayName}',
                            isSelected: selectedCategory == cat,
                            onTap: () => onCategoryChanged(cat),
                          ),
                        )),
                    // Refresh button at the very end of chip row
                    GestureDetector(
                      onTap: onRefresh,
                      child: Container(
                        height: 38,
                        width: 40,
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
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
