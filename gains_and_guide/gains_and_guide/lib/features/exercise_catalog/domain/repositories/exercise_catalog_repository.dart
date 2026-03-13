import '../entities/exercise_catalog.dart';

/// 운동 카탈로그 검색/시딩 — 도메인 리포지토리(포트)
abstract class ExerciseCatalogRepository {
  Future<bool> isEmpty();
  Future<void> seed(List<Map<String, dynamic>> exercises);
  Future<List<ExerciseCatalog>> searchByName(String keyword);
  Future<List<ExerciseCatalog>> getAll();
}
