import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/utils/app_date_utils.dart';

void main() {
  group('AppDateUtils.isOverdue', () {
    final now = DateTime(2026, 9, 17, 12, 0);

    test('a past instant is overdue', () {
      expect(AppDateUtils.isOverdue(now.subtract(const Duration(minutes: 1)), now: now),
          isTrue);
    });

    test('a future instant is not overdue', () {
      expect(AppDateUtils.isOverdue(now.add(const Duration(minutes: 1)), now: now),
          isFalse);
    });

    test('earlier the same day is overdue — overdue is by the minute, not the day',
        () {
      expect(AppDateUtils.isOverdue(DateTime(2026, 9, 17, 11, 0), now: now), isTrue);
    });

    test('null is never overdue', () {
      expect(AppDateUtils.isOverdue(null, now: now), isFalse);
    });
  });

  group('AppDateUtils.isUpcoming', () {
    final now = DateTime(2026, 9, 17, 12, 0);

    test('later today is not upcoming — it belongs to today', () {
      expect(AppDateUtils.isUpcoming(DateTime(2026, 9, 17, 23, 0), now: now), isFalse);
    });

    test('tomorrow is upcoming', () {
      expect(AppDateUtils.isUpcoming(DateTime(2026, 9, 18, 1, 0), now: now), isTrue);
    });

    test('the past is not upcoming', () {
      expect(AppDateUtils.isUpcoming(DateTime(2026, 9, 16), now: now), isFalse);
    });
  });

  group('day boundaries', () {
    test('startOfDay is midnight local', () {
      expect(
        AppDateUtils.startOfDay(DateTime(2026, 9, 17, 23, 59)),
        DateTime(2026, 9, 17),
      );
    });

    test('endOfDay is the first instant of the next day', () {
      expect(
        AppDateUtils.endOfDay(DateTime(2026, 9, 17, 0, 1)),
        DateTime(2026, 9, 18),
      );
    });

    test('isSameDay ignores the time', () {
      expect(
        AppDateUtils.isSameDay(
          DateTime(2026, 9, 17, 1),
          DateTime(2026, 9, 17, 23),
        ),
        isTrue,
      );
    });
  });

  group('relativeLabel', () {
    final now = DateTime(2026, 9, 17, 12, 0);

    test('past reads as overdue', () {
      expect(
        AppDateUtils.relativeLabel(now.subtract(const Duration(days: 2)), now: now),
        '2 days overdue',
      );
    });

    test('future reads as in', () {
      expect(
        AppDateUtils.relativeLabel(now.add(const Duration(hours: 3)), now: now),
        'in 3 hours',
      );
    });

    test('singular unit has no plural s', () {
      expect(
        AppDateUtils.relativeLabel(now.add(const Duration(days: 1)), now: now),
        'in 1 day',
      );
    });
  });

  group('formatDuration', () {
    test('returns null while a visit is still open', () {
      expect(AppDateUtils.formatDuration(DateTime(2026, 9, 17), null), isNull);
    });

    test('rejects a negative span rather than showing nonsense', () {
      expect(
        AppDateUtils.formatDuration(DateTime(2026, 9, 17, 12), DateTime(2026, 9, 17, 11)),
        isNull,
      );
    });

    test('formats hours and minutes', () {
      expect(
        AppDateUtils.formatDuration(
          DateTime(2026, 9, 17, 10),
          DateTime(2026, 9, 17, 11, 30),
        ),
        '1 hour 30 min',
      );
    });
  });
}
