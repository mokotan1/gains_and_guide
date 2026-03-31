import '../database/database_helper.dart';
import '../domain/repositories/cardio_history_repository.dart';

class CardioHistoryRepositoryImpl implements CardioHistoryRepository {
  final DatabaseHelper _db;

  CardioHistoryRepositoryImpl(this._db);

  @override
  Future<void> saveCardioHistory(List<Map<String, dynamic>> rows) =>
      _db.saveCardioHistory(rows);

  @override
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  ) =>
      _db.getCardioHistoryForDateRange(startDate, endDate);

  @override
  Future<List<double>> getWeeklyCardioLoads(int weekCount) =>
      _db.getWeeklyCardioLoads(weekCount);
}
