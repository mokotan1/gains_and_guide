import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/user_identity.dart';
import '../../../core/constants/report_constants.dart';
import '../../../core/domain/repositories/exercise_catalog_repository.dart';
import '../../../core/domain/repositories/workout_history_repository.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/repository_providers.dart';
import '../domain/models/weekly_metrics.dart';
import '../domain/models/weekly_report.dart';
import '../domain/repositories/weekly_report_repository.dart';
import '../domain/weekly_metrics_calculator.dart';
import '../domain/weekly_report_generator.dart';
import '../../user_memory/application/user_memory_sync_service.dart';
import 'routine_recommendation_service.dart';

/// 주간 레포트 오케스트레이터.
///
/// 1) 캐시 확인 → 2) 원시 데이터 수집 → 3) 메트릭스 계산 →
/// 4) 규칙 기반 레포트 생성 → 5) (선택) AI 보강 → 6) 저장 후 반환.
class WeeklyReportService {
  final WorkoutHistoryRepository _historyRepo;
  final ExerciseCatalogRepository _catalogRepo;
  final WeeklyReportRepository _reportRepo;
  final RoutineRecommendationService _routineRecommendationService;
  final ApiClient _apiClient;
  final UserIdentity _userIdentity;

  WeeklyReportService(
    this._historyRepo,
    this._catalogRepo,
    this._reportRepo,
    this._routineRecommendationService, {
    required ApiClient apiClient,
    required UserIdentity userIdentity,
  })  : _apiClient = apiClient,
        _userIdentity = userIdentity;

  /// 지정 주의 레포트를 생성(또는 캐시에서 반환)한다.
  ///
  /// [weekStart] 가 null 이면 이번 주 월요일을 기준으로 한다.
  Future<WeeklyReport> getOrGenerateReport({DateTime? weekStart}) async {
    final monday = weekStart ?? _thisMonday();
    final sunday = monday.add(const Duration(days: 6));
    final mondayStr = _dateStr(monday);

    final cached = await _reportRepo.getReport(mondayStr);
    if (cached != null) return cached;

    final report = await _generateReport(monday, sunday);
    await _reportRepo.saveReport(report);
    await _maybeUploadMemoryForReport(report);
    return report;
  }

  /// 캐시를 무시하고 레포트를 재생성한다.
  Future<WeeklyReport> regenerateReport({DateTime? weekStart}) async {
    final monday = weekStart ?? _thisMonday();
    final sunday = monday.add(const Duration(days: 6));

    final report = await _generateReport(monday, sunday);
    await _reportRepo.saveReport(report);
    await _maybeUploadMemoryForReport(report);
    return report;
  }

  /// AI 서버에 메트릭스 요약을 보내 자연어 코멘트를 받아 병합한다.
  ///
  /// AI 보강은 부가 기능이므로, 실패 시 원본 report 를 반환한다 (graceful degradation).
  /// 단, 로그에는 에러 유형을 기록한다.
  Future<WeeklyReport> enrichWithAi(WeeklyReport report) async {
    try {
      final summary = _buildAiSummaryPayload(report.metrics);

      final data = await _apiClient.post('/chat', {
        'user_id': _userIdentity.userId,
        'message': '주간 운동 레포트 데이터를 분석해서 '
            '한국어로 코치 입장에서 한 줄 요약과 핵심 조언을 해줘.',
        'context': summary,
      });

      final aiComment = data['response'] as String?;
      if (aiComment != null && aiComment.isNotEmpty) {
        final enriched = report.copyWith(aiComment: aiComment);
        await _reportRepo.saveReport(enriched);
        return enriched;
      }
    } on AppException catch (e) {
      debugPrint('AI enrichment failed: $e');
    }
    return report;
  }

  /// 주간 분석 데이터를 기반으로 AI에게 다음 주 루틴 추천을 요청하여 병합한다.
  ///
  /// AI 보강은 부가 기능이므로, 실패 시 원본 report 를 반환한다 (graceful degradation).
  Future<WeeklyReport> enrichWithRoutineRecommendation(
    WeeklyReport report,
  ) async {
    try {
      final routine = await _routineRecommendationService.recommend(report);
      if (routine != null && routine.exercises.isNotEmpty) {
        final enriched = report.copyWith(recommendedRoutine: routine);
        await _reportRepo.saveReport(enriched);
        return enriched;
      }
    } on AppException catch (e) {
      debugPrint('Routine recommendation failed: $e');
    }
    return report;
  }

  /// 최근 레포트 목록 조회
  Future<List<WeeklyReport>> getRecentReports({int limit = 8}) =>
      _reportRepo.getRecentReports(limit);

  /// 이번 주에 레포트가 이미 생성되었는지 확인
  Future<bool> hasReportForCurrentWeek() async {
    final monday = _thisMonday();
    final report = await _reportRepo.getReport(_dateStr(monday));
    return report != null;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _maybeUploadMemoryForReport(WeeklyReport report) async {
    if (!UserMemorySyncService.enabled) return;
    final weekKey =
        '${report.weekStart.year}-${report.weekStart.month.toString().padLeft(2, '0')}-${report.weekStart.day.toString().padLeft(2, '0')}';
    final text = _buildAiSummaryPayload(report.metrics);
    await UserMemorySyncService(_apiClient).uploadWeeklyDigest(weekKey, text);
  }

  Future<WeeklyReport> _generateReport(
    DateTime monday,
    DateTime sunday,
  ) async {
    final mondayStr = _dateStr(monday);
    final sundayStr = _dateStr(sunday);

    final currentWeekRows =
        await _historyRepo.getHistoryForDateRange(mondayStr, sundayStr);

    final prevMonday = monday.subtract(const Duration(days: 7));
    final prevSunday = prevMonday.add(const Duration(days: 6));
    final prevWeekRows = await _historyRepo.getHistoryForDateRange(
      _dateStr(prevMonday),
      _dateStr(prevSunday),
    );

    final chronicVolumes = await _historyRepo.getWeeklyVolumes(
      ReportConstants.chronicWindowWeeks,
    );

    final muscleMap = await _buildMuscleMap();

    final metrics = WeeklyMetricsCalculator.calculate(
      currentWeekRows: currentWeekRows,
      chronicWeeklyVolumes: chronicVolumes,
      prevWeekRows: prevWeekRows,
      muscleMap: muscleMap,
      weekStart: monday,
      weekEnd: sunday,
    );

    return WeeklyReportGenerator.generate(metrics);
  }

  /// exercise_catalog 에서 운동명 → primary_muscles 매핑 생성
  Future<Map<String, String>> _buildMuscleMap() async {
    final all = await _catalogRepo.getAll();
    final map = <String, String>{};
    for (final row in all) {
      final name = row['name'] as String? ?? '';
      final muscles = row['primary_muscles'] as String? ?? 'other';
      if (name.isNotEmpty) {
        map[name] = muscles;
      }
    }
    return map;
  }

  String _buildAiSummaryPayload(WeeklyMetrics metrics) {
    final buf = StringBuffer()
      ..writeln('주간 운동 요약 데이터:')
      ..writeln('기간: ${_dateStr(metrics.weekStart)} ~ ${_dateStr(metrics.weekEnd)}')
      ..writeln('훈련 횟수: ${metrics.totalSessions}회')
      ..writeln('총 볼륨: ${metrics.totalVolume.toStringAsFixed(0)}kg')
      ..writeln('평균 RPE: ${metrics.avgRpe.toStringAsFixed(1)}')
      ..writeln('ACWR: ${metrics.acwr.toStringAsFixed(2)}')
      ..writeln('실패율: ${(metrics.failureRate * 100).toStringAsFixed(0)}%');

    if (metrics.prevWeekVolume != null) {
      buf.writeln('지난 주 볼륨: ${metrics.prevWeekVolume!.toStringAsFixed(0)}kg');
    }

    if (metrics.volumeByMuscle.isNotEmpty) {
      buf.writeln('근육군별 볼륨: ${metrics.volumeByMuscle}');
    }

    for (final est in metrics.estimated1RMs.values) {
      buf.write('${est.exerciseName} 예상1RM: ${est.current1RM.toStringAsFixed(1)}kg');
      if (est.previous1RM != null) {
        buf.write(' (지난주 ${est.previous1RM!.toStringAsFixed(1)}kg)');
      }
      buf.writeln();
    }

    return buf.toString();
  }

  static DateTime _thisMonday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final routineRecommendationServiceProvider =
    Provider<RoutineRecommendationService>((ref) {
  return RoutineRecommendationService(
    ref.watch(exerciseCatalogRepositoryProvider),
    apiClient: ref.watch(apiClientProvider),
    userIdentity: ref.watch(userIdentityProvider),
  );
});

final weeklyReportServiceProvider = Provider<WeeklyReportService>((ref) {
  return WeeklyReportService(
    ref.watch(workoutHistoryRepositoryProvider),
    ref.watch(exerciseCatalogRepositoryProvider),
    ref.watch(weeklyReportRepositoryProvider),
    ref.watch(routineRecommendationServiceProvider),
    apiClient: ref.watch(apiClientProvider),
    userIdentity: ref.watch(userIdentityProvider),
  );
});
