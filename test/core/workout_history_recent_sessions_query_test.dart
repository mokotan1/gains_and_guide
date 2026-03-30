import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// [DatabaseHelper] 의 getRecentSessions / getRecentSessionsByExercise 와
/// 동일한 SQL 패턴을 검증한다 (excludeDeload 분기).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('workout_history is_deload session queries', () {
    test('excludeDeload 시 비디로드 날짜만 최근 N 세션으로 잡힌다', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE workout_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              sets INTEGER,
              reps INTEGER,
              weight REAL,
              rpe INTEGER,
              date TEXT,
              is_deload INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      );

      Future<void> insert(
        String name,
        String date,
        int rpe, {
        int isDeload = 0,
      }) async {
        await db.insert('workout_history', {
          'name': name,
          'sets': 1,
          'reps': 5,
          'weight': 80.0,
          'rpe': rpe,
          'date': date,
          'is_deload': isDeload,
        });
      }

      await insert('백 스쿼트', '2026-03-25 12:00:00', 10, isDeload: 1);
      await insert('백 스쿼트', '2026-03-24 12:00:00', 10, isDeload: 1);
      await insert('백 스쿼트', '2026-03-23 12:00:00', 10, isDeload: 1);
      await insert('백 스쿼트', '2026-03-20 12:00:00', 6, isDeload: 0);

      final dates = await db.rawQuery('''
        SELECT DISTINCT SUBSTR(date, 1, 10) AS session_date
        FROM workout_history
        WHERE is_deload = 0
        ORDER BY session_date DESC
        LIMIT ?
      ''', [3]);

      expect(dates.length, 1);
      expect(dates.first['session_date'], '2026-03-20');

      final datesAll = await db.rawQuery('''
        SELECT DISTINCT SUBSTR(date, 1, 10) AS session_date
        FROM workout_history
        ORDER BY session_date DESC
        LIMIT ?
      ''', [3]);

      expect(datesAll.length, 3);
      expect(
        datesAll.map((e) => e['session_date']).toList(),
        ['2026-03-25', '2026-03-24', '2026-03-23'],
      );

      await db.close();
    });
  });
}
