/// HealthKit / Health Connect에서 유산소 데이터를 가져와 DB에 반영한 결과.
class HealthCardioSyncResult {
  final bool success;
  final int sessionsImported;
  final String? message;

  const HealthCardioSyncResult({
    required this.success,
    required this.sessionsImported,
    this.message,
  });

  factory HealthCardioSyncResult.skipped(String reason) => HealthCardioSyncResult(
        success: false,
        sessionsImported: 0,
        message: reason,
      );

  factory HealthCardioSyncResult.ok(int count) => HealthCardioSyncResult(
        success: true,
        sessionsImported: count,
        message: null,
      );

  factory HealthCardioSyncResult.failure(String message) => HealthCardioSyncResult(
        success: false,
        sessionsImported: 0,
        message: message,
      );
}
