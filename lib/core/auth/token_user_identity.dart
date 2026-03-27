import 'user_identity.dart';

/// [AuthSession.subject] 와 동기화되는 [UserIdentity].
class TokenUserIdentity implements UserIdentity {
  @override
  final String userId;

  const TokenUserIdentity(this.userId);
}
