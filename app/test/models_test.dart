import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/util.dart';

void main() {
  group('Recurrence', () {
    final start = DateTime(2026, 7, 1); // a Wednesday

    test('daily occurs every day from start', () {
      final t = Task(
          id: '1', title: 'x', recurrence: RecurrenceType.daily, startDate: start);
      expect(t.occursOn(DateTime(2026, 6, 30)), isFalse);
      expect(t.occursOn(DateTime(2026, 7, 1)), isTrue);
      expect(t.occursOn(DateTime(2026, 8, 15)), isTrue);
    });

    test('weekly occurs on same weekday', () {
      final t = Task(
          id: '1', title: 'x', recurrence: RecurrenceType.weekly, startDate: start);
      expect(t.occursOn(DateTime(2026, 7, 8)), isTrue);
      expect(t.occursOn(DateTime(2026, 7, 9)), isFalse);
    });

    test('monthly occurs on same day of month', () {
      final t = Task(
          id: '1', title: 'x', recurrence: RecurrenceType.monthly, startDate: start);
      expect(t.occursOn(DateTime(2026, 8, 1)), isTrue);
      expect(t.occursOn(DateTime(2026, 8, 2)), isFalse);
    });

    test('everyXDays respects interval', () {
      final t = Task(
        id: '1',
        title: 'x',
        recurrence: RecurrenceType.everyXDays,
        intervalDays: 3,
        startDate: start,
      );
      expect(t.occursOn(DateTime(2026, 7, 4)), isTrue);
      expect(t.occursOn(DateTime(2026, 7, 5)), isFalse);
      expect(t.occursOn(DateTime(2026, 7, 7)), isTrue);
    });

    test('one-off completion is permanent, recurring is per-day', () {
      final oneOff = Task(id: '1', title: 'x', startDate: start);
      oneOff.completedDates.add(dateKey(DateTime(2026, 7, 2)));
      expect(oneOff.isCompletedOn(DateTime(2026, 7, 5)), isTrue);

      final daily = Task(
          id: '2', title: 'y', recurrence: RecurrenceType.daily, startDate: start);
      daily.completedDates.add(dateKey(DateTime(2026, 7, 2)));
      expect(daily.isCompletedOn(DateTime(2026, 7, 2)), isTrue);
      expect(daily.isCompletedOn(DateTime(2026, 7, 3)), isFalse);
    });

    test('task json roundtrip', () {
      final t = Task(
        id: '1',
        title: 'Blumen gießen',
        recurrence: RecurrenceType.everyXDays,
        intervalDays: 4,
        startDate: start,
        colorIndex: 3,
        completedDates: {dateKey(DateTime(2026, 7, 5))},
      );
      final back = Task.fromJson(t.toJson());
      expect(back.title, t.title);
      expect(back.recurrence, t.recurrence);
      expect(back.intervalDays, t.intervalDays);
      expect(back.completedDates, t.completedDates);
    });
  });
}
