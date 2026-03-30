import '../database/database_helper.dart';
import '../domain/repositories/deload_repository.dart';

/// DeloadRepository 구현 (DatabaseHelper에만 의존)
class DeloadRepositoryImpl implements DeloadRepository {
  final DatabaseHelper _db;

  DeloadRepositoryImpl(this._db);

  @override
  Future<DateTime?> getLastDeloadEndDate() async {
    final record = await _db.getLastCompletedDeloadRecord();
    if (record == null) return null;
    return DateTime.tryParse(record['end_date'] as String);
  }

  @override
  Future<void> saveDeloadRecord({
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required double fatigueScore,
    required int cycleSessions,
  }) async {
    await _db.saveDeloadRecord(
      startDate: startDate.toString().split(' ')[0],
      endDate: endDate.toString().split(' ')[0],
      reason: reason,
      fatigueScore: fatigueScore,
      remainingSessions: cycleSessions,
    );
  }

  @override
  Future<bool> isCurrentlyInDeload() => _db.isCurrentlyInDeload();

  @override
  Future<void> decrementDeloadSession() => _db.decrementDeloadSession();

  @override
  Future<Map<String, dynamic>?> getActiveDeloadRecord() =>
      _db.getActiveDeloadRecord();
}
