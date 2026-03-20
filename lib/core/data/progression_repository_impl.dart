import '../database/database_helper.dart';
import '../domain/repositories/progression_repository.dart';

/// ProgressionRepository 구현
class ProgressionRepositoryImpl implements ProgressionRepository {
  final DatabaseHelper _db;

  ProgressionRepositoryImpl(this._db);

  @override
  Future<double?> getLatestWeight(String exerciseName) =>
      _db.getLatestWeight(exerciseName);

  @override
  Future<void> saveProgression(String exerciseName, double weight) =>
      _db.saveProgression(exerciseName, weight);

  @override
  Future<List<Map<String, dynamic>>> getRecentProgressions(
    String exerciseName,
    int limit,
  ) =>
      _db.getRecentProgressions(exerciseName, limit);
}
