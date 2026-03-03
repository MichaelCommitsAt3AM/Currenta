// lib/features/news/presentation/widgets/news_card.dart
// Full-screen immersive news card for vertical PageView.
// Uses a gradient-over-image hero layout with the summary overlaid at bottom.
// Performance: NO per-card AnimationController — the PageView handles transitions.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final primaryCategory =
        article.categories.isNotEmpty ? article.categories.first : null;
    final catColor = AppTheme.categoryColor(primaryCategory?.name ?? 'world');
    final size = MediaQuery.sizeOf(context);

    return Container(
      width: size.width,
      height: size.height,
      color: const Color(0xFF0A0C14),
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
                      index: index,
                      total: total,
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

                const SizedBox(height: 24),

                // ── Feature Image ──────────────────────────────────
                if (article.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        height: size.height * 0.28,
                        color: Colors.white.withValues(alpha: 0.05),
                        child: Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
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
                  article.title,
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

                const SizedBox(height: 16),

                // ── AI Summary ─────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      article.summary,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Source Row (tap to open article in default browser) ──
                GestureDetector(
                  onTap: () => _openOriginal(context, article.originalUrl),
                  child: Row(
                    children: [
                      if (article.sourceFaviconUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              article.sourceFaviconUrl!,
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
                              article.sourceName[0],
                              style: TextStyle(
                                  color: catColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          article.sourceName,
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

                const SizedBox(height: 20),

                // ── Footer Actions ───────────────────────────────
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: Colors.white.withValues(alpha: 0.6), size: 22),
                    const SizedBox(width: 6),
                    Text('10',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6))),
                    const SizedBox(width: 24),
                    Icon(Icons.bookmark_border_rounded,
                        color: Colors.white.withValues(alpha: 0.6), size: 22),
                    const SizedBox(width: 24),
                    Icon(Icons.share_outlined,
                        color: Colors.white.withValues(alpha: 0.6), size: 22),
                    const Spacer(),
                    if (index < total - 1)
                      Icon(Icons.keyboard_double_arrow_up_rounded,
                          color: catColor.withValues(alpha: 0.4), size: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
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
