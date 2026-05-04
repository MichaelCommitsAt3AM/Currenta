import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/widgets/feed_onboarding_overlay.dart';
import '../data/repositories/local_persistence_repository.dart';
import '../../../../core/providers/providers.dart';

class OnboardingNotifier extends StateNotifier<OnboardingStep> {
  final LocalPersistenceRepository _prefs;

  OnboardingNotifier(this._prefs) : super(OnboardingStep.none);

  void setStep(OnboardingStep step) {
    state = step;
  }

  void dismiss() {
    final currentStep = state;
    state = OnboardingStep.none;

    // Optional: Mark specific onboarding as seen if needed
    // For now, we use the existing persistence flags
  }

  bool get hasSeenFeedOnboarding => _prefs.hasSeenFeedOnboarding();
  bool get hasSeenExploreTopics => _prefs.hasSeenExploreTopicsOnboarding();

  Future<void> markFeedOnboardingSeen() async {
    await _prefs.setHasSeenFeedOnboarding(true);
  }

  Future<void> markExploreTopicsSeen() async {
    await _prefs.setHasSeenExploreTopicsOnboarding(true);
  }

  bool get hasSeenFavoritesOnboarding => _prefs.hasSeenFavoritesOnboarding();

  Future<void> markFavoritesOnboardingSeen() async {
    await _prefs.setHasSeenFavoritesOnboarding(true);
  }
}

final onboardingNotifierProvider = StateNotifierProvider<OnboardingNotifier, OnboardingStep>((ref) {
  final prefs = ref.watch(localPersistenceRepositoryProvider);
  return OnboardingNotifier(prefs);
});
