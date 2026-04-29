import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
import 'core/utils/snackbar_utils.dart';
import 'core/widgets/connectivity_listener.dart';

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
  SharedPreferences? prefs;
  bool hasCompletedOnboarding = false;
  bool initFailed = false;
  String errorMessage = '';

  try {
    // 1. Initialize Firebase with a safety guard
    try {
      await Firebase.initializeApp(
        options: AppConfig.isProd
            ? prod.DefaultFirebaseOptions.currentPlatform
            : dev.DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // If the app is already initialized, we can safely ignore this error
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }

    // 2. Initialize other services in parallel
    final initResults = await Future.wait([
      Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureAuthStorage(),
        ),
      ),
      SharedPreferences.getInstance(),
    ]);

    prefs = initResults[1] as SharedPreferences;
    hasCompletedOnboarding =
        prefs.getBool('has_completed_onboarding') ?? false;

    // ── Firebase App Check ─────────────────────────────────────────────────────
    if (AppConfig.isProd && kReleaseMode) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
    }

    // ── Non-Critical / Deferred Task Execution ─────────────────────────────────
    // These tasks don't need to block the first frame.
    unawaited(_initializeDeferredTasks());
  } catch (e, st) {
    initFailed = true;
    errorMessage = e.toString();
    _reportError(e, st, fatal: true);
  } finally {
    // ── Remove Splash ─────────────────────────────────────────────────────────
    // Now that the first frame is ready (or we failed), we remove the splash screen.
    FlutterNativeSplash.remove();
  }

  if (initFailed) {
    runApp(
      MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text('Startup Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs!),
      ],
      child: CurrentaApp(
        initialScreen:
            hasCompletedOnboarding ? const FeedScreen() : const WelcomeScreen(),
      ),
    ),
  );
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
  } catch (e, st) {
    debugPrint('[Init] Deferred initialization failed: $e');
    _reportError(e, st);
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
      scaffoldMessengerKey: AppSnackbar.messengerKey,
      home: ConnectivityListener(child: initialScreen),
    );
  }
}
