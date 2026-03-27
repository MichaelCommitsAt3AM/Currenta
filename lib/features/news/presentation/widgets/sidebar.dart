// lib/features/news/presentation/widgets/sidebar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_notifier.dart';
import '../screens/settings_screen.dart';
import '../screens/trending_screen.dart';
import '../../application/trending_notifier.dart';
import '../../domain/entities/news_article.dart';
import '../../../../theme/theme.dart';

class Sidebar extends ConsumerWidget {
  final Color catColor;

  const Sidebar({
    super.key,
    required this.catColor,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Afternoon';
    } else if (hour >= 17 && hour < 24) {
      return 'Evening';
    } else {
      return 'Hi';
    }
  }

  String _getFirstName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return 'there';
    return displayName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final size = MediaQuery.sizeOf(context);

    // Calculate themed background color derived from article's category
    final sidebarBg = Color.lerp(const Color(0xFF0A0C14), catColor, 0.15)!;
    final accentColor = catColor;

    return Drawer(
      backgroundColor: Colors.transparent,
      width: size.width * 0.8,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              sidebarBg,
              const Color(0xFF0A0C14),
            ],
          ),
          border: Border(
            right: BorderSide(
              color: accentColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Branding Section ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icons/app_logo_new.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Currenta',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Header Section ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: authState.avatarUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.network(
                                  authState.avatarUrl!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.person_outline_rounded,
                                    size: 32,
                                    color: accentColor,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person_outline_rounded,
                                size: 32,
                                color: accentColor,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      authState.isAuthenticated
                          ? '${_getGreeting()} ${_getFirstName(authState.displayName)}'
                          : 'Welcome back',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      authState.isAuthenticated
                          ? 'Signed in as member'
                          : 'Your Daily News Pulse',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(
                  color: Colors.white.withValues(alpha: 0.05),
                  indent: 24,
                  endIndent: 24),
              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Trending Now Section ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const TrendingScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.trending_up_rounded,
                                    color: Colors.orangeAccent, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'Trending Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final trendingAsync =
                              ref.watch(trendingNotifierProvider);

                          return trendingAsync.when(
                            data: (articles) {
                              if (articles.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Text(
                                    'Stay tuned for trending stories...',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: articles.length
                                    .clamp(0, 5), // Show top 5 in sidebar
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final article = articles[index];
                                  return _TrendingTile(
                                    article: article,
                                    onTap: () {
                                      Navigator.pop(context); // Close drawer
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TrendingScreen(
                                            initialArticle: article,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            error: (e, st) => const SizedBox.shrink(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Bottom Section ─────────────────────────────────────────
              Divider(
                  color: Colors.white.withValues(alpha: 0.05),
                  indent: 24,
                  endIndent: 24),
              _SidebarTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                color: Colors.white.withValues(alpha: 0.7),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()),
                  );
                },
              ),

              const SizedBox(height: 12),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'v1.2.0 • Premium',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingTile extends ConsumerWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const _TrendingTile({
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCountry = ref.watch(authNotifierProvider).preferredCountry;
    final isLocal =
        article.countryCode != null && article.countryCode == userCountry;

    final primaryCategory =
        article.categories.isNotEmpty ? article.categories.first : null;
    final catColor = AppTheme.categoryColor(primaryCategory?.name ?? 'world');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        article.sourceName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isLocal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color:
                                    Colors.blueAccent.withValues(alpha: 0.2)),
                          ),
                          child: const Text(
                            'LOCAL',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        Icons.trending_up,
                        size: 10,
                        color: Colors.orangeAccent.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}
