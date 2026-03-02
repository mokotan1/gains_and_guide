import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/routine/domain/exercise.dart';
import '../features/routine/application/workout_service.dart';
import 'database/database_helper.dart'; // DB 기록 조회를 위해 추가

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
    List<Exercise> routine = _currentWeeklyRoutine[weekday] ?? [];

    // [수정 1] 백 스쿼트가 포함된 루틴이라면, 요일 무시하고 이전 운동 기록을 기반으로 A/B 코스 결정
    if (routine.isNotEmpty && routine.any((e) => e.name == '백 스쿼트')) {
      routine = await _getSmartStrongliftsRoutine(routine);
    }

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

  // [기록 기반 A/B 코스 교차 로직 함수]
  Future<List<Exercise>> _getSmartStrongliftsRoutine(List<Exercise> defaultRoutine) async {
    final history = await DatabaseHelper.instance.getAllHistory();

    if (history.isEmpty) return defaultRoutine; // 기록 없으면 기본값

    // 가장 최근 운동 날짜 찾기
    final lastDate = history.first['date'].toString().split(' ')[0];

    // 가장 최근 운동 날짜에 수행한 운동 이름들 수집
    final lastExercises = history
        .where((h) => h['date'].toString().startsWith(lastDate))
        .map((h) => h['name'].toString())
        .toSet();

    // A코스 정의 (스쿼트, 벤치, 로우)
    final routineA = [
      Exercise.initial(id: 's1_a', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      Exercise.initial(id: 's2_a', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
      Exercise.initial(id: 's3_a', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
    ];

    // B코스 정의 (스쿼트, OHP, 데드리프트)
    final routineB = [
      Exercise.initial(id: 's1_b', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      Exercise.initial(id: 's4_b', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
      Exercise.initial(id: 's5_b', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
    ];

    // 마지막으로 '플랫 벤치 프레스'를 했다면 (A코스를 했음) -> 오늘은 B코스
    if (lastExercises.contains('플랫 벤치 프레스')) {
      return routineB;
    }
    // 마지막으로 '오버헤드 프레스 (OHP)'를 했다면 (B코스를 했음) -> 오늘은 A코스
    else if (lastExercises.contains('오버헤드 프레스 (OHP)')) {
      return routineA;
    }

    // 판단 불가 시 지정된 기본 루틴 반환
    return defaultRoutine;
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
        // [수정 2] 증량 조건을 5고정에서, 운동의 목표 세트 수(ex.sets)로 변경
        // 이렇게 하면 1세트인 데드리프트나 3세트인 보조 운동도 기록이 정상 저장됩니다.
        if (countBelow3 >= ex.sets) {
          newWeight += 5.0;
          await _service.saveProgression(ex.name, newWeight);
        } else if (countBelow8 >= ex.sets) {
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