// lib/features/auth/presentation/screens/otp_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_notifier.dart';
import 'reset_password_screen.dart';
import '../../../../core/utils/snackbar_utils.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String type; // 'signup' or 'recovery'

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.type,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _canResend = true;

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = seconds;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          _timer?.cancel();
        }
      });
    });
  }

  void _onVerifyPressed() {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      ref.read(authNotifierProvider.notifier).verifyOtp(
            widget.email,
            otp,
            widget.type,
          );
    }
  }

  void _handleResend() async {
    if (!_canResend) return;

    setState(() => _canResend = false);
    
    try {
      await ref.read(authNotifierProvider.notifier).resendOtp(
        widget.email,
        widget.type,
      );
      
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Verification code resent successfully!');
        _startTimer(60);
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('429') || errorStr.contains('too many requests')) {
        // Disable for 15 minutes
        _startTimer(900);
      } else if (errorStr.contains('network') || errorStr.contains('socket')) {
        // Disable for 5 seconds
        _startTimer(5);
      } else {
        setState(() => _canResend = true);
      }
    }
  }

  void _handlePaste(String value, int index) {
    if (value.length > 1) {
      // Handle paste
      final pasteData = value.trim();
      for (var i = 0; i < pasteData.length && (index + i) < 6; i++) {
        _controllers[index + i].text = pasteData[i];
      }
      // Move focus to the next empty field or the last one
      final nextIndex = (index + pasteData.length).clamp(0, 5);
      _focusNodes[nextIndex].requestFocus();
      
      // If we filled all 6, auto-verify
      if (_controllers.every((c) => c.text.isNotEmpty)) {
        _onVerifyPressed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        // Detect specific errors for timer logic if they come through the state
        final errorStr = next.error!.toLowerCase();
        if (errorStr.contains('429') || errorStr.contains('too many requests')) {
          _startTimer(900);
        } else if (errorStr.contains('network') || errorStr.contains('socket')) {
          _startTimer(5);
        }
        AppSnackbar.showError(context, next.error!);
      }
      if (next.isAuthenticated && !next.needsOtp) {
        if (widget.type == 'recovery') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          );
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.type == 'recovery'
                    ? 'If an account with this email exists, you’ll receive a password reset link.'
                    : 'Enter the 6-digit code sent to\n${widget.email}',
                style: const TextStyle(
                  color: Color(0xFF8890B5),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 55,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      onChanged: (value) {
                        if (value.length > 1) {
                          _handlePaste(value, index);
                          return;
                        }
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (index == 5 && value.isNotEmpty) {
                          _onVerifyPressed();
                        }
                      },
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
                        ),
                      ),
                      textCapitalization: TextCapitalization.none,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: authState.isLoading ? null : _onVerifyPressed,
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Verify Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),

              const SizedBox(height: 32),

              Center(
                child: TextButton(
                  onPressed: (authState.isLoading || !_canResend) 
                    ? null 
                    : _handleResend,
                  child: Text(
                    _canResend 
                      ? 'Resend Code' 
                      : 'Resend in ${_secondsRemaining}s',
                    style: TextStyle(
                      color: _canResend ? const Color(0xFF6C63FF) : const Color(0xFF8890B5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
