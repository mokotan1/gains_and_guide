import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/models/muscle_group.dart';

void main() {
  group('MuscleGroup.matches', () {
    test('chest -> MuscleGroup.chest', () {
      expect(MuscleGroup.chest.matches('chest'), isTrue);
    });

    test('lats -> MuscleGroup.back', () {
      expect(MuscleGroup.back.matches('lats'), isTrue);
    });

    test('middle back -> MuscleGroup.back', () {
      expect(MuscleGroup.back.matches('middle back'), isTrue);
    });

    test('quadriceps -> MuscleGroup.legs', () {
      expect(MuscleGroup.legs.matches('quadriceps'), isTrue);
    });

    test('hamstrings, glutes 복합 -> MuscleGroup.legs', () {
      expect(MuscleGroup.legs.matches('hamstrings, glutes'), isTrue);
    });

    test('abs -> MuscleGroup.core', () {
      expect(MuscleGroup.core.matches('abs'), isTrue);
    });

    test('biceps -> MuscleGroup.arms', () {
      expect(MuscleGroup.arms.matches('biceps'), isTrue);
    });

    test('shoulders -> MuscleGroup.shoulders', () {
      expect(MuscleGroup.shoulders.matches('shoulders'), isTrue);
    });

    test('all은 항상 true', () {
      expect(MuscleGroup.all.matches('anything'), isTrue);
    });

    test('cardio는 항상 false (별도 테이블 사용)', () {
      expect(MuscleGroup.cardio.matches('anything'), isFalse);
    });

    test('관련 없는 근육군은 false', () {
      expect(MuscleGroup.chest.matches('quadriceps'), isFalse);
    });
  });

  group('MuscleGroup.fromPrimaryMuscles', () {
    test('chest -> MuscleGroup.chest', () {
      expect(MuscleGroup.fromPrimaryMuscles('chest'), MuscleGroup.chest);
    });

    test('알 수 없는 근육은 null', () {
      expect(MuscleGroup.fromPrimaryMuscles('unknown_muscle'), isNull);
    });

    test('복합 근육은 첫 번째 매칭 그룹을 반환한다', () {
      final result = MuscleGroup.fromPrimaryMuscles('chest, shoulders');
      expect(result, MuscleGroup.chest);
    });
  });
}
