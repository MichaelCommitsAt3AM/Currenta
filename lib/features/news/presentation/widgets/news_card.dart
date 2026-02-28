// lib/features/news/presentation/widgets/news_card.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/news_article.dart';
import '../../../../core/theme/app_theme.dart';

class NewsCard extends StatefulWidget {
  const NewsCard({super.key, required this.article});
  final NewsArticle article;

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final catColor = AppTheme.categoryColor(article.category.name);

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openOriginal(article.originalUrl),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ─────────────────────────────────
                  Row(
                    children: [
                      _SourceFavicon(url: article.sourceFaviconUrl),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.sourceName,
                              style: Theme.of(context).textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatDate(article.publishedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      // Category chip
                      _CategoryChip(
                        label:
                            '${article.category.emoji} ${article.category.displayName}',
                        color: catColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Title ──────────────────────────────────────
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // ── Divider ───────────────────────────────────
                  Divider(color: catColor.withValues(alpha: 0.3), thickness: 1),

                  const SizedBox(height: 12),

                  // ── 64-word AI summary ─────────────────────────
                  Text(
                    article.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // ── Footer ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (article.isPaywalled) _PremiumBadge(color: catColor),
                      const Spacer(),
                      _ReadMoreButton(color: catColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }

  Future<void> _openOriginal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _SourceFavicon extends StatelessWidget {
  const _SourceFavicon({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: Color(0xFF262A3E),
        child: Icon(Icons.public, size: 14, color: Color(0xFF6C63FF)),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFF262A3E),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 22,
        height: 22,
        imageBuilder: (ctx, img) => CircleAvatar(
          radius: 11,
          backgroundImage: img,
        ),
        placeholder: (ctx, _) => Shimmer.fromColors(
          baseColor: const Color(0xFF262A3E),
          highlightColor: const Color(0xFF363A50),
          child: const CircleAvatar(radius: 11),
        ),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.public, size: 14, color: Color(0xFF6C63FF)),
      ),
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
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          'Premium',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReadMoreButton extends StatelessWidget {
  const _ReadMoreButton({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Read more',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward_rounded, size: 14, color: color),
      ],
    );
  }
}
