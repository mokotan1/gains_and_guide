import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/models/user_profile.dart';
import 'package:gains_and_guide/features/onboarding/application/onboarding_notifier.dart';

void main() {
  late OnboardingNotifier notifier;

  setUp(() {
    notifier = OnboardingNotifier();
  });

  group('OnboardingNotifier', () {
    test('초기 상태는 페이지 0, 모든 선택 null', () {
      expect(notifier.state.currentPage, 0);
      expect(notifier.state.goal, isNull);
      expect(notifier.state.level, isNull);
      expect(notifier.state.frequency, isNull);
      expect(notifier.state.equipment, isEmpty);
    });

    group('선택 동작', () {
      test('setGoal로 목표 설정', () {
        notifier.setGoal(TrainingGoal.fatLoss);
        expect(notifier.state.goal, TrainingGoal.fatLoss);
      });

      test('setLevel로 수준 설정', () {
        notifier.setLevel(TrainingLevel.advanced);
        expect(notifier.state.level, TrainingLevel.advanced);
      });

      test('setFrequency로 빈도 설정', () {
        notifier.setFrequency(WeeklyFrequency.high);
        expect(notifier.state.frequency, WeeklyFrequency.high);
      });

      test('toggleEquipment로 장비 추가/제거', () {
        notifier.toggleEquipment(EquipmentType.freeWeight);
        expect(notifier.state.equipment, contains(EquipmentType.freeWeight));

        notifier.toggleEquipment(EquipmentType.machine);
        expect(notifier.state.equipment.length, 2);

        notifier.toggleEquipment(EquipmentType.freeWeight);
        expect(
          notifier.state.equipment,
          isNot(contains(EquipmentType.freeWeight)),
        );
        expect(notifier.state.equipment.length, 1);
      });
    });

    group('페이지 네비게이션', () {
      test('nextPage는 마지막 페이지 초과 불가', () {
        notifier.goToPage(3);
        notifier.nextPage();
        expect(notifier.state.currentPage, 3);
      });

      test('previousPage는 0 미만 불가', () {
        notifier.previousPage();
        expect(notifier.state.currentPage, 0);
      });

      test('nextPage/previousPage 정상 동작', () {
        notifier.nextPage();
        expect(notifier.state.currentPage, 1);

        notifier.nextPage();
        expect(notifier.state.currentPage, 2);

        notifier.previousPage();
        expect(notifier.state.currentPage, 1);
      });

      test('goToPage 범위 밖 값은 무시', () {
        notifier.goToPage(-1);
        expect(notifier.state.currentPage, 0);

        notifier.goToPage(99);
        expect(notifier.state.currentPage, 0);
      });
    });

    group('buildProfile', () {
      test('모든 선택 완료 시 UserProfile 생성', () {
        notifier.setGoal(TrainingGoal.hypertrophy);
        notifier.setLevel(TrainingLevel.intermediate);
        notifier.setFrequency(WeeklyFrequency.moderate);
        notifier.toggleEquipment(EquipmentType.freeWeight);

        final profile = notifier.buildProfile();

        expect(profile.goal, TrainingGoal.hypertrophy);
        expect(profile.level, TrainingLevel.intermediate);
        expect(profile.frequency, WeeklyFrequency.moderate);
        expect(profile.equipment, {EquipmentType.freeWeight});
        expect(profile.createdAt, isNotNull);
      });

      test('미완료 상태에서 buildProfile 호출 시 StateError', () {
        notifier.setGoal(TrainingGoal.strength);

        expect(() => notifier.buildProfile(), throwsStateError);
      });

      test('equipment만 비어있어도 StateError', () {
        notifier.setGoal(TrainingGoal.strength);
        notifier.setLevel(TrainingLevel.beginner);
        notifier.setFrequency(WeeklyFrequency.low);

        expect(() => notifier.buildProfile(), throwsStateError);
      });
    });
  });
}
