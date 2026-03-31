import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/auth/user_identity.dart';
import 'package:gains_and_guide/core/domain/models/deload_recommendation.dart';
import 'package:gains_and_guide/core/workout_provider.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';

import '../mocks/fake_deload_service.dart';
import '../mocks/fake_workout_service.dart';

class _TestUserIdentity implements UserIdentity {
  @override
  String get userId => 'test_user';
}

/// 같은 날 SharedPreferences 세션 복원 시 DB 프로그레션과 무게를 맞추는 동작 검증.
void main() {
  late FakeWorkoutService fakeService;
  late FakeDeloadService fakeDeload;

  Future<WorkoutNotifier> createNotifier() async {
    final notifier = WorkoutNotifier(fakeService, fakeDeload, _TestUserIdentity());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  setUp(() {
    fakeService = FakeWorkoutService();
    fakeDeload = FakeDeloadService();
    fakeDeload.nextEvaluationResult = const DeloadRecommendation.none();
    final todayWeekday = DateTime.now().weekday;
    fakeService.weeklyProgram = {
      todayWeekday: [
        Exercise.initial(
            id: 'sq', name: '백 스쿼트', sets: 5, reps: 5, weight: 0),
      ],
    };
    fakeService.lastDate = DateTime.now().toString().split(' ')[0];
  });

  test(
      '오늘 날짜 세션 복원 시 프로그레션 DB가 더 크면 디로드 캐시 무게를 덮어씀',
      () async {
    fakeService.currentSession = [
      Exercise.initial(
        id: 'sq',
        name: '백 스쿼트',
        sets: 5,
        reps: 5,
        weight: 61.5,
      ),
    ];
    fakeService.latestWeights['백 스쿼트'] = 112.5;

    final notifier = await createNotifier();

    expect(notifier.state.first.weight, 112.5);
    expect(notifier.state.first.setWeights.every((w) => w == 112.5), true);
  });

  test('활성 디로드가 있으면 프로그레션에 디로드 비율을 다시 적용', () async {
    fakeDeload.simulatedRemainingSessions = 1;
    fakeDeload.activeRecommendation = const DeloadRecommendation(
      shouldDeload: true,
      totalScore: 70,
      signals: [],
      reductionRatio: 0.6,
      cycleSessions: 3,
      summary: 'test',
    );

    fakeService.currentSession = [
      Exercise.initial(
        id: 'sq',
        name: '백 스쿼트',
        sets: 5,
        reps: 5,
        weight: 50,
      ),
    ];
    fakeService.latestWeights['백 스쿼트'] = 100;

    final notifier = await createNotifier();

    expect(notifier.state.first.weight, 60.0);
    expect(notifier.state.first.setWeights.every((w) => w == 60.0), true);
  });

  test('세트 완료 상태는 재동기화 후에도 유지', () async {
    final ex = Exercise.initial(
      id: 'sq',
      name: '백 스쿼트',
      sets: 3,
      reps: 5,
      weight: 60,
    );
    fakeService.currentSession = [
      ex.copyWith(
        setStatus: [true, false, false],
        setRpe: [7, null, null],
      ),
    ];
    fakeService.latestWeights['백 스쿼트'] = 100;

    final notifier = await createNotifier();

    expect(notifier.state.first.setStatus, [true, false, false]);
    expect(notifier.state.first.setRpe, [7, null, null]);
  });
}
