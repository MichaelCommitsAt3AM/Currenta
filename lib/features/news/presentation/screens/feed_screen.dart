// lib/features/news/presentation/screens/feed_screen.dart
// Full-screen vertical PageView feed — one story per screen,
// swipe down (upward gesture) advances to the next story.
// Loads the next batch of 10 articles when the user is within 3 pages of the end.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/news_feed_notifier.dart';
import '../../domain/entities/news_category.dart';
import '../widgets/news_card.dart';
import '../widgets/shimmer_feed.dart';
import 'empty_state_screen.dart';
import 'error_state_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  NewsCategory? _selectedCategory;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  int _lastTriggeredPage = -1;

  /// Triggers next-page load when we are within 3 pages of the end.
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
        currentPage >= totalPages - 3) {
      _lastTriggeredPage = currentPage;
      ref.read(newsFeedNotifierProvider.notifier).loadNextPage();
    }
  }

  /// Preload images when a user lands on a new page.
  void _onPageChanged(int index) {
    final feed = ref.read(newsFeedNotifierProvider).valueOrNull;
    if (feed == null) return;

    // Preload next 3 images only once
    for (var ahead = 1; ahead <= 3; ahead++) {
      final nextIndex = index + ahead;
      if (nextIndex < feed.articles.length) {
        final url = feed.articles[nextIndex].imageUrl;
        if (url != null && url.isNotEmpty) {
          precacheImage(NetworkImage(url), context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(newsFeedNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
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

                  return RepaintBoundary(
                    child: NewsCard(
                      article: feed.articles[i],
                      index: i,
                      total: feed.articles.length,
                    ),
                  );
                },
              );
            },
          ),

          // ── Category filter bar ──────────────────────────────────
          SafeArea(
            child: _CategoryBar(
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
  });

  final NewsCategory? selectedCategory;
  final ValueChanged<NewsCategory?> onCategoryChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0C14).withValues(alpha: 0.92),
            Colors.transparent,
          ],
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              height: 38,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
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
