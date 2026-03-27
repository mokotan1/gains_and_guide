import '../database/database_helper.dart';
import '../domain/repositories/workout_history_repository.dart';

/// WorkoutHistoryRepository 구현 (DatabaseHelper에만 의존)
class WorkoutHistoryRepositoryImpl implements WorkoutHistoryRepository {
  final DatabaseHelper _db;

  WorkoutHistoryRepositoryImpl(this._db);

  @override
  Future<List<Map<String, dynamic>>> getAllHistory() =>
      _db.getAllHistory();

  @override
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history) =>
      _db.saveWorkoutHistory(history);

  @override
  Future<List<Map<String, dynamic>>> getRecentSessionsByExercise(
    String exerciseName,
    int sessionLimit,
  ) =>
      _db.getRecentSessionsByExercise(exerciseName, sessionLimit);

  @override
  Future<List<Map<String, dynamic>>> getRecentSessions(int sessionLimit) =>
      _db.getRecentSessions(sessionLimit);

  @override
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  ) =>
      _db.getHistoryForDateRange(startDate, endDate);

  @override
  Future<List<double>> getWeeklyVolumes(int weekCount) =>
      _db.getWeeklyVolumes(weekCount);
}
