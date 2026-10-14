import 'package:intl/intl.dart';

import '../../../core/formatting/safe_calendar_date.dart';

String formatOrderDate(String value) =>
    SafeCalendarDate.formatFullIndonesian(value);

String formatOrderWeight(double value) {
  final formatted = value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  return '$formatted kg';
}

String formatOrderCurrency(double amount, String currency) {
  switch (currency) {
    case 'JPY':
      return NumberFormat.currency(
        locale: 'ja_JP',
        name: 'JPY',
        symbol: '¥',
        decimalDigits: 0,
      ).format(amount);
    case 'SGD':
      return NumberFormat.currency(
        locale: 'en_SG',
        name: 'SGD',
        decimalDigits: 0,
      ).format(amount);
    case 'MYR':
      return NumberFormat.currency(
        locale: 'ms_MY',
        name: 'MYR',
        decimalDigits: 0,
      ).format(amount);
    default:
      return NumberFormat.currency(
        locale: 'id_ID',
        name: 'IDR',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amount);
  }
}
