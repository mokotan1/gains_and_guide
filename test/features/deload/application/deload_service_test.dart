import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/models/deload_recommendation.dart';
import 'package:gains_and_guide/core/domain/repositories/deload_repository.dart';
import 'package:gains_and_guide/core/domain/repositories/progression_repository.dart';
import 'package:gains_and_guide/core/domain/repositories/workout_history_repository.dart';
import 'package:gains_and_guide/features/deload/application/deload_service.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';

// =============================================================================
// Fake repositories (외부 의존 격리)
// =============================================================================
class FakeWorkoutHistoryRepository implements WorkoutHistoryRepository {
  List<Map<String, dynamic>> historyRows = [];

  @override
  Future<List<Map<String, dynamic>>> getAllHistory() async => historyRows;

  @override
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history) async {}

  @override
  Future<List<Map<String, dynamic>>> getRecentSessionsByExercise(
    String exerciseName,
    int sessionLimit,
  ) async {
    return historyRows.where((r) => r['name'] == exerciseName).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentSessions(
      int sessionLimit) async {
    return historyRows;
  }
}

class FakeProgressionRepository implements ProgressionRepository {
  Map<String, List<Map<String, dynamic>>> progressionData = {};

  @override
  Future<double?> getLatestWeight(String exerciseName) async {
    final list = progressionData[exerciseName];
    if (list == null || list.isEmpty) return null;
    return (list.first['weight'] as num).toDouble();
  }

  @override
  Future<void> saveProgression(String exerciseName, double weight) async {}

  @override
  Future<List<Map<String, dynamic>>> getRecentProgressions(
    String exerciseName,
    int limit,
  ) async {
    return progressionData[exerciseName] ?? [];
  }
}

class FakeDeloadRepository implements DeloadRepository {
  DateTime? lastDeloadEnd;
  bool inDeload = false;
  final List<Map<String, dynamic>> records = [];

  @override
  Future<DateTime?> getLastDeloadEndDate() async => lastDeloadEnd;

  @override
  Future<void> saveDeloadRecord({
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required double fatigueScore,
  }) async {
    records.add({
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'fatigueScore': fatigueScore,
    });
  }

  @override
  Future<bool> isCurrentlyInDeload() async => inDeload;
}

// =============================================================================
// Test helpers
// =============================================================================
List<Exercise> _sampleExercises() => [
      Exercise.initial(
          id: '1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      Exercise.initial(
          id: '2', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
    ];

Map<String, dynamic> _historyRow(String name, int rpe, String date) => {
      'name': name,
      'sets': 1,
      'reps': 5,
      'weight': 80.0,
      'rpe': rpe,
      'date': date,
    };

void main() {
  late FakeWorkoutHistoryRepository historyRepo;
  late FakeProgressionRepository progressionRepo;
  late FakeDeloadRepository deloadRepo;
  late DeloadService service;

  setUp(() {
    historyRepo = FakeWorkoutHistoryRepository();
    progressionRepo = FakeProgressionRepository();
    deloadRepo = FakeDeloadRepository();
    service = DeloadService(historyRepo, progressionRepo, deloadRepo);
  });

  // ===========================================================================
  group('evaluateDeloadNeed', () {
    test('운동 목록이 비어 있으면 디로드 불필요', () async {
      final rec = await service.evaluateDeloadNeed([]);
      expect(rec.shouldDeload, false);
    });

    test('이미 디로드 기간 중이면 추가 디로드 불필요', () async {
      deloadRepo.inDeload = true;
      final rec = await service.evaluateDeloadNeed(_sampleExercises());
      expect(rec.shouldDeload, false);
    });

    test('모든 시그널이 낮으면 디로드 불필요', () async {
      historyRepo.historyRows = [
        _historyRow('백 스쿼트', 6, '2026-03-18'),
        _historyRow('플랫 벤치 프레스', 7, '2026-03-18'),
      ];
      progressionRepo.progressionData = {
        '백 스쿼트': [
          {'weight': 105.0, 'date': '2026-03-18'},
          {'weight': 100.0, 'date': '2026-03-15'},
          {'weight': 95.0, 'date': '2026-03-12'},
        ],
        '플랫 벤치 프레스': [
          {'weight': 82.5, 'date': '2026-03-18'},
          {'weight': 80.0, 'date': '2026-03-15'},
        ],
      };
      deloadRepo.lastDeloadEnd = DateTime(2026, 3, 10);

      final rec = await service.evaluateDeloadNeed(_sampleExercises());
      expect(rec.shouldDeload, false);
    });

    test('RPE + 정체 + 오래된 주기 → 디로드 필요', () async {
      historyRepo.historyRows = [
        _historyRow('백 스쿼트', 10, '2026-03-18'),
        _historyRow('백 스쿼트', 10, '2026-03-16'),
        _historyRow('백 스쿼트', 10, '2026-03-14'),
        _historyRow('플랫 벤치 프레스', 10, '2026-03-18'),
        _historyRow('플랫 벤치 프레스', 10, '2026-03-16'),
      ];
      progressionRepo.progressionData = {
        '백 스쿼트': [
          {'weight': 100.0, 'date': '2026-03-18'},
          {'weight': 100.0, 'date': '2026-03-16'},
          {'weight': 100.0, 'date': '2026-03-14'},
          {'weight': 100.0, 'date': '2026-03-12'},
        ],
      };
      deloadRepo.lastDeloadEnd = DateTime(2026, 1, 1);

      final rec = await service.evaluateDeloadNeed(_sampleExercises());
      expect(rec.shouldDeload, true);
      expect(rec.summary, isNotEmpty);
    });
  });

  // ===========================================================================
  group('applyDeload', () {
    test('디로드 불필요 시 원본 그대로 반환', () {
      final exercises = _sampleExercises();
      final result = service.applyDeload(
        exercises,
        const DeloadRecommendation(
          shouldDeload: false,
          totalScore: 30,
          signals: [],
          reductionRatio: 1.0,
          durationDays: 0,
          summary: '',
        ),
      );
      expect(result.length, exercises.length);
      expect(result[0].weight, exercises[0].weight);
    });

    test('디로드 적용 시 무게가 감량됨', () {
      final exercises = _sampleExercises();
      final result = service.applyDeload(
        exercises,
        const DeloadRecommendation(
          shouldDeload: true,
          totalScore: 80,
          signals: [],
          reductionRatio: 0.6,
          durationDays: 7,
          summary: 'test',
        ),
      );
      expect(result[0].weight, 60.0); // 100 * 0.6
      expect(result[1].weight, 48.0); // 80 * 0.6
      expect(result[0].setWeights.every((w) => w == 60.0), true);
    });

    test('유산소/맨몸 운동은 감량하지 않음', () {
      final exercises = [
        Exercise.initial(
            id: '1', name: '런닝머신', sets: 1, reps: 30, weight: 0,
            isCardio: true),
        Exercise.initial(
            id: '2', name: '풀업', sets: 3, reps: 10, weight: 70,
            isBodyweight: true),
      ];
      final result = service.applyDeload(
        exercises,
        const DeloadRecommendation(
          shouldDeload: true,
          totalScore: 80,
          signals: [],
          reductionRatio: 0.6,
          durationDays: 7,
          summary: 'test',
        ),
      );
      expect(result[0].weight, 0);
      expect(result[1].weight, 70);
    });
  });

  // ===========================================================================
  group('recordDeload', () {
    test('DB에 디로드 기록 저장', () async {
      await service.recordDeload(
        const DeloadRecommendation(
          shouldDeload: true,
          totalScore: 75,
          signals: [],
          reductionRatio: 0.6,
          durationDays: 7,
          summary: 'test',
        ),
      );
      expect(deloadRepo.records.length, 1);
      expect(deloadRepo.records.first['fatigueScore'], 75);
    });
  });
}
