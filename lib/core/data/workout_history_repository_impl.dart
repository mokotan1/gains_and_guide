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
}
