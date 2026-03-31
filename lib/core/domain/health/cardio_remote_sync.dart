/// 웨어러블 유산소 행을 원격(Supabase 등)에 반영한다. 세션이 없으면 no-op.
abstract class CardioRemoteSync {
  /// [startDate]~[endDate] 구간의 `source=health` 행을 원격에서 제거한 뒤 [rows]를 삽입한다.
  Future<void> pushHealthCardioWindow({
    required String userId,
    required String startDate,
    required String endDate,
    required List<Map<String, dynamic>> rows,
  });
}
