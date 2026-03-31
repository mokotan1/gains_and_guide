import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/health/heart_rate_stats.dart';
import 'package:health/health.dart';

void main() {
  group('averageAndMaxHeartRateBpm', () {
    test('empty list returns nulls', () {
      final r = averageAndMaxHeartRateBpm([]);
      expect(r.avg, isNull);
      expect(r.max, isNull);
    });

    test('single HR sample', () {
      final points = [
        HealthDataPoint(
          uuid: '1',
          value: NumericHealthValue(numericValue: 140),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: DateTime(2026, 1, 1, 10),
          dateTo: DateTime(2026, 1, 1, 10, 1),
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: 'd',
          sourceId: 's',
          sourceName: 'n',
        ),
      ];
      final r = averageAndMaxHeartRateBpm(points);
      expect(r.avg, 140);
      expect(r.max, 140);
    });

    test('multiple samples average and max', () {
      final points = [
        _hr(100),
        _hr(120),
        _hr(140),
      ];
      final r = averageAndMaxHeartRateBpm(points);
      expect(r.avg, 120);
      expect(r.max, 140);
    });

    test('ignores non heart_rate types', () {
      final points = [
        HealthDataPoint(
          uuid: '1',
          value: NumericHealthValue(numericValue: 999),
          type: HealthDataType.STEPS,
          unit: HealthDataUnit.COUNT,
          dateFrom: DateTime(2026, 1, 1),
          dateTo: DateTime(2026, 1, 1),
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: 'd',
          sourceId: 's',
          sourceName: 'n',
        ),
        _hr(130),
      ];
      final r = averageAndMaxHeartRateBpm(points);
      expect(r.avg, 130);
      expect(r.max, 130);
    });
  });
}

HealthDataPoint _hr(num bpm) => HealthDataPoint(
      uuid: 'u',
      value: NumericHealthValue(numericValue: bpm),
      type: HealthDataType.HEART_RATE,
      unit: HealthDataUnit.BEATS_PER_MINUTE,
      dateFrom: DateTime(2026, 1, 1),
      dateTo: DateTime(2026, 1, 1),
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'd',
      sourceId: 's',
      sourceName: 'n',
    );
