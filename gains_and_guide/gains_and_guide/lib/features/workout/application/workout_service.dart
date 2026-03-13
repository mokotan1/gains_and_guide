import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/exercise.dart';
import '../domain/repositories/progression_repository.dart';
import '../domain/repositories/workout_history_repository.dart';
import '../domain/repositories/workout_session_repository.dart';
import '../infrastructure/providers.dart';

class WorkoutService {
  final WorkoutSessionRepository _sessionRepo;
  final WorkoutHistoryRepository _historyRepo;
  final ProgressionRepository _progressionRepo;

  WorkoutService(
    this._sessionRepo,
    this._historyRepo,
    this._progressionRepo,
  );

  Future<Map<int, List<Exercise>>> loadWeeklyProgram() =>
      _sessionRepo.loadWeeklyProgram();

  Future<void> saveWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) =>
      _sessionRepo.saveWeeklyProgram(weeklyRoutine);

  Future<List<Exercise>?> loadCurrentSession() =>
      _sessionRepo.loadCurrentSession();

  Future<void> saveCurrentSession(List<Exercise> state, bool isFinished) =>
      _sessionRepo.saveCurrentSession(state, isFinished);

  Future<void> clearSession() => _sessionRepo.clearSession();

  Future<String?> getLastDate() => _sessionRepo.getLastDate();

  Future<void> updateLastDate(String date) => _sessionRepo.updateLastDate(date);

  Future<bool> getIsFinished() => _sessionRepo.getIsFinished();

  Future<double?> getLatestWeight(String name) =>
      _progressionRepo.getLatestWeight(name);

  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> historyData) =>
      _historyRepo.saveWorkoutHistory(historyData);

  Future<void> saveProgression(String name, double weight) =>
      _progressionRepo.saveProgression(name, weight);

  Future<List<Map<String, dynamic>>> getAllHistory() =>
      _historyRepo.getAllHistory();
}

final workoutServiceProvider = Provider<WorkoutService>((ref) {
  return WorkoutService(
    ref.watch(workoutSessionRepositoryProvider),
    ref.watch(workoutHistoryRepositoryProvider),
    ref.watch(progressionRepositoryProvider),
  );
});
