import '../../features/routine/domain/exercise_catalog.dart';
import '../database/database_helper.dart';
import '../domain/repositories/exercise_catalog_repository.dart';

/// ExerciseCatalogRepository 구현
class ExerciseCatalogRepositoryImpl implements ExerciseCatalogRepository {
  final DatabaseHelper _db;

  ExerciseCatalogRepositoryImpl(this._db);

  @override
  Future<List<ExerciseCatalog>> search(String keyword) =>
      _db.searchCatalogExercises(keyword);

  @override
  Future<List<Map<String, dynamic>>> getAll() => _db.getExerciseCatalogAll();

  @override
  Future<List<ExerciseCatalog>> searchWithFilters({
    String keyword = '',
    List<String> muscleKeys = const [],
    String? equipment,
  }) =>
      _db.searchCatalogWithFilters(
        keyword: keyword,
        muscleKeys: muscleKeys,
        equipment: equipment,
      );

  @override
  Future<List<String>> getRecentExerciseNames({int limit = 5}) =>
      _db.getRecentExerciseNames(limit: limit);
}
