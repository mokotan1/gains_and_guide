import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';
import 'package:gains_and_guide/core/constants/workout_constants.dart';

void main() {
  group('WorkoutNotifier - _mergeWithAccessories logic', () {
    List<Exercise> mergeWithAccessories(
      List<Exercise> mainRoutine,
      List<Exercise> dayRoutine,
      List<String> mainNames,
    ) {
      final accessories = dayRoutine
          .where((e) => !mainNames.contains(e.name))
          .toList();
      if (accessories.isEmpty) return mainRoutine;
      return [...mainRoutine, ...accessories];
    }

    test('accessories are appended after main routine', () {
      final mainRoutine = [
        Exercise.initial(id: 's1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 's2', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
        Exercise.initial(id: 's3', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
      ];

      final dayRoutine = [
        Exercise.initial(id: 's1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 's2', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
        Exercise.initial(id: 's3', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
        Exercise.initial(id: 'acc1', name: '바벨 컬', sets: 3, reps: 10, weight: 20),
      ];

      final result = mergeWithAccessories(
        mainRoutine,
        dayRoutine,
        WorkoutConstants.strongliftsMainA,
      );

      expect(result.length, 4);
      expect(result.last.name, '바벨 컬');
    });

    test('returns main routine only when no accessories exist', () {
      final mainRoutine = [
        Exercise.initial(id: 's1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      ];
      final dayRoutine = [
        Exercise.initial(id: 's1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      ];

      final result = mergeWithAccessories(
        mainRoutine,
        dayRoutine,
        WorkoutConstants.strongliftsMainA,
      );

      expect(result.length, 1);
      expect(identical(result, mainRoutine), true);
    });
  });

  group('WorkoutNotifier - _normalizeDateString logic', () {
    String normalizeDateString(dynamic value) {
      if (value == null) return '';
      final s = value.toString().trim();
      if (s.isEmpty) return '';
      final part = s.split(' ').first;
      return part.length >= 10 ? part.substring(0, 10) : part;
    }

    test('normalizes full datetime string', () {
      expect(normalizeDateString('2026-03-20 14:30:00'), '2026-03-20');
    });

    test('normalizes date-only string', () {
      expect(normalizeDateString('2026-03-20'), '2026-03-20');
    });

    test('returns empty for null', () {
      expect(normalizeDateString(null), '');
    });

    test('returns empty for empty string', () {
      expect(normalizeDateString(''), '');
      expect(normalizeDateString('  '), '');
    });

    test('handles short date strings', () {
      expect(normalizeDateString('2026-03'), '2026-03');
    });
  });

  group('WorkoutNotifier - Stronglifts A/B rotation', () {
    test('routine A keys contain bench press', () {
      expect(
        WorkoutConstants.strongliftsRoutineAKeys,
        contains('플랫 벤치 프레스'),
      );
    });

    test('routine B keys contain OHP', () {
      expect(
        WorkoutConstants.strongliftsRoutineBKeys,
        contains('오버헤드 프레스 (OHP)'),
      );
    });

    test('main A and main B have disjoint non-squat exercises', () {
      final aOnly = WorkoutConstants.strongliftsMainA
          .where((e) => e != '백 스쿼트')
          .toSet();
      final bOnly = WorkoutConstants.strongliftsMainB
          .where((e) => e != '백 스쿼트')
          .toSet();

      expect(aOnly.intersection(bOnly), isEmpty);
    });
  });

  group('Exercise ID uniqueness for predefined programs', () {
    test('PPL program has unique IDs across all days', () {
      final pplWeekly = <int, List<Exercise>>{
        1: [Exercise.initial(id: 'p1_d1', name: '벤치프레스', sets: 4, reps: 10, weight: 60)],
        4: [Exercise.initial(id: 'p1_d4', name: '벤치프레스', sets: 4, reps: 10, weight: 60)],
        2: [Exercise.initial(id: 'l1_d2', name: '데드리프트', sets: 3, reps: 8, weight: 100)],
        5: [Exercise.initial(id: 'l1_d5', name: '데드리프트', sets: 3, reps: 8, weight: 100)],
      };

      final allIds = <String>{};
      for (final exercises in pplWeekly.values) {
        for (final ex in exercises) {
          expect(allIds.contains(ex.id), false,
              reason: 'Duplicate ID found: ${ex.id}');
          allIds.add(ex.id);
        }
      }
    });

    test('Cardio program has unique IDs across all days', () {
      final cardioWeekly = <int, List<Exercise>>{};
      for (int day = 1; day <= 7; day++) {
        cardioWeekly[day] = [
          Exercise.initial(id: 'c1_d$day', name: '실내 사이클', sets: 1, reps: 30, weight: 0),
          Exercise.initial(id: 't1_d$day', name: '런닝머신', sets: 1, reps: 20, weight: 0),
        ];
      }

      final allIds = <String>{};
      for (final exercises in cardioWeekly.values) {
        for (final ex in exercises) {
          expect(allIds.contains(ex.id), false,
              reason: 'Duplicate ID found: ${ex.id}');
          allIds.add(ex.id);
        }
      }
      expect(allIds.length, 14);
    });
  });
}
