import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../domain/repositories/routine_repository.dart';
import 'routine_repository_impl.dart';

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepositoryImpl(DatabaseHelper.instance);
});
