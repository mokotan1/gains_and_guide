/// 운동 기록 조회/저장 추상화 (DIP: 고수준이 저수준에 의존하지 않음)
abstract class WorkoutHistoryRepository {
  Future<List<Map<String, dynamic>>> getAllHistory();
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history);

  /// 특정 운동의 최근 N개 세션 기록 (디로드 분석용)
  Future<List<Map<String, dynamic>>> getRecentSessionsByExercise(
    String exerciseName,
    int sessionLimit,
  );

  /// 최근 N개 세션의 전체 기록 (세션 = 고유 날짜)
  Future<List<Map<String, dynamic>>> getRecentSessions(int sessionLimit);
}
