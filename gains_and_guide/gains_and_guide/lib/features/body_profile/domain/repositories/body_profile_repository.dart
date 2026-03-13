import '../entities/body_profile.dart';

/// 신체 프로필 저장/조회 — 도메인 리포지토리(포트)
abstract class BodyProfileRepository {
  Future<int> save(BodyProfile profile);
  Future<BodyProfile?> get();
}
