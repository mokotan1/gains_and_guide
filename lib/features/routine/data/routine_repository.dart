import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/routine.dart';
import '../domain/exercise.dart';
import '../../../core/database/database_helper.dart';

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(DatabaseHelper.instance);
});

class RoutineRepository {
  final DatabaseHelper _dbHelper;

  RoutineRepository(this._dbHelper);

  /// 루틴 + 운동 + 요일 스케줄을 하나의 트랜잭션으로 저장
  Future<Routine> createRoutineWithExercises(Routine routine) async {
    final db = await _dbHelper.database;
    late final int routineId;

    await db.transaction((txn) async {
      routineId = await txn.insert('routine', {
        'name': routine.name,
        'description': routine.description,
        'created_at': routine.createdAt,
      });

      for (int i = 0; i < routine.exercises.length; i++) {
        await txn.insert(
          'routine_exercises',
          routine.exercises[i].toDbRow(routineId, i),
        );
      }

      for (final weekday in routine.assignedWeekdays) {
        await txn.insert('weekly_schedule', {
          'routine_id': routineId,
          'weekday': weekday,
        });
      }
    });

    return routine.copyWith(id: routineId);
  }

  /// 기존 주간 스케줄을 모두 지우고 새 루틴들로 대체 (프로그램 적용 시)
  Future<void> replaceWeeklyProgram(List<Routine> routines) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final existing = await txn.query('routine');
      for (final row in existing) {
        final id = row['_id'] as int;
        await txn.delete('routine_exercises',
            where: 'routine_id = ?', whereArgs: [id]);
        await txn.delete('weekly_schedule',
            where: 'routine_id = ?', whereArgs: [id]);
      }
      await txn.delete('routine');

      for (final routine in routines) {
        final routineId = await txn.insert('routine', {
          'name': routine.name,
          'description': routine.description,
          'created_at': routine.createdAt,
        });

        for (int i = 0; i < routine.exercises.length; i++) {
          await txn.insert(
            'routine_exercises',
            routine.exercises[i].toDbRow(routineId, i),
          );
        }

        for (final weekday in routine.assignedWeekdays) {
          await txn.insert('weekly_schedule', {
            'routine_id': routineId,
            'weekday': weekday,
          });
        }
      }
    });
  }

  /// 요일별 전체 주간 프로그램 조회 -> Map<int, List<Exercise>>
  Future<Map<int, List<Exercise>>> getWeeklyProgram() async {
    final db = await _dbHelper.database;
    final Map<int, List<Exercise>> result = {};

    final schedules = await db.query('weekly_schedule');
    final routineIds = schedules.map((s) => s['routine_id'] as int).toSet();

    for (final routineId in routineIds) {
      final exerciseRows = await db.query(
        'routine_exercises',
        where: 'routine_id = ?',
        whereArgs: [routineId],
        orderBy: 'sort_order ASC',
      );
      final exercises = exerciseRows.map(Exercise.fromDbRow).toList();

      final weekdays = schedules
          .where((s) => s['routine_id'] == routineId)
          .map((s) => s['weekday'] as int);

      for (final weekday in weekdays) {
        result[weekday] = exercises;
      }
    }

    return result;
  }

  /// 특정 요일의 운동 목록 조회
  Future<List<Exercise>> getExercisesByWeekday(int weekday) async {
    final db = await _dbHelper.database;
    final schedules = await db.query(
      'weekly_schedule',
      where: 'weekday = ?',
      whereArgs: [weekday],
      limit: 1,
    );
    if (schedules.isEmpty) return [];

    final routineId = schedules.first['routine_id'] as int;
    final rows = await db.query(
      'routine_exercises',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(Exercise.fromDbRow).toList();
  }

  /// 전체 루틴 목록 (운동 + 요일 포함)
  Future<List<Routine>> getAllRoutinesWithDetails() async {
    final db = await _dbHelper.database;
    final routineRows = await db.query('routine', orderBy: 'created_at DESC');

    final List<Routine> routines = [];
    for (final row in routineRows) {
      final routineId = row['_id'] as int;

      final exerciseRows = await db.query(
        'routine_exercises',
        where: 'routine_id = ?',
        whereArgs: [routineId],
        orderBy: 'sort_order ASC',
      );

      final scheduleRows = await db.query(
        'weekly_schedule',
        where: 'routine_id = ?',
        whereArgs: [routineId],
      );

      routines.add(Routine.fromMap(row).copyWith(
        exercises: exerciseRows.map(Exercise.fromDbRow).toList(),
        assignedWeekdays: scheduleRows.map((s) => s['weekday'] as int).toList()
          ..sort(),
      ));
    }

    return routines;
  }

  /// 루틴 삭제 (FK CASCADE로 routine_exercises, weekly_schedule 함께 삭제)
  Future<int> deleteRoutine(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('routine', where: '_id = ?', whereArgs: [id]);
  }

  /// 주간 프로그램이 비어있는지 확인
  Future<bool> isWeeklyProgramEmpty() async {
    final db = await _dbHelper.database;
    final count = await db.rawQuery('SELECT COUNT(*) as cnt FROM weekly_schedule');
    return (count.first['cnt'] as int) == 0;
  }
}
