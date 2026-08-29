// lib/features/news/presentation/widgets/mute_subcategory_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/providers.dart';

/// Formats a raw canonical taxonomy slug (e.g. 'ai_research', or
/// 'artificial_intelligence.ai_research' for an L3 node — see
/// taxonomy/taxonomy.json) into something readable, without needing the
/// taxonomy file itself bundled client-side (it isn't, yet — every slug
/// does have a proper `display_name` there; a follow-up could bundle it as
/// a Flutter asset and look names up exactly instead of this heuristic).
String formatSubcategorySlug(String slug) {
  final leaf = slug.contains('.') ? slug.split('.').last : slug;
  const smallCaps = {'ai', 'us', 'uk', 'eu', 'un', 'nba', 'nfl', 'ai '};
  return leaf
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => smallCaps.contains(w.toLowerCase())
          ? w.toUpperCase()
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Local-only (per-device) preference for whether to keep showing this
/// sheet after "Not interested" — no server round-trip needed, it's purely
/// a UI annoyance-avoidance setting, not personalization data.
class NotInterestedSheetPrefs {
  static const _key = 'not_interested_mute_sheet_dont_ask_again';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_key) ?? false);
  }

  static Future<void> setDontAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

/// Shown right after "Not interested" skips the current article (see
/// NewsCard._handleNotInterested) when that article has a subcategory —
/// offers the stronger action of muting the whole topic, not just this
/// one article.
class MuteSubCategorySheet extends ConsumerStatefulWidget {
  const MuteSubCategorySheet({super.key, required this.subcategorySlug});

  /// Raw taxonomy slug — passed through as-is to muteSubCategory (the
  /// backend exclusion filter matches on this exact string), only
  /// formatted for the label shown to the user.
  final String subcategorySlug;

  @override
  ConsumerState<MuteSubCategorySheet> createState() =>
      _MuteSubCategorySheetState();
}

class _MuteSubCategorySheetState extends ConsumerState<MuteSubCategorySheet> {
  bool _dontAskAgain = false;
  bool _isMuting = false;

  Future<void> _saveDontAskAgainIfSet() async {
    if (_dontAskAgain) {
      await NotInterestedSheetPrefs.setDontAskAgain();
    }
  }

  Future<void> _mute() async {
    HapticFeedback.mediumImpact();
    setState(() => _isMuting = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .muteSubCategory(widget.subcategorySlug);

      // Bust the backend's cached user_state so this takes effect on the
      // very next feed fetch instead of waiting out its 5-minute TTL —
      // same convention personalization_screen.dart already follows after
      // writing sub-interests directly to Supabase.
      await ref.read(newsRepositoryProvider).clearRemoteUserState();

      await _saveDontAskAgainIfSet();

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mute this topic: $e')),
      );
      setState(() => _isMuting = false);
    }
  }

  Future<void> _dismiss() async {
    await _saveDontAskAgainIfSet();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final label = formatSubcategorySlug(widget.subcategorySlug);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF262A3E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'This article is related to $label.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Would you like to stop seeing stories like this in your feed?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () => setState(() => _dontAskAgain = !_dontAskAgain),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _dontAskAgain,
                      onChanged: (v) =>
                          setState(() => _dontAskAgain = v ?? false),
                      activeColor: const Color(0xFF6C63FF),
                      side: const BorderSide(color: Colors.white38),
                    ),
                    const Expanded(
                      child: Text(
                        "Don't ask me this again",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isMuting ? null : _mute,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                elevation: 0,
              ),
              child: _isMuting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Stop showing $label',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isMuting ? null : _dismiss,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
