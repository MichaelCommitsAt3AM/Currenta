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

  /// Fetches the user's selected interests from the database.
  Future<List<String>> getUserInterests();

  /// Clears all interests for the current user.
  Future<void> clearUserInterests();

  /// Saves the user's selected sub-interests to the database.
  Future<void> saveUserSubInterests(List<String> subCategories);

  /// Fetches the user's selected sub-interests from the database.
  Future<List<String>> getUserSubInterests();

  /// Clears all sub-interests for the current user.
  Future<void> clearUserSubInterests();

  /// Updates the current user's password.
  Future<void> updatePassword(String newPassword);

  /// Verifies an OTP code for a given email and type.
  Future<void> verifyOtp({
    required String email,
    required String token,
    required String type,
  });

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email);
}
