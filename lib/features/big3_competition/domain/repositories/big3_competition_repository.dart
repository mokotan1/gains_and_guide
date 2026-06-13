import '../models/big3_stats.dart';
import '../models/competition_profile.dart';
import '../models/competition_season.dart';
import '../models/leaderboard_entry.dart';
import '../models/rank_summary.dart';

abstract class Big3CompetitionRepository {
  Future<CompetitionSeason?> fetchCurrentSeason();

  Future<CompetitionProfile?> fetchMyProfile();

  Future<CompetitionProfile> optIn({String? displayAlias});

  Future<CompetitionProfile> optOut();

  Future<CompetitionProfile> setLeaderboardVisibility({required bool visible});

  Future<Big3Stats> submitLift({
    required String liftType,
    required double weightKg,
    required int reps,
  });

  Future<Big3Stats> fetchMyStats({String? seasonId});

  Future<List<LeaderboardEntry>> fetchLeaderboard({
    String? seasonId,
    int limit = 50,
    int offset = 0,
  });

  Future<RankSummary> fetchMyRank({String? seasonId});
}
