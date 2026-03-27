import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../application/onboarding_notifier.dart';
import '../../application/onboarding_service.dart';
import '../../domain/onboarding_state.dart';

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(ref.watch(userProfileRepositoryProvider));
});

final onboardingCompletedProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingServiceProvider).isOnboardingCompleted();
});

final onboardingStateProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
