import '../../../core/data/exercise_name_ko.dart';
import '../../../core/domain/models/cardio_catalog.dart';
import '../../../core/domain/models/muscle_group.dart';
import '../../../core/domain/repositories/cardio_catalog_repository.dart';
import '../../../core/domain/repositories/exercise_catalog_repository.dart';
import '../../../core/domain/repositories/favorite_exercise_repository.dart';
import '../../routine/domain/exercise_catalog.dart';
import '../utils/korean_search_utils.dart';

/// 운동 검색 비즈니스 로직 (DB 쿼리 + 한글 필터링 결합).
class ExerciseSearchService {
  final ExerciseCatalogRepository _catalogRepo;
  final CardioCatalogRepository _cardioRepo;
  final FavoriteExerciseRepository _favoriteRepo;

  ExerciseSearchService({
    required ExerciseCatalogRepository catalogRepo,
    required CardioCatalogRepository cardioRepo,
    required FavoriteExerciseRepository favoriteRepo,
  })  : _catalogRepo = catalogRepo,
        _cardioRepo = cardioRepo,
        _favoriteRepo = favoriteRepo;

  /// 근력 운동 검색: DB 필터 -> 한글 이름 변환 -> 초성 검색 적용
  Future<List<ExerciseCatalog>> searchStrength({
    String query = '',
    MuscleGroup muscleGroup = MuscleGroup.all,
    String? equipment,
  }) async {
    final muscleKeys = muscleGroup == MuscleGroup.all
        ? <String>[]
        : muscleGroup.dbMuscleKeys;

    final dbResults = await _catalogRepo.searchWithFilters(
      muscleKeys: muscleKeys,
      equipment: equipment,
    );

    if (query.isEmpty) return dbResults;

    return dbResults.where((exercise) {
      final koName = ExerciseNameKo.get(exercise.name);
      return KoreanSearchUtils.matchesSearch(query, koName) ||
          KoreanSearchUtils.matchesSearch(query, exercise.name);
    }).toList();
  }

  /// 유산소 운동 검색
  Future<List<CardioCatalog>> searchCardio({String query = ''}) async {
    final all = await _cardioRepo.getAll();
    if (query.isEmpty) return all;

    return all.where((exercise) {
      final koName = ExerciseNameKo.get(exercise.name);
      return KoreanSearchUtils.matchesSearch(query, koName) ||
          KoreanSearchUtils.matchesSearch(query, exercise.name);
    }).toList();
  }

  Future<List<String>> getRecentExerciseNames({int limit = 5}) =>
      _catalogRepo.getRecentExerciseNames(limit: limit);

  Future<Set<int>> getFavoriteStrengthIds() =>
      _favoriteRepo.getFavoriteIds(isCardio: false);

  Future<Set<int>> getFavoriteCardioIds() =>
      _favoriteRepo.getFavoriteIds(isCardio: true);

  Future<void> toggleFavorite(int catalogId, {required bool isCardio}) async {
    final ids = await _favoriteRepo.getFavoriteIds(isCardio: isCardio);
    if (ids.contains(catalogId)) {
      await _favoriteRepo.remove(catalogId, isCardio: isCardio);
    } else {
      await _favoriteRepo.add(catalogId, isCardio: isCardio);
    }
  }
}
