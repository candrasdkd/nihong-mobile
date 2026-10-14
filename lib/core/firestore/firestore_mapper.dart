abstract final class FirestoreMapper {
  static String string(Object? value, {String fallback = ''}) =>
      value?.toString() ?? fallback;

  static String? nullableString(Object? value) => value?.toString();

  static double number(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool? optionalBool(Object? value) {
    if (value is bool) return value;
    if (value == 'true') return true;
    if (value == 'false') return false;
    return null;
  }

  static Map<String, dynamic>? map(Object? value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> mapList(Object? value) {
    if (value is! Iterable) return const [];
    return value.map(map).whereType<Map<String, dynamic>>().toList();
  }

  static void putOptional(
    Map<String, dynamic> target,
    String key,
    Object? value,
  ) {
    if (value != null) target[key] = value;
  }
}
