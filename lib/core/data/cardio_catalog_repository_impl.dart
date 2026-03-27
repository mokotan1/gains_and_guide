import '../database/database_helper.dart';
import '../domain/models/cardio_catalog.dart';
import '../domain/repositories/cardio_catalog_repository.dart';

class CardioCatalogRepositoryImpl implements CardioCatalogRepository {
  final DatabaseHelper _db;

  CardioCatalogRepositoryImpl(this._db);

  @override
  Future<List<CardioCatalog>> getAll() => _db.getCardioCatalogAll();

  @override
  Future<List<CardioCatalog>> search(String keyword) =>
      _db.searchCardioCatalog(keyword);
}
