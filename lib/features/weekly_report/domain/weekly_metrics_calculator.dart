import 'dart:math';

import '../../../core/constants/report_constants.dart';
import 'models/weekly_metrics.dart';

/// 운동 기록 원시 데이터로부터 주간 지표를 산출하는 순수 함수 집합.
///
/// 외부 의존 없이 [List<Map<String, dynamic>>] 형태의 DB 행만 받아 계산한다.
/// 모든 메서드는 static 이며 부수효과가 없다.
class WeeklyMetricsCalculator {
  WeeklyMetricsCalculator._();

  /// workout_history 행 리스트와 부가 정보로부터 [WeeklyMetrics] 를 산출한다.
  ///
  /// - [currentWeekRows] : 이번 주 workout_history 행 (name, sets, reps, weight, rpe, date)
  /// - [chronicWeeklyVolumes] : 최근 N주간의 주별 총 볼륨 리스트 (최신순, 이번 주 제외)
  /// - [prevWeekRows] : 지난 주 workout_history 행 (1RM·무게 비교용)
  /// - [muscleMap] : 운동명 → 주요 근육군 매핑 (exercise_catalog 에서 추출)
  /// - [weekStart], [weekEnd] : 이번 주 시작/종료 날짜
  static WeeklyMetrics calculate({
    required List<Map<String, dynamic>> currentWeekRows,
    required List<double> chronicWeeklyVolumes,
    required List<Map<String, dynamic>> prevWeekRows,
    required Map<String, String> muscleMap,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    if (currentWeekRows.isEmpty) {
      return WeeklyMetrics(
        weekStart: weekStart,
        weekEnd: weekEnd,
        totalSessions: 0,
        totalVolume: 0,
        avgRpe: 0,
        acwr: 0,
        volumeByMuscle: const {},
        estimated1RMs: const {},
        failureRate: 0,
        prevWeekVolume:
            chronicWeeklyVolumes.isNotEmpty ? chronicWeeklyVolumes.first : null,
        exerciseDeltas: const [],
      );
    }

    final totalSessions = _countUniqueDates(currentWeekRows);
    final totalVolume = _totalVolume(currentWeekRows);
    final avgRpe = _averageRpe(currentWeekRows);
    final acwr = _calculateAcwr(totalVolume, chronicWeeklyVolumes);
    final volumeByMuscle =
        _volumeByMuscleGroup(currentWeekRows, muscleMap);
    final failureRate = _failureRate(currentWeekRows);

    final currentEstimates = _estimated1RMs(currentWeekRows);
    final prevEstimates = _estimated1RMs(prevWeekRows);
    final estimated1RMs = _mergeEstimates(currentEstimates, prevEstimates);

    final exerciseDeltas =
        _exerciseDeltas(currentWeekRows, prevWeekRows);

    final prevWeekVolume = chronicWeeklyVolumes.isNotEmpty
        ? chronicWeeklyVolumes.first
        : null;

    return WeeklyMetrics(
      weekStart: weekStart,
      weekEnd: weekEnd,
      totalSessions: totalSessions,
      totalVolume: totalVolume,
      avgRpe: avgRpe,
      acwr: acwr,
      volumeByMuscle: volumeByMuscle,
      estimated1RMs: estimated1RMs,
      failureRate: failureRate,
      prevWeekVolume: prevWeekVolume,
      exerciseDeltas: exerciseDeltas,
    );
  }

  // ---------------------------------------------------------------------------
  // 개별 지표 산출 (패키지 외부에서도 단독 테스트 가능하도록 static 공개)
  // ---------------------------------------------------------------------------

  /// 총 볼륨 = SUM(weight × reps)
  static double totalVolume(List<Map<String, dynamic>> rows) =>
      _totalVolume(rows);

  /// 평균 RPE
  static double averageRpe(List<Map<String, dynamic>> rows) =>
      _averageRpe(rows);

  /// ACWR 산출
  static double calculateAcwr(
    double acuteVolume,
    List<double> chronicWeeklyVolumes,
  ) =>
      _calculateAcwr(acuteVolume, chronicWeeklyVolumes);

  /// Epley 공식으로 1RM 추정: weight × (1 + reps / 30)
  static double epley1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / ReportConstants.epleyDivisor);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static double _totalVolume(List<Map<String, dynamic>> rows) {
    return rows.fold(0.0, (sum, row) {
      final weight = (row['weight'] as num?)?.toDouble() ?? 0;
      final reps = (row['reps'] as num?)?.toInt() ?? 0;
      return sum + weight * reps;
    });
  }

  static double _averageRpe(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 0;
    final rpes = rows
        .map((r) => (r['rpe'] as num?)?.toDouble())
        .where((r) => r != null)
        .cast<double>()
        .toList();
    if (rpes.isEmpty) return 0;
    return rpes.reduce((a, b) => a + b) / rpes.length;
  }

  static int _countUniqueDates(List<Map<String, dynamic>> rows) {
    final dates = <String>{};
    for (final row in rows) {
      final date = row['date']?.toString();
      if (date != null && date.length >= 10) {
        dates.add(date.substring(0, 10));
      }
    }
    return dates.length;
  }

  static double _calculateAcwr(
    double acuteVolume,
    List<double> chronicWeeklyVolumes,
  ) {
    if (chronicWeeklyVolumes.isEmpty) return 0;
    final chronicAvg =
        chronicWeeklyVolumes.reduce((a, b) => a + b) / chronicWeeklyVolumes.length;
    if (chronicAvg <= 0) return 0;
    return acuteVolume / chronicAvg;
  }

  static Map<String, double> _volumeByMuscleGroup(
    List<Map<String, dynamic>> rows,
    Map<String, String> muscleMap,
  ) {
    final result = <String, double>{};
    for (final row in rows) {
      final name = row['name'] as String? ?? '';
      final weight = (row['weight'] as num?)?.toDouble() ?? 0;
      final reps = (row['reps'] as num?)?.toInt() ?? 0;
      final volume = weight * reps;

      final muscle = muscleMap[name] ?? 'other';
      result[muscle] = (result[muscle] ?? 0) + volume;
    }
    return result;
  }

  static double _failureRate(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 0;
    final failed = rows.where((r) => (r['rpe'] as num?)?.toInt() == 10).length;
    return failed / rows.length;
  }

  /// 운동별 베스트 세트 기준 Epley 1RM 산출
  static Map<String, double> _estimated1RMs(
    List<Map<String, dynamic>> rows,
  ) {
    final best = <String, double>{};
    for (final row in rows) {
      final name = row['name'] as String? ?? '';
      final weight = (row['weight'] as num?)?.toDouble() ?? 0;
      final reps = (row['reps'] as num?)?.toInt() ?? 0;
      final est = epley1RM(weight, reps);
      if (est > (best[name] ?? 0)) {
        best[name] = est;
      }
    }
    return best;
  }

  static Map<String, Estimated1RM> _mergeEstimates(
    Map<String, double> current,
    Map<String, double> previous,
  ) {
    final result = <String, Estimated1RM>{};
    for (final entry in current.entries) {
      result[entry.key] = Estimated1RM(
        exerciseName: entry.key,
        current1RM: _round1(entry.value),
        previous1RM:
            previous.containsKey(entry.key) ? _round1(previous[entry.key]!) : null,
      );
    }
    return result;
  }

  static List<ExerciseWeeklyDelta> _exerciseDeltas(
    List<Map<String, dynamic>> currentRows,
    List<Map<String, dynamic>> prevRows,
  ) {
    final currentMax = _maxWeightByExercise(currentRows);
    final prevMax = _maxWeightByExercise(prevRows);

    return currentMax.entries.map((e) {
      return ExerciseWeeklyDelta(
        exerciseName: e.key,
        thisWeekMaxWeight: e.value,
        lastWeekMaxWeight: prevMax[e.key],
      );
    }).toList();
  }

  static Map<String, double> _maxWeightByExercise(
    List<Map<String, dynamic>> rows,
  ) {
    final result = <String, double>{};
    for (final row in rows) {
      final name = row['name'] as String? ?? '';
      final weight = (row['weight'] as num?)?.toDouble() ?? 0;
      result[name] = max(result[name] ?? 0, weight);
    }
    return result;
  }

  static double _round1(double value) =>
      (value * 10).roundToDouble() / 10;
}
