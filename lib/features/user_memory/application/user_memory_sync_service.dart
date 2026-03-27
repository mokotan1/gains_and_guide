import '../../../core/auth/auth_session.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';

/// 주간 요약 등을 `/memory/chunks` 로 동기화한다.
///
/// `--dart-define=ENABLE_MEMORY_SYNC=true` 일 때만 동작하며, Bearer 토큰이 있을 때만 호출한다.
class UserMemorySyncService {
  UserMemorySyncService(this._apiClient);

  final ApiClient _apiClient;

  static bool get enabled => const bool.fromEnvironment(
        'ENABLE_MEMORY_SYNC',
        defaultValue: false,
      );

  Future<void> uploadWeeklyDigest(String weekKey, String summaryText) async {
    if (!enabled) return;
    if (summaryText.isEmpty) return;
    if (!AuthSession.instance.hasBearer) return;
    try {
      await _apiClient.post(
        '/memory/chunks',
        {
          'chunks': [
            {
              'text': summaryText,
              'source': 'weekly_report',
              'topic': weekKey,
              'client_chunk_id': 'weekly_$weekKey',
            },
          ],
        },
      );
    } on AppException {
      // 보조 기능: 실패는 무시
    }
  }
}
