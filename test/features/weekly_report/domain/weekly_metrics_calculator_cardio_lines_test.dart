import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/weekly_report/domain/weekly_metrics_calculator.dart';

void main() {
  group('buildCardioSessionLinesForAi', () {
    test('formats distance and heart rate', () {
      final rows = [
        {
          'cardio_name': 'HealthSync|달리기',
          'duration_minutes': 40.0,
          'distance_km': 5.0,
          'date': '2026-03-24',
          'avg_heart_rate': 135,
          'max_heart_rate': 155,
          'source': 'health',
        },
      ];
      final lines = WeeklyMetricsCalculator.buildCardioSessionLinesForAi(rows);
      expect(lines.length, 1);
      expect(
        lines.first,
        '2026-03-24: HealthSync|달리기 40분 (거리: 5.0km) (평균 심박: 135bpm, 최대 심박: 155bpm)',
      );
    });

    test('health source without HR shows wearable message', () {
      final rows = [
        {
          'cardio_name': 'HealthSync|달리기',
          'duration_minutes': 30.0,
          'date': '2026-03-24',
          'source': 'health',
        },
      ];
      final lines = WeeklyMetricsCalculator.buildCardioSessionLinesForAi(rows);
      expect(lines.first, contains('웨어러블 심박 샘플 없음'));
    });

    test('sorts by date', () {
      final rows = [
        {
          'cardio_name': 'B',
          'duration_minutes': 10.0,
          'date': '2026-03-25',
          'source': 'manual',
        },
        {
          'cardio_name': 'A',
          'duration_minutes': 10.0,
          'date': '2026-03-24',
          'source': 'manual',
        },
      ];
      final lines = WeeklyMetricsCalculator.buildCardioSessionLinesForAi(rows);
      expect(lines.first.startsWith('2026-03-24'), isTrue);
      expect(lines.last.startsWith('2026-03-25'), isTrue);
    });
  });
}
