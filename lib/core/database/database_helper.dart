import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // 버전을 1에서 2로 올립니다.
    _database = await _initDB('gains_v5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    return await openDatabase(
      join(dbPath, filePath),
      version: 2, // 버전을 2로 변경
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // 업그레이드 로직 추가
    );
  }

  // 처음 설치 시 호출
  Future _createDB(Database db, int version) async {
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
    await db.execute('''
      CREATE TABLE workout_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, sets INTEGER, 
        reps INTEGER, weight REAL, rpe INTEGER, date TEXT
      )
    ''');
  }

  // 이미 설치된 상태에서 버전이 올라갔을 때 호출
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 기존에 workout_history 테이블이 없었다면 생성합니다.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workout_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, sets INTEGER, 
          reps INTEGER, weight REAL, rpe INTEGER, date TEXT
        )
      ''');
    }
  }

  // 운동 삭제
  Future<int> deleteExercise(String id) async {
    final db = await instance.database;
    return await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // 프로필 저장/가져오기
  Future<int> saveProfile(Map<String, dynamic> p) async {
    final db = await instance.database;
    return await db.insert('body_profile', p, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final db = await instance.database;
    final res = await db.query('body_profile', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  // 운동 기록 저장
  Future<void> saveWorkoutHistory(List<Map<String, dynamic>> history) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var h in history) {
      batch.insert('workout_history', h);
    }
    await batch.commit(noResult: true);
  }

  // 모든 기록 가져오기 (CSV용)
  Future<List<Map<String, dynamic>>> getAllHistory() async {
    final db = await instance.database;
    return await db.query('workout_history', orderBy: 'date DESC');
  }
}