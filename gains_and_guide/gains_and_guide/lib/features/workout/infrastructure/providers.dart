import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../domain/repositories/progression_repository.dart';
import '../domain/repositories/workout_history_repository.dart';
import '../domain/repositories/workout_session_repository.dart';
import 'progression_repository_impl.dart';
import 'workout_history_repository_impl.dart';
import 'workout_session_repository_impl.dart';

final workoutHistoryRepositoryProvider = Provider<WorkoutHistoryRepository>((ref) {
  return WorkoutHistoryRepositoryImpl(DatabaseHelper.instance);
});

final progressionRepositoryProvider = Provider<ProgressionRepository>((ref) {
  return ProgressionRepositoryImpl(DatabaseHelper.instance);
});

final workoutSessionRepositoryProvider = Provider<WorkoutSessionRepository>((ref) {
  return WorkoutSessionRepositoryImpl();
});
