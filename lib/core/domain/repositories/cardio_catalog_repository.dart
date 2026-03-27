import '../models/cardio_catalog.dart';

/// 유산소 운동 카탈로그 조회 추상화
abstract class CardioCatalogRepository {
  Future<List<CardioCatalog>> getAll();
  Future<List<CardioCatalog>> search(String keyword);
}
