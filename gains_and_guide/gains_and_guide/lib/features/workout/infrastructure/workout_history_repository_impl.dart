import '../../../../core/database/database_helper.dart';
import '../domain/repositories/workout_history_repository.dart';

class WorkoutHistoryRepositoryImpl implements WorkoutHistoryRepository {
  final DatabaseHelper _db;

  WorkoutHistoryRepositoryImpl(this._db);

  @override
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history) =>
      _db.saveWorkoutHistory(history);

  @override
  Future<List<Map<String, dynamic>>> getAllHistory() => _db.getAllHistory();
}
