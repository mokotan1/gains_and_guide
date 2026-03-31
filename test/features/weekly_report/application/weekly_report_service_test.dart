import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

import 'package:gains_and_guide/core/auth/user_identity.dart';
import 'package:gains_and_guide/core/config/app_config.dart';
import 'package:gains_and_guide/core/domain/repositories/cardio_history_repository.dart';
import 'package:gains_and_guide/core/domain/repositories/exercise_catalog_repository.dart';
import 'package:gains_and_guide/core/domain/repositories/workout_history_repository.dart';
import 'package:gains_and_guide/core/network/api_client.dart';
import 'package:gains_and_guide/features/routine/domain/exercise_catalog.dart';
import 'package:gains_and_guide/features/weekly_report/application/routine_recommendation_service.dart';
import 'package:gains_and_guide/features/weekly_report/application/weekly_report_service.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/weekly_report.dart';
import 'package:gains_and_guide/features/weekly_report/domain/repositories/weekly_report_repository.dart';

class _TestUserIdentity implements UserIdentity {
  @override
  String get userId => 'test_user';
}

// =============================================================================
// Fake repositories
// =============================================================================

class FakeWorkoutHistoryRepository implements WorkoutHistoryRepository {
  List<Map<String, dynamic>> rows = [];

  @override
  Future<List<Map<String, dynamic>>> getAllHistory() async => rows;

  @override
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history) async {}

  @override
  Future<List<Map<String, dynamic>>> getRecentSessionsByExercise(
    String exerciseName,
    int sessionLimit, {
    bool excludeDeload = false,
  }) async =>
      rows.where((r) => r['name'] == exerciseName).toList();

  @override
  Future<List<Map<String, dynamic>>> getRecentSessions(
    int sessionLimit, {
    bool excludeDeload = false,
  }) async =>
      rows;

  @override
  Future<List<String>> getDistinctWorkoutSessionDates() async {
    final dates = rows
        .map((r) => (r['date'] as String).substring(0, 10))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return dates;
  }

  @override
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  ) async {
    return rows.where((r) {
      final date = (r['date'] as String).substring(0, 10);
      return date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;
    }).toList();
  }

  @override
  Future<List<double>> getWeeklyVolumes(int weekCount) async {
    return List.filled(weekCount, 2000.0);
  }
}

class FakeCardioHistoryRepository implements CardioHistoryRepository {
  List<Map<String, dynamic>> rows = [];

  @override
  Future<void> saveCardioHistory(List<Map<String, dynamic>> history) async {}

  @override
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  ) async {
    return rows.where((r) {
      final date = (r['date'] as String).substring(0, 10);
      return date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;
    }).toList();
  }

  @override
  Future<List<double>> getWeeklyCardioLoads(int weekCount) async {
    return List.filled(weekCount, 100.0);
  }
}

class FakeExerciseCatalogRepository implements ExerciseCatalogRepository {
  List<Map<String, dynamic>> catalogRows = [];

  @override
  Future<List<ExerciseCatalog>> search(String keyword) async => [];

  @override
  Future<List<Map<String, dynamic>>> getAll() async => catalogRows;

  @override
  Future<List<ExerciseCatalog>> searchWithFilters({
    String keyword = '',
    List<String> muscleKeys = const [],
    String? equipment,
  }) async => [];

  @override
  Future<List<String>> getRecentExerciseNames({int limit = 5}) async => [];
}

class FakeWeeklyReportRepository implements WeeklyReportRepository {
  final Map<String, WeeklyReport> _store = {};

  @override
  Future<WeeklyReport?> getReport(String weekStart) async =>
      _store[weekStart];

  @override
  Future<void> saveReport(WeeklyReport report) async {
    final key =
        '${report.weekStart.year}-${report.weekStart.month.toString().padLeft(2, '0')}-${report.weekStart.day.toString().padLeft(2, '0')}';
    _store[key] = report;
  }

  @override
  Future<List<WeeklyReport>> getRecentReports(int limit) async {
    final sorted = _store.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted.take(limit).map((e) => e.value).toList();
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late FakeWorkoutHistoryRepository historyRepo;
  late FakeCardioHistoryRepository cardioRepo;
  late FakeExerciseCatalogRepository catalogRepo;
  late FakeWeeklyReportRepository reportRepo;
  late RoutineRecommendationService routineRecService;
  late WeeklyReportService service;

  final monday = DateTime(2026, 3, 23);

  final testConfig = const AppConfig(
    apiBaseUrl: 'http://localhost:0',
    defaultTimeout: Duration(seconds: 5),
  );

  setUp(() {
    historyRepo = FakeWorkoutHistoryRepository();
    cardioRepo = FakeCardioHistoryRepository();
    catalogRepo = FakeExerciseCatalogRepository();
    reportRepo = FakeWeeklyReportRepository();
    final failingHttp = http_testing.MockClient((_) async {
      throw http.ClientException('test: no server');
    });
    final apiClient = ApiClient(testConfig, httpClient: failingHttp);
    final userIdentity = _TestUserIdentity();
    routineRecService = RoutineRecommendationService(
      catalogRepo,
      apiClient: apiClient,
      userIdentity: userIdentity,
    );
    service = WeeklyReportService(
      historyRepo,
      cardioRepo,
      catalogRepo,
      reportRepo,
      routineRecService,
      apiClient: apiClient,
      userIdentity: userIdentity,
    );
  });

  Map<String, dynamic> _row({
    required String name,
    required double weight,
    required int reps,
    int rpe = 8,
    required String date,
  }) =>
      {'name': name, 'weight': weight, 'reps': reps, 'rpe': rpe, 'date': date};

  group('getOrGenerateReport', () {
    test('데이터가 없으면 빈 레포트를 반환한다', () async {
      final report = await service.getOrGenerateReport(weekStart: monday);

      expect(report.metrics.totalSessions, 0);
      expect(report.headline.text, contains('기록이 없습니다'));
    });

    test('운동 데이터로 정상적인 레포트를 생성한다', () async {
      historyRepo.rows = [
        _row(name: '스쿼트', weight: 100, reps: 5, rpe: 8, date: '2026-03-24'),
        _row(name: '스쿼트', weight: 100, reps: 5, rpe: 9, date: '2026-03-24'),
        _row(name: '벤치프레스', weight: 80, reps: 5, rpe: 8, date: '2026-03-26'),
      ];
      cardioRepo.rows = [
        {
          'cardio_name': '러닝',
          'duration_minutes': 30.0,
          'rpe': 6.0,
          'date': '2026-03-24',
          'distance_km': 3.0,
        },
      ];
      catalogRepo.catalogRows = [
        {'name': '스쿼트', 'primary_muscles': 'quadriceps'},
        {'name': '벤치프레스', 'primary_muscles': 'chest'},
      ];

      final report = await service.getOrGenerateReport(weekStart: monday);

      expect(report.metrics.totalSessions, greaterThan(0));
      expect(report.metrics.totalVolume, greaterThan(0));
      expect(report.metrics.volumeByMuscle, isNotEmpty);
      expect(report.metrics.totalCardioMinutes, greaterThan(0));
    });

    test('두 번째 호출 시 캐시에서 반환한다', () async {
      historyRepo.rows = [
        _row(name: '스쿼트', weight: 100, reps: 5, rpe: 8, date: '2026-03-24'),
      ];

      final first = await service.getOrGenerateReport(weekStart: monday);
      final second = await service.getOrGenerateReport(weekStart: monday);

      expect(second.generatedAt, first.generatedAt);
    });
  });

  group('regenerateReport', () {
    test('캐시를 무시하고 새로 생성한다', () async {
      historyRepo.rows = [
        _row(name: '스쿼트', weight: 100, reps: 5, rpe: 8, date: '2026-03-24'),
      ];

      final first = await service.getOrGenerateReport(weekStart: monday);

      // 데이터 추가 후 재생성
      historyRepo.rows.add(
        _row(name: '데드리프트', weight: 120, reps: 5, rpe: 9, date: '2026-03-25'),
      );

      final regenerated = await service.regenerateReport(weekStart: monday);

      expect(regenerated.metrics.totalVolume,
          greaterThan(first.metrics.totalVolume));
    });
  });

  group('getRecentReports', () {
    test('저장된 레포트 목록을 반환한다', () async {
      historyRepo.rows = [
        _row(name: '스쿼트', weight: 100, reps: 5, rpe: 8, date: '2026-03-24'),
      ];

      await service.getOrGenerateReport(weekStart: monday);

      final reports = await service.getRecentReports();
      expect(reports, hasLength(1));
    });
  });

  group('ACWR 경고 시나리오', () {
    test('높은 ACWR 에서 경고와 액션 아이템이 생성된다', () async {
      // 이번 주 많은 볼륨
      historyRepo.rows = List.generate(
        20,
        (i) => _row(
          name: '스쿼트',
          weight: 100,
          reps: 10,
          rpe: 9,
          date: '2026-03-24',
        ),
      );

      // chronic 볼륨을 낮게 설정 (ACWR 올리기)
      historyRepo = FakeWorkoutHistoryRepository()
        ..rows = historyRepo.rows;
      final lowChronicRepo = _LowChronicHistoryRepo(historyRepo);

      final failingHttp = http_testing.MockClient((_) async {
        throw http.ClientException('test: no server');
      });
      final apiClient = ApiClient(testConfig, httpClient: failingHttp);
      final userIdentity = _TestUserIdentity();
      routineRecService = RoutineRecommendationService(
        catalogRepo,
        apiClient: apiClient,
        userIdentity: userIdentity,
      );
      service = WeeklyReportService(
        lowChronicRepo,
        cardioRepo,
        catalogRepo,
        reportRepo,
        routineRecService,
        apiClient: apiClient,
        userIdentity: userIdentity,
      );
      final report = await service.getOrGenerateReport(weekStart: monday);

      expect(report.warnings, isNotEmpty);
      expect(report.actionItems, isNotEmpty);
    });
  });
}

/// chronic 볼륨을 의도적으로 낮게 반환하는 래퍼
class _LowChronicHistoryRepo implements WorkoutHistoryRepository {
  final FakeWorkoutHistoryRepository _inner;
  _LowChronicHistoryRepo(this._inner);

  @override
  Future<List<Map<String, dynamic>>> getAllHistory() => _inner.getAllHistory();
  @override
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> h) =>
      _inner.saveWorkoutHistory(h);
  @override
  Future<List<Map<String, dynamic>>> getRecentSessionsByExercise(
    String n,
    int l, {
    bool excludeDeload = false,
  }) =>
      _inner.getRecentSessionsByExercise(n, l, excludeDeload: excludeDeload);
  @override
  Future<List<Map<String, dynamic>>> getRecentSessions(
    int l, {
    bool excludeDeload = false,
  }) =>
      _inner.getRecentSessions(l, excludeDeload: excludeDeload);
  @override
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
          String s, String e) =>
      _inner.getHistoryForDateRange(s, e);

  @override
  Future<List<String>> getDistinctWorkoutSessionDates() =>
      _inner.getDistinctWorkoutSessionDates();

  @override
  Future<List<double>> getWeeklyVolumes(int weekCount) async =>
      List.filled(weekCount, 2000.0);
}
