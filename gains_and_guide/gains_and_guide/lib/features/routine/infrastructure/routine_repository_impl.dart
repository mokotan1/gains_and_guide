import '../../../../core/database/database_helper.dart';
import '../domain/entities/routine.dart';
import '../domain/repositories/routine_repository.dart';

class RoutineRepositoryImpl implements RoutineRepository {
  final DatabaseHelper _db;

  RoutineRepositoryImpl(this._db);

  @override
  Future<Routine> create(Routine routine) async {
    final db = await _db.database;
    final id = await db.insert('routine', routine.toMap());
    return routine.copyWith(id: id as int?);
  }

  @override
  Future<List<Routine>> readAllRoutines() async {
    final db = await _db.database;
    final rows = await db.query('routine', orderBy: 'created_at ASC');
    return rows.map((json) => Routine.fromMap(json)).toList();
  }

  @override
  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('routine', where: '_id = ?', whereArgs: [id]);
  }
}
