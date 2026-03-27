import '../../../core/domain/models/user_profile.dart';
import '../../../core/domain/repositories/user_profile_repository.dart';

class OnboardingService {
  final UserProfileRepository _repository;

  OnboardingService(this._repository);

  Future<bool> isOnboardingCompleted() => _repository.isOnboardingCompleted();

  Future<UserProfile?> getUserProfile() => _repository.getProfile();

  Future<void> completeOnboarding(UserProfile profile) async {
    _validate(profile);
    await _repository.saveProfile(profile);
  }

  void _validate(UserProfile profile) {
    if (profile.equipment.isEmpty) {
      throw ArgumentError('최소 1개 이상의 장비 환경을 선택해야 합니다.');
    }
  }
}
