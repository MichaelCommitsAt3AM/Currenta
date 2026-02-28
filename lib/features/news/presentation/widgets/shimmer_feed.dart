// lib/features/news/presentation/widgets/shimmer_feed.dart
// Skeleton placeholder list shown while the feed is loading.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerFeed extends StatelessWidget {
  const ShimmerFeed({super.key, this.itemCount = 4});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => const _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1E2E),
      highlightColor: const Color(0xFF262A3E),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E2E),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _Skel(width: 28, height: 28, radius: 14),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Skel(width: 100, height: 10, radius: 5),
                    const SizedBox(height: 4),
                    _Skel(width: 60, height: 8, radius: 4),
                  ],
                ),
                const Spacer(),
                _Skel(width: 70, height: 24, radius: 100),
              ],
            ),
            const SizedBox(height: 18),
            // Title lines
            _Skel(width: double.infinity, height: 14, radius: 6),
            const SizedBox(height: 8),
            _Skel(width: 220, height: 14, radius: 6),
            const SizedBox(height: 16),
            // Summary lines
            _Skel(width: double.infinity, height: 10, radius: 5),
            const SizedBox(height: 6),
            _Skel(width: double.infinity, height: 10, radius: 5),
            const SizedBox(height: 6),
            _Skel(width: 180, height: 10, radius: 5),
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
