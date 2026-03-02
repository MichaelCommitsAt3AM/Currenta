// lib/features/news/presentation/widgets/news_card.dart
// Full-screen immersive news card for vertical PageView.
// Uses a gradient-over-image hero layout with the summary overlaid at bottom.
// Performance: NO per-card AnimationController — the PageView handles transitions.

import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import '../../domain/entities/news_article.dart';
import '../../../../core/theme/app_theme.dart';

class NewsCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final catColor = AppTheme.categoryColor(article.category.name);
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onTap: () => _openOriginal(context, article.originalUrl),
      child: Container(
        width: size.width,
        height: size.height,
        color: const Color(0xFF0A0C14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background gradient (category-tinted) ──────────────
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
                      catColor.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Content area ───────────────────────────────────────
            Padding(
              // Top padding: clear the floating header (logo ~80px + safe area)
              // Bottom padding: clear the category bar (~56px)
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
                        index: index,
                        total: total,
                        color: catColor,
                      ),
                      _CategoryChip(
                        label:
                            '${article.category.emoji} ${article.category.displayName}',
                        color: catColor,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Title ──────────────────────────────────────────
                  Text(
                    article.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24, // Slightly smaller to ensure fit
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(blurRadius: 12, color: Colors.black54),
                      ],
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 18),

                  // ── Divider ────────────────────────────────────────
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          catColor.withValues(alpha: 0.8),
                          catColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── AI Summary ─────────────────────────────────────
                  Text(
                    article.summary,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      height:
                          1.45, // Tighter leading to ensure 64 words fit comfortably
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 15, // Allow the full 64 words to show
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 24),

                  // ── Read more + swipe hint ─────────────────────────
                  Row(
                    children: [
                      // Read more pill
                      GestureDetector(
                        onTap: () =>
                            _openOriginal(context, article.originalUrl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                catColor,
                                catColor.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: catColor.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Read full story',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Swipe hint
                      if (index < total - 1)
                        Column(
                          children: [
                            Icon(Icons.keyboard_arrow_up_rounded,
                                color: Colors.white.withValues(alpha: 0.35),
                                size: 20),
                            Text(
                              'Next',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
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

  Future<void> _openOriginal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    try {
      await launchUrl(
        uri,
        customTabsOptions: CustomTabsOptions.partial(
          configuration: PartialCustomTabsConfiguration.bottomSheet(
            // Set height to full screen to make it slide up and fill the screen
            initialHeight: size.height,
            activityHeightResizeBehavior:
                CustomTabsActivityHeightResizeBehavior.defaultBehavior,
            cornerRadius: 16,
          ),
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: theme.colorScheme.surface,
          ),
          showTitle: true,
          closeButton: CustomTabsCloseButton(
            icon: CustomTabsCloseButtonIcons.back,
          ),
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: theme.colorScheme.surface,
          preferredControlTintColor: theme.colorScheme.onSurface,
          barCollapsingEnabled: true,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (_) {
      // Intentionally swallowed if the device lacks any browser
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
