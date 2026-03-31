import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../constants/cardio_source.dart';
import '../constants/health_sync_constants.dart';
import '../domain/health/health_cardio_sync_repository.dart';
import '../domain/health/health_cardio_sync_result.dart';
import '../domain/health/health_distance_energy.dart';
import '../domain/health/health_workout_labels.dart';
import '../domain/health/heart_rate_stats.dart';
import '../domain/health/cardio_remote_sync.dart';
import '../domain/repositories/cardio_history_repository.dart';

/// [Health] 패키지를 사용하는 [HealthCardioSyncRepository] 구현.
class HealthCardioSyncRepositoryImpl implements HealthCardioSyncRepository {
  HealthCardioSyncRepositoryImpl({
    required Health health,
    required CardioHistoryRepository cardioHistoryRepository,
    CardioRemoteSync? remoteSync,
  })  : _health = health,
        _cardioHistoryRepository = cardioHistoryRepository,
        _remoteSync = remoteSync;

  final Health _health;
  final CardioHistoryRepository _cardioHistoryRepository;
  final CardioRemoteSync? _remoteSync;

  @override
  Future<HealthCardioSyncResult> syncCardioFromHealth({
    required String userId,
    int lookbackDays = 7,
  }) async {
    if (kIsWeb) {
      return HealthCardioSyncResult.skipped('웹에서는 건강 데이터 연동을 지원하지 않습니다.');
    }
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return HealthCardioSyncResult.skipped('이 기기에서는 건강 데이터 연동을 지원하지 않습니다.');
    }

    try {
      await _health.configure();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final available = await _health.isHealthConnectAvailable();
        if (!available) {
          return HealthCardioSyncResult.failure(
            'Health Connect를 사용할 수 없습니다. Play 스토어에서 설치한 뒤 다시 시도해 주세요.',
          );
        }
      }

      final types = <HealthDataType>[
        HealthDataType.WORKOUT,
        HealthDataType.HEART_RATE,
      ];
      final authorized = await _health.requestAuthorization(types);
      if (!authorized) {
        return HealthCardioSyncResult.failure('건강 데이터 읽기 권한이 필요합니다.');
      }

      final end = DateTime.now();
      final start = end.subtract(Duration(days: lookbackDays));

      final workoutPoints = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );

      final rows = <Map<String, dynamic>>[];

      for (final point in workoutPoints) {
        if (point.type != HealthDataType.WORKOUT) continue;
        final raw = point.value;
        if (raw is! WorkoutHealthValue) continue;
        if (!isAerobicCardioWorkout(raw.workoutActivityType)) continue;

        final durationMinutes =
            point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
        if (durationMinutes <= 0) continue;

        final hrSamples = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.HEART_RATE],
          startTime: point.dateFrom,
          endTime: point.dateTo,
        );
        final hr = averageAndMaxHeartRateBpm(hrSamples);

        final dateStr = _dateOnly(point.dateFrom);
        final label = koreanLabelForWorkoutType(raw.workoutActivityType);
        final name = '$kHealthSyncCardioPrefix$label';

        rows.add({
          'user_id': userId,
          'cardio_name': name,
          'duration_minutes': durationMinutes,
          'distance_km': workoutDistanceKm(raw),
          'calories': workoutEnergyKcal(raw),
          'rpe': null,
          'date': dateStr,
          'avg_heart_rate': hr.avg,
          'max_heart_rate': hr.max,
          'source': kCardioSourceHealth,
          'external_id': point.uuid,
          'synced_at': null,
        });
      }

      final startStr = _dateOnly(start);
      final endStr = _dateOnly(end);

      await _cardioHistoryRepository.deleteCardioBySourceInDateRange(
        userId,
        startStr,
        endStr,
        kCardioSourceHealth,
      );

      if (rows.isNotEmpty) {
        await _cardioHistoryRepository.saveCardioHistory(rows);
      }

      await _remoteSync?.pushHealthCardioWindow(
        userId: userId,
        startDate: startStr,
        endDate: endStr,
        rows: rows,
      );

      return HealthCardioSyncResult.ok(rows.length);
    } catch (e, st) {
      debugPrint('HealthCardioSyncRepositoryImpl: $e\n$st');
      return HealthCardioSyncResult.failure('동기화에 실패했습니다: $e');
    }
  }

  static String _dateOnly(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
