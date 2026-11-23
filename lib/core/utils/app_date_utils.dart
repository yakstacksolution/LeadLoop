import 'package:intl/intl.dart';

/// Date helpers shared by the follow-up logic and the UI.
///
/// All comparisons work on the device's local timezone. Firestore stores
/// `Timestamp`s (UTC instants), and `Timestamp.toDate()` hands back a local
/// `DateTime`, so "is this overdue today" is answered in the employee's own
/// day — which is what a field team expects.
abstract final class AppDateUtils {
  static final _dayFormat = DateFormat('d MMM yyyy');
  static final _dayShortFormat = DateFormat('d MMM');
  static final _timeFormat = DateFormat('h:mm a');
  static final _dayTimeFormat = DateFormat('d MMM yyyy, h:mm a');
  static final _weekdayFormat = DateFormat('EEE, d MMM');
  static final _monthFormat = DateFormat('MMM');

  static String formatDate(DateTime? value) =>
      value == null ? '—' : _dayFormat.format(value.toLocal());

  static String formatShortDate(DateTime? value) =>
      value == null ? '—' : _dayShortFormat.format(value.toLocal());

  static String formatTime(DateTime? value) =>
      value == null ? '—' : _timeFormat.format(value.toLocal());

  static String formatDateTime(DateTime? value) =>
      value == null ? '—' : _dayTimeFormat.format(value.toLocal());

  /// Short month name, for chart axes.
  static String formatMonth(DateTime? value) =>
      value == null ? '—' : _monthFormat.format(value.toLocal());

  static String formatWeekday(DateTime? value) =>
      value == null ? '—' : _weekdayFormat.format(value.toLocal());

  /// Midnight at the start of [value]'s local day.
  static DateTime startOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// The first instant of the following local day — an exclusive upper bound.
  static DateTime endOfDay(DateTime value) =>
      startOfDay(value).add(const Duration(days: 1));

  static DateTime startOfToday() => startOfDay(DateTime.now());
  static DateTime endOfToday() => endOfDay(DateTime.now());

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  static bool isToday(DateTime? value) => isSameDay(value, DateTime.now());

  /// A follow-up counts as overdue once its scheduled instant has passed.
  ///
  /// Deliberately instant-based rather than day-based: an 11:00 call is late
  /// at 11:30, not at midnight.
  static bool isOverdue(DateTime? scheduledAt, {DateTime? now}) {
    if (scheduledAt == null) return false;
    return scheduledAt.toLocal().isBefore(now?.toLocal() ?? DateTime.now());
  }

  /// Scheduled for after today — i.e. genuinely upcoming, not just "not yet
  /// overdue".
  static bool isUpcoming(DateTime? scheduledAt, {DateTime? now}) {
    if (scheduledAt == null) return false;
    final reference = now ?? DateTime.now();
    return scheduledAt.toLocal().isAfter(endOfDay(reference));
  }

  /// "2 days overdue", "in 3 hours", "just now" — used on follow-up cards.
  static String relativeLabel(DateTime? value, {DateTime? now}) {
    if (value == null) return '—';
    final reference = now ?? DateTime.now();
    final target = value.toLocal();
    final difference = target.difference(reference);
    final overdue = difference.isNegative;
    final absolute = difference.abs();

    final String amount;
    if (absolute.inMinutes < 1) {
      return 'just now';
    } else if (absolute.inMinutes < 60) {
      amount = '${absolute.inMinutes} min';
    } else if (absolute.inHours < 24) {
      amount = _plural(absolute.inHours, 'hour');
    } else {
      amount = _plural(absolute.inDays, 'day');
    }

    return overdue ? '$amount overdue' : 'in $amount';
  }

  static String _plural(int count, String unit) =>
      '$count $unit${count == 1 ? '' : 's'}';

  /// Combines a picked date with a picked time into one instant.
  static DateTime combine(DateTime date, {int hour = 9, int minute = 0}) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day, hour, minute);
  }

  /// Human-readable visit length, or null while a visit is still open.
  static String? formatDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final span = end.difference(start);
    if (span.isNegative) return null;
    if (span.inMinutes < 1) return 'under a minute';
    if (span.inMinutes < 60) return '${span.inMinutes} min';
    final hours = span.inHours;
    final minutes = span.inMinutes % 60;
    return minutes == 0 ? _plural(hours, 'hour') : '${_plural(hours, 'hour')} $minutes min';
  }
}
