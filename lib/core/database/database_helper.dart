import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../features/routine/domain/exercise_catalog.dart';
import '../domain/models/cardio_catalog.dart';

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
      version: 10,
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
    await _createCardioCatalogTable(db);
    await _createFavoriteExercisesTable(db);
    await _createRoutineTables(db);
    await _createDeloadHistoryTable(db);
    await _createWeeklyReportsTable(db);
  }

  Future _createWeeklyReportsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        week_start TEXT NOT NULL,
        week_end TEXT NOT NULL,
        report_json TEXT NOT NULL,
        generated_at TEXT NOT NULL,
        UNIQUE(week_start)
      )
    ''');
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
        secondary_muscles TEXT,
        instructions TEXT,
        level TEXT,
        force_type TEXT,
        mechanic TEXT
      )
    ''');
  }

  Future _createCardioCatalogTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cardio_catalog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        equipment TEXT NOT NULL DEFAULT '',
        instructions TEXT NOT NULL DEFAULT '',
        level TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future _createFavoriteExercisesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_catalog_id INTEGER NOT NULL,
        is_cardio INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        UNIQUE(exercise_catalog_id, is_cardio)
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
    if (oldVersion < 8) {
      await _createWeeklyReportsTable(db);
    }
    if (oldVersion < 9) {
      await db.execute(
          'ALTER TABLE exercise_catalog ADD COLUMN secondary_muscles TEXT');
      await db.execute(
          'ALTER TABLE exercise_catalog ADD COLUMN level TEXT');
      await db.execute(
          'ALTER TABLE exercise_catalog ADD COLUMN force_type TEXT');
      await db.execute(
          'ALTER TABLE exercise_catalog ADD COLUMN mechanic TEXT');
      await db.execute('DELETE FROM exercise_catalog');
    }
    if (oldVersion < 10) {
      await _createCardioCatalogTable(db);
      await _createFavoriteExercisesTable(db);
      // 기존 exercise_catalog에서 cardio 항목을 cardio_catalog로 이동
      await db.execute('''
        INSERT INTO cardio_catalog (name, equipment, instructions, level)
        SELECT name, equipment, instructions, level
        FROM exercise_catalog
        WHERE LOWER(category) = 'cardio'
      ''');
      await db.execute('''
        DELETE FROM exercise_catalog WHERE LOWER(category) = 'cardio'
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

  // ---------------------------------------------------------------------------
  // Cardio catalog
  // ---------------------------------------------------------------------------

  Future<void> seedCardioCatalog(List<Map<String, dynamic>> exercises) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var exercise in exercises) {
      batch.insert('cardio_catalog', exercise);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> isCardioCatalogEmpty() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM cardio_catalog'));
    return count == 0;
  }

  Future<List<CardioCatalog>> getCardioCatalogAll() async {
    final db = await instance.database;
    final res = await db.query('cardio_catalog', orderBy: 'name ASC');
    return res.map((m) => CardioCatalog.fromMap(m)).toList();
  }

  Future<List<CardioCatalog>> searchCardioCatalog(String keyword) async {
    final db = await instance.database;
    final res = await db.query(
      'cardio_catalog',
      where: 'name LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'name ASC',
    );
    return res.map((m) => CardioCatalog.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // Exercise catalog — advanced search
  // ---------------------------------------------------------------------------

  /// 부위 + 장비 필터 검색. SQL LIKE로 primary_muscles와 equipment를 필터링.
  Future<List<ExerciseCatalog>> searchCatalogWithFilters({
    String keyword = '',
    List<String> muscleKeys = const [],
    String? equipment,
  }) async {
    final db = await instance.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (keyword.isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%$keyword%');
    }
    if (muscleKeys.isNotEmpty) {
      final muscleWhere =
          muscleKeys.map((_) => 'LOWER(primary_muscles) LIKE ?').join(' OR ');
      where.add('($muscleWhere)');
      args.addAll(muscleKeys.map((k) => '%$k%'));
    }
    if (equipment != null && equipment.isNotEmpty) {
      where.add('LOWER(equipment) LIKE ?');
      args.add('%${equipment.toLowerCase()}%');
    }

    final res = await db.query(
      'exercise_catalog',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return res.map((m) => ExerciseCatalog.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // Favorite exercises
  // ---------------------------------------------------------------------------

  Future<void> addFavorite(int catalogId, {bool isCardio = false}) async {
    final db = await instance.database;
    await db.insert(
      'favorite_exercises',
      {
        'exercise_catalog_id': catalogId,
        'is_cardio': isCardio ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeFavorite(int catalogId, {bool isCardio = false}) async {
    final db = await instance.database;
    await db.delete(
      'favorite_exercises',
      where: 'exercise_catalog_id = ? AND is_cardio = ?',
      whereArgs: [catalogId, isCardio ? 1 : 0],
    );
  }

  Future<Set<int>> getFavoriteIds({bool isCardio = false}) async {
    final db = await instance.database;
    final res = await db.query(
      'favorite_exercises',
      columns: ['exercise_catalog_id'],
      where: 'is_cardio = ?',
      whereArgs: [isCardio ? 1 : 0],
    );
    return res.map((r) => r['exercise_catalog_id'] as int).toSet();
  }

  Future<List<ExerciseCatalog>> getFavoriteExercises() async {
    final db = await instance.database;
    final res = await db.rawQuery('''
      SELECT ec.* FROM exercise_catalog ec
      INNER JOIN favorite_exercises fe
        ON ec.id = fe.exercise_catalog_id AND fe.is_cardio = 0
      ORDER BY fe.created_at DESC
    ''');
    return res.map((m) => ExerciseCatalog.fromMap(m)).toList();
  }

  Future<List<CardioCatalog>> getFavoriteCardioExercises() async {
    final db = await instance.database;
    final res = await db.rawQuery('''
      SELECT cc.* FROM cardio_catalog cc
      INNER JOIN favorite_exercises fe
        ON cc.id = fe.exercise_catalog_id AND fe.is_cardio = 1
      ORDER BY fe.created_at DESC
    ''');
    return res.map((m) => CardioCatalog.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // Recent exercises (from workout_history)
  // ---------------------------------------------------------------------------

  /// 가장 최근에 수행한 운동 이름을 중복 없이 N개 반환한다.
  Future<List<String>> getRecentExerciseNames({int limit = 5}) async {
    final db = await instance.database;
    final res = await db.rawQuery('''
      SELECT name, MAX(date) AS last_date
      FROM workout_history
      GROUP BY name
      ORDER BY last_date DESC
      LIMIT ?
    ''', [limit]);
    return res.map((r) => r['name'] as String).toList();
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

  // ---------------------------------------------------------------------------
  // Workout history — date range queries (주간 레포트용)
  // ---------------------------------------------------------------------------

  /// 날짜 범위 내의 모든 운동 기록 조회
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT * FROM workout_history
      WHERE SUBSTR(date, 1, 10) >= ? AND SUBSTR(date, 1, 10) <= ?
      ORDER BY date ASC
    ''', [startDate, endDate]);
  }

  /// 최근 N주간의 주별 총 볼륨 리스트 반환 (최신순, 이번 주 제외)
  Future<List<double>> getWeeklyVolumes(int weekCount) async {
    final db = await instance.database;
    final now = DateTime.now();

    final results = <double>[];
    for (int i = 1; i <= weekCount; i++) {
      final weekEnd = now.subtract(Duration(days: 7 * i - (7 - now.weekday % 7)));
      final weekStart = weekEnd.subtract(const Duration(days: 6));
      final startStr = _dateStr(weekStart);
      final endStr = _dateStr(weekEnd);

      final rows = await db.rawQuery('''
        SELECT COALESCE(SUM(weight * reps), 0) AS volume
        FROM workout_history
        WHERE SUBSTR(date, 1, 10) >= ? AND SUBSTR(date, 1, 10) <= ?
      ''', [startStr, endStr]);

      final volume = (rows.first['volume'] as num?)?.toDouble() ?? 0;
      results.add(volume);
    }
    return results;
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Weekly reports
  // ---------------------------------------------------------------------------

  Future<void> saveWeeklyReport({
    required String weekStart,
    required String weekEnd,
    required String reportJson,
    required String generatedAt,
  }) async {
    final db = await instance.database;
    await db.insert(
      'weekly_reports',
      {
        'week_start': weekStart,
        'week_end': weekEnd,
        'report_json': reportJson,
        'generated_at': generatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getWeeklyReport(String weekStart) async {
    final db = await instance.database;
    final res = await db.query(
      'weekly_reports',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getRecentWeeklyReports(int limit) async {
    final db = await instance.database;
    return db.query(
      'weekly_reports',
      orderBy: 'week_start DESC',
      limit: limit,
    );
  }

  /// remaining_sessions > 0인 활성 디로드 레코드 반환 (없으면 null)
  Future<Map<String, dynamic>?> getActiveDeloadRecord() async {
    final db = await instance.database;
    final res = await db.query(
      'deload_history',
      where: 'remaining_sessions > 0',
      orderBy: 'id DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }
}