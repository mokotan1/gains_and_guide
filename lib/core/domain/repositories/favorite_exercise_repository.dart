import '../../../features/routine/domain/exercise_catalog.dart';
import '../models/cardio_catalog.dart';

/// 즐겨찾기 운동 CRUD 추상화
abstract class FavoriteExerciseRepository {
  Future<void> add(int catalogId, {bool isCardio = false});
  Future<void> remove(int catalogId, {bool isCardio = false});
  Future<Set<int>> getFavoriteIds({bool isCardio = false});
  Future<List<ExerciseCatalog>> getFavorites();
  Future<List<CardioCatalog>> getFavoriteCardio();
}
