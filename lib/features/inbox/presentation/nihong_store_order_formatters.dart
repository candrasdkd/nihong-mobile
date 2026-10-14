import 'package:intl/intl.dart';

import '../../../core/formatting/firestore_date_time.dart';

String formatNihongStoreDateTime(Object? value) {
  final date = FirestoreDateTime.parse(value);
  if (date == null) return 'Tanggal belum tersedia';
  return DateFormat('d MMMM y, HH:mm', 'id_ID').format(date);
}

String formatNihongStoreDate(Object? value) {
  final date = FirestoreDateTime.parse(value);
  if (date == null) return '—';
  return DateFormat('d MMMM y', 'id_ID').format(date);
}

String formatNihongStoreRupiah(double? amount) {
  if (amount == null) return '—';
  return NumberFormat.currency(
    locale: 'id_ID',
    name: 'IDR',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(amount);
}

String formatNihongStoreYen(double? amount) {
  if (amount == null) return '—';
  return NumberFormat.currency(
    locale: 'ja_JP',
    name: 'JPY',
    symbol: '¥',
    decimalDigits: 0,
  ).format(amount);
}

String formatNihongStoreWeight(double amount) {
  final formatted = amount
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  return '$formatted kg';
}
