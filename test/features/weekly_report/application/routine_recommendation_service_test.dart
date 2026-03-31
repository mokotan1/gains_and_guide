import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;


import 'package:gains_and_guide/core/auth/user_identity.dart';
import 'package:gains_and_guide/core/config/app_config.dart';
import 'package:gains_and_guide/core/domain/repositories/exercise_catalog_repository.dart';
import 'package:gains_and_guide/core/error/app_exception.dart';
import 'package:gains_and_guide/core/network/api_client.dart';
import 'package:gains_and_guide/features/routine/domain/exercise_catalog.dart';
import 'package:gains_and_guide/features/weekly_report/application/routine_recommendation_service.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/recommended_routine.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/report_section.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/weekly_metrics.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/weekly_report.dart';

class _FakeCatalogRepo implements ExerciseCatalogRepository {
  @override
  Future<List<ExerciseCatalog>> search(String keyword) async {
    final catalog = [
      const ExerciseCatalog(
        name: '랫 풀다운',
        category: 'strength',
        equipment: 'machine',
        primaryMuscles: 'lats',
        instructions: '',
      ),
      const ExerciseCatalog(
        name: '시티드 로우',
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

class _FakeUserIdentity implements UserIdentity {
  @override
  String get userId => 'test_user';
}

const _testConfig = AppConfig(
  apiBaseUrl: 'https://test.example.com',
  defaultTimeout: Duration(seconds: 5),
  supabaseUrl: '',
  supabaseAnonKey: '',
);

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
    late _FakeCatalogRepo catalogRepo;

    setUp(() {
      catalogRepo = _FakeCatalogRepo();
    });

    RoutineRecommendationService _createService(http.Client mockHttp) {
      final apiClient = ApiClient(_testConfig, httpClient: mockHttp);
      return RoutineRecommendationService(
        catalogRepo,
        apiClient: apiClient,
        userIdentity: _FakeUserIdentity(),
      );
    }

    test('서버 연결 실패 시 NetworkException 전파', () async {
      final mockHttp = http_testing.MockClient((_) async {
        throw http.ClientException('Connection refused');
      });
      final service = _createService(mockHttp);
      final report = _createTestReport();

      expect(
        () => service.recommend(report),
        throwsA(isA<NetworkException>()),
      );
    });

    test('서버 500 응답 시 ServerException 전파', () async {
      final mockHttp = http_testing.MockClient((_) async {
        return http.Response('error', 500);
      });
      final service = _createService(mockHttp);
      final report = _createTestReport();

      expect(
        () => service.recommend(report),
        throwsA(isA<ServerException>()),
      );
    });

    test('성공 응답 시 RecommendedRoutine 파싱 및 반환', () async {
      final mockHttp = http_testing.MockClient((_) async {
        final body = jsonEncode({
          'routine': {
            'title': '다음 주 추천 루틴',
            'rationale': 'ACWR 안정적이므로 볼륨 유지',
            'exercises': [
              {'name': '백 스쿼트', 'sets': 5, 'reps': 5, 'weight': 100.0},
              {'name': '랫 풀다운', 'sets': 4, 'reps': 10, 'weight': 55.0},
            ],
          },
        });
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = _createService(mockHttp);
      final report = _createTestReport();

      final result = await service.recommend(report);

      expect(result, isNotNull);
      expect(result!.title, '다음 주 추천 루틴');
      expect(result.rationale, 'ACWR 안정적이므로 볼륨 유지');
      expect(result.exercises.length, 2);
      expect(result.exercises[0].name, '백 스쿼트');
      expect(result.exercises[1].name, '랫 풀다운');
      expect(result.exercises[1].sets, 4);
    });

    test('응답에 routine 키가 없으면 null 반환', () async {
      final mockHttp = http_testing.MockClient((_) async {
        return http.Response(
          jsonEncode({'status': 'ok', 'message': 'no routine'}),
          200,
        );
      });
      final service = _createService(mockHttp);
      final report = _createTestReport();

      final result = await service.recommend(report);
      expect(result, isNull);
    });

    test('운동명이 카탈로그에 있으면 정규화된 이름으로 교체', () async {
      final mockHttp = http_testing.MockClient((_) async {
        final body = jsonEncode({
          'routine': {
            'title': '테스트',
            'rationale': '테스트',
            'exercises': [
              {'name': '랫 풀다운', 'sets': 4, 'reps': 12, 'weight': 50.0},
            ],
          },
        });
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = _createService(mockHttp);
      final report = _createTestReport();

      final result = await service.recommend(report);

      expect(result, isNotNull);
      expect(result!.exercises.first.name, '랫 풀다운');
    });

    test('요청 body에 user_id와 weekly_summary가 포함됨', () async {
      Map<String, dynamic>? capturedBody;
      final mockHttp = http_testing.MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'routine': null}), 200);
      });
      final service = _createService(mockHttp);
      final report = _createTestReport();

      await service.recommend(report);

      expect(capturedBody, isNotNull);
      expect(capturedBody!['user_id'], 'test_user');
      expect(capturedBody!['weekly_summary'], isNotEmpty);
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
          RoutineExercise(
            name: 'Lat Pulldown',
            sets: 4,
            reps: 12,
            weight: 50,
          ),
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
      expect(
        restored.recommendedRoutine!.exercises.first.name,
        'Lat Pulldown',
      );
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
