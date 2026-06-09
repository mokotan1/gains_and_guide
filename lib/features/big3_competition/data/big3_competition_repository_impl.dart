import '../../../core/network/api_client.dart';
import '../domain/models/big3_stats.dart';
import '../domain/models/competition_profile.dart';
import '../domain/models/competition_season.dart';
import '../domain/models/leaderboard_entry.dart';
import '../domain/repositories/big3_competition_repository.dart';

class Big3CompetitionRepositoryImpl implements Big3CompetitionRepository {
  Big3CompetitionRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<CompetitionSeason?> fetchCurrentSeason() async {
    final json = await _api.get('/strength/seasons/current');
    final season = json['season'];
    if (season is! Map<String, dynamic>) return null;
    return CompetitionSeason.fromJson(season);
  }

  @override
  Future<CompetitionProfile?> fetchMyProfile() async {
    final json = await _api.get('/strength/profile/me');
    final profile = json['profile'];
    if (profile is! Map<String, dynamic>) return null;
    return CompetitionProfile.fromJson(profile);
  }

  @override
  Future<CompetitionProfile> optIn({String? displayAlias}) async {
    return updateProfile(
      displayAlias: displayAlias,
      competitionOptedIn: true,
      leaderboardOptIn: true,
    );
  }

  @override
  Future<CompetitionProfile> optOut() async {
    return updateProfile(
      competitionOptedIn: false,
      leaderboardOptIn: false,
    );
  }

  @override
  Future<CompetitionProfile> setLeaderboardVisibility({
    required bool visible,
  }) async {
    return updateProfile(leaderboardOptIn: visible);
  }

  Future<CompetitionProfile> updateProfile({
    String? displayAlias,
    bool? competitionOptedIn,
    bool? leaderboardOptIn,
    double? bodyWeightKg,
  }) async {
    final body = <String, dynamic>{};
    if (displayAlias != null && displayAlias.trim().isNotEmpty) {
      body['display_alias'] = displayAlias.trim();
    }
    if (competitionOptedIn != null) {
      body['competition_opted_in'] = competitionOptedIn;
    }
    if (leaderboardOptIn != null) {
      body['leaderboard_opt_in'] = leaderboardOptIn;
    }
    if (bodyWeightKg != null) {
      body['body_weight_kg'] = bodyWeightKg;
    }
    final json = await _api.put('/strength/profile/me', body);
    final profile = json['profile'];
    if (profile is! Map<String, dynamic>) {
      throw const FormatException('profile response missing profile');
    }
    return CompetitionProfile.fromJson(profile);
  }

  @override
  Future<Big3Stats> submitLift({
    required String liftType,
    required double weightKg,
    required int reps,
  }) async {
    final json = await _api.post('/strength/lifts', {
      'lift_type': liftType,
      'weight_kg': weightKg,
      'reps': reps,
    });
    return _statsFromResponse(json);
  }

  @override
  Future<Big3Stats> fetchMyStats({String? seasonId}) async {
    final path = seasonId == null
        ? '/strength/records/me'
        : '/strength/records/me?season_id=$seasonId';
    final json = await _api.get(path);
    return _statsFromResponse(json);
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    String? seasonId,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String>[
      'limit=$limit',
      'offset=$offset',
      if (seasonId != null) 'season_id=$seasonId',
    ].join('&');
    final json = await _api.get('/strength/leaderboard?$query');
    final entries = json['entries'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList();
  }

  Big3Stats _statsFromResponse(Map<String, dynamic> json) {
    final records = json['records'];
    final bests = json['bests'];
    final source = records is Map
        ? Map<String, dynamic>.from(records)
        : (bests is Map ? Map<String, dynamic>.from(bests) : null);
    if (source == null) {
      return const Big3Stats(
        squat1rmKg: null,
        bench1rmKg: null,
        deadlift1rmKg: null,
      );
    }
    final total = source['total_1rm_kg'] ?? json['total_1rm_kg'];
    return Big3Stats.fromBestsMap(
      {
        'squat': source['squat_1rm_kg'] ?? source['squat'],
        'bench': source['bench_1rm_kg'] ?? source['bench'],
        'deadlift': source['deadlift_1rm_kg'] ?? source['deadlift'],
      },
      total: total is num ? total.toDouble() : null,
    );
  }
}
