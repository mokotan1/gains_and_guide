/// 운동 기록 저장/조회 — 도메인 리포지토리(포트)
abstract class WorkoutHistoryRepository {
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history);
  Future<List<Map<String, dynamic>>> getAllHistory();
}
