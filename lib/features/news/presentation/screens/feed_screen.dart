// lib/features/news/presentation/screens/feed_screen.dart
// Main news feed — PageView with swipe-up navigation,
// category filter bar, and AsyncNotifierProvider state handling.

import 'package:flutter/material.dart';
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
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(newsFeedNotifierProvider);

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, _) => [
          _AppBar(
            onRefresh: () =>
                ref.read(newsFeedNotifierProvider.notifier).refresh(),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryFilterDelegate(
              selectedCategory: _selectedCategory,
              onCategoryChanged: (cat) {
                setState(() => _selectedCategory = cat);
                ref
                    .read(newsFeedNotifierProvider.notifier)
                    .filterByCategory(cat);
              },
            ),
          ),
        ],
        body: RefreshIndicator(
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF1A1E2E),
          onRefresh: () =>
              ref.read(newsFeedNotifierProvider.notifier).refresh(),
          child: feedAsync.when(
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

              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: SliverList.separated(
                      itemCount: articles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 16),
                      itemBuilder: (_, i) =>
                          NewsCard(article: articles[i]),
                    ),
                  ),
                  // Bottom safe area
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: 24),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      snap: true,
      pinned: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Row(
          children: [
            // Currenta logo mark
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
                ),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Currenta',
              style: TextStyle(
                color: Color(0xFFF0F2FF),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: onRefresh,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ── Category Filter Bar ───────────────────────────────────────────

class _CategoryFilterDelegate extends SliverPersistentHeaderDelegate {
  const _CategoryFilterDelegate({
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final NewsCategory? selectedCategory;
  final ValueChanged<NewsCategory?> onCategoryChanged;

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFF0A0C14),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // "All" chip
          _FilterChip(
            label: '🌐 All',
            isSelected: selectedCategory == null,
            onTap: () => onCategoryChanged(null),
          ),
          const SizedBox(width: 8),
          ...NewsCategory.values.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: '${cat.emoji} ${cat.displayName}',
                  isSelected: selectedCategory == cat,
                  onTap: () => onCategoryChanged(cat),
                ),
              )),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CategoryFilterDelegate old) =>
      old.selectedCategory != selectedCategory;
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : const Color(0xFF1A1E2E),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6C63FF)
                  : const Color(0xFF262A3E),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8890B5),
              fontSize: 12,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
