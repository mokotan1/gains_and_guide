import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/data/health_cardio_sync_repository_impl.dart';

void main() {
  group('healthCardioSyncFailureFromError', () {
    test('MissingPluginException maps to friendly message without raw exception', () {
      final result = healthCardioSyncFailureFromError(
        MissingPluginException('getDeviceInfo'),
        StackTrace.empty,
      );
      expect(result.success, false);
      expect(result.sessionsImported, 0);
      expect(result.message, kHealthPluginMissingUserMessage);
      expect(result.message, isNot(contains('MissingPluginException')));
    });

    test('other exceptions keep technical detail in message for debugging', () {
      final result = healthCardioSyncFailureFromError(
        StateError('bad'),
        StackTrace.empty,
      );
      expect(result.success, false);
      expect(result.message, contains('동기화에 실패했습니다'));
      expect(result.message, contains('Bad state'));
    });
  });
}
