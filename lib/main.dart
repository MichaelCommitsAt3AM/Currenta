import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/config/app_config.dart';
import 'core/providers/providers.dart';
import 'core/navigation/app_route_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/storage/secure_auth_storage.dart';

import 'theme/theme.dart';
import 'features/news/presentation/screens/feed_screen.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';

// ── Crash Reporting Shim ─────────────────────────────────────────────────────
void _reportError(Object error, StackTrace stack, {bool fatal = false}) {
  // In debug mode use the standard output; in release this will be silent
  // until you wire up a real reporter.
  debugPrint('[CrashReporter] ${fatal ? "FATAL" : "ERROR"}: $error');
  debugPrintStack(stackTrace: stack);

  // Crashlytics integration:
  if (Firebase.apps.isNotEmpty) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }
}

Future<void> main() async {
  // ── Error Handling ────────────────────────────────────────────────────────

  // Catch all errors thrown synchronously in Flutter framework callbacks
  FlutterError.onError = (FlutterErrorDetails details) {
    _reportError(details.exception, details.stack ?? StackTrace.current);
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Catch all async / isolate errors not caught by FlutterError.onError.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _reportError(error, stack, fatal: true);
    return true;
  };

  // ── Silence debugPrint in Production ───────────────────────────────────────
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // ── Splash Screen ──────────────────────────────────────────────────────────
  // Preserve the native splash screen until critical initializations are done.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ── System UI ──────────────────────────────────────────────────────────────
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ── Parallel Initialization ────────────────────────────────────────────────
  // Grouping core heavy-hitters to initialize concurrently.
  final initResults = await Future.wait([
    Firebase.initializeApp(
      options: AppConfig.isProd
          ? prod.DefaultFirebaseOptions.currentPlatform
          : dev.DefaultFirebaseOptions.currentPlatform,
    ),
    Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureAuthStorage(),
      ),
    ),
    SharedPreferences.getInstance(),
  ]);

  final prefs = initResults[2] as SharedPreferences;
  final hasCompletedOnboarding =
      prefs.getBool('has_completed_onboarding') ?? false;

  // ── Non-Critical / Deferred Task Execution ─────────────────────────────────
  // These tasks don't need to block the first frame.
  unawaited(_initializeDeferredTasks());

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: CurrentaApp(
        initialScreen:
            hasCompletedOnboarding ? const FeedScreen() : const WelcomeScreen(),
      ),
    ),
  );

  // ── Remove Splash ─────────────────────────────────────────────────────────
  // Now that the first frame is ready, we remove the splash screen.
  FlutterNativeSplash.remove();
}

/// Tasks that can run after the app has started or in the background
/// to improve the 'Time to Interactive'.
Future<void> _initializeDeferredTasks() async {
  try {
    // Sign in anonymously if no session exists to track 'seen' state
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentSession == null) {
      debugPrint(
          '[Auth] No session found. Signing in anonymously (deferred)...');
      await supabase.auth.signInAnonymously();
    }
  } catch (e) {
    debugPrint('[Init] Deferred initialization failed: $e');
  }
}

class CurrentaApp extends StatelessWidget {
  const CurrentaApp({super.key, required this.initialScreen});

  final Widget initialScreen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currenta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorObservers: [appRouteObserver],
      home: initialScreen,
    );
  }
}
