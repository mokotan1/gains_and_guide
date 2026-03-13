import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/exercise.dart';
import '../domain/repositories/workout_session_repository.dart';

class WorkoutSessionRepositoryImpl implements WorkoutSessionRepository {
  static const String _programKey = 'saved_weekly_program';
  static const String _sessionKey = 'current_workout_session';
  static const String _lastDateKey = 'last_session_date';
  static const String _isFinishedKey = 'is_workout_finished';

  @override
  Future<Map<int, List<Exercise>>> loadWeeklyProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_programKey);
    final Map<int, List<Exercise>> result = {};
    if (saved != null) {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      decoded.forEach((day, list) {
        result[int.parse(day)] = (list as List)
            .map((i) => Exercise.fromJson(i as Map<String, dynamic>))
            .toList();
      });
    }
    return result;
  }

  @override
  Future<void> saveWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    weeklyRoutine.forEach((day, exList) {
      data[day.toString()] = exList.map((e) => e.toJson()).toList();
    });
    await prefs.setString(_programKey, jsonEncode(data));
    await prefs.setString(_lastDateKey, DateTime.now().toString().split(' ')[0]);
  }

  @override
  Future<List<Exercise>?> loadCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_sessionKey);
    if (saved == null) return null;
    final list = jsonDecode(saved) as List<dynamic>;
    return list.map((i) => Exercise.fromJson(i as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> saveCurrentSession(List<Exercise> state, bool isFinished) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(state.map((e) => e.toJson()).toList()));
    await prefs.setBool(_isFinishedKey, isFinished);
  }

  @override
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.setBool(_isFinishedKey, false);
  }

  @override
  Future<String?> getLastDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastDateKey);
  }

  @override
  Future<void> updateLastDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDateKey, date);
  }

  @override
  Future<bool> getIsFinished() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFinishedKey) ?? false;
  }
}
