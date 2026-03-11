import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/theme.dart';
import 'features/news/application/background_fetch_service.dart';
import 'features/news/presentation/screens/feed_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';

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
  // Catch all errors thrown synchronously in Flutter framework callbacks
  // (e.g. build, layout, paint). In release builds this prevents white screens.
  FlutterError.onError = (FlutterErrorDetails details) {
    _reportError(details.exception, details.stack ?? StackTrace.current);
    // Re-present the error in debug mode (keeps the red screen behaviour).
    FlutterError.presentError(details);
    
    // Route fatal errors directly to Crashlytics
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Catch all async / isolate errors not caught by FlutterError.onError.
  // Return true to mark the error as handled (prevents process termination).
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _reportError(error, stack, fatal: true);
    return true;
  };

  // ── Silence debugPrint in Production ───────────────────────────────────────
  // debugPrint still writes to logcat in release mode by default. This overrides
  // it to be a no-op in release, ensuring zero console output in production.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  WidgetsFlutterBinding.ensureInitialized();
  
  // ── Firebase Initialization ────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ── System UI ────────────────────────────────────────────────
  // Enable drawing behind status and navigation bars for a seamless immersive look
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ── Supabase x──────────────────────────────────────────────────
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Sign in anonymously if no session exists to track 'seen' state
  final supabase = Supabase.instance.client;
  if (supabase.auth.currentSession == null) {
    debugPrint('[Auth] No session found. Signing in anonymously...');
    await supabase.auth.signInAnonymously();
  }

  // ── Initial Route Check ───────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

  // ── Background Tasks ──────────────────────────────────────────
  await registerBackgroundTasks();

  runApp(
    ProviderScope(
      child: CurrentaApp(initialScreen: hasCompletedOnboarding ? const FeedScreen() : const OnboardingScreen()),
    ),
  );
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
      home: initialScreen,
    );
  }
}
