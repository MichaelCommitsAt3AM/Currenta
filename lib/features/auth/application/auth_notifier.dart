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
    this.needsOtp = false,
    this.pendingEmail,
    this.preferredCountry,
    this.selectedInterests = const [],
    this.displayName,
    this.avatarUrl,
  });

  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final bool isAnonymous;
  final bool needsOtp;
  final String? pendingEmail;
  final String? preferredCountry;
  final List<String> selectedInterests;
  final String? displayName;
  final String? avatarUrl;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool? isAnonymous,
    bool? needsOtp,
    String? pendingEmail,
    String? Function()? preferredCountry,
    List<String>? selectedInterests,
    String? Function()? displayName,
    String? Function()? avatarUrl,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      needsOtp: needsOtp ?? this.needsOtp,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      preferredCountry: preferredCountry != null ? preferredCountry() : this.preferredCountry,
      selectedInterests: selectedInterests ?? this.selectedInterests,
      displayName: displayName != null ? displayName() : this.displayName,
      avatarUrl: avatarUrl != null ? avatarUrl() : this.avatarUrl,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState()) {
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
    try {
      await _repository.signInWithEmail(email: email, password: password);
      // Success will be caught by authStateChanges listener
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
    try {
      await _repository.signInWithGoogle();
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
}

// ── Provider ─────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    repository: ref.watch(authRepositoryProvider),
  );
});
