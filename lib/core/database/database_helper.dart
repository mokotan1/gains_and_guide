import 'dart:convert';
import 'package:flutter/services.dart';
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

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const boolType = 'BOOLEAN NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // 1. Routine
    await db.execute('''
      CREATE TABLE routine (
        _id $idType,
        name $textType,
        description TEXT,
        created_at $textType
      )
    ''');

    // 2. Exercise (스키마 확장)
    await db.execute('''
      CREATE TABLE exercise (
        _id $idType,
        name $textType,
        target_muscle $textType,
        equipment_type $textType,
        instructions TEXT,
        category TEXT,
        is_custom $boolType
      )
    ''');

    // 3. Routine_Exercise
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

    // 4. Workout_Log
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

    // 초기 데이터 시딩
    await _seedDatabase(db);
  }

  Future<void> _seedDatabase(Database db) async {
    try {
      final String response = await rootBundle.loadString('assets/data/exercises.json');
      final data = json.decode(response);
      final List exercises = data['exercises'];

      for (var exercise in exercises) {
        await db.insert('exercise', {
          'name': exercise['name'],
          'target_muscle': (exercise['primary_muscles'] as List).join(', '),
          'equipment_type': (exercise['equipment'] as List).join(', '),
          'instructions': (exercise['instructions'] as List).join('\n'),
          'category': exercise['category'],
          'is_custom': 0,
        });
      }
    } catch (e) {
      print('Error seeding database: $e');
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
