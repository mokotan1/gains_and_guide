import '../../../../core/database/database_helper.dart';
import '../domain/entities/body_profile.dart';
import '../domain/repositories/body_profile_repository.dart';

class BodyProfileRepositoryImpl implements BodyProfileRepository {
  final DatabaseHelper _db;

  BodyProfileRepositoryImpl(this._db);

  @override
  Future<int> save(BodyProfile profile) =>
      _db.saveProfile(profile.toMap());

  @override
  Future<BodyProfile?> get() async {
    final map = await _db.getProfile();
    return map != null ? BodyProfile.fromMap(map) : null;
  }
}
