class Big3Stats {
  const Big3Stats({
    required this.squat1rmKg,
    required this.bench1rmKg,
    required this.deadlift1rmKg,
    this.total1rmKg,
  });

  final double? squat1rmKg;
  final double? bench1rmKg;
  final double? deadlift1rmKg;
  final double? total1rmKg;

  factory Big3Stats.fromBestsMap(Map<String, dynamic> bests, {double? total}) {
    double? read(String key) {
      final v = bests[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return null;
    }

    return Big3Stats(
      squat1rmKg: read('squat'),
      bench1rmKg: read('bench'),
      deadlift1rmKg: read('deadlift'),
      total1rmKg: total,
    );
  }
}
