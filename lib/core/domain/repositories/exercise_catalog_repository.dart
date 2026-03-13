import '../../../features/routine/domain/exercise_catalog.dart';

/// 운동 카탈로그 조회 추상화
abstract class ExerciseCatalogRepository {
  Future<List<ExerciseCatalog>> search(String keyword);
  Future<List<Map<String, dynamic>>> getAll();
}
