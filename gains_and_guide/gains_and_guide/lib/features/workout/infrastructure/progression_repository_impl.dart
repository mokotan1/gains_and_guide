import '../../../../core/database/database_helper.dart';
import '../domain/repositories/progression_repository.dart';

class ProgressionRepositoryImpl implements ProgressionRepository {
  final DatabaseHelper _db;

  ProgressionRepositoryImpl(this._db);

  @override
  Future<void> saveProgression(String exerciseName, double weight) =>
      _db.saveProgression(exerciseName, weight);

  @override
  Future<double?> getLatestWeight(String exerciseName) =>
      _db.getLatestWeight(exerciseName);
}
