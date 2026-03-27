import '../database/database_helper.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/user_profile_repository.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final DatabaseHelper _db;

  UserProfileRepositoryImpl(this._db);

  @override
  Future<UserProfile?> getProfile() async {
    final map = await _db.getUserProfile();
    if (map == null) return null;
    return UserProfile.fromMap(map);
  }

  @override
  Future<void> saveProfile(UserProfile profile) =>
      _db.saveUserProfile(profile.toMap());

  @override
  Future<bool> isOnboardingCompleted() => _db.hasUserProfile();
}
