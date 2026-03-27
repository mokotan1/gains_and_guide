import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/models/user_profile.dart';
import 'package:gains_and_guide/features/onboarding/domain/onboarding_state.dart';

void main() {
  group('OnboardingState', () {
    test('초기 상태는 모든 선택값이 null/empty', () {
      const state = OnboardingState();

      expect(state.currentPage, 0);
      expect(state.goal, isNull);
      expect(state.level, isNull);
      expect(state.frequency, isNull);
      expect(state.equipment, isEmpty);
    });

    group('isComplete', () {
      test('모든 항목이 선택되면 true', () {
        const state = OnboardingState(
          goal: TrainingGoal.strength,
          level: TrainingLevel.beginner,
          frequency: WeeklyFrequency.low,
          equipment: {EquipmentType.freeWeight},
        );

        expect(state.isComplete, isTrue);
      });

      test('goal이 null이면 false', () {
        const state = OnboardingState(
          level: TrainingLevel.beginner,
          frequency: WeeklyFrequency.low,
          equipment: {EquipmentType.freeWeight},
        );

        expect(state.isComplete, isFalse);
      });

      test('equipment가 비어있으면 false', () {
        const state = OnboardingState(
          goal: TrainingGoal.strength,
          level: TrainingLevel.beginner,
          frequency: WeeklyFrequency.low,
        );

        expect(state.isComplete, isFalse);
      });
    });

    group('canProceed', () {
      test('페이지 0: goal이 선택되면 true', () {
        const state = OnboardingState(
          currentPage: 0,
          goal: TrainingGoal.hypertrophy,
        );

        expect(state.canProceed, isTrue);
      });

      test('페이지 0: goal이 null이면 false', () {
        const state = OnboardingState(currentPage: 0);
        expect(state.canProceed, isFalse);
      });

      test('페이지 1: level이 선택되면 true', () {
        const state = OnboardingState(
          currentPage: 1,
          level: TrainingLevel.intermediate,
        );

        expect(state.canProceed, isTrue);
      });

      test('페이지 2: frequency가 선택되면 true', () {
        const state = OnboardingState(
          currentPage: 2,
          frequency: WeeklyFrequency.high,
        );

        expect(state.canProceed, isTrue);
      });

      test('페이지 3: equipment가 1개 이상이면 true', () {
        const state = OnboardingState(
          currentPage: 3,
          equipment: {EquipmentType.machine, EquipmentType.bodyweight},
        );

        expect(state.canProceed, isTrue);
      });

      test('페이지 3: equipment가 비어있으면 false', () {
        const state = OnboardingState(currentPage: 3);
        expect(state.canProceed, isFalse);
      });

      test('범위를 벗어난 페이지는 false', () {
        const state = OnboardingState(currentPage: 99);
        expect(state.canProceed, isFalse);
      });
    });

    group('progress', () {
      test('페이지 0 → 25%', () {
        const state = OnboardingState(currentPage: 0);
        expect(state.progress, closeTo(0.25, 0.01));
      });

      test('페이지 3 → 100%', () {
        const state = OnboardingState(currentPage: 3);
        expect(state.progress, closeTo(1.0, 0.01));
      });
    });

    group('copyWith', () {
      test('currentPage만 변경', () {
        const original = OnboardingState(
          currentPage: 0,
          goal: TrainingGoal.strength,
        );
        final updated = original.copyWith(currentPage: 2);

        expect(updated.currentPage, 2);
        expect(updated.goal, TrainingGoal.strength);
      });
    });
  });
}
