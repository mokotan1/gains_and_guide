/// 유산소 기록 조회/저장 추상화 (DIP)
abstract class CardioHistoryRepository {
  Future<void> saveCardioHistory(List<Map<String, dynamic>> rows);

  /// [startDate], [endDate] 는 'YYYY-MM-DD' 형식.
  Future<List<Map<String, dynamic>>> getHistoryForDateRange(
    String startDate,
    String endDate,
  );

  /// 최근 N주간 주별 유산소 급성 부하 (duration×rpe) 리스트, 최신순, 이번 주 제외
  Future<List<double>> getWeeklyCardioLoads(int weekCount);
}
