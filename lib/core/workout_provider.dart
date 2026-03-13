import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/routine/domain/exercise.dart';
import '../features/routine/application/workout_service.dart';
import 'constants/workout_constants.dart';

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
    final coreState = state
        .where((ex) => WorkoutConstants.coreExerciseNamesToKeep.contains(ex.name))
        .toList();
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

  /// 기록 기반 Stronglifts 5x5 A/B 코스 교차 로직
  /// - workout_history는 date DESC로 조회되므로 첫 행이 가장 최근 날짜
  /// - 날짜는 항상 YYYY-MM-DD로 정규화해 비교 (DB/시간대 차이 대비)
  Future<List<Exercise>> _getSmartStrongliftsRoutine(List<Exercise> defaultRoutine) async {
    final history = await _service.getAllHistory();
    if (history.isEmpty) return defaultRoutine;

    final lastDate = _normalizeDateString(history.first['date']);
    if (lastDate.isEmpty) return defaultRoutine;

    final lastExercises = history
        .where((h) => _normalizeDateString(h['date']) == lastDate)
        .map((h) => (h['name']?.toString() ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    final routineA = [
      Exercise.initial(id: 's1_a', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      Exercise.initial(id: 's2_a', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
      Exercise.initial(id: 's3_a', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
    ];
    final routineB = [
      Exercise.initial(id: 's1_b', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      Exercise.initial(id: 's4_b', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
      Exercise.initial(id: 's5_b', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
    ];

    if (lastExercises.any((e) => WorkoutConstants.strongliftsRoutineAKeys.contains(e))) {
      return _mergeWithAccessories(routineB, defaultRoutine, WorkoutConstants.strongliftsMainB);
    }
    if (lastExercises.any((e) => WorkoutConstants.strongliftsRoutineBKeys.contains(e))) {
      return _mergeWithAccessories(routineA, defaultRoutine, WorkoutConstants.strongliftsMainA);
    }

    return defaultRoutine;
  }

  /// 메인 루틴(A 또는 B) 뒤에, 그날 루틴에 있던 보조 운동을 그대로 붙임
  static List<Exercise> _mergeWithAccessories(
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

  /// DB/SharedPreferences 등에서 오는 날짜 값을 YYYY-MM-DD로 통일
  static String _normalizeDateString(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty) return '';
    final part = s.split(' ').first;
    return part.length >= 10 ? part.substring(0, 10) : part;
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
          int rpe = ex.setRpe[i] ?? WorkoutConstants.defaultRpe;
          if (rpe < WorkoutConstants.rpeThresholdForFullIncrement) countBelow3++;
          if (rpe < WorkoutConstants.rpeThresholdForHalfIncrement) countBelow8++;

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
        if (countBelow3 >= ex.sets) {
          newWeight += WorkoutConstants.weightIncrementFull;
          await _service.saveProgression(ex.name, newWeight);
        } else if (countBelow8 >= ex.sets) {
          newWeight += WorkoutConstants.weightIncrementHalf;
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