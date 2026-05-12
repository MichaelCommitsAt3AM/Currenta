import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../application/ad_manager.dart';

class NativeAdCard extends ConsumerStatefulWidget {
  const NativeAdCard({super.key});

  @override
  ConsumerState<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends ConsumerState<NativeAdCard>
    with AutomaticKeepAliveClientMixin {
  NativeAd? _ad;
  bool _adLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tryGetAd();

    // TODO: Implement fallback to auto-advance or display the next regular article if the ad fails to load or times out.
  }

  void _tryGetAd() {
    final manager = ref.read(adManagerProvider.notifier);
    final ad = manager.getAd();
    if (ad != null) {
      _ad = ad;
      _adLoaded = true;
    }
  }

  @override
  void dispose() {
    // The widget that renders the NativeAd takes ownership of its platform resources.
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_adLoaded) {
      // Subscribe to ad pool changes to grab an ad as soon as preloading completes
      final pool = ref.watch(adManagerProvider.select((s) => s.pool));
      if (pool.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_adLoaded) {
            setState(() {
              _tryGetAd();
            });
          }
        });
      }

      return Container(
        color: const Color(0xFF0A0C14),
        child: const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: Color(0xFF6C63FF),
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0A0C14),
      child: AdWidget(ad: _ad!),
    );
  }
}
