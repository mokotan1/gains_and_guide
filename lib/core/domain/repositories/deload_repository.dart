/// 디로드 이력 조회/저장 추상화 (DIP: 고수준이 저수준에 의존하지 않음)
abstract class DeloadRepository {
  Future<DateTime?> getLastDeloadEndDate();
  Future<void> saveDeloadRecord({
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required double fatigueScore,
    required int cycleSessions,
  });
  Future<bool> isCurrentlyInDeload();
  Future<void> decrementDeloadSession();

  /// remaining_sessions > 0인 활성 디로드 레코드 반환 (없으면 null)
  Future<Map<String, dynamic>?> getActiveDeloadRecord();
}
