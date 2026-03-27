/// 현재 사용자를 식별하는 추상 인터페이스.
///
/// 향후 Firebase Auth 등 본격적인 인증 시스템 도입 시
/// 이 인터페이스를 구현하는 새 클래스를 주입하면 된다.
abstract class UserIdentity {
  String get userId;
}
