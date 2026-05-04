// lib/features/news/presentation/widgets/shimmer_feed.dart
// Full-screen shimmer placeholder that matches the new PageView card layout.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerFeed extends StatelessWidget {
  const ShimmerFeed({super.key, this.itemCount = 1});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1E2E),
      highlightColor: const Color(0xFF2C3150),
      child: Container(
        width: size.width,
        height: size.height,
        color: const Color(0xFF0A0C14),
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.paddingOf(context).top + 56,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dot indicator + Category chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: i == 0 ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const _Skel(
                    width: 72, height: 24, radius: 100), // category chip
              ],
            ),
            const Spacer(),
            // Title
            _Skel(width: double.infinity, height: 28, radius: 8),
            const SizedBox(height: 12),
            _Skel(width: size.width * 0.75, height: 28, radius: 8),
            const SizedBox(height: 12),
            _Skel(width: size.width * 0.5, height: 28, radius: 8),
            const SizedBox(height: 24),
            // Divider
            _Skel(width: double.infinity, height: 1, radius: 1),
            const SizedBox(height: 20),
            // Summary lines
            for (var i = 0; i < 4; i++) ...[
              _Skel(
                width: i == 3 ? size.width * 0.6 : double.infinity,
                height: 13,
                radius: 6,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
            // Button
            _Skel(width: 150, height: 40, radius: 100),
          ],
        ),
      ),
    );
  }
}

class _Skel extends StatelessWidget {
  const _Skel({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
