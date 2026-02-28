// lib/features/news/presentation/screens/empty_state_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyStateScreen extends StatefulWidget {
  const EmptyStateScreen({super.key, required this.onRetry});
  final VoidCallback onRetry;

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
                child: const Icon(
                  Icons.newspaper_rounded,
                  size: 54,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'No News Yet',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF0F2FF),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'We couldn\'t find any stories.\nPull down to refresh or check back soon.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF8890B5),
                height: 1.6,
              ),
            ),

            const SizedBox(height: 32),

            // ── Retry button ────────────────────────────────────
            FilledButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
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
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
