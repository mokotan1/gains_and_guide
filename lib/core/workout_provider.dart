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
    final routine = await _getSmartStrongliftsRoutine();

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
    } else {
      state = [];
    }
    _saveCurrentSession();
  }

  Future<List<Exercise>> _getSmartStrongliftsRoutine() async {
    // 1. 사용자 설정 주간 루틴이 있는지 먼저 확인
    final weekday = DateTime.now().weekday;
    if (_currentWeeklyRoutine.containsKey(weekday) && _currentWeeklyRoutine[weekday]!.isNotEmpty) {
      return _currentWeeklyRoutine[weekday]!;
    }

    // 2. 설정이 없다면 Stronglifts A/B 교차 로직 실행
    // 월(1), 수(3), 금(5)에만 루틴 생성
    if (weekday != 1 && weekday != 3 && weekday != 5) return [];

    // 마지막으로 수행한 '프레스' 종목을 찾아 A/B 판별
    // 벤치 프레스(A) vs 오버헤드 프레스(B)
    final lastBench = await _service.getLatestWeight('플랫 벤치 프레스') ?? await _service.getLatestWeight('벤치 프레스');
    final lastOhp = await _service.getLatestWeight('오버헤드 프레스 (OHP)') ?? await _service.getLatestWeight('오버헤드 프레스');

    // 기록이 없거나, OHP가 더 최근(또는 동일)이면 Workout A 추천
    // 실제로는 날짜 비교가 정확하지만, 여기서는 단순 교차를 위해 마지막 기록 유무로 판단하거나 
    // 기본값 A로 시작
    bool isWorkoutA = true;
    if (lastBench != null && lastOhp != null) {
      // 더 최근에 한 쪽의 반대 루틴 선택 (여기서는 간단히 교차 로직 구현)
      // 실제 구현 시에는 history 테이블에서 마지막 date를 조회하는 것이 가장 정확함
      final history = await _service.getAllHistory();
      if (history.isNotEmpty) {
        final lastWorkoutName = history.first['name'];
        if (lastWorkoutName.contains('벤치')) isWorkoutA = false;
        else if (lastWorkoutName.contains('오버헤드')) isWorkoutA = true;
      }
    }

    if (isWorkoutA) {
      return [
        Exercise.initial(id: 'a1', name: '백 스쿼트', sets: 5, reps: 5, weight: 60),
        Exercise.initial(id: 'a2', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 40),
        Exercise.initial(id: 'a3', name: '펜들레이 로우', sets: 5, reps: 5, weight: 40),
      ];
    } else {
      return [
        Exercise.initial(id: 'b1', name: '백 스쿼트', sets: 5, reps: 5, weight: 60),
        Exercise.initial(id: 'b2', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 30),
        Exercise.initial(id: 'b3', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 80),
      ];
    }
  }

  Future<void> saveCurrentWorkoutToHistory() async {
    final now = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD로 통일
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
