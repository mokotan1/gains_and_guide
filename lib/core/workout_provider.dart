import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/home/presentation/home_screen.dart'; // Exercise 모델 공유를 위해

// 운동 목록 상태를 관리하는 Notifier
class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]) {
    _init();
  }

  static const String _storageKey = 'saved_weekly_program';

  Future<void> _init() async {
    await _loadSavedProgram();
  }

  // AI 추천 보조 운동 목록을 별도로 관리
  List<Exercise> _aiRecommendedExercises = [];
  List<Exercise> get aiRecommendedExercises => _aiRecommendedExercises;

  void setAiRecommendations(List<Exercise> recommendations) {
    _aiRecommendedExercises = recommendations;
    // 상태를 새로고침하기 위해 현재 상태를 재할당 (UI 업데이트 유도)
    state = [...state];
  }

  // 특정 프로그램의 요일별 전체 루틴 적용
  Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  Future<void> applyWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    _currentWeeklyRoutine = weeklyRoutine;
    await _saveProgram(weeklyRoutine);
    updateRoutineByDay();
  }

  Future<void> _saveProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    final prefs = await SharedPreferences.getInstance();
    // Exercise를 JSON으로 직렬화하기 위해 Map으로 변환
    final Map<String, dynamic> serializableMap = {};
    weeklyRoutine.forEach((day, exercises) {
      serializableMap[day.toString()] = exercises.map((e) => {
        'id': e.id,
        'name': e.name,
        'sets': e.sets,
        'reps': e.reps,
        'weight': e.weight,
      }).toList();
    });
    
    await prefs.setString(_storageKey, jsonEncode(serializableMap));
  }

  Future<void> _loadSavedProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);
    
    if (savedData != null) {
      final Map<String, dynamic> decoded = jsonDecode(savedData);
      final Map<int, List<Exercise>> loadedRoutine = {};
      
      decoded.forEach((dayStr, exList) {
        final day = int.parse(dayStr);
        final exercises = (exList as List).map((item) => Exercise(
          id: item['id'],
          name: item['name'],
          sets: item['sets'],
          reps: item['reps'],
          weight: (item['weight'] as num).toDouble(),
        )).toList();
        loadedRoutine[day] = exercises;
      });
      
      _currentWeeklyRoutine = loadedRoutine;
      updateRoutineByDay();
    }
  }

  void updateRoutineByDay() {
    final weekday = DateTime.now().weekday;
    state = _currentWeeklyRoutine[weekday] ?? [];
  }

  // 세트 상태 업데이트
  void toggleSet(int exIndex, int setIndex, int? rpe, {bool isAi = false}) {
    if (isAi) {
      var newAi = [..._aiRecommendedExercises];
      var ex = newAi[exIndex];
      var newStatus = [...ex.setStatus];
      var newRpe = [...ex.setRpe];

      newStatus[setIndex] = !newStatus[setIndex];
      newRpe[setIndex] = newStatus[setIndex] ? rpe : null;

      newAi[exIndex] = ex.copyWith(setStatus: newStatus, setRpe: newRpe);
      _aiRecommendedExercises = newAi;
      state = [...state]; // Force UI update
      return;
    }

    var newState = [...state];
    var ex = newState[exIndex];
    var newStatus = [...ex.setStatus];
    var newRpe = [...ex.setRpe];
    
    newStatus[setIndex] = !newStatus[setIndex];
    newRpe[setIndex] = newStatus[setIndex] ? rpe : null;
    
    newState[exIndex] = ex.copyWith(setStatus: newStatus, setRpe: newRpe);
    state = newState;
  }

  // 운동 추가
  void addExercise(Exercise exercise) {
    state = [...state, exercise];
  }
}

// Provider 정의
final workoutProvider = StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) {
  return WorkoutNotifier();
});
