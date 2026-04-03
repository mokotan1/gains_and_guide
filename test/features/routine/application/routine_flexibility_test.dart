import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/routine/application/routine_flexibility.dart';

void main() {
  group('countScheduledTrainingDaysBetween', () {
    test('counts only scheduled weekdays strictly between last and today', () {
      // Mon 10 — last workout; Fri 14 — today. Scheduled Mon/Wed/Fri.
      // Between: Tue 11, Wed 12, Thu 13 → Wed counts → 1
      final last = DateTime(2025, 6, 9); // Mon
      final today = DateTime(2025, 6, 13); // Fri
      const scheduled = {DateTime.monday, DateTime.wednesday, DateTime.friday};
      expect(
        countScheduledTrainingDaysBetween(last, today, scheduled),
        1,
      );
    });

    test('two scheduled slots between last session and today', () {
      // Mon 9 last, next Mon 16 today. Mon/Wed/Fri → Wed 11, Fri 13 between → 2
      final last = DateTime(2025, 6, 9);
      final today = DateTime(2025, 6, 16);
      const scheduled = {DateTime.monday, DateTime.wednesday, DateTime.friday};
      expect(
        countScheduledTrainingDaysBetween(last, today, scheduled),
        2,
      );
    });

    test('same calendar day yields 0', () {
      final d = DateTime(2025, 6, 9);
      expect(countScheduledTrainingDaysBetween(d, d, {DateTime.monday}), 0);
    });
  });

  group('shouldSuggestRoutineFlexibility', () {
    test('true when missed scheduled days >= threshold', () {
      final last = DateTime(2025, 6, 9);
      final today = DateTime(2025, 6, 16);
      const scheduled = {DateTime.monday, DateTime.wednesday, DateTime.friday};
      expect(
        shouldSuggestRoutineFlexibility(
          latestHistoryDay: last,
          today: today,
          scheduledWeekdays: scheduled,
          minMissedScheduledDays: 2,
        ),
        isTrue,
      );
    });

    test('false when below threshold', () {
      final last = DateTime(2025, 6, 9);
      final today = DateTime(2025, 6, 13);
      const scheduled = {DateTime.monday, DateTime.wednesday, DateTime.friday};
      expect(
        shouldSuggestRoutineFlexibility(
          latestHistoryDay: last,
          today: today,
          scheduledWeekdays: scheduled,
          minMissedScheduledDays: 2,
        ),
        isFalse,
      );
    });

    test('false when no history', () {
      expect(
        shouldSuggestRoutineFlexibility(
          latestHistoryDay: null,
          today: DateTime(2025, 6, 16),
          scheduledWeekdays: {DateTime.monday},
        ),
        isFalse,
      );
    });
  });
}
