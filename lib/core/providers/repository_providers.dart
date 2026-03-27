import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../data/body_profile_repository_impl.dart';
import '../data/cardio_catalog_repository_impl.dart';
import '../data/deload_repository_impl.dart';
import '../data/exercise_catalog_repository_impl.dart';
import '../data/favorite_exercise_repository_impl.dart';
import '../data/progression_repository_impl.dart';
import '../data/user_profile_repository_impl.dart';
import '../data/workout_history_repository_impl.dart';
import '../domain/repositories/body_profile_repository.dart';
import '../domain/repositories/cardio_catalog_repository.dart';
import '../domain/repositories/deload_repository.dart';
import '../domain/repositories/exercise_catalog_repository.dart';
import '../domain/repositories/favorite_exercise_repository.dart';
import '../domain/repositories/progression_repository.dart';
import '../domain/repositories/user_profile_repository.dart';
import '../domain/repositories/workout_history_repository.dart';
import '../../features/weekly_report/data/weekly_report_repository_impl.dart';
import '../../features/weekly_report/domain/repositories/weekly_report_repository.dart';

final _dbProvider = Provider<DatabaseHelper>((_) => DatabaseHelper.instance);

final workoutHistoryRepositoryProvider = Provider<WorkoutHistoryRepository>((ref) {
  return WorkoutHistoryRepositoryImpl(ref.watch(_dbProvider));
});

final progressionRepositoryProvider = Provider<ProgressionRepository>((ref) {
  return ProgressionRepositoryImpl(ref.watch(_dbProvider));
});

final bodyProfileRepositoryProvider = Provider<BodyProfileRepository>((ref) {
  return BodyProfileRepositoryImpl(ref.watch(_dbProvider));
});

final exerciseCatalogRepositoryProvider = Provider<ExerciseCatalogRepository>((ref) {
  return ExerciseCatalogRepositoryImpl(ref.watch(_dbProvider));
});

final deloadRepositoryProvider = Provider<DeloadRepository>((ref) {
  return DeloadRepositoryImpl(ref.watch(_dbProvider));
});

final weeklyReportRepositoryProvider = Provider<WeeklyReportRepository>((ref) {
  return WeeklyReportRepositoryImpl(ref.watch(_dbProvider));
});

final cardioCatalogRepositoryProvider = Provider<CardioCatalogRepository>((ref) {
  return CardioCatalogRepositoryImpl(ref.watch(_dbProvider));
});

final favoriteExerciseRepositoryProvider = Provider<FavoriteExerciseRepository>((ref) {
  return FavoriteExerciseRepositoryImpl(ref.watch(_dbProvider));
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl(ref.watch(_dbProvider));
});
