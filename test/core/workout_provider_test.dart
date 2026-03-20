import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';
import 'package:gains_and_guide/core/constants/workout_constants.dart';

void main() {
  final allStrongliftsMainNames = <String>{
    ...WorkoutConstants.strongliftsMainA,
    ...WorkoutConstants.strongliftsMainB,
  };

  List<Exercise> mergeWithAccessories(
    List<Exercise> mainRoutine,
    List<Exercise> dayRoutine,
  ) {
    final accessories = dayRoutine
        .where((e) => !allStrongliftsMainNames.contains(e.name))
        .toList();
    if (accessories.isEmpty) return mainRoutine;
    return [...mainRoutine, ...accessories];
  }

  group('_mergeWithAccessories - cross-contamination prevention', () {
    test('does NOT add A-main exercises as accessories when switching to B', () {
      final routineB = [
        Exercise.initial(id: 's1_b', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 's4_b', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
        Exercise.initial(id: 's5_b', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
      ];
      final dayRoutineA = [
        Exercise.initial(id: 's1_a', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 's2_a', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
        Exercise.initial(id: 's3_a', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
      ];

      final result = mergeWithAccessories(routineB, dayRoutineA);

      expect(result.length, 3, reason: 'B should have exactly 3 exercises, no A leakage');
      expect(result.map((e) => e.name).toList(), [
        '백 스쿼트', '오버헤드 프레스 (OHP)', '컨벤셔널 데드리프트',
      ]);
    });

    test('does NOT add B-main exercises as accessories when switching to A', () {
      final routineA = [
        Exercise.initial(id: 's1_a', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 's2_a', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
        Exercise.initial(id: 's3_a', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
      ];
      final dayRoutineB = [
        Exercise.initial(id: 's1_b', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 's4_b', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
        Exercise.initial(id: 's5_b', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
      ];

      final result = mergeWithAccessories(routineA, dayRoutineB);

      expect(result.length, 3, reason: 'A should have exactly 3 exercises, no B leakage');
      expect(result.map((e) => e.name).toList(), [
        '백 스쿼트', '플랫 벤치 프레스', '펜들레이 로우',
      ]);
    });

    test('user-added accessories are still preserved', () {
      final routineB = [
        Exercise.initial(id: 's1_b', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 's4_b', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
        Exercise.initial(id: 's5_b', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
      ];
      final dayRoutineWithAccessory = [
        Exercise.initial(id: 's1_a', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 's2_a', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
        Exercise.initial(id: 'acc1', name: '바벨 컬', sets: 3, reps: 10, weight: 20),
      ];

      final result = mergeWithAccessories(routineB, dayRoutineWithAccessory);

      expect(result.length, 4);
      expect(result.last.name, '바벨 컬');
    });
  });

  group('Stronglifts A/B rotation detection', () {
    test('A-keys contain both bench press and barbell row', () {
      expect(WorkoutConstants.strongliftsRoutineAKeys, contains('플랫 벤치 프레스'));
      expect(WorkoutConstants.strongliftsRoutineAKeys, contains('펜들레이 로우'));
    });

    test('B-keys contain both OHP and deadlift', () {
      expect(WorkoutConstants.strongliftsRoutineBKeys, contains('오버헤드 프레스 (OHP)'));
      expect(WorkoutConstants.strongliftsRoutineBKeys, contains('컨벤셔널 데드리프트'));
    });

    test('A-keys and B-keys have no overlap', () {
      final aSet = WorkoutConstants.strongliftsRoutineAKeys.toSet();
      final bSet = WorkoutConstants.strongliftsRoutineBKeys.toSet();
      expect(aSet.intersection(bSet), isEmpty);
    });

    test('main A and main B share only squat', () {
      final aSet = WorkoutConstants.strongliftsMainA.toSet();
      final bSet = WorkoutConstants.strongliftsMainB.toSet();
      expect(aSet.intersection(bSet), {'백 스쿼트'});
    });

    test('simulated Week 1-2 rotation produces correct A/B pattern', () {
      final List<String> weeklyPattern = [];

      Set<String> lastExercises = {};

      for (int day = 0; day < 6; day++) {
        final bool lastWasA = lastExercises.any(
            (e) => WorkoutConstants.strongliftsRoutineAKeys.contains(e));
        final bool lastWasB = lastExercises.any(
            (e) => WorkoutConstants.strongliftsRoutineBKeys.contains(e));

        String selectedCourse;
        if (lastExercises.isEmpty) {
          selectedCourse = 'A';
        } else if (lastWasA && !lastWasB) {
          selectedCourse = 'B';
        } else if (lastWasB && !lastWasA) {
          selectedCourse = 'A';
        } else {
          selectedCourse = 'A';
        }

        weeklyPattern.add(selectedCourse);

        if (selectedCourse == 'A') {
          lastExercises = {'백 스쿼트', '플랫 벤치 프레스', '펜들레이 로우'};
        } else {
          lastExercises = {'백 스쿼트', '오버헤드 프레스 (OHP)', '컨벤셔널 데드리프트'};
        }
      }

      expect(weeklyPattern, ['A', 'B', 'A', 'B', 'A', 'B']);
    });
  });

  group('_normalizeDateString logic', () {
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
