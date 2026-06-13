import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/big3_competition/application/big3_competition_service.dart';
import 'package:gains_and_guide/features/big3_competition/domain/models/big3_stats.dart';
import 'package:gains_and_guide/features/big3_competition/domain/models/competition_profile.dart';
import 'package:gains_and_guide/features/big3_competition/domain/models/competition_season.dart';
import 'package:gains_and_guide/features/big3_competition/domain/models/leaderboard_entry.dart';
import 'package:gains_and_guide/features/big3_competition/domain/models/rank_summary.dart';
import 'package:gains_and_guide/features/big3_competition/domain/repositories/big3_competition_repository.dart';

class _FakeRepo implements Big3CompetitionRepository {
  @override
  Future<CompetitionSeason?> fetchCurrentSeason() async => null;

  @override
  Future<CompetitionProfile?> fetchMyProfile() async => null;

  @override
  Future<CompetitionProfile> optIn({String? displayAlias}) async {
    return CompetitionProfile(
      displayAlias: displayAlias ?? '리프터-TEST',
      competitionOptedIn: true,
      leaderboardOptIn: true,
    );
  }

  @override
  Future<CompetitionProfile> optOut() async {
    return const CompetitionProfile(
      displayAlias: '리프터-TEST',
      competitionOptedIn: false,
      leaderboardOptIn: false,
    );
  }

  @override
  Future<CompetitionProfile> setLeaderboardVisibility({
    required bool visible,
  }) async {
    return CompetitionProfile(
      displayAlias: '리프터-TEST',
      competitionOptedIn: true,
      leaderboardOptIn: visible,
    );
  }

  @override
  Future<Big3Stats> submitLift({
    required String liftType,
    required double weightKg,
    required int reps,
  }) async {
    return const Big3Stats(
      squat1rmKg: 100,
      bench1rmKg: null,
      deadlift1rmKg: null,
    );
  }

  @override
  Future<Big3Stats> fetchMyStats({String? seasonId}) async {
    return const Big3Stats(
      squat1rmKg: 100,
      bench1rmKg: 80,
      deadlift1rmKg: 120,
      total1rmKg: 300,
    );
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    String? seasonId,
    int limit = 50,
    int offset = 0,
  }) async {
    return const [];
  }

  @override
  Future<RankSummary> fetchMyRank({String? seasonId}) async {
    return const RankSummary(
      ranked: true,
      rank: 3,
      displayAlias: '리프터-TEST',
      reason: null,
      records: Big3Stats(
        squat1rmKg: 100,
        bench1rmKg: 80,
        deadlift1rmKg: 120,
        total1rmKg: 300,
      ),
      totalParticipants: 20,
    );
  }
}

void main() {
  group('Big3CompetitionService', () {
    late Big3CompetitionService service;

    setUp(() {
      service = Big3CompetitionService(_FakeRepo());
    });

    test('rejects invalid lift type', () {
      expect(
        () => service.submitLift(liftType: 'ohp', weightKg: 60, reps: 5),
        throwsArgumentError,
      );
    });

    test('rejects reps above 12', () {
      expect(
        () => service.submitLift(liftType: 'squat', weightKg: 100, reps: 15),
        throwsArgumentError,
      );
    });

    test('accepts valid submission', () async {
      final stats = await service.submitLift(
        liftType: 'squat',
        weightKg: 100,
        reps: 5,
      );
      expect(stats.squat1rmKg, 100);
    });

    test('loads my rank summary', () async {
      final rank = await service.myRank(seasonId: 'season-1');
      expect(rank.ranked, isTrue);
      expect(rank.rank, 3);
      expect(rank.statusMessage, '내 순위 3위 · 전체 20명');
    });
  });
}
