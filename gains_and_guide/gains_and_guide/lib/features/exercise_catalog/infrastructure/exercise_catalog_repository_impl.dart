import '../../../../core/database/database_helper.dart';
import '../domain/entities/exercise_catalog.dart';
import '../domain/repositories/exercise_catalog_repository.dart';

class ExerciseCatalogRepositoryImpl implements ExerciseCatalogRepository {
  final DatabaseHelper _db;

  ExerciseCatalogRepositoryImpl(this._db);

  @override
  Future<bool> isEmpty() => _db.isExerciseCatalogEmpty();

  @override
  Future<void> seed(List<Map<String, dynamic>> exercises) =>
      _db.seedExerciseCatalog(exercises);

  @override
  Future<List<ExerciseCatalog>> searchByName(String keyword) async {
    final rows = await _db.searchCatalogExercisesRaw(keyword);
    return rows.map((m) => ExerciseCatalog.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  @override
  Future<List<ExerciseCatalog>> getAll() async {
    final rows = await _db.getAllCatalogRaw();
    return rows.map((m) => ExerciseCatalog.fromMap(Map<String, dynamic>.from(m))).toList();
  }
}
