import '../../../features/routine/domain/exercise_catalog.dart';

/// 운동 카탈로그(근력) 조회 추상화
abstract class ExerciseCatalogRepository {
  Future<List<ExerciseCatalog>> search(String keyword);
  Future<List<Map<String, dynamic>>> getAll();

  /// 부위 + 장비 + 키워드 복합 필터 검색
  Future<List<ExerciseCatalog>> searchWithFilters({
    String keyword = '',
    List<String> muscleKeys = const [],
    String? equipment,
  });

  /// 최근 수행한 운동 이름 목록
  Future<List<String>> getRecentExerciseNames({int limit = 5});
}
