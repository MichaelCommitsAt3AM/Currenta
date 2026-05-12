import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AdConfig {
  /// Returns the AdMob Native Advanced Ad Unit ID based on platform and release mode.
  static String get nativeAdUnitId {
    if (kReleaseMode) {
      // TODO: Replace with your actual AdMob production Ad Unit IDs before publishing.
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ca-app-pub-8795852141624819/8613992385';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ca-app-pub-3940256099942544/3986624511';
      }
    } else {
      // Dev environment Ad Unit mapping (Use Google sample units to bypass server SHA blocks locally)
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ca-app-pub-3940256099942544/2247696110';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ca-app-pub-3940256099942544/3986624511';
      }
    }
    throw UnsupportedError('Unsupported platform for ads');
  }
}
