/// 증량 기록 조회/저장 추상화
abstract class ProgressionRepository {
  Future<double?> getLatestWeight(String exerciseName);
  Future<void> saveProgression(String exerciseName, double weight);

  /// 특정 운동의 최근 프로그레션 이력 (디로드 정체/퇴보 분석용)
  Future<List<Map<String, dynamic>>> getRecentProgressions(
    String exerciseName,
    int limit,
  );
}
