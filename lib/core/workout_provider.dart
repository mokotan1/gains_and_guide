import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import '../features/routine/domain/exercise.dart';

class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    await _loadSavedProgram();
    // 현재 진행 중인 루틴이 있다면 덮어씌움 (앱 재시작 시 상태 유지)
    await _loadCurrentRoutineFromPrefs();
  }

  static const String _storageKey = 'saved_weekly_program';
  static const String _activeRoutineKey = 'current_active_routine';
  final Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  Future<void> applyWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    _currentWeeklyRoutine.clear();
    _currentWeeklyRoutine.addAll(weeklyRoutine);
    await _saveProgram(weeklyRoutine);
    updateRoutineByDay();
  }

  void removeExercise(String id) async {
    await DatabaseHelper.instance.deleteExercise(id);
    state = state.where((ex) => ex.id != id).toList();
    await _saveCurrentRoutineToPrefs();
  }

  void updateRoutineByDay() {
    final weekday = DateTime.now().weekday;
    final routine = _currentWeeklyRoutine[weekday] ?? [];
    state = routine.map((ex) => Exercise.initial(
      id: ex.id,
      name: ex.name,
      sets: ex.sets,
      reps: ex.reps,
      weight: ex.weight,
      isBodyweight: ex.isBodyweight,
      isCardio: ex.isCardio,
    )).toList();
    _saveCurrentRoutineToPrefs();
  }

  Future<void> _saveProgram(Map<int, List<Exercise>> routine) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    routine.forEach((day, exList) {
      data[day.toString()] = exList.map((e) => e.toJson()).toList();
    });
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> _loadSavedProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null) {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      decoded.forEach((day, list) {
        _currentWeeklyRoutine[int.parse(day)] = (list as List)
            .map((i) => Exercise.fromJson(i as Map<String, dynamic>))
            .toList();
      });
      // 초기 로딩 시 오늘 루틴으로 설정
      updateRoutineByDay();
    }
  }

  Future<void> _saveCurrentRoutineToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.map((e) => e.toJson()).toList();
    await prefs.setString(_activeRoutineKey, jsonEncode(data));
  }

  Future<void> _loadCurrentRoutineFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_activeRoutineKey);
    if (saved != null) {
      final List<dynamic> decoded = jsonDecode(saved);
      state = decoded.map((i) => Exercise.fromJson(i as Map<String, dynamic>)).toList();
    }
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
    _saveCurrentRoutineToPrefs();
  }

  void addExercise(Exercise ex) {
    state = [...state, ex];
    _saveCurrentRoutineToPrefs();
  }

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
            'rpe': ex.setRpe[i],
            'date': now,
          });
        }
      }
    }

    if (historyData.isNotEmpty) {
      await DatabaseHelper.instance.saveWorkoutHistory(historyData);
      // 저장 후 현재 루틴 상태 초기화 (옵션: 필요 시)
      // state = []; 
      // await _saveCurrentRoutineToPrefs();
    }
  }
}

final workoutProvider =
    StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) => WorkoutNotifier());
