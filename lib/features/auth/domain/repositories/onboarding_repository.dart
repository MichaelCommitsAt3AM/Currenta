// lib/features/auth/domain/repositories/onboarding_repository.dart

abstract class OnboardingRepository {
  /// Returns true if the user has completed the onboarding flow.
  Future<bool> hasCompletedOnboarding();

  /// Marks the onboarding flow as completed.
  Future<void> completeOnboarding();
}
