import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required SupabaseClient supabaseClient,
    required Dio dio,
    required SharedPreferences prefs,
    SecureStorageService? secureStorage,
  })  : _supabase = supabaseClient,
        _dio = dio,
        _prefs = prefs,
        _secureStorage = secureStorage ?? SecureStorageService.instance;

  final SupabaseClient _supabase;
  final Dio _dio;
  final SharedPreferences _prefs;
  final SecureStorageService _secureStorage;

  // Session-level cache for country detection
  String? _cachedCountry;

  @override
  Stream<bool> get authStateChanges => _supabase.auth.onAuthStateChange.map(
        (event) =>
            event.session != null && event.session?.user.isAnonymous == false,
      ).distinct();

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
  String? getGuestId() {
    final user = _supabase.auth.currentUser;
    if (user != null && user.isAnonymous) {
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
      final googleSignIn = GoogleSignIn.instance;

      // 1. Initialize once
      if (!_isGoogleSignInInitialized) {
        await googleSignIn.initialize(
          serverClientId: AppConfig.googleWebClientId,
        );
        _isGoogleSignInInitialized = true;
      }

      // 2. Trigger native picker
      final googleUser = await googleSignIn.authenticate();

      // 3. Get tokens
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw const ServerException('No ID Token found. Please try again.');
      }

      // 4. PREVENT CONFLICT: Sign out of any local anonymous session before upgrading
      // to the Google session. This is safer for some Supabase edge cases.
      final currentSession = _supabase.auth.currentSession;
      final isAnonymous = currentSession?.user.isAnonymous ?? false;

      if (isAnonymous) {
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      // 5. Sign in to Supabase
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      
      // 6. Migration is now handled selectively by the caller via checkPersonalizationConflict
      // and selectiveMigrateUserData. Auto-migration removed.
    } on GoogleSignInException catch (e) {
      debugPrint('[Auth] GoogleSignInException: ${e.code}, $e');
      if (e.code == GoogleSignInExceptionCode.canceled) {
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

      // Clear local persistence for sensitive fields
      await Future.wait([
        _secureStorage.delete('primary_country_code'),
        _secureStorage.delete('last_location_check_at'),
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
      // Update caches (in-memory and disk)
      _cachedCountry = countryCode;
      await _secureStorage.write('primary_country_code', countryCode);
      await _secureStorage.write('last_location_check_at', DateTime.now().millisecondsSinceEpoch.toString());
    } catch (e) {
      debugPrint('[Auth] Error saving preferred country: $e');
      throw ServerException('Failed to save country preference: $e');
    }
  }

  @override
  Future<String?> getPreferredCountry() async {
    // 1. Session-level cache (fastest)
    if (_cachedCountry != null) return _cachedCountry;

    // 2. Local persistence fallback (immediate availability on app start)
    final saved = await _secureStorage.read('primary_country_code');
    if (saved != null) {
      _cachedCountry = saved;
      return saved;
    }

    // 3. Remote source of truth
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('user_profiles')
          .select('preferred_country')
          .eq('user_id', uid)
          .maybeSingle();
      
      final remoteCountry = response?['preferred_country'] as String?;
      if (remoteCountry != null) {
        _cachedCountry = remoteCountry;
        await _secureStorage.write('primary_country_code', remoteCountry);
      }
      return remoteCountry;
    } catch (e) {
      debugPrint('[Auth] Error fetching preferred country from remote: $e');
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
    // 1. Check Cache TTL to avoid redundant network overhead
    final lastCheckStr = await _secureStorage.read('last_location_check_at');
    final lastCheck = int.tryParse(lastCheckStr ?? '0') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedHours = (now - lastCheck) / (1000 * 60 * 60);

    if (elapsedHours < AppConfig.locationCacheTtlHours) {
      debugPrint('[Auth] Skipping background location detection; cache is fresh (${elapsedHours.toStringAsFixed(1)}h elapsed).');
      return getPreferredCountry();
    }

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
        await _secureStorage.write('primary_country_code', country);
        await _secureStorage.write('last_location_check_at', DateTime.now().millisecondsSinceEpoch.toString());
      }

      debugPrint('[Auth] Background location detection result: $country');
      return country;
    } catch (e) {
      debugPrint('[Auth] detectAndSaveCountry failed: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> checkPersonalizationConflict(
      String guestUid) async {
    final accountUid = _supabase.auth.currentUser?.id;
    if (accountUid == null) return null;

    try {
      final response =
          await _supabase.rpc('check_personalization_conflict', params: {
        'guest_uid': guestUid,
        'account_uid': accountUid,
      });
      return response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[Auth] check_personalization_conflict error: $e');
      return null;
    }
  }

  @override
  Future<void> selectiveMigrateUserData({
    required String guestUid,
    required bool useGuestSettings,
  }) async {
    final accountUid = _supabase.auth.currentUser?.id;
    if (accountUid == null) return;

    try {
      await _supabase.rpc('selective_migrate_user_data', params: {
        'guest_uid': guestUid,
        'account_uid': accountUid,
        'use_guest_settings': useGuestSettings,
      });
      // Clear country cache so it's re-fetched after migration
      _cachedCountry = null;
    } catch (e) {
      throw ServerException('Failed to selective migrate user data: $e');
    }
  }

  @override
  bool shouldAskLocationUpdate() {
    return _prefs.getBool('should_ask_location_update') ?? true;
  }

  @override
  Future<void> setShouldAskLocationUpdate(bool shouldAsk) async {
    await _prefs.setBool('should_ask_location_update', shouldAsk);
  }

  @override
  Future<void> deleteAccount() async {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    
    if (user == null) return;

    // 1. If non-anonymous, call backend to delete remote account
    if (!user.isAnonymous && session != null) {
      try {
        final url = '${AppConfig.apiBaseUrl}/api/auth/account';
        final options = Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
          },
        );
        
        final response = await _dio.delete(url, options: options);
        if (response.statusCode != 200) {
          throw ServerException('Failed to delete account: ${response.data['detail'] ?? 'Unknown error'}');
        }
      } on DioException catch (e) {
        final message = e.response?.data?['detail'] ?? e.message;
        throw ServerException('Cloud deletion failed: $message');
      } catch (e) {
        throw ServerException('An unexpected error occurred during account deletion: $e');
      }
    }

    // 2. Perform local cleanup (sign out)
    await signOut();
  }

  @override
  Future<void> clearOnboardingStatus() async {
    await _prefs.setBool('has_completed_onboarding', false);
  }
}
