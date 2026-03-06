// lib/features/news/presentation/widgets/news_card.dart
// Full-screen immersive news card for vertical PageView.
// Uses a gradient-over-image hero layout with the summary overlaid at bottom.
// Performance: NO per-card AnimationController — the PageView handles transitions.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/news_article.dart';
import '../../../../theme/theme.dart';
import '../../application/news_feed_notifier.dart';
import 'heart_shower.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class NewsCard extends ConsumerStatefulWidget {
  const NewsCard({
    super.key,
    required this.article,
    required this.index,
    required this.total,
  });

  final NewsArticle article;
  final int index;
  final int total;

  @override
  ConsumerState<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends ConsumerState<NewsCard> {
  bool showShower = false;

  // Local optimistic state for instant feedback
  bool? _localIsLiked;
  int? _localLikesCount;

  bool get _isLiked => _localIsLiked ?? widget.article.isLiked;
  int get _likesCount => _localLikesCount ?? widget.article.likesCount;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(NewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the underlying article data has caught up with our local state,
    // clear the local state to stay in sync with the source of truth.
    if (_localIsLiked != null &&
        widget.article.isLiked == _localIsLiked &&
        widget.article.likesCount == _localLikesCount) {
      _localIsLiked = null;
      _localLikesCount = null;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();

    final isAuth = ref.read(authNotifierProvider).isAuthenticated;
    if (!isAuth) {
      _showAuthSheet();
      return;
    }

    setState(() {
      showShower = true;
      if (!_isLiked) {
        _localLikesCount = _likesCount + 1;
        _localIsLiked = true;
      }
    });

    if (!widget.article.isLiked) {
      ref.read(newsFeedNotifierProvider.notifier).toggleLike(widget.article.id);
    }
  }

  void _handleIconPress() {
    HapticFeedback.mediumImpact();

    final isAuth = ref.read(authNotifierProvider).isAuthenticated;
    if (!isAuth) {
      _showAuthSheet();
      return;
    }

    setState(() {
      final newIsLiked = !_isLiked;
      _localIsLiked = newIsLiked;
      _localLikesCount = newIsLiked ? _likesCount + 1 : _likesCount - 1;

      if (newIsLiked) {
        showShower = true;
      }
    });
    ref.read(newsFeedNotifierProvider.notifier).toggleLike(widget.article.id);
  }

  void _showAuthSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF262A3E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 40,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign In Required',
                style: TextStyle(
                  color: Color(0xFFF0F2FF),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You need to be signed in to like or favorite stories. Join us to personalize your feed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8890B5),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Sign In to Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryCategory = widget.article.categories.isNotEmpty
        ? widget.article.categories.first
        : null;
    final catColor = AppTheme.categoryColor(primaryCategory?.name ?? 'world');
    final size = MediaQuery.sizeOf(context);

    return Container(
      width: size.width,
      height: size.height,
      color: const Color(0xFF0A0C14),
      child: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background Gradient ─────────────────────
            _BackgroundGradient(catColor: catColor),

            // ── Decorative accent circle ───────────────────────────
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      catColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Content area ───────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.paddingOf(context).top + 56,
                24,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Row (Page Indicator + Category) ─────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PageIndicator(
                        index: widget.index,
                        total: widget.total,
                        color: catColor,
                      ),
                      _CategoryChip(
                        label: primaryCategory != null
                            ? '${primaryCategory.emoji} ${primaryCategory.displayName}'
                            : '🌍 World',
                        color: catColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Feature Image ──────────────────────────────────
                  if (widget.article.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          height: size.height * 0.25,
                          color: Colors.white.withValues(alpha: 0.05),
                          child: Image.network(
                            widget.article.imageUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: (size.width * MediaQuery.devicePixelRatioOf(context)).toInt(),
                            errorBuilder: (context, _, __) => Center(
                              child: Icon(Icons.image_not_supported_rounded,
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Title ──────────────────────────────────────────
                  Text(
                    widget.article.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),
 
                   // ── AI Summary ─────────────────────────────────────
                   Expanded(
                     child: SingleChildScrollView(
                       physics: const BouncingScrollPhysics(),
                       child: Text(
                         widget.article.summary,
                         style: TextStyle(
                           color: Colors.white.withValues(alpha: 0.75),
                           fontSize: 15,
                           height: 1.5,
                           fontWeight: FontWeight.w400,
                         ),
                       ),
                     ),
                   ),
 
                   const SizedBox(height: 18),

                  // ── Source Row (tap to open article in default browser) ──
                  GestureDetector(
                    onTap: () =>
                        _openOriginal(context, widget.article.originalUrl),
                    child: Row(
                      children: [
                        if (widget.article.sourceFaviconUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                widget.article.sourceFaviconUrl!,
                                width: 20,
                                height: 20,
                                errorBuilder: (context, _, __) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                widget.article.sourceName[0],
                                style: TextStyle(
                                    color: catColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            widget.article.sourceName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.open_in_new_rounded,
                            size: 14, color: catColor.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Footer Actions ───────────────────────────────
                  Row(
                    children: [
                      IconButton(
                        onPressed: _handleIconPress,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _isLiked
                              ? Colors.redAccent
                              : Colors.white.withValues(alpha: 0.6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_likesCount.toString(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6))),
                      const SizedBox(width: 24),
                      Icon(Icons.bookmark_border_rounded,
                          color: Colors.white.withValues(alpha: 0.6), size: 22),
                      const SizedBox(width: 24),
                      Icon(Icons.share_outlined,
                          color: Colors.white.withValues(alpha: 0.6), size: 22),
                      const Spacer(),
                      if (widget.index < widget.total - 1)
                        Icon(Icons.keyboard_double_arrow_up_rounded,
                            color: catColor.withValues(alpha: 0.4), size: 20),
                    ],
                  ),
                ],
              ),
            ),

            // ── Heart Shower Particles ─────────────────────
            HeartShower(
              isAnimating: showShower,
              color: _isLiked ? Colors.redAccent : Colors.white70,
              onEnd: () => setState(() => showShower = false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOriginal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      // LaunchMode.externalApplication opens in the user's default browser
      // (Chrome, Brave, Firefox, etc.) — not constrained to Custom Tabs.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Swallowed if the device has no browser capable of handling the URL.
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient({required this.catColor});
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0C14),
            Color.lerp(const Color(0xFF0A0C14), catColor, 0.12)!,
            const Color(0xFF0A0C14),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.index,
    required this.total,
    required this.color,
  });

  final int index;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Dot row
        ...List.generate(
          total.clamp(0, 7), // max 7 dots
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 4),
            width: i == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? color : Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (total > 7) ...[
          const SizedBox(width: 4),
          Text(
            '${index + 1}/$total',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
