// lib/features/auth/domain/repositories/auth_repository.dart

abstract class AuthRepository {
  /// Stream of authentication state changes.
  Stream<bool> get authStateChanges;

  /// Returns the current user's ID, or null if not signed in.
  String? get currentUserId;

  /// Signs in with an email and password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Signs up a new user with an email and password.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  });

  /// Initiates the Google OAuth sign-in flow.
  Future<void> signInWithGoogle();

  /// Signs the user out.
  Future<void> signOut();

  /// Saves the user's selected interests to the database.
  Future<void> saveUserInterests(List<String> categories);
}
