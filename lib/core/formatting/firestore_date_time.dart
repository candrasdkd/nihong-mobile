import 'package:cloud_firestore/cloud_firestore.dart';

import 'safe_calendar_date.dart';

abstract final class FirestoreDateTime {
  /// Reads Firestore Timestamp, legacy epoch seconds/milliseconds, DateTime, or string.
  static DateTime? parse(Object? value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();

    if (value is num) {
      final raw = value.toDouble();
      if (!raw.isFinite) return null;
      final milliseconds = raw.abs() >= 100000000000
          ? raw.round()
          : (raw * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
    }

    if (value is String) {
      final input = value.trim();
      if (input.isEmpty) return null;
      final numeric = num.tryParse(input);
      if (numeric != null) return parse(numeric);
      return SafeCalendarDate.parse(input);
    }

    return null;
  }
}
