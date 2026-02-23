import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gains_and_guide.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 운동 기록 테이블
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT,
        sets INTEGER,
        reps INTEGER,
        weight REAL,
        setStatus TEXT,
        setRpe TEXT,
        date TEXT
      )
    ''');

    // 신체 프로필 테이블 (체중, 근육량 등)
    await db.execute('''
      CREATE TABLE body_profile (
        id INTEGER PRIMARY KEY,
        height REAL,
        weight REAL,
        muscle_mass REAL
      )
    ''');
  }

  // 프로필 저장/가져오기
  Future<int> saveProfile(Map<String, dynamic> profile) async {
    final db = await instance.database;
    return await db.insert('body_profile', profile, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final db = await instance.database;
    final res = await db.query('body_profile', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  // 운동 삭제
  Future<int> deleteExercise(String id) async {
    final db = await instance.database;
    return await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }
}