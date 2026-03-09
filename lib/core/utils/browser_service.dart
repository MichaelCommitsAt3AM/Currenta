// lib/core/utils/browser_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as gct;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to manage Custom Tabs performance optimizations like pre-warming and pre-fetching.
class BrowserService {
  BrowserService._();
  static final BrowserService instance = BrowserService._();

  bool _isWarmedUp = false;

  /// Warms up the browser process in the background.
  /// Should be called before the user is likely to click a link.
  Future<void> warmup() async {
    if (_isWarmedUp) return;
    try {
      debugPrint('[BrowserService] Pre-warming browser engine...');
      // Explicitly pre-warm the default browser to respect user choice
      await gct.warmupCustomTabs(
        options: const gct.CustomTabsSessionOptions(
          prefersDefaultBrowser: true,
        ),
      );
      _isWarmedUp = true;
    } catch (e) {
      debugPrint('[BrowserService] Warmup failed: $e');
    }
  }


  /// Opens a URL in a Custom Tab with a premium design.
  Future<void> openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      await gct.launchUrl(
        uri,
        customTabsOptions: gct.CustomTabsOptions(
          colorSchemes: gct.CustomTabsColorSchemes.defaults(
            toolbarColor: const Color(0xFF0A0C14), // Dark background matching app theme
            navigationBarColor: const Color(0xFF0A0C14),
          ),
          shareState: gct.CustomTabsShareState.on,
          urlBarHidingEnabled: true,
          showTitle: true,
          animations: gct.CustomTabsSystemAnimations.slideIn(),
          browser: const gct.CustomTabsBrowserConfiguration(
            prefersDefaultBrowser: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[BrowserService] Could not launch Custom Tab: $e');
      // Fallback or ignore is handled by the caller or UI
    }
  }
}

final browserServiceProvider = Provider((ref) => BrowserService.instance);
