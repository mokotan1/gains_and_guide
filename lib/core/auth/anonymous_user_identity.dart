import 'user_identity.dart';

/// 인증 시스템 도입 전까지 사용하는 익명 사용자 구현.
///
/// `--dart-define=DEFAULT_USER_ID=xxx` 로 빌드 타임에 오버라이드 가능.
class AnonymousUserIdentity implements UserIdentity {
  @override
  final String userId;

  const AnonymousUserIdentity({
    this.userId = const String.fromEnvironment(
      'DEFAULT_USER_ID',
      defaultValue: 'master_user',
    ),
  });
}
