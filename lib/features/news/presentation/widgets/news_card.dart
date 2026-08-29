// lib/features/news/presentation/widgets/news_card.dart
import 'package:currenta/features/news/domain/entities/news_category.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../domain/entities/news_article.dart';
import '../../../../theme/theme.dart';
import '../../application/news_feed_notifier.dart';
import '../../application/onboarding_notifier.dart';
import '../widgets/feed_onboarding_overlay.dart';
import 'heart_shower.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../core/utils/browser_service.dart';
import 'ai_quick_chat_sheet.dart';
import '../../application/pending_activity_provider.dart';
import 'share_card_sheet.dart';
import 'mute_subcategory_sheet.dart';

const bool _hideFeedIndicators =
    bool.fromEnvironment('CURRENTA_HIDE_FEED_INDICATORS', defaultValue: false);

enum _ArticleMenuAction { share, notInterested }

class NewsCard extends ConsumerStatefulWidget {
  final NewsArticle article;
  final int index;
  final int total;
  final double? topPadding;

  const NewsCard({
    super.key,
    required this.article,
    required this.index,
    required this.total,
    this.topPadding,
  });

  @override
  ConsumerState<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends ConsumerState<NewsCard>
    with TickerProviderStateMixin {
  bool showShower = false;

  // Local optimistic state for instant feedback
  bool? _localIsLiked;
  bool? _localIsFavorited;
  int? _localLikesCount;

  late AnimationController _bookmarkController;

  bool get _isLiked => _localIsLiked ?? widget.article.isLiked;
  bool get _isFavorited => _localIsFavorited ?? widget.article.isFavorited;
  int get _likesCount => _localLikesCount ?? widget.article.likesCount;

  @override
  void initState() {
    super.initState();
    _bookmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
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
    if (_localIsFavorited != null &&
        widget.article.isFavorited == _localIsFavorited) {
      _localIsFavorited = null;
    }
  }

  @override
  void dispose() {
    _bookmarkController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();

    final isAuth = ref.read(authNotifierProvider).isAuthenticated;
    if (!isAuth) {
      ref
          .read(pendingActivityNotifierProvider.notifier)
          .set(PendingAction.like, widget.article.id);
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
      ref
          .read(pendingActivityNotifierProvider.notifier)
          .set(PendingAction.like, widget.article.id);
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

  void _handleFavoritePress() {
    HapticFeedback.lightImpact();

    final isAuth = ref.read(authNotifierProvider).isAuthenticated;
    if (!isAuth) {
      ref
          .read(pendingActivityNotifierProvider.notifier)
          .set(PendingAction.favorite, widget.article.id);
      _showAuthSheet();
      return;
    }

    setState(() {
      _localIsFavorited = !_isFavorited;
    });

    // Run pop animation
    _bookmarkController
        .forward(from: 0)
        .then((_) => _bookmarkController.reverse());

    ref
        .read(newsFeedNotifierProvider.notifier)
        .toggleFavorite(widget.article.id);

    // ── Onboarding Trigger ──
    final onboarding = ref.read(onboardingNotifierProvider.notifier);
    if (!onboarding.hasSeenFavoritesOnboarding) {
      onboarding.setStep(OnboardingStep.favorites);
      onboarding.markFavoritesOnboardingSeen();
    }
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
                'You need to be signed in to like, favorite, or chat with AI. Join us to personalize your experience.',
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
    final authState = ref.watch(authNotifierProvider);
    final userCountry = authState.preferredCountry;

    // Determine the primary category to display.
    // If the article is local to the user, we prioritize the 'Local' badge.
    final isLocalToUser = widget.article.countryCode != null &&
        userCountry != null &&
        widget.article.countryCode == userCountry;

    final displayCategory = isLocalToUser
        ? NewsCategory.local
        : (widget.article.categories.isNotEmpty
            ? widget.article.categories.first
            : NewsCategory.world);

    final catColor = AppTheme.categoryColor(displayCategory.name);
    final size = MediaQuery.sizeOf(context);
    final availableHeight = size.height;
    final bool isWideScreen = size.width >= 600 && size.width > size.height;

    return Container(
      width: size.width,
      height: availableHeight,
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
                MediaQuery.paddingOf(context).top +
                    (widget.topPadding ?? 56),
                24,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: isWideScreen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopRow(catColor, displayCategory),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.article.imageUrl != null) ...[
                                Expanded(
                                  flex: 1,
                                  child: _buildImage(
                                      availableHeight, size, true),
                                ),
                                const SizedBox(width: 24),
                              ],
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _buildTitle(),
                                    const SizedBox(height: 8),
                                    _buildSummary(),
                                    const SizedBox(height: 2),
                                    _buildSourceRow(catColor),
                                    const SizedBox(height: 4),
                                    _buildFooterActions(catColor),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopRow(catColor, displayCategory),
                        const SizedBox(height: 16),
                        if (widget.article.imageUrl != null)
                          Flexible(
                            flex: 0,
                            fit: FlexFit.loose,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child:
                                  _buildImage(availableHeight, size, false),
                            ),
                          ),
                        _buildTitle(),
                        const SizedBox(height: 8),
                        _buildSummary(),
                        const SizedBox(height: 2),
                        _buildSourceRow(catColor),
                        const SizedBox(height: 4),
                        _buildFooterActions(catColor),
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

  Widget _buildTopRow(Color catColor, NewsCategory displayCategory) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PageIndicator(
          index: widget.index,
          total: widget.total,
          color: catColor,
        ),
        _CategoryChip(
          label: displayCategory.displayName,
          color: catColor,
        ),
      ],
    );
  }

  Widget _buildImage(double availableHeight, Size size, bool isWideScreen) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (size.width * (isWideScreen ? 0.5 : 1.0) * dpr).toInt();
    final cacheHeight =
        (availableHeight * (isWideScreen ? 1.0 : 0.25) * dpr).toInt();

    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: isWideScreen ? null : double.infinity,
        height: isWideScreen ? null : availableHeight * 0.25,
        constraints: isWideScreen
            ? BoxConstraints(
                maxWidth: size.width * 0.5,
                maxHeight: availableHeight,
              )
            : null,
        color: Colors.white.withValues(alpha: 0.05),
        child: CachedNetworkImage(
          imageUrl: widget.article.imageUrl!,
          fit: isWideScreen ? BoxFit.contain : BoxFit.cover,
          memCacheWidth: cacheWidth,
          memCacheHeight: cacheHeight,
          maxWidthDiskCache: cacheWidth,
          maxHeightDiskCache: cacheHeight,
          filterQuality: FilterQuality.low,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(color: Colors.white),
            ),
          ),
          errorWidget: (context, url, error) => Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
    );

    if (isWideScreen) {
      return Container(
        height: double.infinity,
        alignment: Alignment.center,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildTitle() {
    return Text(
      widget.article.title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.3,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSummary() {
    return Expanded(
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
    );
  }

  Widget _buildSourceRow(Color catColor) {
    return GestureDetector(
      onTap: () => _openOriginal(context, widget.article.originalUrl),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (widget.article.sourceFaviconUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: widget.article.sourceFaviconUrl!,
                    width: 20,
                    height: 20,
                    memCacheWidth: 40,
                    memCacheHeight: 40,
                    maxWidthDiskCache: 40,
                    maxHeightDiskCache: 40,
                    placeholder: (context, url) => Container(
                      width: 20,
                      height: 20,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    errorWidget: (context, url, _) => const SizedBox.shrink(),
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
                    widget.article.sourceName.trim().isNotEmpty
                        ? widget.article.sourceName.trim()[0]
                        : '?',
                    style: TextStyle(
                      color: catColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Text(
                widget.article.sourceName.trim(),
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
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: catColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(Color catColor) {
    return Row(
      children: [
        _buildActionPill(),
        const Spacer(),
        _buildMoreMenuButton(),
      ],
    );
  }

  Widget _pillDivider() {
    return Container(
      width: 1,
      height: 15,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.14),
    );
  }

  // Like + Save + AI grouped under one pill, per the redesign — the 3-dot
  // menu (Share / Not interested) takes the pill's old standalone spot on
  // the far right, where the AI button used to sit alone.
  //
  // Icon size and padding are balanced against each other so the pill's
  // overall footprint stays put even as the icons themselves grow — see
  // the icon `size:` values below.
  Widget _buildActionPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _handleIconPress,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: _isLiked ? 'Unlike' : 'Like',
            icon: Icon(
              _isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isLiked
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.75),
              size: 20,
            ),
          ),
          _pillDivider(),
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.3).animate(
              CurvedAnimation(
                parent: _bookmarkController,
                curve: Curves.easeOutBack,
              ),
            ),
            child: IconButton(
              onPressed: _handleFavoritePress,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: _isFavorited ? 'Remove from Saved' : 'Save',
              icon: Icon(
                _isFavorited
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _isFavorited
                    ? const Color(0xFFFFD700)
                    : Colors.white.withValues(alpha: 0.75),
                size: 20,
              ),
            ),
          ),
          _pillDivider(),
          _buildAiButton(),
        ],
      ),
    );
  }

  // Standalone at the far right — the pill's old spot before AI joined it.
  // 3-dot dropdown: Share (functional) and Not interested (UI scaffolding
  // for now — see _handleNotInterested).
  Widget _buildMoreMenuButton() {
    return PopupMenuButton<_ArticleMenuAction>(
      padding: EdgeInsets.zero,
      splashRadius: 20,
      // PopupMenuButton anchors the menu's top edge to the button's top
      // edge by default (it only clamps to stay on-screen, it never moves
      // away from the button to avoid covering it) — with the button this
      // close to the bottom of the card, that clamping pinned the menu
      // right on top of the button instead of beside it. Shifting the
      // anchor up by roughly the menu's own height (2 items ~48px each +
      // 16px surface padding) plus a gap opens it just above the button.
      offset: const Offset(0, -140),
      icon: Icon(
        Icons.more_vert_rounded,
        color: Colors.white.withValues(alpha: 0.75),
        size: 18,
      ),
      color: const Color(0xFF1A1E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      onSelected: _handleMenuAction,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _ArticleMenuAction.share,
          child: Row(
            children: [
              Icon(Icons.ios_share_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Share', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ArticleMenuAction.notInterested,
          child: Row(
            children: [
              Icon(Icons.not_interested_rounded,
                  color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Not interested', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  // Third icon inside the action pill, alongside Like and Save.
  Widget _buildAiButton() {
    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        final isAuth = ref.read(authNotifierProvider).isAuthenticated;
        if (!isAuth) {
          ref
              .read(pendingActivityNotifierProvider.notifier)
              .set(PendingAction.chat, widget.article.id);
          _showAuthSheet();
          return;
        }
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AiQuickChatSheet(article: widget.article),
        );
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        Icons.auto_awesome,
        color: Colors.white.withValues(alpha: 0.75),
        size: 20,
      ),
    );
  }

  void _handleMenuAction(_ArticleMenuAction action) {
    switch (action) {
      case _ArticleMenuAction.share:
        _shareArticle();
      case _ArticleMenuAction.notInterested:
        _handleNotInterested();
    }
  }

  void _shareArticle() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ShareCardSheet(article: widget.article),
    );
  }

  Future<void> _handleNotInterested() async {
    HapticFeedback.mediumImpact();

    // Instant skip (removes the article from the pager immediately) +
    // fire-and-forget dislike write — see NewsFeedNotifier.dislikeArticle
    // for why this is a removal, not just a flag like toggleLike/
    // toggleFavorite. No snackbar: the skip itself is the confirmation.
    ref
        .read(newsFeedNotifierProvider.notifier)
        .dislikeArticle(widget.article.id);

    // Offer the stronger "mute this whole topic" action, but only if this
    // article actually has a subcategory and the user hasn't opted out of
    // seeing this prompt.
    final slug = widget.article.primarySubcategorySlug;
    if (slug == null || slug.isEmpty) return;
    if (!await NotInterestedSheetPrefs.shouldShow()) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => MuteSubCategorySheet(subcategorySlug: slug),
    );
  }

  Future<void> _openOriginal(BuildContext context, String url) async {
    ref.read(browserServiceProvider).openUrl(context, url);
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
    if (_hideFeedIndicators) return const SizedBox.shrink();
    // Hidden in Release build so production UI matches intended store look.
    // Enabled in Debug and Profile builds for testing and profiling.
    if (kReleaseMode) return const SizedBox.shrink();

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
