import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:gains_and_guide/core/database/database_helper.dart';
import 'package:gains_and_guide/features/routine/data/routine_repository.dart';
import 'package:gains_and_guide/features/routine/domain/routine.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';

void main() {
  late Database db;
  late RoutineRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('PRAGMA foreign_keys = ON');
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
      },
    );

    repository = RoutineRepository(DatabaseHelper.instance);
  });

  tearDown(() async {
    await db.close();
  });

  Routine _makeRoutine({
    String name = 'Test Routine',
    List<Exercise>? exercises,
    List<int>? weekdays,
  }) {
    return Routine(
      name: name,
      description: 'Test description',
      createdAt: '2026-03-20',
      exercises: exercises ?? [
        Exercise.initial(id: 'ex1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
        Exercise.initial(id: 'ex2', name: '벤치 프레스', sets: 5, reps: 5, weight: 80),
      ],
      assignedWeekdays: weekdays ?? [1, 3, 5],
    );
  }

  group('Routine entity', () {
    test('weekdayLabel returns correct Korean labels', () {
      expect(Routine.weekdayLabel(1), '월');
      expect(Routine.weekdayLabel(7), '일');
      expect(Routine.weekdayLabel(0), '');
      expect(Routine.weekdayLabel(8), '');
    });

    test('weekdaySummary joins weekday labels', () {
      final routine = _makeRoutine(weekdays: [1, 3, 5]);
      expect(routine.weekdaySummary, '월, 수, 금');
    });

    test('copyWith preserves and overrides fields', () {
      final original = _makeRoutine();
      final copied = original.copyWith(name: 'New Name', assignedWeekdays: [2, 4]);
      expect(copied.name, 'New Name');
      expect(copied.assignedWeekdays, [2, 4]);
      expect(copied.description, original.description);
    });
  });

  group('Exercise entity', () {
    test('toDbRow produces correct map', () {
      final exercise = Exercise.initial(
        id: 'test1', name: '스쿼트', sets: 5, reps: 5, weight: 100,
      );
      final row = exercise.toDbRow(1, 0);

      expect(row['routine_id'], 1);
      expect(row['exercise_id'], 'test1');
      expect(row['name'], '스쿼트');
      expect(row['sets'], 5);
      expect(row['weight'], 100.0);
      expect(row['is_cardio'], 0);
    });

    test('fromDbRow restores exercise correctly', () {
      final row = {
        'exercise_id': 'ex1',
        'name': '런닝머신',
        'sets': 1,
        'reps': 30,
        'weight': 0.0,
        'is_bodyweight': 0,
        'is_cardio': 1,
      };
      final exercise = Exercise.fromDbRow(row);

      expect(exercise.id, 'ex1');
      expect(exercise.name, '런닝머신');
      expect(exercise.isCardio, true);
      expect(exercise.setStatus.length, 1);
    });

    test('fromDbRow handles null values defensively', () {
      final row = <String, dynamic>{
        'exercise_id': null,
        'name': null,
        'sets': null,
        'reps': null,
        'weight': null,
        'is_bodyweight': null,
        'is_cardio': null,
      };
      final exercise = Exercise.fromDbRow(row);

      expect(exercise.id, '');
      expect(exercise.name, '');
      expect(exercise.sets, 3);
      expect(exercise.reps, 10);
      expect(exercise.weight, 0.0);
    });

    test('fromJson rejects empty id or name', () {
      expect(
        () => Exercise.fromJson({'id': '', 'name': 'test'}),
        throwsA(isA<ExerciseParseException>()),
      );
      expect(
        () => Exercise.fromJson({'id': 'test', 'name': ''}),
        throwsA(isA<ExerciseParseException>()),
      );
    });
  });

  group('Routine fromMap / toMap', () {
    test('round-trip preserves data', () {
      final map = {
        '_id': 42,
        'name': 'My Routine',
        'description': 'Desc',
        'created_at': '2026-01-01',
      };
      final routine = Routine.fromMap(map);
      expect(routine.id, 42);
      expect(routine.name, 'My Routine');

      final output = routine.toMap();
      expect(output['_id'], 42);
      expect(output['name'], 'My Routine');
    });

    test('fromMap handles null values', () {
      final map = <String, dynamic>{
        '_id': null,
        'name': null,
        'description': null,
        'created_at': null,
      };
      final routine = Routine.fromMap(map);
      expect(routine.id, null);
      expect(routine.name, '');
    });
  });
}
