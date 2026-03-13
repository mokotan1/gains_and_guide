/// 증량/최신 무게 — 도메인 리포지토리(포트)
abstract class ProgressionRepository {
  Future<void> saveProgression(String exerciseName, double weight);
  Future<double?> getLatestWeight(String exerciseName);
}
