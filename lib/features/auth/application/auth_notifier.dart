import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/providers.dart';
import '../domain/repositories/auth_repository.dart';
import '../../news/domain/repositories/news_repository.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.isAnonymous = false,
    this.isProfileLoaded = false,
    this.needsOtp = false,
    this.pendingEmail,
    this.preferredCountry,
    this.selectedInterests = const [],
    this.displayName,
    this.avatarUrl,
    this.needsConflictResolution = false,
    this.conflictData,
    this.previousGuestUid,
    this.detectedCountry,
    this.showLocationUpdatePopup = false,
    this.hasCheckedLocation = false,
    this.email,
  });

  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final bool isAnonymous;
  final bool isProfileLoaded;
  final bool needsOtp;
  final String? pendingEmail;
  final String? preferredCountry;
  final List<String> selectedInterests;
  final String? displayName;
  final String? avatarUrl;
  final bool needsConflictResolution;
  final Map<String, dynamic>? conflictData;
  final String? previousGuestUid;
  final String? detectedCountry;
  final bool showLocationUpdatePopup;
  final bool hasCheckedLocation;
  final String? email;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool? isAnonymous,
    bool? isProfileLoaded,
    bool? needsOtp,
    String? pendingEmail,
    String? Function()? preferredCountry,
    List<String>? selectedInterests,
    String? Function()? displayName,
    String? Function()? avatarUrl,
    bool? needsConflictResolution,
    Map<String, dynamic>? conflictData,
    String? previousGuestUid,
    String? Function()? detectedCountry,
    bool? showLocationUpdatePopup,
    bool? hasCheckedLocation,
    String? Function()? email,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isProfileLoaded: isProfileLoaded ?? this.isProfileLoaded,
      needsOtp: needsOtp ?? this.needsOtp,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      preferredCountry: preferredCountry != null ? preferredCountry() : this.preferredCountry,
      selectedInterests: selectedInterests ?? this.selectedInterests,
      displayName: displayName != null ? displayName() : this.displayName,
      avatarUrl: avatarUrl != null ? avatarUrl() : this.avatarUrl,
      needsConflictResolution: needsConflictResolution ?? this.needsConflictResolution,
      conflictData: conflictData ?? this.conflictData,
      previousGuestUid: previousGuestUid ?? this.previousGuestUid,
      detectedCountry: detectedCountry != null ? detectedCountry() : this.detectedCountry,
      showLocationUpdatePopup: showLocationUpdatePopup ?? this.showLocationUpdatePopup,
      hasCheckedLocation: hasCheckedLocation ?? this.hasCheckedLocation,
      email: email != null ? email() : this.email,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.isAuthenticated == isAuthenticated &&
        other.isAnonymous == isAnonymous &&
        other.isProfileLoaded == isProfileLoaded &&
        other.needsOtp == needsOtp &&
        other.pendingEmail == pendingEmail &&
        other.preferredCountry == preferredCountry &&
        listEquals(other.selectedInterests, selectedInterests) &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.needsConflictResolution == needsConflictResolution &&
        other.conflictData == conflictData &&
        other.previousGuestUid == previousGuestUid &&
        other.detectedCountry == detectedCountry &&
        other.showLocationUpdatePopup == showLocationUpdatePopup &&
        other.hasCheckedLocation == hasCheckedLocation &&
        other.email == email;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      isLoading,
      error,
      isAuthenticated,
      isAnonymous,
      isProfileLoaded,
      needsOtp,
      pendingEmail,
      preferredCountry,
      Object.hashAll(selectedInterests),
      displayName,
      avatarUrl,
      needsConflictResolution,
      conflictData,
      previousGuestUid,
      detectedCountry,
      showLocationUpdatePopup,
      hasCheckedLocation,
      email,
    ]);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required AuthRepository repository,
    required NewsRepository newsRepository,
  })  : _repository = repository,
        _newsRepository = newsRepository,
        super(AuthState(
          isAuthenticated: repository.currentUserId != null,
          isAnonymous: repository.isAnonymous,
          displayName: repository.displayName,
          avatarUrl: repository.avatarUrl,
          email: repository.email,
        )) {
    // Listen to Supabase auth state changes
    _authSubscription = _repository.authStateChanges.listen((isAuthenticated) async {
      String? country;
      String? name;
      String? avatar;
      String? email;
      List<String> interests = [];
      if (isAuthenticated || _repository.isAnonymous) {
        country = await _repository.getPreferredCountry();
        interests = await _repository.getUserInterests();
        name = _repository.displayName;
        avatar = _repository.avatarUrl;
        email = _repository.email;
      }
      debugPrint('[Auth] Profile loaded: country=$country, interestsCount=${interests.length}');
      state = state.copyWith(
        isAuthenticated: isAuthenticated,
        isAnonymous: _repository.isAnonymous,
        isProfileLoaded: true,
        preferredCountry: () => country,
        selectedInterests: interests,
        displayName: () => name,
        avatarUrl: () => avatar,
        email: () => email,
      );

      // ── Strategic Location Re-check ──
      // 1. Fresh Install Exception: If country is null, we check regardless of interests.
      // 2. Regular Check: If interests contain 'local', we check.
      final isFreshInstall = country == null;
      final wantsLocal = interests.contains('local');

      if ((isFreshInstall || wantsLocal) && !state.hasCheckedLocation && !_isDetectingLocation) {
        detectLocation(force: isFreshInstall);
      }
    });
  }

  final AuthRepository _repository;
  final NewsRepository _newsRepository;
  late final StreamSubscription<bool> _authSubscription;

  bool _isDetectingLocation = false;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  /// Exposes the current user ID if logged in
  String? get currentUserId => _repository.currentUserId;

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final oldGuestUid = _repository.isAnonymous ? _repository.getGuestId() : null;
    try {
      await _repository.signInWithEmail(email: email, password: password);
      await _handleSignInResult(oldGuestUid);
      state = state.copyWith(isLoading: false);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
  }

  Future<void> signUpWithEmail(
      String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signUpWithEmail(
          email: email, password: password, name: name);
      state = state.copyWith(isLoading: false, needsOtp: true, pendingEmail: email);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    final oldGuestUid = _repository.isAnonymous ? _repository.getGuestId() : null;
    try {
      await _repository.signInWithGoogle();
      await _handleSignInResult(oldGuestUid);
      state = state.copyWith(isLoading: false);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.signOut();
      await _newsRepository.wipeLocalData();
      state = state.copyWith(isLoading: false);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Wipe remote account (if not guest)
      await _repository.deleteAccount();
      
      // 2. Wipe local database and cache
      await _newsRepository.wipeLocalData();
      
      // 3. Reset onboarding status for brand new user experience
      await _repository.clearOnboardingStatus();
      
      state = state.copyWith(isLoading: false);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Deletion failed: $e');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
  }

  Future<void> verifyOtp(String email, String token, String type) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.verifyOtp(email: email, token: token, type: type);
      state = state.copyWith(isLoading: false, needsOtp: false, pendingEmail: null);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(isLoading: false, needsOtp: true, pendingEmail: email);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
  }

  void resetOtpState() {
     state = state.copyWith(needsOtp: false, pendingEmail: null);
  }

  Future<void> refreshPreferredCountry() async {
    if (state.isAuthenticated || state.isAnonymous) {
      final country = await _repository.getPreferredCountry();
      state = state.copyWith(preferredCountry: () => country);
    }
  }

  Future<void> detectLocation({bool force = false}) async {
    if (!force && !state.selectedInterests.contains('local')) {
      debugPrint('[Auth] Skipping location check: Local category not selected and not forced.');
      return;
    }

    if (_isDetectingLocation) return;
    _isDetectingLocation = true;
    
    // Optimistically mark as checked to prevent redundant parallel calls 
    // from multiple auth events during startup.
    state = state.copyWith(hasCheckedLocation: true);
    
    debugPrint('[Auth] detectLocation started (force=$force)...');
    
    try {
      final country = await _repository.detectAndSaveCountry();
      debugPrint('[Auth] detectLocation result: $country (Current: ${state.preferredCountry})');
      
      if (country == null) return;

      final currentCountry = state.preferredCountry;
      
      if (currentCountry == null) {
        // First time detection (Onboarding/Fresh Install): Update local state silently.
        // Save to remote profile is batched at the end of onboarding.
        state = state.copyWith(
          preferredCountry: () => country,
          hasCheckedLocation: true,
        );
      } else if (currentCountry != country && _repository.shouldAskLocationUpdate()) {
        // Location Update: We've moved countries. Show prompt as requested.
        state = state.copyWith(
          detectedCountry: () => country,
          showLocationUpdatePopup: true,
          hasCheckedLocation: true,
        );
      } else {
        // Same Location or user dismissed: Do nothing per requirements.
        state = state.copyWith(hasCheckedLocation: true);
      }
    } catch (e) {
      debugPrint('[Auth] detectLocation error in Notifier: $e');
    } finally {
      _isDetectingLocation = false;
    }
  }

  Future<void> updateLocation(String countryCode) async {
    state = state.copyWith(isLoading: true, showLocationUpdatePopup: false);
    try {
      await _repository.savePreferredCountry(countryCode);
      state = state.copyWith(
        isLoading: false,
        preferredCountry: () => countryCode,
        detectedCountry: () => null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to update location: $e');
    }
  }

  Future<void> dismissLocationUpdate({required bool permanent}) async {
    if (permanent) {
      await _repository.setShouldAskLocationUpdate(false);
    }
    state = state.copyWith(
      showLocationUpdatePopup: false,
      detectedCountry: () => null,
    );
  }

  Future<void> refreshInterests() async {
    if (state.isAuthenticated || state.isAnonymous) {
      final wasLocalSelected = state.selectedInterests.contains('local');
      final interests = await _repository.getUserInterests();
      final isLocalSelectedNow = interests.contains('local');

      state = state.copyWith(selectedInterests: interests);

      // Robust Category Handoff: 
      // If 'local' was just added, trigger a location check immediately.
      if (!wasLocalSelected && isLocalSelectedNow) {
        debugPrint('[Auth] Local category added. Triggering robust handoff check...');
        detectLocation(force: true);
      }
    }
  }

  Future<void> _handleSignInResult(String? oldGuestUid) async {
    if (oldGuestUid == null) return;

    try {
      final conflict = await _repository.checkPersonalizationConflict(oldGuestUid);
      if (conflict != null) {
        final guestData = conflict['guest'] as Map<String, dynamic>;
        final accountData = conflict['account'] as Map<String, dynamic>;

        final guestInterests = List<String>.from(guestData['interests'] ?? []);
        final accountInterests = List<String>.from(accountData['interests'] ?? []);

        final guestCountry = guestData['country'] as String?;
        final accountCountry = accountData['country'] as String?;

        // 1. Check if interests are identical as sets
        final guestSet = guestInterests.toSet();
        final accountSet = accountInterests.toSet();
        final isInterestsEqual = guestSet.length == accountSet.length && guestSet.containsAll(accountSet);
        
        // 2. Check if country is equal
        final isCountryEqual = guestCountry == accountCountry;

        // We only trigger resolution if BOTH have interests AND they differ (interests or country)
        if (guestInterests.isNotEmpty && accountInterests.isNotEmpty && (!isInterestsEqual || !isCountryEqual)) {
          state = state.copyWith(
            needsConflictResolution: true,
            conflictData: conflict,
            previousGuestUid: oldGuestUid,
          );
        } else if (guestInterests.isNotEmpty) {
          // Case: Only guest has data, OR they are identical!
          // We can migrate automatically and cleanly.
          await _repository.selectiveMigrateUserData(
            guestUid: oldGuestUid,
            useGuestSettings: true,
          );
          await _newsRepository.clearRemoteUserState();
          await refreshInterests();
          await refreshPreferredCountry();
        } else {
          // No guest data or only account has data, just cleanup the guest session
          await _repository.selectiveMigrateUserData(
            guestUid: oldGuestUid,
            useGuestSettings: false,
          );
          await _newsRepository.clearRemoteUserState();
        }
      }
    } catch (e) {
      debugPrint('[Auth] Error handling sign-in result/migration: $e');
    }
  }

  Future<void> resolveConflict(bool useGuestSettings) async {
    final oldGuestUid = state.previousGuestUid;
    if (oldGuestUid == null) return;

    state = state.copyWith(isLoading: true);
    try {
      await _repository.selectiveMigrateUserData(
        guestUid: oldGuestUid,
        useGuestSettings: useGuestSettings,
      );
      await _newsRepository.clearRemoteUserState();
      state = state.copyWith(
        isLoading: false,
        needsConflictResolution: false,
        conflictData: null,
        previousGuestUid: null,
      );
      await refreshInterests();
      await refreshPreferredCountry();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to resolve conflict: $e');
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    repository: ref.watch(authRepositoryProvider),
    newsRepository: ref.watch(newsRepositoryProvider),
  );
});
