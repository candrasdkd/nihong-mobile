import 'dart:math' as math;

abstract final class OrderStatuses {
  static const unpaid = 'Belum Membayar';
  static const depositPaid = 'DP Terbayar';
  static const completed = 'Selesai';
}

class DerivedOrderTotals {
  const DerivedOrderTotals({
    required this.kgCeil,
    required this.baseOngkir,
    required this.baseJastip,
    required this.jastipMarkup,
    required this.ongkirMarkup,
    required this.totalPembayaran,
    required this.totalKeuntungan,
  });

  final double kgCeil;
  final double baseOngkir;
  final double baseJastip;
  final double jastipMarkup;
  final double ongkirMarkup;
  final double totalPembayaran;
  final double totalKeuntungan;
}

/// Mirrors the web order calculation; the two markup fields are summed as stored.
DerivedOrderTotals computeDerivedOrderTotals({
  required double jumlahKg,
  required double unitPrice,
  double hargaJastip = 0,
  double hargaJastipMarkup = 0,
  double? hargaOngkir,
  double hargaOngkirMarkup = 0,
}) {
  final kgCeil = (jumlahKg * 2).ceil() / 2;
  final baseOngkir = hargaOngkir ?? kgCeil * unitPrice;
  final totalPembayaran = hargaJastipMarkup + hargaOngkirMarkup;
  final totalKeuntungan = totalPembayaran - (baseOngkir + hargaJastip);

  return DerivedOrderTotals(
    kgCeil: kgCeil,
    baseOngkir: baseOngkir,
    baseJastip: hargaJastip,
    jastipMarkup: hargaJastipMarkup,
    ongkirMarkup: hargaOngkirMarkup,
    totalPembayaran: totalPembayaran,
    totalKeuntungan: totalKeuntungan,
  );
}

class PaymentSummary {
  const PaymentSummary({
    required this.dp,
    required this.settlement,
    required this.paid,
    required this.remaining,
    required this.percent,
    required this.status,
  });

  final double dp;
  final double settlement;
  final double paid;
  final double remaining;
  final int percent;
  final String status;
}

PaymentSummary getPaymentSummary({
  required double total,
  double? dpNominal,
  double? pelunasanNominal,
}) {
  final dp = math.max(0, dpNominal ?? 0).toDouble();
  final settlement = math.max(0, pelunasanNominal ?? 0).toDouble();
  final paid = dp + settlement;
  final remaining = math.max(0, total - paid).toDouble();
  final percent = total > 0 ? math.min(100, (paid / total * 100).floor()) : 0;
  final status = total > 0 && paid >= total
      ? OrderStatuses.completed
      : paid > 0
      ? OrderStatuses.depositPaid
      : OrderStatuses.unpaid;

  return PaymentSummary(
    dp: dp,
    settlement: settlement,
    paid: paid,
    remaining: remaining,
    percent: percent,
    status: status,
  );
}
