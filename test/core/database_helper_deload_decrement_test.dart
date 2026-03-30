import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// [DatabaseHelper.decrementDeloadSession] 과 동일한 SQL — 행이 바뀌면 테스트도 맞춘다.
const String kDecrementDeloadSessionSql = '''
      UPDATE deload_history
      SET remaining_sessions = remaining_sessions - 1
      WHERE id = (
        SELECT id FROM (
          SELECT id FROM deload_history
          WHERE remaining_sessions > 0
          ORDER BY id DESC
          LIMIT 1
        )
      )
    ''';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('decrementDeloadSession SQL', () {
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

      await db.rawUpdate(kDecrementDeloadSessionSql);

      final rows = await db.query('deload_history', orderBy: 'id ASC');
      expect(rows.length, 2);
      expect(rows[0]['remaining_sessions'], 2);
      expect(rows[1]['remaining_sessions'], 2);

      await db.close();
    });
  });
}
