// lib/features/news/presentation/widgets/daily_digest_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/daily_digest_notifier.dart';

/// Replaces the category chip row while the leading `totalCount` articles
/// of the "For You" feed are the daily digest. `currentIndex`/`totalCount`
/// come from the same scroll position FeedScreen already tracks for the
/// main feed — once the user scrolls past the digest articles, FeedScreen
/// stops rendering this bar automatically. The toggle is a manual
/// "skip the digest chrome now" shortcut (see [DailyDigestNotifier.dismiss]);
/// it doesn't move the scroll position, the merged content stays put.
class DailyDigestBar extends ConsumerWidget {
  const DailyDigestBar({
    super.key,
    required this.onOpenDrawer,
    required this.currentIndex,
    required this.totalCount,
  });

  final VoidCallback onOpenDrawer;
  final int currentIndex;
  final int totalCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final current =
        totalCount == 0 ? 0 : (currentIndex + 1).clamp(0, totalCount);

    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0C14).withValues(alpha: 0.95),
            const Color(0xFF0A0C14).withValues(alpha: 0.70),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onOpenDrawer,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      height: 40,
                      width: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8A84FF)],
                    ).createShader(bounds),
                    child: const Text(
                      'What matters today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoSwitch(
                  value: true,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (_) =>
                      ref.read(dailyDigestNotifierProvider.notifier).dismiss(),
                ),
              ],
            ),
          ),
          // Thin edge-to-edge read-progress bar. Indeterminate (no `value`)
          // while the digest is still fetching (totalCount == 0); once it
          // has a real target, TweenAnimationBuilder eases the fill toward
          // it instead of jumping straight there on every page change.
          SizedBox(
            height: 3,
            child: totalCount == 0
                ? LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: current / totalCount),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    builder: (context, animatedValue, _) =>
                        LinearProgressIndicator(
                      value: animatedValue,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6C63FF),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
