import 'big3_stats.dart';

class RankSummary {
  const RankSummary({
    required this.ranked,
    required this.rank,
    required this.displayAlias,
    required this.reason,
    required this.records,
    required this.totalParticipants,
  });

  final bool ranked;
  final int? rank;
  final String? displayAlias;
  final String? reason;
  final Big3Stats records;
  final int totalParticipants;

  factory RankSummary.fromJson(Map<String, dynamic> json) {
    final recordsJson = json['records'];
    final records = recordsJson is Map<String, dynamic>
        ? recordsJson
        : recordsJson is Map
            ? Map<String, dynamic>.from(recordsJson)
            : const <String, dynamic>{};

    return RankSummary(
      ranked: json['ranked'] == true,
      rank: json['rank'] is num ? (json['rank'] as num).toInt() : null,
      displayAlias:
          json['display_alias'] is String ? json['display_alias'] as String : null,
      reason: json['reason'] is String ? json['reason'] as String : null,
      records: Big3Stats.fromBestsMap(
        {
          'squat': records['squat_1rm_kg'] ?? records['squat'],
          'bench': records['bench_1rm_kg'] ?? records['bench'],
          'deadlift': records['deadlift_1rm_kg'] ?? records['deadlift'],
        },
        total: records['total_1rm_kg'] is num
            ? (records['total_1rm_kg'] as num).toDouble()
            : null,
      ),
      totalParticipants: json['total_participants'] is num
          ? (json['total_participants'] as num).toInt()
          : 0,
    );
  }

  String get statusMessage {
    if (ranked && rank != null) {
      return '내 순위 $rank위 · 전체 $totalParticipants명';
    }
    return switch (reason) {
      'not_opted_in' => '시즌 참가 후 순위를 볼 수 있어요.',
      'leaderboard_hidden' => '순위표에서 숨김 상태예요.',
      'incomplete_lifts' => '3종목 기록이 모두 있어야 순위가 표시됩니다.',
      _ => '아직 순위를 표시할 수 없어요.',
    };
  }
}
