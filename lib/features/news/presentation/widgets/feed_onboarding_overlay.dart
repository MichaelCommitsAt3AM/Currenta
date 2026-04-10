import 'dart:async';
import 'package:flutter/material.dart';

class FeedOnboardingOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final bool showCategoryHint;

  const FeedOnboardingOverlay({
    super.key,
    required this.onDismiss,
    this.showCategoryHint = false,
  });

  @override
  State<FeedOnboardingOverlay> createState() => _FeedOnboardingOverlayState();
}

class _FeedOnboardingOverlayState extends State<FeedOnboardingOverlay> with TickerProviderStateMixin {
  late AnimationController _handController;
  late Animation<Offset> _handOffset;
  late Animation<double> _handOpacity;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  bool _showScrollHint = true;

  @override
  void initState() {
    super.initState();

    // Hand Animation (Swipe Up)
    _handController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _handOffset = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: const Offset(0, -0.4),
    ).animate(CurvedAnimation(
      parent: _handController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
    ));

    _handOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _handController,
      curve: const Interval(0.0, 0.9),
    ));

    // Pulse Animation for Categories
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 2.2).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));

    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));
    
    // Auto-transition to category hint after some time or interaction
    if (_showScrollHint) {
       Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showScrollHint = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _handController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      onVerticalDragStart: (_) => widget.onDismiss(),
      child: Stack(
        children: [
          // Semi-darkened background to make hints pop
          AnimatedOpacity(
            opacity: 0.4,
            duration: const Duration(milliseconds: 500),
            child: Container(color: Colors.black),
          ),

          // ── Scroll Hint (Center) ──
          if (_showScrollHint)
            Center(
              child: AnimatedBuilder(
                animation: _handController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _handOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _handOffset.value.dy * 200),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Icon(
                            Icons.touch_app_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 64,
                            shadows: [
                              Shadow(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Swipe up for more',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── Category Hint (Top) ──
          if (!_showScrollHint && widget.showCategoryHint)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 7,
              left: 17, // Aligned with the menu button approx
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
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
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
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
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                            border: Border.all(
                                color: const Color(0xFF6C63FF), width: 1.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Tap to explore categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Dismiss Button (Bottom Center) ──
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
