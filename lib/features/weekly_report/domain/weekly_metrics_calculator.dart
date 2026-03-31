import 'dart:math';

import '../../../core/constants/report_constants.dart';
import 'models/weekly_metrics.dart';

/// 운동 기록 원시 데이터로부터 주간 지표를 산출하는 순수 함수 집합.
///
/// 외부 의존 없이 [List<Map<String, dynamic>>] 형태의 DB 행만 받아 계산한다.
/// 모든 메서드는 static 이며 부수효과가 없다.
class WeeklyMetricsCalculator {
  WeeklyMetricsCalculator._();

  /// workout_history / cardio_history 행으로부터 [WeeklyMetrics] 를 산출한다.
  ///
  /// - [currentWeekRows] : 이번 주 workout_history (웨이트만)
  /// - [currentCardioRows] : 이번 주 cardio_history
  /// - [chronicWeeklyVolumes] / [chronicWeeklyCardioLoads] : 최근 N주 (최신순, 이번 주 제외)
  /// - [prevWeekRows] : 지난 주 workout_history
  static WeeklyMetrics calculate({
    required List<Map<String, dynamic>> currentWeekRows,
    required List<Map<String, dynamic>> currentCardioRows,
    required List<double> chronicWeeklyVolumes,
    required List<double> chronicWeeklyCardioLoads,
    required List<Map<String, dynamic>> prevWeekRows,
    required Map<String, String> muscleMap,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    final weightEmpty = currentWeekRows.isEmpty;
    final cardioEmpty = currentCardioRows.isEmpty;

    if (weightEmpty && cardioEmpty) {
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
        prevWeekCardioLoad: chronicWeeklyCardioLoads.isNotEmpty
            ? chronicWeeklyCardioLoads.first
            : null,
        cardioSessionLinesForAi: const [],
      );
    }

    final cardioSessionLinesForAi = cardioEmpty
        ? const <String>[]
        : buildCardioSessionLinesForAi(currentCardioRows);

    final totalCardioSessions =
        cardioEmpty ? 0 : _countUniqueDates(currentCardioRows);
    final double totalCardioMinutes =
        cardioEmpty ? 0.0 : _totalCardioMinutes(currentCardioRows);
    final double totalCardioDistance =
        cardioEmpty ? 0.0 : _totalCardioDistance(currentCardioRows);
    final double totalCardioCalories =
        cardioEmpty ? 0.0 : _totalCardioCalories(currentCardioRows);
    final double avgCardioRpe =
        cardioEmpty ? 0.0 : _averageCardioRpe(currentCardioRows);
    final double acuteCardioLoad =
        cardioEmpty ? 0.0 : _acuteCardioLoad(currentCardioRows);
    final double cardioAcwr = cardioEmpty
        ? 0.0
        : _calculateAcwr(acuteCardioLoad, chronicWeeklyCardioLoads);
    final prevWeekCardioLoad = chronicWeeklyCardioLoads.isNotEmpty
        ? chronicWeeklyCardioLoads.first
        : null;

    if (weightEmpty) {
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
        totalCardioSessions: totalCardioSessions,
        totalCardioMinutes: totalCardioMinutes,
        totalCardioDistance: totalCardioDistance,
        totalCardioCalories: totalCardioCalories,
        cardioAcwr: cardioAcwr,
        prevWeekCardioLoad: prevWeekCardioLoad,
        acuteCardioLoad: acuteCardioLoad,
        avgCardioRpe: avgCardioRpe,
        cardioSessionLinesForAi: cardioSessionLinesForAi,
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
      totalCardioSessions: totalCardioSessions,
      totalCardioMinutes: totalCardioMinutes,
      totalCardioDistance: totalCardioDistance,
      totalCardioCalories: totalCardioCalories,
      cardioAcwr: cardioAcwr,
      prevWeekCardioLoad: prevWeekCardioLoad,
      acuteCardioLoad: acuteCardioLoad,
      avgCardioRpe: avgCardioRpe,
      cardioSessionLinesForAi: cardioSessionLinesForAi,
    );
  }

  /// AI 프롬프트용 유산소 세션 한 줄 요약 (날짜순).
  static List<String> buildCardioSessionLinesForAi(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return [];
    final sorted = List<Map<String, dynamic>>.from(rows);
    sorted.sort((a, b) {
      final da = (a['date']?.toString() ?? '').substring(0, 10);
      final db = (b['date']?.toString() ?? '').substring(0, 10);
      return da.compareTo(db);
    });
    return sorted.map(_formatCardioRowForAi).toList();
  }

  static String _formatCardioRowForAi(Map<String, dynamic> r) {
    final name = r['cardio_name'] as String? ?? '';
    final date = (r['date']?.toString() ?? '').length >= 10
        ? (r['date'] as String).substring(0, 10)
        : (r['date']?.toString() ?? '');
    final dm = (r['duration_minutes'] as num?)?.toDouble() ?? 0;
    final dist = r['distance_km'] as num?;
    final avgHr = r['avg_heart_rate'] as int?;
    final maxHr = r['max_heart_rate'] as int?;
    final src = r['source'] as String? ?? 'manual';
    final buf = StringBuffer('$date: $name ${dm.toStringAsFixed(0)}분');
    if (dist != null) {
      buf.write(' (거리: ${dist.toStringAsFixed(1)}km)');
    }
    if (avgHr != null || maxHr != null) {
      buf.write(
        ' (평균 심박: ${avgHr ?? '-'}bpm, 최대 심박: ${maxHr ?? '-'}bpm)',
      );
    } else if (src == 'health') {
      buf.write(' (웨어러블 심박 샘플 없음)');
    } else {
      buf.write(' (수동 기록, 심박 미기록)');
    }
    return buf.toString();
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

  /// ACWR 산출 (웨이트 볼륨 또는 유산소 급성 부하)
  static double calculateAcwr(
    double acuteVolume,
    List<double> chronicWeeklyVolumes,
  ) =>
      _calculateAcwr(acuteVolume, chronicWeeklyVolumes);

  static double acuteCardioLoad(List<Map<String, dynamic>> rows) =>
      _acuteCardioLoad(rows);

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

  static double _totalCardioMinutes(List<Map<String, dynamic>> rows) {
    return rows.fold(0.0, (sum, row) {
      return sum + ((row['duration_minutes'] as num?)?.toDouble() ?? 0);
    });
  }

  static double _totalCardioDistance(List<Map<String, dynamic>> rows) {
    return rows.fold(0.0, (sum, row) {
      return sum + ((row['distance_km'] as num?)?.toDouble() ?? 0);
    });
  }

  static double _totalCardioCalories(List<Map<String, dynamic>> rows) {
    return rows.fold(0.0, (sum, row) {
      return sum + ((row['calories'] as num?)?.toDouble() ?? 0);
    });
  }

  static double _averageCardioRpe(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 0;
    final rpes = rows
        .map((r) => (r['rpe'] as num?)?.toDouble())
        .where((r) => r != null)
        .cast<double>()
        .toList();
    if (rpes.isEmpty) return 0;
    return rpes.reduce((a, b) => a + b) / rpes.length;
  }

  static double _acuteCardioLoad(List<Map<String, dynamic>> rows) {
    return rows.fold(0.0, (sum, row) {
      final dm = (row['duration_minutes'] as num?)?.toDouble() ?? 0;
      final r = (row['rpe'] as num?)?.toDouble() ?? 0;
      final rpe = r < 1 ? 1.0 : r;
      return sum + dm * rpe;
    });
  }
}
