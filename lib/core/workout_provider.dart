import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import '../features/routine/domain/exercise.dart';

class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]) {
    _loadSavedProgram();
  }

  static const String _storageKey = 'saved_weekly_program';
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
    )).toList();
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

  void addExercise(Exercise ex) {
    state = [...state, ex];
  }
}

final workoutProvider =
    StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) => WorkoutNotifier());
