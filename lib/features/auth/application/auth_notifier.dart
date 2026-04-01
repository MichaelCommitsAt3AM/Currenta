import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/providers.dart';
import '../domain/repositories/auth_repository.dart';

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
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({required AuthRepository repository})
      : _repository = repository,
        super(AuthState(
          isAuthenticated: repository.currentUserId != null,
          isAnonymous: repository.isAnonymous,
          displayName: repository.displayName,
          avatarUrl: repository.avatarUrl,
        )) {
    // Listen to Supabase auth state changes
    _repository.authStateChanges.listen((isAuthenticated) async {
      String? country;
      String? name;
      String? avatar;
      List<String> interests = [];
      if (isAuthenticated || _repository.isAnonymous) {
        country = await _repository.getPreferredCountry();
        interests = await _repository.getUserInterests();
        name = _repository.displayName;
        avatar = _repository.avatarUrl;
      }
      state = state.copyWith(
        isAuthenticated: isAuthenticated,
        isAnonymous: _repository.isAnonymous,
        isProfileLoaded: true,
        preferredCountry: () => country,
        selectedInterests: interests,
        displayName: () => name,
        avatarUrl: () => avatar,
      );
    });
  }

  final AuthRepository _repository;

  /// Exposes the current user ID if logged in
  String? get currentUserId => _repository.currentUserId;

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final oldGuestUid = _repository.isAnonymous ? _repository.currentUserId : null;
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
    final oldGuestUid = _repository.isAnonymous ? _repository.currentUserId : null;
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
      state = state.copyWith(isLoading: false);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
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

  Future<void> detectLocation() async {
    try {
      final country = await _repository.detectAndSaveCountry();
      if (country != null && state.preferredCountry == null) {
        state = state.copyWith(preferredCountry: () => country);
      }
    } catch (e) {
      debugPrint('[Auth] detectLocation error in Notifier: $e');
    }
  }

  Future<void> refreshInterests() async {
    if (state.isAuthenticated || state.isAnonymous) {
      final interests = await _repository.getUserInterests();
      state = state.copyWith(selectedInterests: interests);
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

        // We only trigger resolution if BOTH have interests.
        // User request: "inform the user which personalization settings they want to continue with"
        if (guestInterests.isNotEmpty && accountInterests.isNotEmpty) {
          state = state.copyWith(
            needsConflictResolution: true,
            conflictData: conflict,
            previousGuestUid: oldGuestUid,
          );
        } else if (guestInterests.isNotEmpty) {
          // Only guest has data, migrate automatically to the new account
          await _repository.selectiveMigrateUserData(
            guestUid: oldGuestUid,
            useGuestSettings: true,
          );
          await refreshInterests();
          await refreshPreferredCountry();
        } else {
          // No guest data or only account has data, just cleanup the guest session
          await _repository.selectiveMigrateUserData(
            guestUid: oldGuestUid,
            useGuestSettings: false,
          );
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
  );
});
