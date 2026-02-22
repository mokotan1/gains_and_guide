import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// DB 인스턴스 Provider (Dependency Injection)
final databaseProvider = FutureProvider<Database>((ref) async {
  return await DatabaseHelper.instance.database;
});

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gains_guide.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const boolType = 'BOOLEAN NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL'; // 소수점 (무게 등)

    // 1. Routine (루틴 마스터)
    await db.execute('''
      CREATE TABLE routine (
        _id $idType,
        name $textType,
        description TEXT,
        created_at $textType
      )
    ''');

    // 2. Exercise (운동 종목 마스터)
    await db.execute('''
      CREATE TABLE exercise (
        _id $idType,
        name $textType,
        target_muscle $textType,
        equipment_type $textType,
        is_custom $boolType
      )
    ''');

    // 3. Routine_Exercise (루틴-운동 연결)
    await db.execute('''
      CREATE TABLE routine_exercise (
        _id $idType,
        routine_id $intType,
        exercise_id $intType,
        order_index $intType,
        target_sets $intType,
        target_reps $intType,
        FOREIGN KEY (routine_id) REFERENCES routine (_id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercise (_id) ON DELETE CASCADE
      )
    ''');

    // 4. Workout_Log (실제 운동 기록)
    await db.execute('''
      CREATE TABLE workout_log (
        _id $idType,
        date $textType,
        exercise_id $intType,
        set_number $intType,
        weight $realType,
        reps $intType,
        is_completed $boolType,
        FOREIGN KEY (exercise_id) REFERENCES exercise (_id)
      )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
