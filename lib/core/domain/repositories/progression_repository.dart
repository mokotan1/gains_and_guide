/// 증량 기록 조회/저장 추상화
abstract class ProgressionRepository {
  Future<double?> getLatestWeight(String exerciseName);
  Future<void> saveProgression(String exerciseName, double weight);
}
