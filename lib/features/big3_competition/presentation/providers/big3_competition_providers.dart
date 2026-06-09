import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../application/big3_competition_service.dart';
import '../../data/big3_competition_repository_impl.dart';
import '../../domain/models/big3_stats.dart';
import '../../domain/models/competition_profile.dart';
import '../../domain/models/competition_season.dart';
import '../../domain/models/leaderboard_entry.dart';
import '../../domain/repositories/big3_competition_repository.dart';

final big3CompetitionRepositoryProvider = Provider<Big3CompetitionRepository>((ref) {
  return Big3CompetitionRepositoryImpl(ref.watch(apiClientProvider));
});

final big3CompetitionServiceProvider = Provider<Big3CompetitionService>((ref) {
  return Big3CompetitionService(ref.watch(big3CompetitionRepositoryProvider));
});

final big3CurrentSeasonProvider = FutureProvider<CompetitionSeason?>((ref) async {
  return ref.watch(big3CompetitionServiceProvider).currentSeason();
});

final big3MyProfileProvider = FutureProvider<CompetitionProfile?>((ref) async {
  return ref.watch(big3CompetitionServiceProvider).myProfile();
});

final big3MyStatsProvider = FutureProvider<Big3Stats>((ref) async {
  final season = await ref.watch(big3CurrentSeasonProvider.future);
  return ref
      .watch(big3CompetitionServiceProvider)
      .myStats(seasonId: season?.id);
});

final big3LeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final season = await ref.watch(big3CurrentSeasonProvider.future);
  return ref
      .watch(big3CompetitionServiceProvider)
      .leaderboard(seasonId: season?.id);
});
