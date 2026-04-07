// lib/features/auth/domain/repositories/auth_repository.dart

abstract class AuthRepository {
  /// Stream of authentication state changes.
  Stream<bool> get authStateChanges;

  /// Returns the current user's ID, or null if not signed in.
  String? get currentUserId;

  /// Returns the current user's display name, or null if not signed in or not found.
  String? get displayName;

  /// Returns the current user's avatar URL, or null if not signed in or not found.
  String? get avatarUrl;

  /// Returns true if the current user is anonymous (guest).
  bool get isAnonymous;

  /// Returns the current anonymous guest's ID, or null if not signed in or not guest.
  String? getGuestId();

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

  /// Signs in anonymously to track guest preferences.
  Future<void> signInAnonymously();

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

  /// Saves the user's preferred country for local news.
  Future<void> savePreferredCountry(String countryCode);

  /// Fetches the user's preferred country.
  Future<String?> getPreferredCountry();

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email);

  /// Triggers background location detection on the backend and saves to profile.
  Future<String?> detectAndSaveCountry();

  /// Checks for a conflict between guest data and account data.
  /// Returns a map with 'guest' and 'account' personalization data.
  Future<Map<String, dynamic>?> checkPersonalizationConflict(String guestUid);

  /// Performs a selective migration based on user choice.
  Future<void> selectiveMigrateUserData({
    required String guestUid,
    required bool useGuestSettings,
  });

  /// Returns true if the user should be prompted to update their location.
  bool shouldAskLocationUpdate();

  /// Sets whether the user should be prompted to update their location.
  Future<void> setShouldAskLocationUpdate(bool shouldAsk);
}
