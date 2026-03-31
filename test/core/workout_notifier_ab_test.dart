import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/auth/user_identity.dart';
import 'package:gains_and_guide/core/constants/workout_constants.dart';
import 'package:gains_and_guide/core/domain/models/deload_recommendation.dart';
import 'package:gains_and_guide/core/workout_provider.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';

import '../mocks/fake_deload_service.dart';
import '../mocks/fake_workout_service.dart';

class _TestUserIdentity implements UserIdentity {
  @override
  String get userId => 'test_user';
}

/// [WorkoutNotifier] 의 Stronglifts A/B 루틴 교체 로직을 검증한다.
///
/// 비즈니스 규칙 요약:
/// - 히스토리가 비어있으면 → 기본 루틴 유지
/// - 마지막 세션이 A (벤치/로우) → B (OHP/데드) 로 교체
/// - 마지막 세션이 B (OHP/데드) → A (벤치/로우) 로 교체
/// - 마지막 세션이 데드리프트만 → B 판별 → A 반환
/// - 마지막 세션에 A+B 모두 → 기본 루틴 유지 (ambiguous)
/// - 보조 운동 병합 시 메인 운동 오염 없음
void main() {
  late FakeWorkoutService fakeService;
  late FakeDeloadService fakeDeload;

  final defaultSquatRoutine = [
    Exercise.initial(
        id: 'sq', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
    Exercise.initial(
        id: 'bp', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
    Exercise.initial(
        id: 'row', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
  ];

  /// notifier 를 생성하고 비동기 초기화(_loadAllData)가 완료되기를 기다린다.
  Future<WorkoutNotifier> createNotifier() async {
    final notifier = WorkoutNotifier(fakeService, fakeDeload, _TestUserIdentity());
    // _loadAllData()는 constructor에서 fire-and-forget으로 실행되므로
    // microtask 큐를 비워 비동기 초기화를 완료시킨다.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  setUp(() {
    fakeService = FakeWorkoutService();
    fakeDeload = FakeDeloadService();
    fakeDeload.nextEvaluationResult = const DeloadRecommendation.none();
    // 생성자 호출 시점에 weeklyProgram이 이미 세팅되어 있어야 함
    final todayWeekday = DateTime.now().weekday;
    fakeService.weeklyProgram = {todayWeekday: defaultSquatRoutine};
    // _loadAllData 에서 lastDate 비교: 오늘과 다르면 updateRoutineByDay 호출
    fakeService.lastDate = '2000-01-01';
  });

  group('Stronglifts A/B 루틴 교체', () {
    test('히스토리 비어있으면 기본 루틴 유지', () async {
      fakeService.history = [];

      final notifier = await createNotifier();

      final names = notifier.state.map((e) => e.name).toList();
      expect(names, contains('백 스쿼트'));
      expect(names, contains('플랫 벤치 프레스'));
      expect(names, contains('펜들레이 로우'));
    });

    test('마지막 세션이 A (벤치+로우) → B 루틴(OHP+데드) 으로 교체', () async {
      fakeService.history = [
        {'date': '2025-12-01', 'name': '플랫 벤치 프레스'},
        {'date': '2025-12-01', 'name': '백 스쿼트'},
        {'date': '2025-12-01', 'name': '펜들레이 로우'},
      ];

      final notifier = await createNotifier();

      final names = notifier.state.map((e) => e.name).toSet();
      expect(names, contains('백 스쿼트'));
      expect(names, contains('오버헤드 프레스 (OHP)'));
      expect(names, contains('컨벤셔널 데드리프트'));
      expect(names.contains('플랫 벤치 프레스'), false);
    });

    test('마지막 세션이 B (OHP+데드) → A 루틴(벤치+로우) 으로 교체', () async {
      fakeService.history = [
        {'date': '2025-12-01', 'name': '오버헤드 프레스 (OHP)'},
        {'date': '2025-12-01', 'name': '백 스쿼트'},
        {'date': '2025-12-01', 'name': '컨벤셔널 데드리프트'},
      ];

      final notifier = await createNotifier();

      final names = notifier.state.map((e) => e.name).toSet();
      expect(names, contains('백 스쿼트'));
      expect(names, contains('플랫 벤치 프레스'));
      expect(names, contains('펜들레이 로우'));
      expect(names.contains('오버헤드 프레스 (OHP)'), false);
    });

    test('마지막 세션이 데드리프트만 포함 → B 판별 → A 반환', () async {
      fakeService.history = [
        {'date': '2025-12-01', 'name': '컨벤셔널 데드리프트'},
        {'date': '2025-12-01', 'name': '백 스쿼트'},
      ];

      final notifier = await createNotifier();

      final names = notifier.state.map((e) => e.name).toSet();
      expect(names, contains('플랫 벤치 프레스'));
      expect(names, contains('펜들레이 로우'));
    });

    test('마지막 세션에 A+B 운동 모두 존재 → 기본 루틴 유지 (ambiguous)',
        () async {
      fakeService.history = [
        {'date': '2025-12-01', 'name': '플랫 벤치 프레스'},
        {'date': '2025-12-01', 'name': '오버헤드 프레스 (OHP)'},
        {'date': '2025-12-01', 'name': '백 스쿼트'},
      ];

      final notifier = await createNotifier();

      final names = notifier.state.map((e) => e.name).toList();
      expect(names, contains('플랫 벤치 프레스'));
      expect(names, contains('펜들레이 로우'));
    });

    test('보조 운동은 A/B 교체 시 메인 운동에 오염되지 않고 뒤에 병합',
        () async {
      final todayWeekday = DateTime.now().weekday;
      fakeService.weeklyProgram = {
        todayWeekday: [
          ...defaultSquatRoutine,
          Exercise.initial(
              id: 'acc', name: '바벨 컬', sets: 3, reps: 10, weight: 20),
        ],
      };

      fakeService.history = [
        {'date': '2025-12-01', 'name': '플랫 벤치 프레스'},
        {'date': '2025-12-01', 'name': '펜들레이 로우'},
      ];

      final notifier = await createNotifier();

      final names = notifier.state.map((e) => e.name).toList();
      expect(names, contains('오버헤드 프레스 (OHP)'));
      expect(names, contains('컨벤셔널 데드리프트'));
      expect(names, contains('바벨 컬'));
      expect(names.where((n) => n == '플랫 벤치 프레스').length, 0,
          reason: 'A의 메인 운동이 B에 오염되면 안 됨');
    });

    test('Stronglifts key 상수가 중복 없이 올바르게 정의됨', () {
      final allA = WorkoutConstants.strongliftsMainA.toSet();
      final allB = WorkoutConstants.strongliftsMainB.toSet();

      final intersection = allA.intersection(allB);
      expect(intersection, {'백 스쿼트'},
          reason: 'A/B 공통 운동은 스쿼트뿐이어야 함');
    });
  });
}
