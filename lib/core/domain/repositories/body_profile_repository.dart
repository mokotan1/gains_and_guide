/// 신체 프로필 조회/저장 추상화
abstract class BodyProfileRepository {
  Future<Map<String, dynamic>?> getProfile();
  Future<void> saveProfile(Map<String, dynamic> profile);
}
