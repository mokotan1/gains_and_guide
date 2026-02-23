import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import '../features/home/presentation/home_screen.dart';

class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]) { _loadSavedProgram(); }

  static const String _storageKey = 'saved_weekly_program';
  Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  // 1. 요일별 프로그램 적용 (에러 해결 부분)
  Future<void> applyWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    _currentWeeklyRoutine = weeklyRoutine;
    await _saveProgram(weeklyRoutine);
    updateRoutineByDay();
  }

  // 2. 운동 삭제 기능
  void removeExercise(String id) async {
    await DatabaseHelper.instance.deleteExercise(id);
    state = state.where((ex) => ex.id != id).toList();
  }

  void updateRoutineByDay() {
    final weekday = DateTime.now().weekday;
    state = _currentWeeklyRoutine[weekday] ?? [];
  }

  Future<void> _saveProgram(Map<int, List<Exercise>> routine) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    routine.forEach((day, exList) {
      data[day.toString()] = exList.map((e) => {'id': e.id, 'name': e.name, 'sets': e.sets, 'reps': e.reps, 'weight': e.weight}).toList();
    });
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> _loadSavedProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null) {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      decoded.forEach((day, list) {
        _currentWeeklyRoutine[int.parse(day)] = (list as List).map((i) => Exercise(id: i['id'], name: i['name'], sets: i['sets'], reps: i['reps'], weight: i['weight'])).toList();
      });
      updateRoutineByDay();
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
  }

  void addExercise(Exercise ex) { state = [...state, ex]; }
}

final workoutProvider = StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) => WorkoutNotifier());