import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/constants/report_constants.dart';
import 'package:gains_and_guide/features/weekly_report/domain/weekly_metrics_calculator.dart';

void main() {
  final weekStart = DateTime(2026, 3, 23);
  final weekEnd = DateTime(2026, 3, 29);

  Map<String, dynamic> _row({
    required String name,
    required double weight,
    required int reps,
    int rpe = 8,
    String date = '2026-03-25',
  }) =>
      {'name': name, 'weight': weight, 'reps': reps, 'rpe': rpe, 'date': date};

  // ---------------------------------------------------------------------------
  // totalVolume
  // ---------------------------------------------------------------------------
  group('totalVolume', () {
    test('빈 리스트이면 0을 반환한다', () {
      expect(WeeklyMetricsCalculator.totalVolume([]), 0);
    });

    test('weight × reps 의 합을 정확히 계산한다', () {
      final rows = [
        _row(name: '스쿼트', weight: 100, reps: 5),
        _row(name: '스쿼트', weight: 100, reps: 5),
        _row(name: '벤치프레스', weight: 80, reps: 5),
      ];
      // 100*5 + 100*5 + 80*5 = 1400
      expect(WeeklyMetricsCalculator.totalVolume(rows), 1400);
    });

    test('weight 또는 reps 가 null 이면 해당 행을 0으로 처리한다', () {
      final rows = [
        {'name': 'a', 'weight': null, 'reps': 5, 'rpe': 8, 'date': '2026-03-25'},
        {'name': 'b', 'weight': 50, 'reps': null, 'rpe': 8, 'date': '2026-03-25'},
      ];
      expect(WeeklyMetricsCalculator.totalVolume(rows), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // averageRpe
  // ---------------------------------------------------------------------------
  group('averageRpe', () {
    test('빈 리스트이면 0을 반환한다', () {
      expect(WeeklyMetricsCalculator.averageRpe([]), 0);
    });

    test('RPE 평균을 정확히 계산한다', () {
      final rows = [
        _row(name: 'a', weight: 100, reps: 5, rpe: 8),
        _row(name: 'a', weight: 100, reps: 5, rpe: 9),
        _row(name: 'a', weight: 100, reps: 5, rpe: 10),
      ];
      expect(WeeklyMetricsCalculator.averageRpe(rows), 9.0);
    });

    test('RPE null 행은 평균 계산에서 제외한다', () {
      final rows = [
        {'name': 'a', 'weight': 100, 'reps': 5, 'rpe': null, 'date': '2026-03-25'},
        _row(name: 'a', weight: 100, reps: 5, rpe: 8),
      ];
      expect(WeeklyMetricsCalculator.averageRpe(rows), 8.0);
    });
  });

  // ---------------------------------------------------------------------------
  // epley1RM
  // ---------------------------------------------------------------------------
  group('epley1RM', () {
    test('reps=1 이면 weight 그대로 반환한다', () {
      expect(WeeklyMetricsCalculator.epley1RM(100, 1), 100);
    });

    test('reps=0 이면 0을 반환한다', () {
      expect(WeeklyMetricsCalculator.epley1RM(100, 0), 0);
    });

    test('weight=0 이면 0을 반환한다', () {
      expect(WeeklyMetricsCalculator.epley1RM(0, 5), 0);
    });

    test('Epley 공식을 정확히 계산한다', () {
      // 100 * (1 + 5/30) = 100 * 1.1667 ≈ 116.67
      final result = WeeklyMetricsCalculator.epley1RM(100, 5);
      expect(result, closeTo(116.67, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // calculateAcwr
  // ---------------------------------------------------------------------------
  group('calculateAcwr', () {
    test('chronic 데이터가 비어 있으면 0을 반환한다', () {
      expect(WeeklyMetricsCalculator.calculateAcwr(1000, []), 0);
    });

    test('chronic 평균이 0이면 0을 반환한다', () {
      expect(WeeklyMetricsCalculator.calculateAcwr(1000, [0, 0, 0, 0]), 0);
    });

    test('ACWR = acute / chronic_avg 를 정확히 계산한다', () {
      // chronic avg = (1000 + 1000 + 1000 + 1000) / 4 = 1000
      // ACWR = 1300 / 1000 = 1.3
      expect(
        WeeklyMetricsCalculator.calculateAcwr(1300, [1000, 1000, 1000, 1000]),
        closeTo(1.3, 0.001),
      );
    });

    test('ACWR 위험 존 (1.5 이상) 케이스', () {
      // chronic avg = 800, acute = 1300 → 1.625
      final acwr = WeeklyMetricsCalculator.calculateAcwr(1300, [800, 800, 800, 800]);
      expect(acwr, greaterThan(ReportConstants.acwrDangerMax));
    });
  });

  // ---------------------------------------------------------------------------
  // calculate (통합)
  // ---------------------------------------------------------------------------
  group('calculate (통합)', () {
    test('빈 데이터일 때 안전하게 빈 메트릭스를 반환한다', () {
      final metrics = WeeklyMetricsCalculator.calculate(
        currentWeekRows: [],
        chronicWeeklyVolumes: [],
        prevWeekRows: [],
        muscleMap: {},
        weekStart: weekStart,
        weekEnd: weekEnd,
      );

      expect(metrics.totalSessions, 0);
      expect(metrics.totalVolume, 0);
      expect(metrics.acwr, 0);
      expect(metrics.estimated1RMs, isEmpty);
    });

    test('정상 데이터로 모든 지표가 올바르게 산출된다', () {
      final currentRows = [
        _row(name: '백 스쿼트', weight: 100, reps: 5, rpe: 8, date: '2026-03-24'),
        _row(name: '백 스쿼트', weight: 100, reps: 5, rpe: 9, date: '2026-03-24'),
        _row(name: '백 스쿼트', weight: 100, reps: 5, rpe: 9, date: '2026-03-24'),
        _row(name: '벤치프레스', weight: 80, reps: 5, rpe: 8, date: '2026-03-26'),
        _row(name: '벤치프레스', weight: 80, reps: 5, rpe: 8, date: '2026-03-26'),
      ];

      final prevRows = [
        _row(name: '백 스쿼트', weight: 95, reps: 5, rpe: 8, date: '2026-03-17'),
        _row(name: '벤치프레스', weight: 75, reps: 5, rpe: 7, date: '2026-03-19'),
      ];

      final muscleMap = {
        '백 스쿼트': 'quadriceps',
        '벤치프레스': 'chest',
      };

      final metrics = WeeklyMetricsCalculator.calculate(
        currentWeekRows: currentRows,
        chronicWeeklyVolumes: [2000, 1900, 1800, 1700],
        prevWeekRows: prevRows,
        muscleMap: muscleMap,
        weekStart: weekStart,
        weekEnd: weekEnd,
      );

      // 세션: 2026-03-24, 2026-03-26 → 2일
      expect(metrics.totalSessions, 2);

      // 볼륨: 100*5*3 + 80*5*2 = 1500 + 800 = 2300
      expect(metrics.totalVolume, 2300);

      // 평균 RPE: (8+9+9+8+8)/5 = 42/5 = 8.4
      expect(metrics.avgRpe, closeTo(8.4, 0.01));

      // ACWR: 2300 / ((2000+1900+1800+1700)/4) = 2300 / 1850 ≈ 1.243
      expect(metrics.acwr, closeTo(1.243, 0.01));

      // 근육군 볼륨
      expect(metrics.volumeByMuscle['quadriceps'], 1500);
      expect(metrics.volumeByMuscle['chest'], 800);

      // 1RM: 스쿼트 100*(1+5/30)=116.67, 벤치 80*(1+5/30)=93.33
      expect(metrics.estimated1RMs['백 스쿼트']!.current1RM, closeTo(116.7, 0.1));
      expect(metrics.estimated1RMs['벤치프레스']!.current1RM, closeTo(93.3, 0.1));

      // 이전 1RM: 스쿼트 95*(1+5/30)=110.83
      expect(metrics.estimated1RMs['백 스쿼트']!.previous1RM, closeTo(110.8, 0.1));

      // 실패율: RPE 10인 세트 없음 → 0
      expect(metrics.failureRate, 0);

      // prevWeekVolume
      expect(metrics.prevWeekVolume, 2000);
    });

    test('실패율이 올바르게 산출된다 (RPE 10 = 실패)', () {
      final rows = [
        _row(name: 'a', weight: 100, reps: 5, rpe: 8),
        _row(name: 'a', weight: 100, reps: 3, rpe: 10),
        _row(name: 'a', weight: 100, reps: 5, rpe: 9),
        _row(name: 'a', weight: 100, reps: 2, rpe: 10),
      ];

      final metrics = WeeklyMetricsCalculator.calculate(
        currentWeekRows: rows,
        chronicWeeklyVolumes: [2000],
        prevWeekRows: [],
        muscleMap: {},
        weekStart: weekStart,
        weekEnd: weekEnd,
      );

      // 4개 중 2개 RPE 10 → 0.5
      expect(metrics.failureRate, 0.5);
    });

    test('exerciseDeltas 가 올바르게 계산된다', () {
      final current = [
        _row(name: '스쿼트', weight: 105, reps: 5),
        _row(name: '스쿼트', weight: 100, reps: 5),
      ];
      final prev = [
        _row(name: '스쿼트', weight: 100, reps: 5, date: '2026-03-18'),
      ];

      final metrics = WeeklyMetricsCalculator.calculate(
        currentWeekRows: current,
        chronicWeeklyVolumes: [],
        prevWeekRows: prev,
        muscleMap: {},
        weekStart: weekStart,
        weekEnd: weekEnd,
      );

      final delta = metrics.exerciseDeltas
          .firstWhere((d) => d.exerciseName == '스쿼트');
      expect(delta.thisWeekMaxWeight, 105);
      expect(delta.lastWeekMaxWeight, 100);
      expect(delta.deltaKg, 5);
    });
  });
}
