// lib/features/news/presentation/widgets/share_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import '../../../../theme/app_theme.dart';

/// Visual card rendered to a PNG for sharing (see [ShareCardSheet]).
///
/// Deliberately NOT a literal screenshot of the feed — that would capture
/// the status bar, the action pill, ads, and whatever scroll position the
/// card happened to be at. This is a clean, purpose-built layout instead,
/// consistent every time regardless of what's actually on screen.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.article});

  final NewsArticle article;

  /// Logical width of the card — fixed, so it always crops to a consistent
  /// portrait shape as a chat attachment or story/status post. Height is
  /// NOT fixed: the card sizes itself to its content (see mainAxisSize.min
  /// below) so the summary is never truncated and there's never leftover
  /// dead space either, regardless of how long a given article's title or
  /// summary happens to be. Captured at pixelRatio 3 in ShareCardSheet, so
  /// the exported PNG comes out roughly 1080px wide.
  static const double width = 360;

  @override
  Widget build(BuildContext context) {
    final category =
        article.categories.isNotEmpty ? article.categories.first : NewsCategory.world;
    final catColor = AppTheme.categoryColor(category.name);

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0C14),
            Color.lerp(const Color(0xFF0A0C14), catColor, 0.18)!,
            const Color(0xFF0A0C14),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Brand row ──
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/icons/app_logo_new.png',
                    width: 22,
                    height: 22,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Currenta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: catColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    category.displayName,
                    style: TextStyle(
                      color: catColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Cover image ──
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: article.imageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.white.withValues(alpha: 0.06)),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
            const SizedBox(height: 16),

            // ── Title ──
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // ── Summary ──
            // No maxLines cap — the card sizes to fit it (see mainAxisSize
            // above), so the full summary always shows. The generous cap
            // here is purely a sanity backstop against pathological/corrupt
            // data producing an absurdly tall card, not a normal-case limit.
            Text(
              article.summary,
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // ── Source ──
            Text(
              article.sourceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 14),

            // Google's own official "Get it on Google Play" badge (the
            // real multi-color triangle mark + wordmark), sourced directly
            // from play.google.com's public badge assets — not a hand-drawn
            // approximation.
            Image.asset('assets/icons/google_play_badge.png', height: 46),
          ],
        ),
      ),
    );
  }
}
