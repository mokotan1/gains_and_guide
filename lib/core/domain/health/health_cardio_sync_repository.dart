import 'health_cardio_sync_result.dart';

/// Apple Health / Health Connect에서 유산소·심박 데이터를 읽어 로컬 DB에 반영한다.
abstract class HealthCardioSyncRepository {
  /// 최근 [lookbackDays]일 구간의 유산소 워크아웃을 가져와 `cardio_history`에 저장한다.
  /// 동일 기간에 `source=health` 행은 삭제 후 재삽입한다.
  Future<HealthCardioSyncResult> syncCardioFromHealth({
    required String userId,
    int lookbackDays = 7,
  });
}
