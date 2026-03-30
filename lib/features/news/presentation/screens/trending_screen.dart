// lib/features/news/presentation/screens/trending_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../application/trending_notifier.dart';
import '../../domain/entities/news_article.dart';
import '../widgets/news_card.dart';
import 'empty_state_screen.dart';

class TrendingScreen extends ConsumerStatefulWidget {
  final NewsArticle? initialArticle;
  const TrendingScreen({super.key, this.initialArticle});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Mark the very first article as viewed and preload first few images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheImages(0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _precacheImages(int index) {
    final trendingAsync = ref.read(trendingNotifierProvider);
    final articles = trendingAsync.valueOrNull;
    if (articles == null) return;

    final displayArticles = [
      if (widget.initialArticle != null) widget.initialArticle!,
      ...articles.where((a) => a.id != widget.initialArticle?.id),
    ];

    // Preload next 5 articles
    for (var ahead = 1; ahead <= 5; ahead++) {
      final nextIndex = index + ahead;
      if (nextIndex < displayArticles.length) {
        final article = displayArticles[nextIndex];
        final imageUrl = article.imageUrl;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(imageUrl), context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(trendingNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        title: const Text(
          'Trending Today',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: trendingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'Error loading trending: $e',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        data: (articles) {
          final displayArticles = [
            if (widget.initialArticle != null) widget.initialArticle!,
            ...articles.where((a) => a.id != widget.initialArticle?.id),
          ];

          if (displayArticles.isEmpty) {
            return EmptyStateScreen(
              title: 'Nothing Trending',
              message: "Check back later for trending stories.",
              buttonLabel: "Go back",
              icon: Icons.trending_up_rounded,
              onRetry: () => Navigator.pop(context),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: displayArticles.length,
            onPageChanged: _precacheImages,
            itemBuilder: (context, i) {
              final article = displayArticles[i];
              return RepaintBoundary(
                child: NewsCard(
                  article: article,
                  index: i,
                  total: displayArticles.length,
                  topPadding: 10.0,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
