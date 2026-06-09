class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayAlias,
    required this.squat1rmKg,
    required this.bench1rmKg,
    required this.deadlift1rmKg,
    required this.total1rmKg,
  });

  final int rank;
  final String displayAlias;
  final double squat1rmKg;
  final double bench1rmKg;
  final double deadlift1rmKg;
  final double total1rmKg;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      displayAlias: json['display_alias'] as String,
      squat1rmKg: (json['squat_1rm_kg'] as num).toDouble(),
      bench1rmKg: (json['bench_1rm_kg'] as num).toDouble(),
      deadlift1rmKg: (json['deadlift_1rm_kg'] as num).toDouble(),
      total1rmKg: (json['total_1rm_kg'] as num).toDouble(),
    );
  }
}
