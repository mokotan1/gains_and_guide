/// 운동 기록 조회/저장 추상화 (DIP: 고수준이 저수준에 의존하지 않음)
abstract class WorkoutHistoryRepository {
  Future<List<Map<String, dynamic>>> getAllHistory();
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history);

  /// 특정 운동의 최근 N개 세션 기록 (디로드 분석용)
  Future<List<Map<String, dynamic>>> getRecentSessionsByExercise(
    String exerciseName,
    int sessionLimit, {
    bool excludeDeload = false,
  });

  /// 최근 N개 세션의 전체 기록 (세션 = 고유 날짜)
  Future<List<Map<String, dynamic>>> getRecentSessions(
    int sessionLimit, {
    bool excludeDeload = false,
  });

  /// 기록이 있는 운동일 목록 (최신순)
  Future<List<String>> getDistinctWorkoutSessionDates();

  /// 날짜 범위 내의 모든 기록 조회 (주간 레포트용)
  /// [startDate], [endDate] 는 'YYYY-MM-DD' 형식.
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  );

  /// 주별 총 볼륨 리스트 반환 (최신순, [weekCount] 주간)
  /// 반환값: 주별 SUM(weight * reps) 리스트
  Future<List<double>> getWeeklyVolumes(int weekCount);
}
