import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/routine.dart';
import '../../core/database/database_helper.dart';

// Provider (DI)
final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  // DB Helper 주입
  return RoutineRepository(DatabaseHelper.instance);
});

class RoutineRepository {
  final DatabaseHelper dbHelper;

  RoutineRepository(this.dbHelper);

  // 1. 루틴 생성
  Future<Routine> create(Routine routine) async {
    final db = await dbHelper.database;
    final id = await db.insert('routine', routine.toMap());
    return routine.copyWith(id: id);
  }

  // 2. 전체 루틴 조회
  Future<List<Routine>> readAllRoutines() async {
    final db = await dbHelper.database;
    final orderBy = 'created_at ASC';
    final result = await db.query('routine', orderBy: orderBy);

    return result.map((json) => Routine.fromMap(json)).toList();
  }

  // 3. 루틴 삭제
  Future<int> delete(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'routine',
      where: '_id = ?',
      whereArgs: [id],
    );
  }
}
