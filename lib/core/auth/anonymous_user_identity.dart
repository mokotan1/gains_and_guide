import 'user_identity.dart';

/// 테스트·레거시 전용: 고정 userId (프로덕션 앱은 [TokenUserIdentity] + [AuthSession] 사용).
///
/// `--dart-define=DEFAULT_USER_ID=xxx` 로 빌드 타임에 오버라이드 가능.
class AnonymousUserIdentity implements UserIdentity {
  @override
  final String userId;

  const AnonymousUserIdentity({
    this.userId = const String.fromEnvironment(
      'DEFAULT_USER_ID',
      defaultValue: 'test_user',
    ),
  });
}
