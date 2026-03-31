import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// 건강 동기화 중 [MissingPluginException](네이티브 플러그인 미등록 등) 시 사용자에게 보여줄 문구.
const String kHealthPluginMissingUserMessage =
    '건강 연동 모듈이 연결되지 않았습니다. 앱을 완전히 종료한 뒤 다시 실행하거나, 앱 삭제 후 재설치해 주세요.';

/// [syncCardioFromHealth]의 예외를 결과로 변환한다. 단위 테스트용.
@visibleForTesting
HealthCardioSyncResult healthCardioSyncFailureFromError(Object e, StackTrace st) {
  if (e is MissingPluginException) {
    debugPrint('HealthCardioSyncRepositoryImpl (MissingPluginException): $e\n$st');
    return HealthCardioSyncResult.failure(kHealthPluginMissingUserMessage);
  }
  debugPrint('HealthCardioSyncRepositoryImpl: $e\n$st');
  return HealthCardioSyncResult.failure('동기화에 실패했습니다: $e');
}

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
        final sdkStatus = await _health.getHealthConnectSdkStatus();
        if (sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          return HealthCardioSyncResult.failure(
            '이 기기의 Health Connect(헬스 커넥트)가 업데이트가 필요합니다. '
            '설정에서 시스템 업데이트를 확인하거나 Play 스토어에서 시스템 구성 요소·헬스 커넥트를 업데이트한 뒤 다시 시도해 주세요.',
          );
        }
        if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
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
      return healthCardioSyncFailureFromError(e, st);
    }
  }

  static String _dateOnly(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
