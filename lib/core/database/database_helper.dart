import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gains_v5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    return await openDatabase(
      join(dbPath, filePath),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exercises (
            id TEXT PRIMARY KEY, name TEXT, sets INTEGER, reps INTEGER, 
            weight REAL, setRpe TEXT, date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE body_profile (
            id INTEGER PRIMARY KEY, weight REAL, muscle_mass REAL
          )
        ''');
      },
    );
  }

  // --- CSV 추출을 위한 전체 기록 조회 ---
  Future<List<Map<String, dynamic>>> getAllHistory() async {
    final db = await instance.database;
    return await db.query('exercises', orderBy: 'date ASC');
  }

  // 데이터 저장 및 삭제
  Future<int> saveProfile(Map<String, dynamic> p) async => (await database).insert('body_profile', p, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<Map<String, dynamic>?> getProfile() async {
    final res = await (await database).query('body_profile', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }
  Future<int> deleteExercise(String id) async => (await database).delete('exercises', where: 'id = ?', whereArgs: [id]);
}