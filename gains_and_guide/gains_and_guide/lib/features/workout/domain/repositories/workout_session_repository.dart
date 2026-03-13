import '../entities/exercise.dart';

/// 현재 운동 세션·주간 프로그램 저장소 (SharedPreferences 등) — 도메인 포트
abstract class WorkoutSessionRepository {
  Future<Map<int, List<Exercise>>> loadWeeklyProgram();
  Future<void> saveWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine);
  Future<List<Exercise>?> loadCurrentSession();
  Future<void> saveCurrentSession(List<Exercise> state, bool isFinished);
  Future<void> clearSession();
  Future<String?> getLastDate();
  Future<void> updateLastDate(String date);
  Future<bool> getIsFinished();
}
