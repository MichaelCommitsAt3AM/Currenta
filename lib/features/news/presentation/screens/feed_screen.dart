// lib/features/news/presentation/screens/feed_screen.dart
// Full-screen vertical PageView feed — one story per screen,
// swipe down (upward gesture) advances to the next story.

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

  // PageController — itemExtent not set so each page = full screen height
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Full-screen immersive: hide status bar tint and make it transparent
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            data: (articles) {
              if (articles.isEmpty) {
                return EmptyStateScreen(
                  onRetry: () =>
                      ref.read(newsFeedNotifierProvider.notifier).refresh(),
                );
              }

              return PageView.builder(
                controller: _pageController,
                // Vertical scroll; scrollDirection: Axis.vertical means
                // dragging UP shows the next item (natural TikTok-style).
                scrollDirection: Axis.vertical,
                // BouncingScrollPhysics gives a snappy page snap
                physics: const BouncingScrollPhysics(),
                itemCount: articles.length,
                // RepaintBoundary per page prevents neighbour cards from
                // repainting during the swipe animation — key perf fix.
                itemBuilder: (context, i) {
                  // ── Preload the next 3 article images ────────────
                  // Fire-and-forget: warms the image cache so images are
                  // ready before the user swipes down to those cards.
                  for (var ahead = 1; ahead <= 3; ahead++) {
                    final nextIndex = i + ahead;
                    if (nextIndex < articles.length) {
                      final url = articles[nextIndex].imageUrl;
                      if (url != null && url.isNotEmpty) {
                        precacheImage(NetworkImage(url), context);
                      }
                    }
                  }

                  return RepaintBoundary(
                    child: NewsCard(
                      article: articles[i],
                      index: i,
                      total: articles.length,
                    ),
                  );
                },
              );
            },
          ),

          // ── Category filter bar (full top area, no logo) ──────
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

// ── Category filter bar ───────────────────────────────────────────

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
      // Subtle dark-to-transparent so cards bleed under it cleanly
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
          // Refresh at the very end of chip row
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
