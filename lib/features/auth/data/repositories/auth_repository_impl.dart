import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required SupabaseClient supabaseClient,
    required Dio dio,
  })  : _supabase = supabaseClient,
        _dio = dio;

  final SupabaseClient _supabase;
  final Dio _dio;

  // Session-level cache for country detection
  String? _cachedCountry;

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
  String? get displayName {
    final user = _supabase.auth.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.userMetadata?['full_name'] as String?;
    }
    return null;
  }

  @override
  String? get avatarUrl {
    final user = _supabase.auth.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.userMetadata?['avatar_url'] as String?;
    }
    return null;
  }

  @override
  bool get isAnonymous => _supabase.auth.currentUser?.isAnonymous ?? false;

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
      final oldUid = currentSession?.user.id;
      final isAnonymous = currentSession?.user.isAnonymous ?? false;

      if (isAnonymous) {
        debugPrint('[Auth] Clearing existing anonymous session...');
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      // 5. Sign in to Supabase
      debugPrint('[Auth] Calling Supabase signInWithIdToken...');
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      
      final newUid = response.user?.id;
      
      // 6. Migrate Data if transitioning from Anonymous
      if (isAnonymous && oldUid != null && newUid != null && oldUid != newUid) {
        debugPrint('[Auth] Upgrading account: Migrating data from $oldUid to $newUid');
        try {
          await _supabase.rpc('migrate_user_data', params: {
            'old_uid': oldUid,
            'new_uid': newUid,
          });
        } catch (e) {
          debugPrint('[Auth] Warning: Data migration failed: $e');
          // We don't throw here because they are successfully signed in,
          // but logging is important for debugging.
        }
      }
      
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
  Future<void> signInAnonymously() async {
    try {
      await _supabase.auth.signInAnonymously();
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e.toString().contains('No host specified')) {
        throw const ServerException(
          'Supabase configuration is missing or invalid. Please check your AppConfig and environment variables.'
        );
      }
      throw ServerException('An unexpected error occurred during guest sign-in: $e');
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

      // Clear the country cache on sign out
      _cachedCountry = null;

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
  @override
  Future<void> saveUserInterests(List<String> categories) async {
    var user = _supabase.auth.currentUser;
    
    // If no user exists (even anonymous), create one now so we can save preferences
    if (user == null) {
      debugPrint('[Auth] No user found for saveUserInterests. Signing in anonymously...');
      await _supabase.auth.signInAnonymously();
      user = _supabase.auth.currentUser;
    }

    final uid = user?.id;
    if (uid == null) {
      throw const ServerException('Unable to establish a session to save interests.');
    }

    try {
      // Deduplicate categories to prevent Postgrest error 21000 on upsert
      final uniqueCategories = categories.toSet().toList();
      
      final dataToInsert = uniqueCategories.map((cat) => {
        'user_id': uid,
        'category': cat,
      }).toList();

      // We use upsert to cleanly handle re-selections or updates
      await _supabase
          .from('user_interests')
          .upsert(dataToInsert, onConflict: 'user_id, category');
    } catch (e) {
      throw ServerException('Failed to save interests: $e');
    }
  }

  @override
  Future<List<String>> getUserInterests() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      final response = await _supabase
          .from('user_interests')
          .select('category')
          .eq('user_id', uid);
      
      return (response as List<dynamic>)
          .map((item) => item['category'] as String)
          .toList();
    } catch (e) {
      debugPrint('[Auth] Error fetching user interests: $e');
      return [];
    }
  }

  @override
  Future<void> clearUserInterests() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _supabase
          .from('user_interests')
          .delete()
          .eq('user_id', uid);
    } catch (e) {
      throw ServerException('Failed to clear interests: $e');
    }
  }

  @override
  Future<void> saveUserSubInterests(List<String> subCategories) async {
    var user = _supabase.auth.currentUser;
    
    if (user == null) {
      debugPrint('[Auth] No user found for saveUserSubInterests. Signing in anonymously...');
      await _supabase.auth.signInAnonymously();
      user = _supabase.auth.currentUser;
    }

    final uid = user?.id;
    if (uid == null) {
      throw const ServerException('Unable to establish a session to save sub-interests.');
    }

    try {
      if (subCategories.isEmpty) return;
      
      // Deduplicate sub-categories to prevent Postgrest error 21000 on upsert
      final uniqueSubCategories = subCategories.toSet().toList();

      final dataToInsert = uniqueSubCategories.map((sub) => {
        'user_id': uid,
        'sub_category': sub,
      }).toList();

      await _supabase
          .from('user_sub_interests')
          .upsert(dataToInsert, onConflict: 'user_id, sub_category');
    } catch (e) {
      // If table doesn't exist yet, we might want to fail silently or log it
      debugPrint('[Auth] Error saving sub-interests: $e');
    }
  }

  @override
  Future<List<String>> getUserSubInterests() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      final response = await _supabase
          .from('user_sub_interests')
          .select('sub_category')
          .eq('user_id', uid);
      
      return (response as List<dynamic>)
          .map((item) => item['sub_category'] as String)
          .toList();
    } catch (e) {
      debugPrint('[Auth] Error fetching user sub-interests: $e');
      return [];
    }
  }

  @override
  Future<void> clearUserSubInterests() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _supabase
          .from('user_sub_interests')
          .delete()
          .eq('user_id', uid);
    } catch (e) {
      debugPrint('[Auth] Error clearing sub-interests: $e');
    }
  }

  @override
  Future<void> savePreferredCountry(String countryCode) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      throw const ServerException('Must be authenticated to save country preference');
    }

    try {
      await _supabase.from('user_profiles').upsert({
        'user_id': uid,
        'preferred_country': countryCode,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      // Update cache
      _cachedCountry = countryCode;
    } catch (e) {
      debugPrint('[Auth] Error saving preferred country: $e');
      throw ServerException('Failed to save country preference: $e');
    }
  }

  @override
  Future<String?> getPreferredCountry() async {
    // Use session-level cache if available
    if (_cachedCountry != null) return _cachedCountry;

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('user_profiles')
          .select('preferred_country')
          .eq('user_id', uid)
          .maybeSingle();
      
      _cachedCountry = response?['preferred_country'] as String?;
      return _cachedCountry;
    } catch (e) {
      debugPrint('[Auth] Error fetching preferred country: $e');
      return null;
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> verifyOtp({
    required String email,
    required String token,
    required String type,
  }) async {
    try {
      final OtpType otpType;
      switch (type) {
        case 'signup':
          otpType = OtpType.signup;
          break;
        case 'recovery':
          otpType = OtpType.recovery;
          break;
        case 'email':
          otpType = OtpType.email;
          break;
        default:
          throw const ServerException('Invalid OTP type');
      }

      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: otpType,
      );
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException('An unexpected error occurred: $e');
    }
  }

  @override
  Future<String?> detectAndSaveCountry() async {
    try {
      final session = _supabase.auth.currentSession;
      final url = '${AppConfig.apiBaseUrl}/api/feed/detect-location';
      
      final options = Options(
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      final response = await _dio.get(url, options: options);
      final country = response.data['country'] as String?;
      
      if (country != null) {
        _cachedCountry = country;
      }

      debugPrint('[Auth] Background location detection result: $country');
      return country;
    } catch (e) {
      debugPrint('[Auth] detectAndSaveCountry failed: $e');
      return null;
    }
  }
}
