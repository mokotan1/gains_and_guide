import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/repositories/cardio_history_repository.dart';
import 'package:gains_and_guide/features/home/domain/settlement_coach.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';

class _FakeCardioRepo implements CardioHistoryRepository {
  _FakeCardioRepo(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<void> deleteCardioBySourceInDateRange(
    String userId,
    String startDate,
    String endDate,
    String source,
  ) async {}

  @override
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  ) async =>
      rows;

  @override
  Future<List<double>> getWeeklyCardioLoads(int weekCount) async => [];

  @override
  Future<void> saveCardioHistory(List<Map<String, dynamic>> rows) async {}

  @override
  Future<void> updateSyncedAtForExternalIds(
    List<String> externalIds,
    String syncedAtIso,
  ) async {}
}

void main() {
  group('SettlementCoach', () {
    test('isStrongliftsTemplateDay when squat present', () {
      expect(
        SettlementCoach.isStrongliftsTemplateDay([
          Exercise.initial(
            id: '1',
            name: '백 스쿼트',
            sets: 5,
            reps: 5,
            weight: 60,
          ),
        ]),
        true,
      );
    });

    test('isStrongliftsTemplateDay false without squat', () {
      expect(
        SettlementCoach.isStrongliftsTemplateDay([
          Exercise.initial(
            id: '1',
            name: '레그 프레스',
            sets: 3,
            reps: 10,
            weight: 100,
          ),
        ]),
        false,
      );
    });

    test('buildCardioCoachContext formats marker block', () async {
      final text = await SettlementCoach.buildCardioCoachContext(
        cardioRepo: _FakeCardioRepo([
          {
            'cardio_name': '런닝',
            'duration_minutes': 30.0,
            'rpe': 7.0,
          },
        ]),
        dateYmd: '2026-04-03',
      );
      expect(text.contains('[유산소 운동 데이터]'), true);
      expect(text.contains('런닝'), true);
      expect(text.contains('30'), true);
    });

    test('weightSettlementMessage branches', () {
      expect(
        SettlementCoach.weightSettlementMessage(
          isStrongliftsDay: true,
          hasCardioToday: true,
          profilePrefix: '',
        ),
        contains('스트롱리프트'),
      );
      expect(
        SettlementCoach.weightSettlementMessage(
          isStrongliftsDay: false,
          hasCardioToday: true,
          profilePrefix: '',
        ),
        contains('별도'),
      );
      expect(
        SettlementCoach.weightSettlementMessage(
          isStrongliftsDay: false,
          hasCardioToday: false,
          profilePrefix: '',
        ),
        contains('스트롱리프트 전용'),
      );
    });
  });
}
