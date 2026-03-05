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

  @override
  Future<void> signInWithGoogle() async {
    try {
      // 1. Access Google Sign-In singleton
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      // 2. Initialize with your Web Client ID
      await googleSignIn.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );

      // 3. Trigger the native Google Account Picker
      // Note: In 7.x, authenticate() returns a Future<GoogleSignInAccount>
      // and throws an exception on failure/cancellation.
      final googleUser = await googleSignIn.authenticate();

      // 4. Obtain the ID token (synchronous property in 7.x)
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw const ServerException('No ID Token found.');
      }

      // 5. Send the ID token to Supabase to sign in
      // For Google, providing the idToken is sufficient for OIDC authentication.
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } on GoogleSignInException catch (e) {
      // Handle user cancellation gracefully
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('[Auth] Google Sign-In cancelled by user');
        return;
      }
      throw ServerException('Google Sign-In failed: ${e.toString()}');
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException('An unexpected error occurred: $e');
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
