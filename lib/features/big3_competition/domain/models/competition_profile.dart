class CompetitionProfile {
  const CompetitionProfile({
    required this.displayAlias,
    required this.competitionOptedIn,
    required this.leaderboardOptIn,
    this.optedInAt,
  });

  final String displayAlias;
  final bool competitionOptedIn;
  final bool leaderboardOptIn;
  final DateTime? optedInAt;

  /// 제출 가능 여부
  bool get canSubmit => competitionOptedIn;

  factory CompetitionProfile.fromJson(Map<String, dynamic> json) {
    final alias = json['display_alias'];
    if (alias is! String || alias.isEmpty) {
      throw FormatException('Invalid competition profile payload');
    }
    final optedInAtRaw = json['opted_in_at'];
    final competitionOptedIn = json['competition_opted_in'] == true
        || json['opted_in'] == true;
    return CompetitionProfile(
      displayAlias: alias,
      competitionOptedIn: competitionOptedIn,
      leaderboardOptIn: json['leaderboard_opt_in'] != false,
      optedInAt: optedInAtRaw is String ? DateTime.tryParse(optedInAtRaw) : null,
    );
  }
}
