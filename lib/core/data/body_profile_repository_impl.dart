import '../database/database_helper.dart';
import '../domain/repositories/body_profile_repository.dart';

/// BodyProfileRepository 구현
class BodyProfileRepositoryImpl implements BodyProfileRepository {
  final DatabaseHelper _db;

  BodyProfileRepositoryImpl(this._db);

  @override
  Future<Map<String, dynamic>?> getProfile() => _db.getProfile();

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) =>
      _db.saveProfile(profile);
}
