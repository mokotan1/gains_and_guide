import '../models/user_profile.dart';

/// 유저 프로필(온보딩 설문 결과) 저장/조회 계약
abstract class UserProfileRepository {
  Future<UserProfile?> getProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<bool> isOnboardingCompleted();
}
