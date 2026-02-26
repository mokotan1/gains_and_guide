import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../features/routine/domain/exercise_catalog.dart';

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
      version: 4, // 버전을 3에서 4로 올림
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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
    await db.execute('''
      CREATE TABLE progression_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, 
        weight REAL, date TEXT
      )
    ''');
    // exercise_catalog 테이블 생성
    await _createExerciseCatalogTable(db);
  }

  Future _createExerciseCatalogTable(Database db) async {
    await db.execute('''
      CREATE TABLE exercise_catalog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        category TEXT,
        equipment TEXT,
        primary_muscles TEXT,
        instructions TEXT
      )
    ''');
  }

  // 이미 설치된 상태에서 버전이 올라갔을 때 호출
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workout_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, sets INTEGER, 
          reps INTEGER, weight REAL, rpe INTEGER, date TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS progression_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, 
          weight REAL, date TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await _createExerciseCatalogTable(db);
    }
  }

  // 운동 카탈로그 시딩
  Future<void> seedExerciseCatalog(List<Map<String, dynamic>> exercises) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var exercise in exercises) {
      batch.insert('exercise_catalog', exercise);
    }
    await batch.commit(noResult: true);
  }

  // 운동 카탈로그가 비어있는지 확인
  Future<bool> isExerciseCatalogEmpty() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM exercise_catalog'));
    return count == 0;
  }

  // 운동 카탈로그 검색
  Future<List<ExerciseCatalog>> searchCatalogExercises(String keyword) async {
    final db = await instance.database;
    final res = await db.query(
      'exercise_catalog',
      where: 'name LIKE ?',
      whereArgs: ['%$keyword%'],
    );
    return res.map((map) => ExerciseCatalog.fromMap(map)).toList();
  }

  // 증량 기록 저장 및 최신 무게 가져오기
  Future<void> saveProgression(String name, double weight) async {
    final db = await instance.database;
    await db.insert('progression_history', {
      'name': name,
      'weight': weight,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<double?> getLatestWeight(String name) async {
    final db = await instance.database;
    final res = await db.query(
      'progression_history',
      where: 'name = ?',
      whereArgs: [name],
      orderBy: 'date DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first['weight'] as double : null;
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