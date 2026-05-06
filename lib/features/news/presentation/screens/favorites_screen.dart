// lib/features/news/presentation/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/favorites_notifier.dart';
import '../widgets/news_card.dart';
import 'empty_state_screen.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../core/errors/app_exception.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final favoritesAsync = ref.watch(favoritesNotifierProvider);

    if (!authState.isAuthenticated) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0C14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Saved Stories', style: TextStyle(color: Colors.white)),
          centerTitle: true,
        ),
        body: EmptyStateScreen(
          title: 'Sign In Required',
          message: 'You need to be signed in to see your saved stories and sync them across devices.',
          buttonLabel: 'Sign In Now',
          icon: Icons.lock_outline_rounded,
          onRetry: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      );
    }

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
          'Saved Stories',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: favoritesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            e.toDisplayMessage(),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        data: (articles) {
          if (articles.isEmpty) {
            return EmptyStateScreen(
              title: 'No Saved Stories',
              message: "You haven't saved any stories yet.",
              buttonLabel: "Go back to Feed",
              icon: Icons.bookmark_outline_rounded,
              onRetry: () => Navigator.pop(context),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: articles.length,
            onPageChanged: (index) {
              // Track current index if needed
            },
            itemBuilder: (context, i) {
              final article = articles[i];
              return RepaintBoundary(
                child: NewsCard(
                  article: article,
                  index: i,
                  total: articles.length,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
