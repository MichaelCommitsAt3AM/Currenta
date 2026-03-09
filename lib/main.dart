// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'theme/theme.dart';
import 'features/news/application/background_fetch_service.dart';
import 'features/news/presentation/screens/feed_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

  // ── Background Tasks ──────────────────────────────────────────
  await registerBackgroundTasks();

  runApp(
    const ProviderScope(
      child: CurrentaApp(),
    ),
  );
}

class CurrentaApp extends StatelessWidget {
  const CurrentaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currenta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const FeedScreen(),
    );
  }
}
