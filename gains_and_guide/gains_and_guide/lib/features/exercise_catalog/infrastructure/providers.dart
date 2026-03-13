import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../domain/repositories/exercise_catalog_repository.dart';
import 'exercise_catalog_repository_impl.dart';

final exerciseCatalogRepositoryProvider = Provider<ExerciseCatalogRepository>((ref) {
  return ExerciseCatalogRepositoryImpl(DatabaseHelper.instance);
});
