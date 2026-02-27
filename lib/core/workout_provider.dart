import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/routine/domain/exercise.dart';
import '../features/routine/application/workout_service.dart';

class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  final WorkoutService _service;

  WorkoutNotifier(this._service) : super([]) {
    _loadAllData();
  }

  bool isFinished = false;
  final Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  Future<void> _loadAllData() async {
    _currentWeeklyRoutine.addAll(await _service.loadWeeklyProgram());

    final String? lastSavedDate = await _service.getLastDate();
    final String todayDate = DateTime.now().toString().split(' ')[0];

    if (lastSavedDate != todayDate) {
      isFinished = false;
      await updateRoutineByDay();
      await _service.updateLastDate(todayDate);
    } else {
      final session = await _service.loadCurrentSession();
      if (session != null) {
        state = session;
        isFinished = await _service.getIsFinished();
      } else {
        await updateRoutineByDay();
      }
    }
  }

  Future<void> applyProgression(List<dynamic> progressions) async {
    for (var p in progressions) {
      final String name = p['name'];
      final double increase = (p['increase'] as num).toDouble();

      _currentWeeklyRoutine.forEach((day, exercises) {
        for (int i = 0; i < exercises.length; i++) {
          if (exercises[i].name == name) {
            exercises[i] = exercises[i].copyWith(weight: exercises[i].weight + increase);
          }
        }
      });
    }

    await _service.saveWeeklyProgram(_currentWeeklyRoutine);
    state = [...state];
  }

  Future<void> _saveCurrentSession() async {
    await _service.saveCurrentSession(state, isFinished);
  }

  void replaceRecommendedExercises(List<Exercise> newExercises) {
    final coreNames = ['백 스쿼트', '플랫 벤치 프레스', '펜들레이 로우', '오버헤드 프레스 (OHP)', '컨벤셔널 데드리프트', '스쿼트', '벤치 프레스'];
    final coreState = state.where((ex) => coreNames.contains(ex.name)).toList();
    state = [...coreState, ...newExercises];
    _saveCurrentSession();
  }

  void finishWorkout() {
    isFinished = true;
    _saveCurrentSession();
    state = [...state];
  }

  void addExercise(Exercise ex) {
    state = [...state, ex];
    _saveCurrentSession();
  }

  void removeExercise(String id) {
    state = state.where((ex) => ex.id != id).toList();
    _saveCurrentSession();
  }

  Future<void> applyWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    isFinished = false;
    _currentWeeklyRoutine.clear();
    _currentWeeklyRoutine.addAll(weeklyRoutine);

    await _service.saveWeeklyProgram(weeklyRoutine);
    await updateRoutineByDay();
  }

  void toggleSet(int exIdx, int sIdx, int? rpe) {
    final newState = [...state];
    final ex = newState[exIdx];
    final newStatus = [...ex.setStatus];
    final newRpe = [...ex.setRpe];
    newStatus[sIdx] = !newStatus[sIdx];
    newRpe[sIdx] = newStatus[sIdx] ? rpe : null;
    newState[exIdx] = ex.copyWith(setStatus: newStatus, setRpe: newRpe);
    state = newState;
    _saveCurrentSession();
  }

  Future<void> updateRoutineByDay() async {
    final weekday = DateTime.now().weekday;
    final routine = _currentWeeklyRoutine[weekday] ?? [];

    if (routine.isNotEmpty) {
      final List<Exercise> updatedRoutine = [];
      for (var ex in routine) {
        final latestWeight = await _service.getLatestWeight(ex.name);
        updatedRoutine.add(ex.copyWith(
          weight: latestWeight ?? ex.weight,
          setStatus: List.filled(ex.sets, false),
          setRpe: List.filled(ex.sets, null),
        ));
      }
      state = updatedRoutine;
    } else if (weekday == 1 || weekday == 3 || weekday == 5) {
      // 5x5 기본 루틴 로직 (필요 시 유지)
      // 이 부분은 Service로 옮기거나 명확히 관리하는 게 좋음
      state = []; // 일단 빈 루틴으로 처리하거나 기존 로직 유지
    } else {
      state = [];
    }
    _saveCurrentSession();
  }

  Future<void> saveCurrentWorkoutToHistory() async {
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> historyData = [];

    for (var ex in state) {
      int countBelow3 = 0;
      int countBelow8 = 0;
      int completedSets = 0;

      for (int i = 0; i < ex.sets; i++) {
        if (ex.setStatus[i]) {
          completedSets++;
          int rpe = ex.setRpe[i] ?? 8;
          if (rpe < 3) countBelow3++;
          if (rpe < 8) countBelow8++;

          historyData.add({
            'name': ex.name,
            'sets': i + 1,
            'reps': ex.reps,
            'weight': ex.weight,
            'rpe': rpe,
            'date': now,
          });
        }
      }

      if (completedSets > 0 && !ex.isCardio) {
        double newWeight = ex.weight;
        if (countBelow3 >= 5) {
          newWeight += 5.0;
          await _service.saveProgression(ex.name, newWeight);
        } else if (countBelow8 >= 5) {
          newWeight += 2.5;
          await _service.saveProgression(ex.name, newWeight);
        }
      }
    }

    if (historyData.isNotEmpty) {
      await _service.saveWorkoutHistory(historyData);
      await _service.clearSession();
      isFinished = false;
    }
  }
}

final workoutProvider =
StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) {
  final service = ref.watch(workoutServiceProvider);
  return WorkoutNotifier(service);
});
