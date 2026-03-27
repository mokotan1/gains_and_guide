/// 주간 운동 데이터에서 산출된 원시 지표 (불변 값 객체)
class WeeklyMetrics {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalSessions;
  final double totalVolume;
  final double avgRpe;

  /// Acute:Chronic Workload Ratio (이번 주 볼륨 / 최근 4주 평균 볼륨)
  final double acwr;

  /// 근육군별 볼륨 분포 (예: {"chest": 5000.0, "back": 3200.0})
  final Map<String, double> volumeByMuscle;

  /// 운동별 예상 1RM
  final Map<String, Estimated1RM> estimated1RMs;

  /// 세트 실패율 (RPE 10 세트 / 전체 세트)
  final double failureRate;

  /// 지난 주 총 볼륨 (주 대비 비교용, 데이터 없으면 null)
  final double? prevWeekVolume;

  /// 운동별 주간 무게 변동
  final List<ExerciseWeeklyDelta> exerciseDeltas;

  const WeeklyMetrics({
    required this.weekStart,
    required this.weekEnd,
    required this.totalSessions,
    required this.totalVolume,
    required this.avgRpe,
    required this.acwr,
    required this.volumeByMuscle,
    required this.estimated1RMs,
    required this.failureRate,
    this.prevWeekVolume,
    this.exerciseDeltas = const [],
  });

  /// 볼륨 주간 증감률 (%). prevWeekVolume 이 없으면 null.
  double? get volumeChangePercent {
    if (prevWeekVolume == null || prevWeekVolume == 0) return null;
    return ((totalVolume - prevWeekVolume!) / prevWeekVolume!) * 100;
  }

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  WeeklyMetrics.empty()
      : weekStart = _epoch,
        weekEnd = _epoch,
        totalSessions = 0,
        totalVolume = 0,
        avgRpe = 0,
        acwr = 0,
        volumeByMuscle = const {},
        estimated1RMs = const {},
        failureRate = 0,
        prevWeekVolume = null,
        exerciseDeltas = const [];
}

/// 운동별 예상 1RM (Epley 공식 기반)
class Estimated1RM {
  final String exerciseName;

  /// 이번 주 예상 1RM (kg)
  final double current1RM;

  /// 지난 주 예상 1RM (데이터 없으면 null)
  final double? previous1RM;

  const Estimated1RM({
    required this.exerciseName,
    required this.current1RM,
    this.previous1RM,
  });

  /// 1RM 변동률 (%). previous1RM 이 없으면 null.
  double? get deltaPercent {
    if (previous1RM == null || previous1RM == 0) return null;
    return ((current1RM - previous1RM!) / previous1RM!) * 100;
  }

  /// 절대 변동량 (kg)
  double? get deltaKg {
    if (previous1RM == null) return null;
    return current1RM - previous1RM!;
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'current1RM': current1RM,
        'previous1RM': previous1RM,
      };

  factory Estimated1RM.fromJson(Map<String, dynamic> json) {
    return Estimated1RM(
      exerciseName: json['exerciseName'] as String,
      current1RM: (json['current1RM'] as num).toDouble(),
      previous1RM: (json['previous1RM'] as num?)?.toDouble(),
    );
  }
}

/// 운동별 주간 무게 변동
class ExerciseWeeklyDelta {
  final String exerciseName;
  final double thisWeekMaxWeight;
  final double? lastWeekMaxWeight;

  const ExerciseWeeklyDelta({
    required this.exerciseName,
    required this.thisWeekMaxWeight,
    this.lastWeekMaxWeight,
  });

  /// 절대 변동량 (kg)
  double? get deltaKg {
    if (lastWeekMaxWeight == null) return null;
    return thisWeekMaxWeight - lastWeekMaxWeight!;
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'thisWeekMaxWeight': thisWeekMaxWeight,
        'lastWeekMaxWeight': lastWeekMaxWeight,
      };

  factory ExerciseWeeklyDelta.fromJson(Map<String, dynamic> json) {
    return ExerciseWeeklyDelta(
      exerciseName: json['exerciseName'] as String,
      thisWeekMaxWeight: (json['thisWeekMaxWeight'] as num).toDouble(),
      lastWeekMaxWeight: (json['lastWeekMaxWeight'] as num?)?.toDouble(),
    );
  }
}
