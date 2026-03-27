import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/models/user_profile.dart';
import 'package:gains_and_guide/core/domain/repositories/user_profile_repository.dart';
import 'package:gains_and_guide/features/onboarding/application/onboarding_service.dart';

class _FakeUserProfileRepository implements UserProfileRepository {
  UserProfile? _stored;

  @override
  Future<UserProfile?> getProfile() async => _stored;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _stored = profile;
  }

  @override
  Future<bool> isOnboardingCompleted() async => _stored != null;
}

void main() {
  late _FakeUserProfileRepository fakeRepo;
  late OnboardingService service;

  setUp(() {
    fakeRepo = _FakeUserProfileRepository();
    service = OnboardingService(fakeRepo);
  });

  group('OnboardingService', () {
    final validProfile = UserProfile(
      goal: TrainingGoal.strength,
      level: TrainingLevel.beginner,
      frequency: WeeklyFrequency.low,
      equipment: {EquipmentType.freeWeight},
      createdAt: DateTime(2026, 3, 27),
    );

    test('초기 상태는 온보딩 미완료', () async {
      expect(await service.isOnboardingCompleted(), isFalse);
    });

    test('completeOnboarding 후 isOnboardingCompleted == true', () async {
      await service.completeOnboarding(validProfile);

      expect(await service.isOnboardingCompleted(), isTrue);
    });

    test('completeOnboarding 후 getUserProfile로 조회 가능', () async {
      await service.completeOnboarding(validProfile);

      final fetched = await service.getUserProfile();
      expect(fetched, isNotNull);
      expect(fetched!.goal, TrainingGoal.strength);
      expect(fetched.level, TrainingLevel.beginner);
    });

    test('equipment가 비어있는 프로필은 ArgumentError', () {
      final invalid = UserProfile(
        goal: TrainingGoal.strength,
        level: TrainingLevel.beginner,
        frequency: WeeklyFrequency.low,
        equipment: const {},
        createdAt: DateTime(2026, 3, 27),
      );

      expect(
        () => service.completeOnboarding(invalid),
        throwsArgumentError,
      );
    });
  });
}
