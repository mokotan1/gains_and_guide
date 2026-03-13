import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../data/body_profile_repository_impl.dart';
import '../data/exercise_catalog_repository_impl.dart';
import '../data/progression_repository_impl.dart';
import '../data/workout_history_repository_impl.dart';
import '../domain/repositories/body_profile_repository.dart';
import '../domain/repositories/exercise_catalog_repository.dart';
import '../domain/repositories/progression_repository.dart';
import '../domain/repositories/workout_history_repository.dart';

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
