import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/constants/report_constants.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/report_section.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/weekly_metrics.dart';
import 'package:gains_and_guide/features/weekly_report/domain/weekly_report_generator.dart';

void main() {
  final weekStart = DateTime(2026, 3, 23);
  final weekEnd = DateTime(2026, 3, 29);

  WeeklyMetrics _metrics({
    int totalSessions = 3,
    double totalVolume = 5000,
    double avgRpe = 8.0,
    double acwr = 1.0,
    Map<String, double> volumeByMuscle = const {},
    Map<String, Estimated1RM> estimated1RMs = const {},
    double failureRate = 0,
    double? prevWeekVolume = 4500,
    List<ExerciseWeeklyDelta> exerciseDeltas = const [],
    int totalCardioSessions = 0,
    double totalCardioMinutes = 0,
    double totalCardioDistance = 0,
    double cardioAcwr = 0,
    double acuteCardioLoad = 0,
    double avgCardioRpe = 0,
  }) =>
      WeeklyMetrics(
        weekStart: weekStart,
        weekEnd: weekEnd,
        totalSessions: totalSessions,
        totalVolume: totalVolume,
        avgRpe: avgRpe,
        acwr: acwr,
        volumeByMuscle: volumeByMuscle,
        estimated1RMs: estimated1RMs,
        failureRate: failureRate,
        prevWeekVolume: prevWeekVolume,
        exerciseDeltas: exerciseDeltas,
        totalCardioSessions: totalCardioSessions,
        totalCardioMinutes: totalCardioMinutes,
        totalCardioDistance: totalCardioDistance,
        cardioAcwr: cardioAcwr,
        acuteCardioLoad: acuteCardioLoad,
        avgCardioRpe: avgCardioRpe,
      );

  // ---------------------------------------------------------------------------
  // Headline
  // ---------------------------------------------------------------------------
  group('Headline', () {
    test('세션 0이면 neutral 메시지', () {
      final report = WeeklyReportGenerator.generate(_metrics(totalSessions: 0));
      expect(report.headline.severity, InsightSeverity.neutral);
      expect(report.headline.text, contains('기록이 없습니다'));
    });

    test('웨이트 없이 유산소만 충분하면 positive headline', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        totalSessions: 0,
        totalVolume: 0,
        avgRpe: 0,
        acwr: 0,
        prevWeekVolume: null,
        totalCardioSessions: 3,
        totalCardioMinutes: 160,
        cardioAcwr: 1.0,
        acuteCardioLoad: 800,
        avgCardioRpe: 5,
      ));
      expect(report.headline.severity, InsightSeverity.positive);
      expect(report.headline.text, contains('유산소'));
    });

    test('유산소 ACWR 위험 시 critical headline (웨이트 없음)', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        totalSessions: 0,
        totalVolume: 0,
        acwr: 0,
        prevWeekVolume: null,
        totalCardioSessions: 2,
        totalCardioMinutes: 120,
        cardioAcwr: ReportConstants.cardioAcwrDangerMax + 0.1,
        acuteCardioLoad: 900,
        avgCardioRpe: 7,
      ));
      expect(report.headline.severity, InsightSeverity.critical);
    });

    test('ACWR > 1.5 → critical headline', () {
      final report = WeeklyReportGenerator.generate(_metrics(acwr: 1.6));
      expect(report.headline.severity, InsightSeverity.critical);
      expect(report.headline.text, contains('오버트레이닝'));
    });

    test('ACWR 1.3~1.5 → warning headline', () {
      final report = WeeklyReportGenerator.generate(_metrics(acwr: 1.35));
      expect(report.headline.severity, InsightSeverity.warning);
      expect(report.headline.text, contains('피로 관리'));
    });

    test('볼륨 성장 >= 5% → positive headline', () {
      final report = WeeklyReportGenerator.generate(
        _metrics(totalVolume: 5000, prevWeekVolume: 4500, acwr: 1.05),
      );
      // 5000→4500 = 11.1% 성장
      expect(report.headline.severity, InsightSeverity.positive);
      expect(report.headline.text, contains('성장세'));
    });

    test('ACWR < 0.8 → undertraining headline', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        acwr: 0.6,
        totalVolume: 3000,
        prevWeekVolume: 3000,
      ));
      expect(report.headline.severity, InsightSeverity.neutral);
      expect(report.headline.text, contains('낮았습니다'));
    });

    test('정상 범위 → 안정적 headline', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        acwr: 1.0,
        totalVolume: 4500,
        prevWeekVolume: 4400,
      ));
      expect(report.headline.severity, InsightSeverity.positive);
      expect(report.headline.text, contains('안정적'));
    });
  });

  // ---------------------------------------------------------------------------
  // Performance (Praise)
  // ---------------------------------------------------------------------------
  group('Performance', () {
    test('1RM 증가가 있으면 Praise 에 포함된다', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        estimated1RMs: {
          '백 스쿼트': const Estimated1RM(
            exerciseName: '백 스쿼트',
            current1RM: 120,
            previous1RM: 115,
          ),
        },
      ));

      final squat1rm = report.performances
          .where((p) => p.title.contains('1RM 증가'))
          .toList();
      expect(squat1rm, isNotEmpty);
      expect(squat1rm.first.description, contains('5.0kg 증가'));
    });

    test('볼륨 5% 이상 성장 시 볼륨 성장 인사이트 포함', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        totalVolume: 6000,
        prevWeekVolume: 5000,
      ));

      final volumeP = report.performances
          .where((p) => p.title.contains('볼륨 성장'))
          .toList();
      expect(volumeP, isNotEmpty);
    });

    test('3회 이상 훈련 시 일관성 Praise', () {
      final report =
          WeeklyReportGenerator.generate(_metrics(totalSessions: 4));
      final consistency = report.performances
          .where((p) => p.title.contains('일관성'))
          .toList();
      expect(consistency, isNotEmpty);
      expect(consistency.first.description, contains('4회'));
    });

    test('1회 훈련 시 일관성 Praise 없음', () {
      final report =
          WeeklyReportGenerator.generate(_metrics(totalSessions: 1));
      final consistency = report.performances
          .where((p) => p.title.contains('일관성'))
          .toList();
      expect(consistency, isEmpty);
    });

    test('유산소 150분 이상이면 WHO 인사이트', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        totalCardioMinutes: 150,
        totalCardioSessions: 2,
        acuteCardioLoad: 750,
        avgCardioRpe: 5,
      ));
      final who = report.performances
          .where((p) => p.title.contains('심혈관'))
          .toList();
      expect(who, isNotEmpty);
    });

    test('무게 증가 운동이 exerciseDeltas 에 있으면 Praise', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        exerciseDeltas: [
          const ExerciseWeeklyDelta(
            exerciseName: '벤치프레스',
            thisWeekMaxWeight: 85,
            lastWeekMaxWeight: 80,
          ),
        ],
      ));

      final delta = report.performances
          .where((p) => p.title.contains('벤치프레스'))
          .toList();
      expect(delta, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Warning
  // ---------------------------------------------------------------------------
  group('Warning', () {
    test('ACWR > 1.3 → ACWR 과부하 경고 포함', () {
      final report = WeeklyReportGenerator.generate(_metrics(acwr: 1.35));
      final acwrW = report.warnings
          .where((w) => w.title == 'ACWR 과부하 경고')
          .toList();
      expect(acwrW, isNotEmpty);
      expect(acwrW.first.metricValue, 1.35);
    });

    test('ACWR > 1.5 → critical severity', () {
      final report = WeeklyReportGenerator.generate(_metrics(acwr: 1.6));
      final acwrW = report.warnings
          .firstWhere((w) => w.title == 'ACWR 과부하 경고');
      expect(acwrW.severity, InsightSeverity.critical);
    });

    test('평균 RPE >= 9.0 → 높은 RPE 경고', () {
      final report = WeeklyReportGenerator.generate(_metrics(avgRpe: 9.2));
      final rpeW = report.warnings
          .where((w) => w.title.contains('RPE'))
          .toList();
      expect(rpeW, isNotEmpty);
      expect(rpeW.first.metricValue, 9.2);
    });

    test('실패율 >= 30% → 실패율 경고', () {
      final report =
          WeeklyReportGenerator.generate(_metrics(failureRate: 0.35));
      final failW = report.warnings
          .where((w) => w.title.contains('실패율'))
          .toList();
      expect(failW, isNotEmpty);
    });

    test('근육군 불균형 감지', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        volumeByMuscle: {
          'chest': 5000,
          'back': 1500,
          'quadriceps': 4000,
        },
      ));

      final imbalance = report.warnings
          .where((w) => w.title.contains('볼륨 부족'))
          .toList();
      expect(imbalance, isNotEmpty);
      expect(imbalance.first.title, contains('back'));
    });

    test('볼륨이 noise floor 미만이면 불균형 무시', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        volumeByMuscle: {'chest': 200, 'back': 50},
      ));

      final imbalance = report.warnings
          .where((w) => w.title.contains('볼륨 부족'))
          .toList();
      expect(imbalance, isEmpty);
    });

    test('ACWR <= 1.3 이면 웨이트 ACWR 경고 없음', () {
      final report = WeeklyReportGenerator.generate(_metrics(acwr: 1.2));
      final acwrW = report.warnings
          .where((w) => w.title == 'ACWR 과부하 경고')
          .toList();
      expect(acwrW, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Action Items
  // ---------------------------------------------------------------------------
  group('ActionItems', () {
    test('ACWR 과부하 시 볼륨 감소 + RPE 조절 액션', () {
      final report = WeeklyReportGenerator.generate(_metrics(acwr: 1.4));
      final deload = report.actionItems
          .where((a) => a.instruction.contains('볼륨'))
          .toList();
      expect(deload, isNotEmpty);
      expect(deload.first.instruction, contains('10%'));
      expect(deload.first.instruction, contains('RPE 8'));
    });

    test('근육군 불균형 시 비중 증가 액션', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        volumeByMuscle: {'chest': 5000, 'back': 1000},
      ));

      final boost = report.actionItems
          .where((a) => a.instruction.contains('back'))
          .toList();
      expect(boost, isNotEmpty);
      expect(boost.first.instruction, contains('20%'));
    });

    test('높은 실패율 시 무게 조절 액션', () {
      final report =
          WeeklyReportGenerator.generate(_metrics(failureRate: 0.4));
      final weight = report.actionItems
          .where((a) => a.instruction.contains('무게'))
          .toList();
      expect(weight, isNotEmpty);
    });

    test('ACWR < 0.8 시 훈련 증가 액션', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        acwr: 0.6,
        totalVolume: 3000,
        prevWeekVolume: 3000,
      ));
      final boost = report.actionItems
          .where((a) => a.instruction.contains('빈도'))
          .toList();
      expect(boost, isNotEmpty);
    });

    test('정상 상태에서는 액션 아이템 없음', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        acwr: 1.0,
        avgRpe: 8.0,
        failureRate: 0.1,
        volumeByMuscle: {'chest': 3000, 'back': 2500},
      ));
      expect(report.actionItems, isEmpty);
    });

    test('우선순위가 1부터 증가순으로 부여된다', () {
      final report = WeeklyReportGenerator.generate(_metrics(
        acwr: 1.4,
        failureRate: 0.35,
        volumeByMuscle: {'chest': 5000, 'back': 1000},
      ));

      if (report.actionItems.length >= 2) {
        for (int i = 0; i < report.actionItems.length - 1; i++) {
          expect(
            report.actionItems[i].priority,
            lessThan(report.actionItems[i + 1].priority),
          );
        }
        expect(report.actionItems.first.priority, 1);
      }
    });
  });
}
