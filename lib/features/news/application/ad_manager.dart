import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/utils/ad_config.dart';

part 'ad_manager.g.dart';

class PooledAd {
  final NativeAd ad;
  final DateTime loadedAt;

  PooledAd({
    required this.ad,
    required this.loadedAt,
  });

  bool get isStale => DateTime.now().difference(loadedAt).inMinutes >= 60;
}

class AdManagerState {
  final List<PooledAd> pool;
  final bool adsAvailable;

  AdManagerState({
    required this.pool,
    required this.adsAvailable,
  });

  AdManagerState copyWith({
    List<PooledAd>? pool,
    bool? adsAvailable,
  }) {
    return AdManagerState(
      pool: pool ?? this.pool,
      adsAvailable: adsAvailable ?? this.adsAvailable,
    );
  }
}

@Riverpod(keepAlive: true)
class AdManager extends _$AdManager {
  static const int _targetPoolSize = 3;
  bool _isLoading = false;
  bool _isDisposed = false;
  Timer? _cleanupTimer;

  @override
  AdManagerState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _cleanupTimer?.cancel();
      for (final pooled in state.pool) {
        pooled.ad.dispose();
      }
    });

    // Periodic cleanup of stale ads every 10 minutes
    _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _evictStaleAds();
    });

    // Start preloading ads immediately
    Future.microtask(_replenishPool);
    return AdManagerState(pool: [], adsAvailable: false);
  }

  void _evictStaleAds() {
    if (_isDisposed) return;

    final validAds = <PooledAd>[];
    bool didEvict = false;

    for (final pooled in state.pool) {
      if (pooled.isStale) {
        if (kDebugMode) {
          debugPrint(
              '[AdManager] Evicting stale ad loaded at ${pooled.loadedAt}');
        }
        pooled.ad.dispose();
        didEvict = true;
      } else {
        validAds.add(pooled);
      }
    }

    if (didEvict) {
      state = state.copyWith(pool: validAds);
      _replenishPool();
    }
  }

  /// Returns a preloaded NativeAd if available, and triggers pool replenishment.
  /// If the pool is empty, returns null (caller can show standard content or await).
  NativeAd? getAd() {
    if (state.pool.isEmpty) {
      _replenishPool();
      return null;
    }

    // O(1) Fast Path: Only run full O(N) eviction scan if the oldest ad (the first one) is stale.
    if (state.pool.first.isStale) {
      _evictStaleAds();
      if (state.pool.isEmpty) {
        _replenishPool();
        return null;
      }
    }

    final pooled = state.pool.first;
    final remaining = state.pool.sublist(1);
    state = state.copyWith(pool: remaining);
    _replenishPool();
    return pooled.ad;
  }

  void _replenishPool() {
    if (_isDisposed || _isLoading || state.pool.length >= _targetPoolSize)
      return;

    _isLoading = true;
    final adUnitId = AdConfig.nativeAdUnitId;

    final ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'NewsCardAdFactory',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          if (_isDisposed) {
            ad.dispose();
            return;
          }
          if (kDebugMode) {
            debugPrint('[AdManager] Native ad loaded successfully.');
          }
          _isLoading = false;
          final newPooled =
              PooledAd(ad: ad as NativeAd, loadedAt: DateTime.now());
          state = state.copyWith(
            pool: [...state.pool, newPooled],
            adsAvailable: true,
          );
          // Continue replenishing if needed
          _replenishPool();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          if (kDebugMode) {
            debugPrint('[AdManager] Native ad failed to load: $error');
          }
          ad.dispose();
          if (_isDisposed) return;

          _isLoading = false;
          // Retry after a brief delay to avoid spamming failed requests
          Future.delayed(const Duration(seconds: 10), () {
            if (!_isDisposed) {
              _replenishPool();
            }
          });
        },
      ),
    );

    ad.load();
  }
}
