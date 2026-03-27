import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/repositories/exercise_catalog_repository.dart';
import 'package:gains_and_guide/features/routine/domain/exercise_catalog.dart';
import 'package:gains_and_guide/features/weekly_report/application/routine_recommendation_service.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/recommended_routine.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/report_section.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/weekly_metrics.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/weekly_report.dart';

class FakeExerciseCatalogRepository implements ExerciseCatalogRepository {
  @override
  Future<List<ExerciseCatalog>> search(String keyword) async {
    final catalog = [
      const ExerciseCatalog(
        name: 'Lat Pulldown',
        category: 'strength',
        equipment: 'machine',
        primaryMuscles: 'lats',
        instructions: '',
      ),
      const ExerciseCatalog(
        name: 'Seated Cable Row',
        category: 'strength',
        equipment: 'cable',
        primaryMuscles: 'middle back',
        instructions: '',
      ),
    ];
    return catalog
        .where((e) => e.name.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAll() async => [];

  @override
  Future<List<ExerciseCatalog>> searchWithFilters({
    String keyword = '',
    List<String> muscleKeys = const [],
    String? equipment,
  }) async =>
      [];

  @override
  Future<List<String>> getRecentExerciseNames({int limit = 5}) async => [];
}

WeeklyReport _createTestReport({
  int sessions = 3,
  double volume = 15000,
  double avgRpe = 7.5,
  double acwr = 1.1,
  double failureRate = 0.05,
  Map<String, double> volumeByMuscle = const {'chest': 5000, 'back': 2000},
  List<WarningInsight> warnings = const [],
  List<ActionItem> actionItems = const [],
}) {
  final monday = DateTime(2026, 3, 23);
  final sunday = monday.add(const Duration(days: 6));
  final metrics = WeeklyMetrics(
    weekStart: monday,
    weekEnd: sunday,
    totalSessions: sessions,
    totalVolume: volume,
    avgRpe: avgRpe,
    acwr: acwr,
    volumeByMuscle: volumeByMuscle,
    estimated1RMs: const {},
    failureRate: failureRate,
    prevWeekVolume: 14000,
  );
  return WeeklyReport(
    weekStart: monday,
    weekEnd: sunday,
    headline: const ReportHeadline(
      text: '안정적 훈련',
      severity: InsightSeverity.positive,
    ),
    performances: const [],
    warnings: warnings,
    actionItems: actionItems,
    metrics: metrics,
    generatedAt: DateTime.now(),
  );
}

void main() {
  group('RoutineRecommendationService', () {
    late FakeExerciseCatalogRepository catalogRepo;
    late RoutineRecommendationService service;

    setUp(() {
      catalogRepo = FakeExerciseCatalogRepository();
      service = RoutineRecommendationService(
        catalogRepo,
        baseUrl: 'http://localhost:0',
      );
    });

    test('서버 연결 실패 시 null 을 반환한다 (graceful degradation)', () async {
      final report = _createTestReport();
      final result = await service.recommend(report);

      expect(result, isNull);
    });

    test('빈 세션(totalSessions=0) 레포트에서도 에러 없이 동작한다', () async {
      final report = _createTestReport(sessions: 0, volume: 0, acwr: 0);
      final result = await service.recommend(report);

      expect(result, isNull);
    });
  });

  group('RecommendedRoutine 직렬화 통합', () {
    test('WeeklyReport 에 recommendedRoutine 포함 시 JSON 왕복이 동작한다', () {
      final monday = DateTime(2026, 3, 23);
      final sunday = monday.add(const Duration(days: 6));
      final metrics = WeeklyMetrics(
        weekStart: monday,
        weekEnd: sunday,
        totalSessions: 3,
        totalVolume: 15000,
        avgRpe: 7.5,
        acwr: 1.1,
        volumeByMuscle: const {'chest': 5000},
        estimated1RMs: const {},
        failureRate: 0.05,
      );

      final routine = RecommendedRoutine(
        title: '테스트 루틴',
        rationale: 'ACWR 안정',
        exercises: const [
          RoutineExercise(name: 'Lat Pulldown', sets: 4, reps: 12, weight: 50),
        ],
        generatedAt: DateTime(2026, 3, 27),
      );

      final report = WeeklyReport(
        weekStart: monday,
        weekEnd: sunday,
        headline: const ReportHeadline(
          text: '테스트',
          severity: InsightSeverity.positive,
        ),
        performances: const [],
        warnings: const [],
        actionItems: const [],
        metrics: metrics,
        recommendedRoutine: routine,
        generatedAt: DateTime(2026, 3, 27),
      );

      final jsonStr = report.toJsonString();
      final restored = WeeklyReport.fromJsonString(jsonStr);

      expect(restored.recommendedRoutine, isNotNull);
      expect(restored.recommendedRoutine!.title, '테스트 루틴');
      expect(restored.recommendedRoutine!.exercises.length, 1);
      expect(restored.recommendedRoutine!.exercises.first.name, 'Lat Pulldown');
    });

    test('recommendedRoutine 이 null 인 WeeklyReport JSON 왕복이 동작한다', () {
      final monday = DateTime(2026, 3, 23);
      final sunday = monday.add(const Duration(days: 6));
      final metrics = WeeklyMetrics(
        weekStart: monday,
        weekEnd: sunday,
        totalSessions: 3,
        totalVolume: 15000,
        avgRpe: 7.5,
        acwr: 1.1,
        volumeByMuscle: const {},
        estimated1RMs: const {},
        failureRate: 0.05,
      );

      final report = WeeklyReport(
        weekStart: monday,
        weekEnd: sunday,
        headline: const ReportHeadline(
          text: '테스트',
          severity: InsightSeverity.positive,
        ),
        performances: const [],
        warnings: const [],
        actionItems: const [],
        metrics: metrics,
        generatedAt: DateTime(2026, 3, 27),
      );

      final jsonStr = report.toJsonString();
      final restored = WeeklyReport.fromJsonString(jsonStr);

      expect(restored.recommendedRoutine, isNull);
    });
  });
}
