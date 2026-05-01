import 'dart:async';
import 'package:flutter/material.dart';

enum OnboardingStep { scroll, categories, favorites, none }

class FeedOnboardingOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final OnboardingStep step;

  const FeedOnboardingOverlay({
    super.key,
    required this.onDismiss,
    required this.step,
  });

  @override
  State<FeedOnboardingOverlay> createState() => _FeedOnboardingOverlayState();
}

class _FeedOnboardingOverlayState extends State<FeedOnboardingOverlay> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  late AnimationController _slideController;
  late Animation<Offset> _slideOffset;

  late AnimationController _categoryFadeController;
  late Animation<double> _categoryFade;

  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    // Pulse Animation for Categories
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 1.8).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));

    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));

    // Slide Animation for Scroll Popup
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideOffset = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Fade/Scale Animation for Category Hint
    _categoryFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _categoryFade = CurvedAnimation(
      parent: _categoryFadeController,
      curve: Curves.easeOut,
    );

    if (widget.step == OnboardingStep.scroll) {
      _slideController.forward();
    } else if (widget.step == OnboardingStep.categories || widget.step == OnboardingStep.favorites) {
      _categoryFadeController.forward();
    }
  }

  @override
  void didUpdateWidget(FeedOnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step != oldWidget.step && !_isDismissing) {
      if (widget.step == OnboardingStep.scroll) {
        _slideController.forward();
        _categoryFadeController.reverse();
      } else if (widget.step == OnboardingStep.categories || widget.step == OnboardingStep.favorites) {
        _categoryFadeController.forward();
        _slideController.reverse();
      } else {
        _slideController.reverse();
        _categoryFadeController.reverse();
      }
    }
  }

  Future<void> _handleDismiss() async {
    if (_isDismissing) return;
    setState(() => _isDismissing = true);

    if (widget.step == OnboardingStep.scroll) {
      await _slideController.animateTo(0.0, 
        duration: const Duration(milliseconds: 400), 
        curve: Curves.easeInCirc
      );
      // Extra nudge down to ensure it's off screen
      await _slideController.reverse();
    } else if (widget.step == OnboardingStep.categories || widget.step == OnboardingStep.favorites) {
      await _categoryFadeController.reverse();
    }

    widget.onDismiss();
    if (mounted) {
      setState(() => _isDismissing = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _categoryFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.step == OnboardingStep.none) return const SizedBox.shrink();

    return Stack(
      children: [
        // ── Scroll Popup (Bottom) ──
        if (widget.step == OnboardingStep.scroll)
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 32,
            left: 20,
            right: 20,
            child: SlideTransition(
              position: _slideOffset,
              child: _OnboardingPopup(
                icon: Icons.unfold_more_rounded,
                title: 'Swipe up for more',
                subtitle: 'Discover your next story',
                onDismiss: _handleDismiss,
              ),
            ),
          ),

        // ── Category Hint (Top) ──
        if (widget.step == OnboardingStep.categories) ...[
          // Pulse Indicator (Positioned exactly over 2nd chip)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 7,
            left: 162,
            child: FadeTransition(
              opacity: _categoryFade,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing ring
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseScale.value,
                        child: Opacity(
                          opacity: _pulseOpacity.value,
                          child: Container(
                            width: 92,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: const Color(0xFF6C63FF),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Static indicator
                  Container(
                    width: 92,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      border: Border.all(
                          color: const Color(0xFF6C63FF), width: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Popup (Positioned relative to screen edges to avoid overflow)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 60,
            left: 16,
            right: 16,
            child: FadeTransition(
              opacity: _categoryFade,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(_categoryFade),
                child: Center(
                  child: _OnboardingPopup(
                    title: 'Explore Topics',
                    subtitle: 'Tap to discover news by topic',
                    onDismiss: _handleDismiss,
                    isCompact: true,
                  ),
                ),
              ),
            ),
          ),
        ],

        // ── Favorites Hint (Bottom) ──
        if (widget.step == OnboardingStep.favorites)
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 32,
            left: 20,
            right: 20,
            child: FadeTransition(
              opacity: _categoryFade,
              child: _OnboardingPopup(
                icon: Icons.bookmark_added_rounded,
                title: 'Saved to Favorites!',
                subtitle: 'View your saved stories anytime in the sidebar.',
                onDismiss: _handleDismiss,
              ),
            ),
          ),
      ],
    );
  }
}

class _OnboardingPopup extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback onDismiss;
  final bool isCompact;

  const _OnboardingPopup({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.onDismiss,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF6C63FF), size: 24),
            ),
            const SizedBox(width: 16),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _GotItButton(onTap: onDismiss),
        ],
      ),
    );
  }
}

class _GotItButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GotItButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'Got it',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }
}
