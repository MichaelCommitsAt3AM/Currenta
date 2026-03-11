// lib/features/auth/presentation/screens/auth_bridge_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/providers.dart';
import '../../../news/domain/entities/news_category.dart';
import '../../../news/presentation/screens/feed_screen.dart';

class AuthBridgeScreen extends ConsumerStatefulWidget {
  const AuthBridgeScreen({super.key, required this.selectedInterests});

  final List<NewsCategory> selectedInterests;

  @override
  ConsumerState<AuthBridgeScreen> createState() => _AuthBridgeScreenState();
}

class _AuthBridgeScreenState extends ConsumerState<AuthBridgeScreen> {
  bool _isLoading = false;
  String _loadingMessage = 'Personalizing your experience...';

  Future<void> _completeOnboardingFlow() async {
    final authRepo = ref.read(authRepositoryProvider);
    final onboardingRepo = ref.read(onboardingRepositoryProvider);

    try {
      // 1. Save interests to backend
      await authRepo.saveUserInterests(
        widget.selectedInterests.map((c) => c.name).toList(),
      );

      // 2. Mark flow as completed locally
      await onboardingRepo.completeOnboarding();

      // 3. Clear cache and trigger fresh feed fetch so new interests apply immediately
      await ref.read(newsRepositoryProvider).clearCache(); 
      
      if (!mounted) return;
      
      // 4. Navigate to Feed
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const FeedScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preferences: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGuest() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Personalizing your experience...';
    });
    // For Guest, they are already signed in anonymously from main.dart,
    // so we just finalize preferences.
    await _completeOnboardingFlow();
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Authenticating safely...';
    });

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      
      setState(() {
        _loadingMessage = 'Personalizing your experience...';
      });
      
      // After sign in and migration (handled internally by AuthRepo), finalize preferences.
      await _completeOnboardingFlow();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0C14),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  size: 40,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Save your feed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to sync your personalized feed across all your devices, or continue as a guest for now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              
              const Spacer(flex: 3),

              // Sign In Button
              ElevatedButton(
                onPressed: _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0A0C14),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/google_logo.png', // Assuming you have this asset
                      height: 24,
                      errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Guest Button
              TextButton(
                onPressed: _handleGuest,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Text(
                  'Continue as Guest',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
