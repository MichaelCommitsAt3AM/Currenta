// lib/features/news/presentation/screens/empty_state_screen.dart

import 'package:flutter/material.dart';

class EmptyStateScreen extends StatefulWidget {
  const EmptyStateScreen({
    super.key,
    required this.onRetry,
    this.title = 'No News Yet',
    this.message = "We couldn't find any stories.\nPull down to refresh or check back soon.",
    this.buttonLabel = 'Try Again',
    this.icon = Icons.newspaper_rounded,
  });

  final VoidCallback onRetry;
  final String title;
  final String message;
  final String buttonLabel;
  final IconData icon;

  @override
  State<EmptyStateScreen> createState() => _EmptyStateScreenState();
}

class _EmptyStateScreenState extends State<EmptyStateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animated globe illustration ─────────────────────
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) => Transform.scale(
                scale: 0.9 + _pulseController.value * 0.1,
                child: child,
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF0A0C14)],
                    stops: [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 54,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF0F2FF),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF8890B5),
                height: 1.6,
              ),
            ),

            const SizedBox(height: 32),

            // ── Retry button ────────────────────────────────────
            FilledButton(
              onPressed: widget.onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.buttonLabel == 'Try Again') ...[
                    const Icon(Icons.refresh_rounded, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(widget.buttonLabel),
                  if (widget.buttonLabel != 'Try Again') ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
