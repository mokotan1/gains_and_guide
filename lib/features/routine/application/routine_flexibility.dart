/// 주 N회(예: 직장인 주 3회)처럼 요일 고정 루틴에서, **마지막 기록 이후·오늘 이전**에
/// 지나간 '예정 운동일'이 몇 번이었는지 센다. (실제 운동 여부는 보지 않음 → 빈 슬롯 추정용)
int countScheduledTrainingDaysBetween(
  DateTime lastWorkoutDay,
  DateTime today,
  Set<int> scheduledWeekdays,
) {
  final last = DateTime(
    lastWorkoutDay.year,
    lastWorkoutDay.month,
    lastWorkoutDay.day,
  );
  final end = DateTime(today.year, today.month, today.day);
  if (!end.isAfter(last)) return 0;
  var count = 0;
  for (
    var d = last.add(const Duration(days: 1));
    d.isBefore(end);
    d = d.add(const Duration(days: 1))
  ) {
    if (scheduledWeekdays.contains(d.weekday)) {
      count++;
    }
  }
  return count;
}

/// [minMissedScheduledDays] 이상의 예정일이 비어 있으면(기록 없이 지나감으로 가정) 안내를 권장.
bool shouldSuggestRoutineFlexibility({
  required DateTime? latestHistoryDay,
  required DateTime today,
  required Set<int> scheduledWeekdays,
  int minMissedScheduledDays = 2,
}) {
  if (latestHistoryDay == null || scheduledWeekdays.isEmpty) return false;
  final missed = countScheduledTrainingDaysBetween(
    latestHistoryDay,
    today,
    scheduledWeekdays,
  );
  return missed >= minMissedScheduledDays;
}
