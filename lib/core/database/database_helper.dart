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
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
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
    await _createExerciseCatalogTable(db);
    await _createRoutineTables(db);
    await _createDeloadHistoryTable(db);
  }

  Future _createDeloadHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deload_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT,
        fatigue_score REAL NOT NULL,
        remaining_sessions INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future _createRoutineTables(Database db) async {
    await db.execute('''
      CREATE TABLE routine (
        _id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE routine_exercises (
        _id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        name TEXT NOT NULL,
        sets INTEGER NOT NULL DEFAULT 3,
        reps INTEGER NOT NULL DEFAULT 10,
        weight REAL NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_bodyweight INTEGER NOT NULL DEFAULT 0,
        is_cardio INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (routine_id) REFERENCES routine(_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE weekly_schedule (
        _id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        weekday INTEGER NOT NULL,
        FOREIGN KEY (routine_id) REFERENCES routine(_id) ON DELETE CASCADE
      )
    ''');
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
    if (oldVersion < 5) {
      await _createRoutineTables(db);
    }
    if (oldVersion < 6) {
      await _createDeloadHistoryTable(db);
    }
    if (oldVersion < 7) {
      await db.execute('''
        ALTER TABLE deload_history
        ADD COLUMN remaining_sessions INTEGER NOT NULL DEFAULT 0
      ''');
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

  /// 전체 운동 카탈로그 조회 (부위별 선택용)
  Future<List<Map<String, dynamic>>> getExerciseCatalogAll() async {
    final db = await instance.database;
    return db.query('exercise_catalog');
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
      'date': DateTime.now().toString().split(' ')[0], // YYYY-MM-DD 형식으로 통일
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

  /// 특정 운동의 최근 N개 세션 날짜별 기록 조회 (디로드 분석용)
  Future<List<Map<String, dynamic>>> getRecentSessionsByExercise(
    String exerciseName,
    int sessionLimit,
  ) async {
    final db = await instance.database;
    final dates = await db.rawQuery('''
      SELECT DISTINCT SUBSTR(date, 1, 10) AS session_date
      FROM workout_history
      WHERE name = ?
      ORDER BY session_date DESC
      LIMIT ?
    ''', [exerciseName, sessionLimit]);

    if (dates.isEmpty) return [];

    final dateList = dates.map((d) => d['session_date'] as String).toList();
    final placeholders = List.filled(dateList.length, '?').join(',');

    return db.rawQuery('''
      SELECT * FROM workout_history
      WHERE name = ? AND SUBSTR(date, 1, 10) IN ($placeholders)
      ORDER BY date DESC
    ''', [exerciseName, ...dateList]);
  }

  /// 최근 N개 세션의 전체 기록 조회 (세션 = 고유 날짜)
  Future<List<Map<String, dynamic>>> getRecentSessions(int sessionLimit) async {
    final db = await instance.database;
    final dates = await db.rawQuery('''
      SELECT DISTINCT SUBSTR(date, 1, 10) AS session_date
      FROM workout_history
      ORDER BY session_date DESC
      LIMIT ?
    ''', [sessionLimit]);

    if (dates.isEmpty) return [];

    final dateList = dates.map((d) => d['session_date'] as String).toList();
    final placeholders = List.filled(dateList.length, '?').join(',');

    return db.rawQuery('''
      SELECT * FROM workout_history
      WHERE SUBSTR(date, 1, 10) IN ($placeholders)
      ORDER BY date DESC
    ''', dateList);
  }

  /// 특정 운동의 최근 프로그레션 이력 조회
  Future<List<Map<String, dynamic>>> getRecentProgressions(
    String exerciseName,
    int limit,
  ) async {
    final db = await instance.database;
    return db.query(
      'progression_history',
      where: 'name = ?',
      whereArgs: [exerciseName],
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  // ---------------------------------------------------------------------------
  // Deload history
  // ---------------------------------------------------------------------------

  Future<void> saveDeloadRecord({
    required String startDate,
    required String endDate,
    required String reason,
    required double fatigueScore,
    required int remainingSessions,
  }) async {
    final db = await instance.database;
    await db.insert('deload_history', {
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'fatigue_score': fatigueScore,
      'remaining_sessions': remainingSessions,
    });
  }

  Future<Map<String, dynamic>?> getLastDeloadRecord() async {
    final db = await instance.database;
    final res = await db.query(
      'deload_history',
      orderBy: 'end_date DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<bool> isCurrentlyInDeload() async {
    final db = await instance.database;
    final res = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM deload_history
      WHERE remaining_sessions > 0
    ''');
    final count = Sqflite.firstIntValue(res) ?? 0;
    return count > 0;
  }

  /// 디로드 세션 1회 차감. 0이 되면 디로드 종료.
  Future<void> decrementDeloadSession() async {
    final db = await instance.database;
    await db.rawUpdate('''
      UPDATE deload_history
      SET remaining_sessions = remaining_sessions - 1
      WHERE remaining_sessions > 0
    ''');
  }
}