import 'dart:convert';

import 'report_section.dart';
import 'weekly_metrics.dart';

/// 주간 레포트 최종 결과물 (불변 값 객체)
///
/// 로컬 규칙 기반으로 생성된 4개 섹션 + 선택적 AI 코멘트를 포함한다.
class WeeklyReport {
  final DateTime weekStart;
  final DateTime weekEnd;
  final ReportHeadline headline;
  final List<PerformanceInsight> performances;
  final List<WarningInsight> warnings;
  final List<ActionItem> actionItems;
  final WeeklyMetrics metrics;

  /// AI 서버에서 받은 자연어 보강 코멘트 (optional)
  final String? aiComment;
  final DateTime generatedAt;

  const WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.headline,
    required this.performances,
    required this.warnings,
    required this.actionItems,
    required this.metrics,
    this.aiComment,
    required this.generatedAt,
  });

  WeeklyReport copyWith({String? aiComment}) {
    return WeeklyReport(
      weekStart: weekStart,
      weekEnd: weekEnd,
      headline: headline,
      performances: performances,
      warnings: warnings,
      actionItems: actionItems,
      metrics: metrics,
      aiComment: aiComment ?? this.aiComment,
      generatedAt: generatedAt,
    );
  }

  /// SQLite 저장용 JSON 직렬화
  String toJsonString() {
    final map = {
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'headline': headline.toJson(),
      'performances': performances.map((p) => p.toJson()).toList(),
      'warnings': warnings.map((w) => w.toJson()).toList(),
      'actionItems': actionItems.map((a) => a.toJson()).toList(),
      'aiComment': aiComment,
      'generatedAt': generatedAt.toIso8601String(),
      'totalVolume': metrics.totalVolume,
      'avgRpe': metrics.avgRpe,
      'acwr': metrics.acwr,
      'totalSessions': metrics.totalSessions,
      'failureRate': metrics.failureRate,
      'prevWeekVolume': metrics.prevWeekVolume,
      'volumeByMuscle': metrics.volumeByMuscle,
      'estimated1RMs': metrics.estimated1RMs
          .map((k, v) => MapEntry(k, v.toJson())),
      'exerciseDeltas':
          metrics.exerciseDeltas.map((d) => d.toJson()).toList(),
    };
    return jsonEncode(map);
  }

  factory WeeklyReport.fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;

    final volumeByMuscle = (map['volumeByMuscle'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
        {};

    final estimated1RMs = (map['estimated1RMs'] as Map<String, dynamic>?)
            ?.map((k, v) =>
                MapEntry(k, Estimated1RM.fromJson(v as Map<String, dynamic>))) ??
        {};

    final exerciseDeltas = (map['exerciseDeltas'] as List<dynamic>?)
            ?.map((d) =>
                ExerciseWeeklyDelta.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];

    final weekStart = DateTime.parse(map['weekStart'] as String);
    final weekEnd = DateTime.parse(map['weekEnd'] as String);

    final metrics = WeeklyMetrics(
      weekStart: weekStart,
      weekEnd: weekEnd,
      totalSessions: map['totalSessions'] as int? ?? 0,
      totalVolume: (map['totalVolume'] as num?)?.toDouble() ?? 0,
      avgRpe: (map['avgRpe'] as num?)?.toDouble() ?? 0,
      acwr: (map['acwr'] as num?)?.toDouble() ?? 0,
      volumeByMuscle: volumeByMuscle,
      estimated1RMs: estimated1RMs,
      failureRate: (map['failureRate'] as num?)?.toDouble() ?? 0,
      prevWeekVolume: (map['prevWeekVolume'] as num?)?.toDouble(),
      exerciseDeltas: exerciseDeltas,
    );

    return WeeklyReport(
      weekStart: weekStart,
      weekEnd: weekEnd,
      headline: ReportHeadline.fromJson(
          map['headline'] as Map<String, dynamic>),
      performances: (map['performances'] as List<dynamic>)
          .map((p) =>
              PerformanceInsight.fromJson(p as Map<String, dynamic>))
          .toList(),
      warnings: (map['warnings'] as List<dynamic>)
          .map((w) => WarningInsight.fromJson(w as Map<String, dynamic>))
          .toList(),
      actionItems: (map['actionItems'] as List<dynamic>)
          .map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
          .toList(),
      metrics: metrics,
      aiComment: map['aiComment'] as String?,
      generatedAt: DateTime.parse(map['generatedAt'] as String),
    );
  }
}
