import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/domain/repositories/exercise_catalog_repository.dart';
import '../domain/models/recommended_routine.dart';
import '../domain/models/report_section.dart';
import '../domain/models/weekly_report.dart';

/// 주간 분석 데이터를 바탕으로 AI 서버에 다음 주 루틴 추천을 요청하는 서비스.
///
/// 책임:
/// 1) [WeeklyReport]에서 구조화된 페이로드 조립
/// 2) POST /recommend 호출
/// 3) 응답 파싱 → [RecommendedRoutine] 변환
/// 4) 운동명을 카탈로그 기준으로 정규화
class RoutineRecommendationService {
  final ExerciseCatalogRepository _catalogRepo;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 45);

  RoutineRecommendationService(
    this._catalogRepo, {
    String baseUrl = 'https://gains-and-guide-1.onrender.com',
  }) : _baseUrl = baseUrl;

  /// [report] 의 메트릭스·경고·액션아이템을 분석하여 추천 루틴을 반환한다.
  ///
  /// AI 서버 호출 실패 또는 파싱 실패 시 null 반환 (graceful degradation).
  Future<RecommendedRoutine?> recommend(WeeklyReport report) async {
    try {
      final payload = _buildPayload(report);

      final response = await http
          .post(
            Uri.parse('$_baseUrl/recommend'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': 'master_user',
              'weekly_summary': payload,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final routineJson = data['routine'] as Map<String, dynamic>?;
      if (routineJson == null) return null;

      final raw = RecommendedRoutine.fromJson({
        ...routineJson,
        'generatedAt': DateTime.now().toIso8601String(),
      });

      return await _normalizeExerciseNames(raw);
    } catch (_) {
      return null;
    }
  }

  /// [WeeklyReport] 를 AI가 소화할 수 있는 구조화된 텍스트로 변환한다.
  String _buildPayload(WeeklyReport report) {
    final m = report.metrics;
    final buf = StringBuffer()
      ..writeln('=== 주간 운동 분석 데이터 ===')
      ..writeln('기간: ${_dateStr(m.weekStart)} ~ ${_dateStr(m.weekEnd)}')
      ..writeln('훈련 횟수: ${m.totalSessions}회')
      ..writeln('총 볼륨: ${m.totalVolume.toStringAsFixed(0)}kg')
      ..writeln('평균 RPE: ${m.avgRpe.toStringAsFixed(1)}')
      ..writeln('ACWR: ${m.acwr.toStringAsFixed(2)}')
      ..writeln('실패율: ${(m.failureRate * 100).toStringAsFixed(0)}%');

    if (m.prevWeekVolume != null) {
      buf.writeln(
          '지난 주 볼륨: ${m.prevWeekVolume!.toStringAsFixed(0)}kg');
      final change = m.volumeChangePercent;
      if (change != null) {
        buf.writeln(
            '볼륨 변화율: ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%');
      }
    }

    buf.writeln();

    if (m.volumeByMuscle.isNotEmpty) {
      buf.writeln('근육군별 볼륨:');
      for (final entry in m.volumeByMuscle.entries) {
        buf.writeln('- ${entry.key}: ${entry.value.toStringAsFixed(0)}kg');
      }
      buf.writeln();
    }

    if (m.estimated1RMs.isNotEmpty) {
      buf.writeln('운동별 예상 1RM 변동:');
      for (final est in m.estimated1RMs.values) {
        buf.write('- ${est.exerciseName}: ${est.current1RM.toStringAsFixed(1)}kg');
        if (est.previous1RM != null) {
          final delta = est.deltaKg;
          buf.write(
              ' (지난주 ${est.previous1RM!.toStringAsFixed(1)}kg, '
              '${delta != null && delta >= 0 ? '+' : ''}${delta?.toStringAsFixed(1) ?? '?'}kg)');
        }
        buf.writeln();
      }
      buf.writeln();
    }

    if (m.exerciseDeltas.isNotEmpty) {
      buf.writeln('운동별 최대 무게 변동:');
      for (final d in m.exerciseDeltas) {
        buf.write(
            '- ${d.exerciseName}: ${d.thisWeekMaxWeight.toStringAsFixed(1)}kg');
        if (d.lastWeekMaxWeight != null) {
          final delta = d.deltaKg;
          buf.write(
              ' (지난주 ${d.lastWeekMaxWeight!.toStringAsFixed(1)}kg, '
              '${delta != null && delta >= 0 ? '+' : ''}${delta?.toStringAsFixed(1) ?? '?'}kg)');
        }
        buf.writeln();
      }
      buf.writeln();
    }

    if (report.warnings.isNotEmpty) {
      buf.writeln('경고 사항:');
      for (final w in report.warnings) {
        buf.writeln('- [${_severityLabel(w.severity)}] ${w.title}: ${w.description}');
      }
      buf.writeln();
    }

    if (report.actionItems.isNotEmpty) {
      buf.writeln('규칙 기반 액션 아이템:');
      for (final a in report.actionItems) {
        buf.writeln('- [P${a.priority}] ${a.instruction} (근거: ${a.rationale})');
      }
    }

    return buf.toString();
  }

  /// AI가 반환한 운동 이름을 카탈로그 기준으로 정규화한다.
  Future<RecommendedRoutine> _normalizeExerciseNames(
    RecommendedRoutine raw,
  ) async {
    final normalized = <RoutineExercise>[];

    for (final ex in raw.exercises) {
      final results = await _catalogRepo.search(ex.name);
      if (results.isNotEmpty) {
        final match = results.firstWhere(
          (r) => r.name.toLowerCase() == ex.name.toLowerCase(),
          orElse: () => results.first,
        );
        normalized.add(RoutineExercise(
          name: match.name,
          sets: ex.sets,
          reps: ex.reps,
          weight: ex.weight,
        ));
      } else {
        normalized.add(ex);
      }
    }

    return RecommendedRoutine(
      title: raw.title,
      rationale: raw.rationale,
      exercises: normalized,
      generatedAt: raw.generatedAt,
    );
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _severityLabel(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.critical:
        return '심각';
      case InsightSeverity.warning:
        return '주의';
      case InsightSeverity.positive:
        return '긍정';
      case InsightSeverity.neutral:
        return '참고';
    }
  }
}
