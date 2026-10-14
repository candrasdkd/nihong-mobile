import 'package:intl/intl.dart';

abstract final class SafeCalendarDate {
  static final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _slashDate = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$');

  /// Parses date-only values as local calendar components to avoid UTC day shifts.
  static DateTime? parse(String? value) {
    final input = value?.trim();
    if (input == null || input.isEmpty) return null;

    final match = _isoDate.firstMatch(input) ?? _slashDate.firstMatch(input);
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }
      return date;
    }

    return DateTime.tryParse(input)?.toLocal();
  }

  static String serialize(DateTime value) {
    final date = value.toLocal();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Formats calendar dates with a full Indonesian month name, e.g. 25 September 2026.
  static String formatFullIndonesian(String? value) {
    final date = parse(value);
    if (date == null) return '';
    return DateFormat('d MMMM y', 'id_ID').format(date);
  }
}
