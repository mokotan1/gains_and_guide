import '../models/weekly_report.dart';

/// 주간 레포트 저장/조회 추상화 (DIP)
abstract class WeeklyReportRepository {
  /// 특정 주의 레포트 조회 (weekStart: 'YYYY-MM-DD')
  Future<WeeklyReport?> getReport(String weekStart);

  /// 레포트 저장 (같은 주가 이미 있으면 교체)
  Future<void> saveReport(WeeklyReport report);

  /// 최근 N개 레포트 조회 (최신순)
  Future<List<WeeklyReport>> getRecentReports(int limit);
}
