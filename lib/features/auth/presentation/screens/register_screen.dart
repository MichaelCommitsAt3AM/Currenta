// lib/features/auth/presentation/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_notifier.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_login_button.dart';
import 'onboarding_screen.dart';
import 'otp_verification_screen.dart';
import '../screens/personalization_conflict_screen.dart';
import '../../../news/presentation/screens/feed_screen.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/utils/snackbar_utils.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    this.redirectToFeedOnSuccess = false,
  });

  final bool redirectToFeedOnSuccess;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKeyPage1 = GlobalKey<FormState>();
  final _formKeyPage2 = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    if (_formKeyPage1.currentState!.validate()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onRegisterPressed() {
    if (_formKeyPage2.currentState!.validate()) {
      ref.read(authNotifierProvider.notifier).signUpWithEmail(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }

  void _onGoogleLoginPressed() {
    ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      if (next.error != null) {
        AppSnackbar.showError(context, next.error!);
      }
      if (next.isAuthenticated && !next.isLoading) {
        if (next.needsConflictResolution && next.conflictData != null) {
          debugPrint('[Register] Conflict detected! Showing resolution dialog...');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PersonalizationConflictScreen(
                guestData: next.conflictData!['guest'] as Map<String, dynamic>,
                accountData: next.conflictData!['account'] as Map<String, dynamic>,
              ),
            ),
          );
          return;
        }

        if (widget.redirectToFeedOnSuccess) {
          if (next.selectedInterests.isEmpty) {
            debugPrint('[Register] New user detected (no interests)! Redirecting to Onboarding...');
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              (route) => false,
            );
          } else {
            // Mark onboarding as complete
            ref.read(onboardingRepositoryProvider).completeOnboarding();
            
            // Clear news cache
            ref.read(newsRepositoryProvider).clearCache();

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const FeedScreen()),
              (route) => false,
            );
          }
        } else {
          // Pop back to login then hopefully back to feed
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else if (next.needsOtp && next.pendingEmail != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: next.pendingEmail!,
              type: 'signup',
            ),
          ),
        );
        ref.read(authNotifierProvider.notifier).resetOtpState();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_pageController.hasClients && _pageController.page == 1) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Page 1: Email & Google
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKeyPage1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Join us to save your favorite articles.',
                      style: TextStyle(
                        color: Color(0xFF8890B5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 48),
                    AuthTextField(
                      controller: _emailController,
                      hintText: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        if (!val.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Continue with Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Divider
                    Row(
                      children: [
                        Expanded(
                            child: Divider(color: const Color(0xFF262A3E))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Color(0xFF8890B5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(color: const Color(0xFF262A3E))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SocialLoginButton(
                      text: 'Continue with Google',
                      iconAsset: 'assets/icons/google.png',
                      onPressed: _onGoogleLoginPressed,
                      isLoading: authState.isLoading,
                    ),
                    const SizedBox(height: 32),
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?',
                          style: TextStyle(
                            color: Color(0xFF8890B5),
                            fontSize: 15,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Page 2: Name, Password, Confirm Password
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKeyPage2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Almost there!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Let\'s secure your account.',
                      style: TextStyle(
                        color: Color(0xFF8890B5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 48),
                    AuthTextField(
                      controller: _nameController,
                      hintText: 'Display Name',
                      icon: Icons.person_outline,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter your display name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Enter a password';
                        }
                        if (val.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Confirm your password';
                        }
                        if (val != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed:
                          authState.isLoading ? null : _onRegisterPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
