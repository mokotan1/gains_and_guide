import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/constants/workout_constants.dart';
import 'package:gains_and_guide/core/domain/models/deload_recommendation.dart';
import 'package:gains_and_guide/core/workout_provider.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';

import '../mocks/fake_deload_service.dart';
import '../mocks/fake_workout_service.dart';

/// [WorkoutNotifier.saveCurrentWorkoutToHistory] 의 증량 규칙을 검증한다.
///
/// 비즈니스 규칙 요약:
/// - 모든 성공 세트 RPE < 3 → +5.0 kg (full increment)
/// - 모든 성공 세트 RPE < 8 → +2.5 kg (half increment)
/// - 그 외 → 증량 없음
/// - 실패 세트 존재 → 증량 스킵
/// - 디로드 진행 중 → 증량 스킵
/// - 유산소 → 증량 스킵
/// - 완료 세트 없음 → 증량 스킵
void main() {
  late FakeWorkoutService fakeService;
  late FakeDeloadService fakeDeload;
  late WorkoutNotifier notifier;

  Exercise _buildExercise({
    String name = '백 스쿼트',
    int sets = 3,
    double weight = 100.0,
    List<bool>? setStatus,
    List<int?>? setRpe,
    List<bool>? setFailed,
    bool isCardio = false,
  }) {
    return Exercise(
      id: 'test_${name.hashCode}',
      name: name,
      sets: sets,
      reps: 5,
      weight: weight,
      setStatus: setStatus ?? List.filled(sets, true),
      setRpe: setRpe ?? List.filled(sets, 2),
      setWeights: List.filled(sets, weight),
      setReps: List.filled(sets, 5),
      setFailed: setFailed ?? List.filled(sets, false),
      isCardio: isCardio,
    );
  }

  setUp(() {
    fakeService = FakeWorkoutService();
    fakeDeload = FakeDeloadService();
    notifier = WorkoutNotifier(fakeService, fakeDeload);
  });

  group('saveCurrentWorkoutToHistory - 증량 규칙', () {
    test('모든 성공 세트 RPE < 3 → +5.0 kg (full increment)', () async {
      final ex = _buildExercise(
        setRpe: [1, 2, 2],
        setStatus: [true, true, true],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(
        fakeService.savedProgressions['백 스쿼트'],
        100.0 + WorkoutConstants.weightIncrementFull,
      );
    });

    test('모든 성공 세트 RPE < 8 (일부 >= 3) → +2.5 kg (half increment)', () async {
      final ex = _buildExercise(
        setRpe: [5, 6, 7],
        setStatus: [true, true, true],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(
        fakeService.savedProgressions['백 스쿼트'],
        100.0 + WorkoutConstants.weightIncrementHalf,
      );
    });

    test('일부 세트 RPE >= 8 → 증량 없음', () async {
      final ex = _buildExercise(
        setRpe: [5, 8, 9],
        setStatus: [true, true, true],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(fakeService.savedProgressions.containsKey('백 스쿼트'), false);
    });

    test('실패 세트가 있으면 증량 스킵', () async {
      final ex = _buildExercise(
        setRpe: [1, 1, 10],
        setStatus: [true, true, true],
        setFailed: [false, false, true],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(fakeService.savedProgressions.containsKey('백 스쿼트'), false);
    });

    test('디로드 진행 중에는 증량 스킵', () async {
      fakeDeload.simulatedRemainingSessions = 3;
      fakeDeload.activeRecommendation = const DeloadRecommendation(
        shouldDeload: true,
        totalScore: 80,
        signals: [],
        reductionRatio: 0.6,
        cycleSessions: 3,
        summary: '테스트 디로드',
      );
      notifier.deloadRecommendation = fakeDeload.activeRecommendation;

      final ex = _buildExercise(
        setRpe: [1, 1, 1],
        setStatus: [true, true, true],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(fakeService.savedProgressions.containsKey('백 스쿼트'), false);
    });

    test('유산소 운동은 증량 대상에서 제외', () async {
      final cardio = _buildExercise(
        name: '런닝머신',
        setRpe: [1, 1, 1],
        setStatus: [true, true, true],
        isCardio: true,
      );
      notifier.state = [cardio];

      await notifier.saveCurrentWorkoutToHistory();

      expect(fakeService.savedProgressions.isEmpty, true);
    });

    test('완료된 세트가 없으면 증량 스킵', () async {
      final ex = _buildExercise(
        setStatus: [false, false, false],
        setRpe: [null, null, null],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(fakeService.savedProgressions.isEmpty, true);
      expect(fakeService.savedHistoryData.isEmpty, true);
    });

    test('RPE 미입력(null) 시 defaultRpe(8) 적용 → half increment 불가', () async {
      final ex = _buildExercise(
        setRpe: [null, null, null],
        setStatus: [true, true, true],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      // defaultRpe=8 → 8 < 8 은 false → 증량 없음
      expect(fakeService.savedProgressions.containsKey('백 스쿼트'), false);
    });

    test('세트별 무게가 다를 때 최고 무게 기준으로 증량', () async {
      final ex = Exercise(
        id: 'test_mixed',
        name: '플랫 벤치 프레스',
        sets: 3,
        reps: 5,
        weight: 80.0,
        setStatus: [true, true, true],
        setRpe: [1, 2, 2],
        setWeights: [80.0, 85.0, 90.0],
        setReps: [5, 5, 5],
        setFailed: [false, false, false],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(
        fakeService.savedProgressions['플랫 벤치 프레스'],
        90.0 + WorkoutConstants.weightIncrementFull,
      );
    });

    test('DB에만 활성 디로드가 있을 때(notifier 플래그 불일치)에도 세션 차감됨', () async {
      fakeDeload.simulatedRemainingSessions = 1;
      fakeDeload.activeRecommendation = const DeloadRecommendation(
        shouldDeload: true,
        totalScore: 65,
        signals: [],
        reductionRatio: 0.6,
        cycleSessions: 1,
        summary: 'test',
      );
      notifier.deloadRecommendation = const DeloadRecommendation.none();

      final ex = _buildExercise(
        setRpe: [1, 1, 1],
        setStatus: [true, true, true],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(fakeDeload.simulatedRemainingSessions, 0);
      expect(fakeDeload.deloadSessionCompleted, true);
    });

    test('디로드 마지막 세션 저장 후 deloadRecommendation 이 종료 상태로 갱신됨', () async {
      fakeDeload.simulatedRemainingSessions = 1;
      fakeDeload.activeRecommendation = const DeloadRecommendation(
        shouldDeload: true,
        totalScore: 80,
        signals: [],
        reductionRatio: 0.6,
        cycleSessions: 1,
        summary: '마지막 디로드',
      );
      fakeDeload.nextEvaluationResult = const DeloadRecommendation.none();
      notifier.deloadRecommendation = fakeDeload.activeRecommendation;

      final ex = _buildExercise(
        setRpe: [1, 1, 1],
        setStatus: [true, true, true],
      );
      notifier.state = [ex];

      await notifier.saveCurrentWorkoutToHistory();

      expect(notifier.deloadRecommendation?.shouldDeload, false);
      expect(fakeDeload.deloadSessionCompleted, true);
      expect(fakeDeload.simulatedRemainingSessions, 0);
    });
  });
}
