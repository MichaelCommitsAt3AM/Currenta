// lib/features/auth/data/repositories/auth_repository_impl.dart

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  @override
  Stream<bool> get authStateChanges => _supabase.auth.onAuthStateChange.map(
        (event) =>
            event.session != null && event.session?.user.isAnonymous == false,
      );

  @override
  String? get currentUserId {
    final user = _supabase.auth.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.id;
    }
    return null;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException('An unexpected error occurred: $e');
    }
  }

  bool _isGoogleSignInInitialized = false;

  @override
  Future<void> signInWithGoogle() async {
    try {
      debugPrint('[Auth] --- Native Google Sign-In Start ---');
      
      final googleSignIn = GoogleSignIn.instance;

      // 1. Initialize once
      if (!_isGoogleSignInInitialized) {
        debugPrint('[Auth] Initializing GoogleSignIn (once) with Web Client ID: ${AppConfig.googleWebClientId}');
        await googleSignIn.initialize(
          serverClientId: AppConfig.googleWebClientId,
        );
        _isGoogleSignInInitialized = true;
      }

      // 2. Trigger native picker
      debugPrint('[Auth] Calling googleSignIn.authenticate()...');
      // If it hangs here, it's a platform/signature issue.
      final googleUser = await googleSignIn.authenticate();
      debugPrint('[Auth] Account selected: ${googleUser.email}');

      // 3. Get tokens
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      
      debugPrint('[Auth] ID Token obtained: ${idToken != null ? "YES" : "NO"}');

      if (idToken == null) {
        debugPrint('[Auth] Error: No ID Token found for user ${googleUser.email}');
        throw const ServerException('No ID Token found. Please try again.');
      }

      // 4. PREVENT CONFLICT: Sign out of any local anonymous session before upgrading
      // to the Google session. This is safer for some Supabase edge cases.
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null && currentSession.user.isAnonymous) {
        debugPrint('[Auth] Clearing existing anonymous session...');
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      // 5. Sign in to Supabase
      debugPrint('[Auth] Calling Supabase signInWithIdToken...');
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      
      debugPrint('[Auth] Supabase response received. User: ${response.user?.email}');
      debugPrint('[Auth] --- Native Google Sign-In Success ---');
    } on GoogleSignInException catch (e) {
      debugPrint('[Auth] GoogleSignInException: ${e.code}, $e');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('[Auth] User cancelled the picker.');
        return; 
      }
      throw ServerException('Google Sign-In failed (${e.code}): ${e.toString()}');
    } on AuthException catch (e) {
      debugPrint('[Auth] Supabase AuthException: ${e.message} (Code: ${e.statusCode})');
      throw ServerException(e.message);
    } catch (e, stack) {
      debugPrint('[Auth] Unexpected error: $e');
      debugPrint('[Auth] Stack trace: $stack');
      throw ServerException('An unexpected error occurred during sign-in.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Sign out from both Supabase and Google to allow switching accounts next time
      final googleSignIn = GoogleSignIn.instance;
      await Future.wait([
        _supabase.auth.signOut(),
        googleSignIn.signOut(),
      ]);

      // Since we rely on anonymous sessions for tracking, immediately create a new one
      if (_supabase.auth.currentSession == null) {
        await _supabase.auth.signInAnonymously();
      }
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException('An unexpected error occurred: $e');
    }
  }
}
