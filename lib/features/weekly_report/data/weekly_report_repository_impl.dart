import '../../../core/database/database_helper.dart';
import '../domain/models/weekly_report.dart';
import '../domain/repositories/weekly_report_repository.dart';

/// WeeklyReportRepository 구현 (DatabaseHelper 에만 의존)
class WeeklyReportRepositoryImpl implements WeeklyReportRepository {
  final DatabaseHelper _db;

  WeeklyReportRepositoryImpl(this._db);

  @override
  Future<WeeklyReport?> getReport(String weekStart) async {
    final row = await _db.getWeeklyReport(weekStart);
    if (row == null) return null;
    return WeeklyReport.fromJsonString(row['report_json'] as String);
  }

  @override
  Future<void> saveReport(WeeklyReport report) async {
    final weekStartStr = _dateStr(report.weekStart);
    final weekEndStr = _dateStr(report.weekEnd);

    await _db.saveWeeklyReport(
      weekStart: weekStartStr,
      weekEnd: weekEndStr,
      reportJson: report.toJsonString(),
      generatedAt: report.generatedAt.toIso8601String(),
    );
  }

  @override
  Future<List<WeeklyReport>> getRecentReports(int limit) async {
    final rows = await _db.getRecentWeeklyReports(limit);
    return rows
        .map((r) => WeeklyReport.fromJsonString(r['report_json'] as String))
        .toList();
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
