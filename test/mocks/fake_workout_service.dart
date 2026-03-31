import 'package:gains_and_guide/core/database/database_helper.dart';
import 'package:gains_and_guide/core/domain/repositories/cardio_history_repository.dart';
import 'package:gains_and_guide/core/domain/repositories/progression_repository.dart';
import 'package:gains_and_guide/core/domain/repositories/workout_history_repository.dart';
import 'package:gains_and_guide/features/routine/application/workout_service.dart';
import 'package:gains_and_guide/features/routine/data/routine_repository.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';

/// [WorkoutService] 의 테스트용 Fake.
///
/// 모든 public 메서드를 오버라이드하므로 super 의 DB/SharedPreferences
/// 호출은 절대 발생하지 않는다.
class FakeWorkoutService extends WorkoutService {
  Map<int, List<Exercise>> weeklyProgram = {};
  List<Exercise>? currentSession;
  String? lastDate;
  bool isFinished = false;
  Map<String, double> latestWeights = {};
  List<Map<String, dynamic>> history = [];

  List<Map<String, dynamic>> savedHistoryData = [];
  Map<String, double> savedProgressions = {};
  Map<int, List<Exercise>>? savedWeeklyProgram;

  FakeWorkoutService()
      : super(
          RoutineRepository(DatabaseHelper.instance),
          _NoopHistoryRepo(),
          _NoopCardioRepo(),
          _NoopProgressionRepo(),
        );

  @override
  Future<Map<int, List<Exercise>>> loadWeeklyProgram() async => weeklyProgram;

  @override
  Future<void> saveWeeklyProgram(Map<int, List<Exercise>> wr) async {
    savedWeeklyProgram = wr;
  }

  @override
  Future<List<Exercise>?> loadCurrentSession() async => currentSession;

  @override
  Future<void> saveCurrentSession(List<Exercise> state, bool fin) async {
    currentSession = state;
    isFinished = fin;
  }

  @override
  Future<void> clearSession() async {
    currentSession = null;
    isFinished = false;
  }

  @override
  Future<String?> getLastDate() async => lastDate;

  @override
  Future<void> updateLastDate(String date) async => lastDate = date;

  @override
  Future<bool> getIsFinished() async => isFinished;

  @override
  Future<double?> getLatestWeight(String name) async =>
      latestWeights[name];

  @override
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> data) async {
    savedHistoryData.addAll(data);
  }

  @override
  Future<void> saveProgression(String name, double weight) async {
    savedProgressions[name] = weight;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllHistory() async => history;
}

class _NoopHistoryRepo implements WorkoutHistoryRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllHistory() async => [];

  @override
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history) async {}

  @override
  Future<List<Map<String, dynamic>>> getRecentSessionsByExercise(
    String exerciseName,
    int sessionLimit, {
    bool excludeDeload = false,
  }) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getRecentSessions(
    int sessionLimit, {
    bool excludeDeload = false,
  }) async =>
      [];

  @override
  Future<List<String>> getDistinctWorkoutSessionDates() async => [];

  @override
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  ) async =>
      [];

  @override
  Future<List<double>> getWeeklyVolumes(int weekCount) async => [];
}

class _NoopCardioRepo implements CardioHistoryRepository {
  @override
  Future<void> saveCardioHistory(List<Map<String, dynamic>> rows) async {}

  @override
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  ) async =>
      [];

  @override
  Future<List<double>> getWeeklyCardioLoads(int weekCount) async => [];
}

class _NoopProgressionRepo implements ProgressionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
