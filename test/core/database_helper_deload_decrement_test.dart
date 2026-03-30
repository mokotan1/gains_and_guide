import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// [DatabaseHelper.decrementDeloadSession] 와 동일한 단계 (로직 변경 시 함께 수정)
Future<void> decrementDeloadSessionLikeHelper(Database db) async {
  final active = await db.rawQuery('''
      SELECT id FROM deload_history
      WHERE remaining_sessions > 0
      ORDER BY id DESC
      LIMIT 1
    ''');
  if (active.isEmpty) return;

  final id = active.first['id'] as int;
  await db.rawUpdate('''
      UPDATE deload_history
      SET remaining_sessions = remaining_sessions - 1
      WHERE id = ?
    ''', [id]);

  final row = await db.query(
    'deload_history',
    columns: ['remaining_sessions'],
    where: 'id = ?',
    whereArgs: [id],
  );
  if (row.isEmpty) return;

  final remaining = row.first['remaining_sessions'] as int;
  if (remaining == 0) {
    final today = DateTime.now().toString().split(' ')[0];
    await db.update(
      'deload_history',
      {'end_date': today},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('decrementDeloadSession (DatabaseHelper 동일 로직)', () {
    test('활성 행이 둘일 때 최신 id 한 행만 차감', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE deload_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL,
              reason TEXT,
              fatigue_score REAL NOT NULL,
              remaining_sessions INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      );

      await db.insert('deload_history', {
        'start_date': '2026-01-01',
        'end_date': '2026-01-01',
        'reason': 'old',
        'fatigue_score': 70.0,
        'remaining_sessions': 2,
      });
      await db.insert('deload_history', {
        'start_date': '2026-02-01',
        'end_date': '2026-02-01',
        'reason': 'new',
        'fatigue_score': 75.0,
        'remaining_sessions': 3,
      });

      await decrementDeloadSessionLikeHelper(db);

      final rows = await db.query('deload_history', orderBy: 'id ASC');
      expect(rows.length, 2);
      expect(rows[0]['remaining_sessions'], 2);
      expect(rows[1]['remaining_sessions'], 2);

      await db.close();
    });

    test('마지막 차감으로 remaining_sessions 가 0이면 end_date 가 오늘로 갱신', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE deload_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL,
              reason TEXT,
              fatigue_score REAL NOT NULL,
              remaining_sessions INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      );

      await db.insert('deload_history', {
        'start_date': '2026-03-23',
        'end_date': '2026-03-23',
        'reason': 'deload',
        'fatigue_score': 80.0,
        'remaining_sessions': 1,
      });

      await decrementDeloadSessionLikeHelper(db);

      final rows = await db.query('deload_history');
      expect(rows.first['remaining_sessions'], 0);
      expect(
        rows.first['end_date'],
        DateTime.now().toString().split(' ')[0],
      );

      await db.close();
    });
  });
}
