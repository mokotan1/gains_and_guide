import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/routine_repository.dart';
import '../domain/exercise.dart';
import '../domain/routine.dart';
import '../../../core/domain/repositories/progression_repository.dart';
import '../../../core/domain/repositories/workout_history_repository.dart';
import '../../../core/providers/repository_providers.dart';

class WorkoutService {
  final RoutineRepository _repository;
  final WorkoutHistoryRepository _historyRepo;
  final ProgressionRepository _progressionRepo;

  WorkoutService(this._repository, this._historyRepo, this._progressionRepo);

  static const String _sessionKey = 'current_workout_session';
  static const String _lastDateKey = 'last_session_date';

  // ---------------------------------------------------------------------------
  // Weekly program (SQLite)
  // ---------------------------------------------------------------------------

  Future<Map<int, List<Exercise>>> loadWeeklyProgram() =>
      _repository.getWeeklyProgram();

  Future<void> saveWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    final now = DateTime.now().toString().split(' ')[0];

    final Map<String, List<int>> groupedByExercises = {};
    weeklyRoutine.forEach((day, exercises) {
      final key = exercises.map((e) => e.id).join(',');
      groupedByExercises.putIfAbsent(key, () => []);
      groupedByExercises[key]!.add(day);
    });

    final List<Routine> routines = [];
    int index = 0;
    for (final entry in groupedByExercises.entries) {
      final weekdays = entry.value;
      final exercises = weeklyRoutine[weekdays.first]!;
      final dayLabels = weekdays.map(Routine.weekdayLabel).join('/');

      routines.add(Routine(
        name: 'Routine ${index + 1} ($dayLabels)',
        description: '${exercises.length}개 운동',
        createdAt: now,
        exercises: exercises,
        assignedWeekdays: weekdays,
      ));
      index++;
    }

    await _repository.replaceWeeklyProgram(routines);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDateKey, now);
  }

  // ---------------------------------------------------------------------------
  // Session management (SharedPreferences - ephemeral data)
  // ---------------------------------------------------------------------------

  Future<List<Exercise>?> loadCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSession = prefs.getString(_sessionKey);
    if (savedSession != null) {
      final List<dynamic> decodedList = jsonDecode(savedSession);
      return decodedList
          .map((i) => Exercise.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    return null;
  }

  Future<void> saveCurrentSession(List<Exercise> state, bool isFinished) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
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

  // ---------------------------------------------------------------------------
  // Delegated repository calls
  // ---------------------------------------------------------------------------

  Future<double?> getLatestWeight(String name) =>
      _progressionRepo.getLatestWeight(name);

  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> historyData) =>
      _historyRepo.saveWorkoutHistory(historyData);

  Future<void> saveProgression(String name, double weight) =>
      _progressionRepo.saveProgression(name, weight);

  Future<List<Map<String, dynamic>>> getAllHistory() =>
      _historyRepo.getAllHistory();
}

final workoutServiceProvider = Provider<WorkoutService>((ref) {
  return WorkoutService(
    ref.watch(routineRepositoryProvider),
    ref.watch(workoutHistoryRepositoryProvider),
    ref.watch(progressionRepositoryProvider),
  );
});
