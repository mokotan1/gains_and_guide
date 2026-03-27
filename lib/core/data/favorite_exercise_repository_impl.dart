import '../../features/routine/domain/exercise_catalog.dart';
import '../database/database_helper.dart';
import '../domain/models/cardio_catalog.dart';
import '../domain/repositories/favorite_exercise_repository.dart';

class FavoriteExerciseRepositoryImpl implements FavoriteExerciseRepository {
  final DatabaseHelper _db;

  FavoriteExerciseRepositoryImpl(this._db);

  @override
  Future<void> add(int catalogId, {bool isCardio = false}) =>
      _db.addFavorite(catalogId, isCardio: isCardio);

  @override
  Future<void> remove(int catalogId, {bool isCardio = false}) =>
      _db.removeFavorite(catalogId, isCardio: isCardio);

  @override
  Future<Set<int>> getFavoriteIds({bool isCardio = false}) =>
      _db.getFavoriteIds(isCardio: isCardio);

  @override
  Future<List<ExerciseCatalog>> getFavorites() => _db.getFavoriteExercises();

  @override
  Future<List<CardioCatalog>> getFavoriteCardio() =>
      _db.getFavoriteCardioExercises();
}
