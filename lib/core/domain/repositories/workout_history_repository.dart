/// 운동 기록 조회/저장 추상화 (DIP: 고수준이 저수준에 의존하지 않음)
abstract class WorkoutHistoryRepository {
  Future<List<Map<String, dynamic>>> getAllHistory();
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history);
}
