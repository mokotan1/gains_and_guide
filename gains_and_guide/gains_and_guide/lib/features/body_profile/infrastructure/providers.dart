import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../domain/repositories/body_profile_repository.dart';
import 'body_profile_repository_impl.dart';

final bodyProfileRepositoryProvider = Provider<BodyProfileRepository>((ref) {
  return BodyProfileRepositoryImpl(DatabaseHelper.instance);
});
