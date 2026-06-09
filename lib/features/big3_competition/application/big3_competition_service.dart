import '../../../core/constants/workout_constants.dart';
import '../domain/models/big3_stats.dart';
import '../domain/models/competition_profile.dart';
import '../domain/models/competition_season.dart';
import '../domain/models/leaderboard_entry.dart';
import '../domain/repositories/big3_competition_repository.dart';

class Big3CompetitionService {
  Big3CompetitionService(this._repository);

  final Big3CompetitionRepository _repository;

  Future<CompetitionSeason?> currentSeason() => _repository.fetchCurrentSeason();

  Future<CompetitionProfile?> myProfile() => _repository.fetchMyProfile();

  Future<CompetitionProfile> optIn({String? displayAlias}) =>
      _repository.optIn(displayAlias: displayAlias);

  Future<CompetitionProfile> optOut() => _repository.optOut();

  Future<CompetitionProfile> setLeaderboardVisibility({required bool visible}) =>
      _repository.setLeaderboardVisibility(visible: visible);

  Future<Big3Stats> submitLift({
    required String liftType,
    required double weightKg,
    required int reps,
  }) {
    if (!WorkoutConstants.big3LiftTypes.contains(liftType)) {
      throw ArgumentError('invalid lift type: $liftType');
    }
    if (weightKg <= 0) {
      throw ArgumentError('weight must be positive');
    }
    if (reps < 1 || reps > 12) {
      throw ArgumentError('reps must be between 1 and 12 for competition');
    }
    return _repository.submitLift(
      liftType: liftType,
      weightKg: weightKg,
      reps: reps,
    );
  }

  Future<Big3Stats> myStats({String? seasonId}) =>
      _repository.fetchMyStats(seasonId: seasonId);

  Future<List<LeaderboardEntry>> leaderboard({
    String? seasonId,
    int limit = 50,
  }) =>
      _repository.fetchLeaderboard(seasonId: seasonId, limit: limit);
}
