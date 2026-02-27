import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/exercise.dart';
import '../domain/routine.dart';
import '../data/routine_repository.dart';
import '../../../core/database/database_helper.dart';

class WorkoutService {
  final RoutineRepository _repository;
  final DatabaseHelper _dbHelper;

  WorkoutService(this._repository, this._dbHelper);

  static const String _programKey = 'saved_weekly_program';
  static const String _sessionKey = 'current_workout_session';
  static const String _lastDateKey = 'last_session_date';

  Future<Map<int, List<Exercise>>> loadWeeklyProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProgram = prefs.getString(_programKey);
    final Map<int, List<Exercise>> routineMap = {};

    if (savedProgram != null) {
      final decoded = jsonDecode(savedProgram) as Map<String, dynamic>;
      decoded.forEach((day, list) {
        routineMap[int.parse(day)] = (list as List)
            .map((i) => Exercise.fromJson(i as Map<String, dynamic>))
            .toList();
      });
    }
    return routineMap;
  }

  Future<void> saveWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    weeklyRoutine.forEach((day, exList) {
      data[day.toString()] = exList.map((e) => e.toJson()).toList();
    });
    await prefs.setString(_programKey, jsonEncode(data));
    await prefs.setString(_lastDateKey, DateTime.now().toString().split(' ')[0]);
  }

  Future<List<Exercise>?> loadCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSession = prefs.getString(_sessionKey);
    if (savedSession != null) {
      final List<dynamic> decodedList = jsonDecode(savedSession);
      return decodedList.map((i) => Exercise.fromJson(i as Map<String, dynamic>)).toList();
    }
    return null;
  }

  Future<void> saveCurrentSession(List<Exercise> state, bool isFinished) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(state.map((e) => e.toJson()).toList()));
    await prefs.setBool('is_workout_finished', isFinished);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.setBool('is_workout_finished', false);
  }

  Future<String?> getLastDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastDateKey);
  }

  Future<void> updateLastDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDateKey, date);
  }

  Future<bool> getIsFinished() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_workout_finished') ?? false;
  }

  Future<double?> getLatestWeight(String name) {
    return _dbHelper.getLatestWeight(name);
  }

  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> historyData) {
    return _dbHelper.saveWorkoutHistory(historyData);
  }

  Future<void> saveProgression(String name, double weight) {
    return _dbHelper.saveProgression(name, weight);
  }
}

final workoutServiceProvider = Provider<WorkoutService>((ref) {
  return WorkoutService(
    ref.watch(routineRepositoryProvider),
    DatabaseHelper.instance,
  );
});
