import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/models/muscle_group.dart';
import 'package:gains_and_guide/features/exercise_search/domain/exercise_search_state.dart';

void main() {
  group('ExerciseSearchState', () {
    test('기본 상태의 isCardioTab은 false', () {
      const state = ExerciseSearchState();
      expect(state.isCardioTab, isFalse);
    });

    test('cardio 탭 선택 시 isCardioTab은 true', () {
      const state =
          ExerciseSearchState(selectedMuscleGroup: MuscleGroup.cardio);
      expect(state.isCardioTab, isTrue);
    });

    test('copyWith가 변경된 필드만 업데이트한다', () {
      const original = ExerciseSearchState(query: 'bench');
      final updated = original.copyWith(
        selectedMuscleGroup: MuscleGroup.chest,
      );
      expect(updated.query, 'bench');
      expect(updated.selectedMuscleGroup, MuscleGroup.chest);
    });

    test('copyWith에서 selectedEquipment를 null로 초기화할 수 있다', () {
      const original = ExerciseSearchState(selectedEquipment: 'barbell');
      final updated = original.copyWith(
        selectedEquipment: () => null,
      );
      expect(updated.selectedEquipment, isNull);
    });
  });

  group('EquipmentFilter', () {
    test('labels에 주요 장비가 모두 포함되어 있다', () {
      expect(EquipmentFilter.labels.containsKey('barbell'), isTrue);
      expect(EquipmentFilter.labels.containsKey('dumbbell'), isTrue);
      expect(EquipmentFilter.labels.containsKey('machine'), isTrue);
      expect(EquipmentFilter.labels.containsKey('cable'), isTrue);
      expect(EquipmentFilter.labels.containsKey('none'), isTrue);
    });

    test('labels 값이 한글이다', () {
      expect(EquipmentFilter.labels['barbell'], '바벨');
      expect(EquipmentFilter.labels['none'], '맨몸');
    });
  });
}
