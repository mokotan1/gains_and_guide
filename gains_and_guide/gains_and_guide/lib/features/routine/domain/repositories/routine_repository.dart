import '../entities/routine.dart';

/// 루틴 CRUD — 도메인 리포지토리(포트)
abstract class RoutineRepository {
  Future<Routine> create(Routine routine);
  Future<List<Routine>> readAllRoutines();
  Future<int> delete(int id);
}
