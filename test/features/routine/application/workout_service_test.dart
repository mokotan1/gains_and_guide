import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';
import 'package:gains_and_guide/features/routine/domain/routine.dart';

void main() {
  group('WorkoutService - saveWeeklyProgram grouping logic', () {
    test('identical exercise sets on different days are grouped into one routine', () {
      final exercises = [
        Exercise.initial(id: 'p1_d1', name: '벤치프레스', sets: 4, reps: 10, weight: 60),
        Exercise.initial(id: 'p2_d1', name: '숄더프레스', sets: 3, reps: 10, weight: 30),
      ];

      final weeklyRoutine = <int, List<Exercise>>{
        1: exercises,
        4: exercises,
      };

      final Map<String, List<int>> grouped = {};
      weeklyRoutine.forEach((day, exList) {
        final key = exList.map((e) => e.id).join(',');
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(day);
      });

      expect(grouped.length, 1);
      expect(grouped.values.first, containsAll([1, 4]));
    });

    test('different exercise sets create separate groups', () {
      final weeklyRoutine = <int, List<Exercise>>{
        1: [Exercise.initial(id: 'a', name: '벤치', sets: 4, reps: 10, weight: 60)],
        2: [Exercise.initial(id: 'b', name: '스쿼트', sets: 4, reps: 8, weight: 80)],
        3: [Exercise.initial(id: 'a', name: '벤치', sets: 4, reps: 10, weight: 60)],
      };

      final Map<String, List<int>> grouped = {};
      weeklyRoutine.forEach((day, exList) {
        final key = exList.map((e) => e.id).join(',');
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(day);
      });

      expect(grouped.length, 2);
    });

    test('empty weekly routine produces no groups', () {
      final weeklyRoutine = <int, List<Exercise>>{};
      final Map<String, List<int>> grouped = {};
      weeklyRoutine.forEach((day, exList) {
        final key = exList.map((e) => e.id).join(',');
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(day);
      });

      expect(grouped.isEmpty, true);
    });
  });

  group('Routine creation from weekly program', () {
    test('routines are created with correct weekday labels', () {
      final weeklyRoutine = <int, List<Exercise>>{
        1: [Exercise.initial(id: 'a', name: '벤치', sets: 4, reps: 10, weight: 60)],
        3: [Exercise.initial(id: 'a', name: '벤치', sets: 4, reps: 10, weight: 60)],
        5: [Exercise.initial(id: 'a', name: '벤치', sets: 4, reps: 10, weight: 60)],
      };

      final now = '2026-03-20';
      final Map<String, List<int>> grouped = {};
      weeklyRoutine.forEach((day, exList) {
        final key = exList.map((e) => e.id).join(',');
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(day);
      });

      int index = 0;
      final List<Routine> routines = [];
      for (final entry in grouped.entries) {
        final weekdays = entry.value;
        final exercises = weeklyRoutine[weekdays.first]!;
        final dayLabels = weekdays.map(Routine.weekdayLabel).join('/');

        routines.add(Routine(
          name: 'Routine ${index + 1} ($dayLabels)',
          description: '${exercises.length}개 운동',
          createdAt: now,
          exercises: exercises,
          assignedWeekdays: weekdays,
        ));
        index++;
      }

      expect(routines.length, 1);
      expect(routines.first.name, contains('월/수/금'));
      expect(routines.first.assignedWeekdays, [1, 3, 5]);
      expect(routines.first.exercises.length, 1);
    });
  });
}
