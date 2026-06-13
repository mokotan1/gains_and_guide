import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/big3_competition/domain/models/rank_summary.dart';

void main() {
  group('RankSummary', () {
    test('parses ranked response', () {
      final summary = RankSummary.fromJson({
        'ranked': true,
        'rank': 12,
        'display_alias': '리프터-TEST',
        'reason': null,
        'records': {
          'squat_1rm_kg': 140.0,
          'bench_1rm_kg': 95.0,
          'deadlift_1rm_kg': 180.0,
          'total_1rm_kg': 415.0,
        },
        'total_participants': 84,
        'subject': 'must-not-be-used',
      });

      expect(summary.ranked, isTrue);
      expect(summary.rank, 12);
      expect(summary.displayAlias, '리프터-TEST');
      expect(summary.reason, isNull);
      expect(summary.totalParticipants, 84);
      expect(summary.records.total1rmKg, 415.0);
      expect(summary.statusMessage, '내 순위 12위 · 전체 84명');
    });

    test('parses incomplete lifts reason', () {
      final summary = RankSummary.fromJson({
        'ranked': false,
        'rank': null,
        'display_alias': '리프터-TEST',
        'reason': 'incomplete_lifts',
        'records': {
          'squat_1rm_kg': 140.0,
          'bench_1rm_kg': null,
          'deadlift_1rm_kg': null,
          'total_1rm_kg': null,
        },
        'total_participants': 10,
      });

      expect(summary.ranked, isFalse);
      expect(summary.statusMessage, '3종목 기록이 모두 있어야 순위가 표시됩니다.');
    });

    test('falls back for unknown reason', () {
      final summary = RankSummary.fromJson({
        'ranked': false,
        'reason': 'new_server_reason',
        'records': {},
        'total_participants': 0,
      });

      expect(summary.statusMessage, '아직 순위를 표시할 수 없어요.');
    });
  });
}
