import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import '../features/routine/domain/exercise.dart';

class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]) {
    _loadAllData();
  }

  bool isFinished = false;
  static const String _programKey = 'saved_weekly_program';
  static const String _sessionKey = 'current_workout_session';
  final Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 저장된 주간 프로그램 로드
    final savedProgram = prefs.getString(_programKey);
    if (savedProgram != null) {
      final decoded = jsonDecode(savedProgram) as Map<String, dynamic>;
      decoded.forEach((day, list) {
        _currentWeeklyRoutine[int.parse(day)] = (list as List)
            .map((i) => Exercise.fromJson(i as Map<String, dynamic>))
            .toList();
      });
    }

    // 2. 현재 진행 중인 세션 로드
    final savedSession = prefs.getString(_sessionKey);
    if (savedSession != null) {
      final List<dynamic> decodedList = jsonDecode(savedSession);
      state = decodedList.map((i) => Exercise.fromJson(i as Map<String, dynamic>)).toList();
      isFinished = prefs.getBool('is_workout_finished') ?? false;
    } else {
      await updateRoutineByDay();
    }
  }

  Future<void> _saveCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(state.map((e) => e.toJson()).toList()));
    await prefs.setBool('is_workout_finished', isFinished);
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
    state = [...state]; // UI 업데이트 강제
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
    
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    weeklyRoutine.forEach((day, exList) {
      data[day.toString()] = exList.map((e) => e.toJson()).toList();
    });
    await prefs.setString(_programKey, jsonEncode(data));
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
      state = routine.map((ex) => Exercise.initial(
        id: ex.id,
        name: ex.name,
        sets: ex.sets,
        reps: ex.reps,
        weight: ex.weight,
        isBodyweight: ex.isBodyweight,
        isCardio: ex.isCardio,
      )).toList();
    } else if (weekday == 1 || weekday == 3 || weekday == 5) {
      // 주간 루틴이 비어있을 경우 스트롱리프트 5x5 기본 루틴 제공
      final history = await DatabaseHelper.instance.getAllHistory();
      if (history.isEmpty) {
        state = _getWorkoutA();
      } else {
        final lastB = history.first['name'] == '오버헤드 프레스 (OHP)' || history.first['name'] == '컨벤셔널 데드리프트';
        state = lastB ? _getWorkoutA() : _getWorkoutB();
      }
    } else {
      state = [];
    }
    _saveCurrentSession();
  }

  List<Exercise> _getWorkoutA() => [
    Exercise.initial(id: 'a1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
    Exercise.initial(id: 'a2', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
    Exercise.initial(id: 'a3', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
  ];

  List<Exercise> _getWorkoutB() => [
    Exercise.initial(id: 'b1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
    Exercise.initial(id: 'b2', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
    Exercise.initial(id: 'b3', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
  ];

  Future<void> saveCurrentWorkoutToHistory() async {
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> historyData = [];

    for (var ex in state) {
      for (int i = 0; i < ex.sets; i++) {
        if (ex.setStatus[i]) {
          historyData.add({
            'name': ex.name,
            'sets': i + 1,
            'reps': ex.reps,
            'weight': ex.weight,
            'rpe': ex.setRpe[i] ?? 8,
            'date': now,
          });
        }
      }
    }

    if (historyData.isNotEmpty) {
      await DatabaseHelper.instance.saveWorkoutHistory(historyData);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.setBool('is_workout_finished', false);
      isFinished = false;
    }
  }
}

final workoutProvider =
    StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) => WorkoutNotifier());
