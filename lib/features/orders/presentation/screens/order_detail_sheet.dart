import 'package:flutter/material.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../data/models/order_doc.dart';
import '../../domain/order_calculations.dart';
import '../order_formatters.dart';
import '../widgets/order_status_badge.dart';

class OrderDetailSheet extends StatelessWidget {
  const OrderDetailSheet({required this.order, super.key});

  final OrderDoc order;

  @override
  Widget build(BuildContext context) {
    final currency = order.tipeNominal;
    final payment = getPaymentSummary(
      total: order.totalPembayaran,
      dpNominal: order.dpNominal,
      pelunasanNominal: order.pelunasanNominal,
    );

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Material(
        color: AppColors.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Detail pesanan',
                      style: TextStyle(
                        color: AppColors.navyDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  Card(
                    color: AppColors.navy,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  order.no.isEmpty ? 'Pesanan' : order.no,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              OrderStatusBadge(status: order.displayStatus),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            order.namaPelanggan.isEmpty
                                ? 'Pelanggan belum dicatat'
                                : order.namaPelanggan,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatOrderDate(order.tanggal).isEmpty
                                ? 'Tanggal belum dicatat'
                                : formatOrderDate(order.tanggal),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoSection(
                    title: 'Barang dan pengiriman',
                    rows: [
                      _InfoRow(
                        label: 'Nama barang',
                        value: _display(order.namaBarang),
                      ),
                      _InfoRow(
                        label: 'Kategori',
                        value: _display(order.kategori),
                      ),
                      _InfoRow(
                        label: 'Metode pengiriman',
                        value: _display(order.pengiriman),
                      ),
                      _InfoRow(
                        label: 'Berat',
                        value: formatOrderWeight(order.jumlahKg),
                      ),
                      _InfoRow(
                        label: 'Pembulatan berat',
                        value: formatOrderWeight(order.kgCeil),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoSection(
                    title: 'Rincian tagihan',
                    rows: [
                      _InfoRow(
                        label: 'Biaya jastip',
                        value: formatOrderCurrency(
                          order.hargaJastipMarkup,
                          currency,
                        ),
                      ),
                      _InfoRow(
                        label: 'Ongkos kirim',
                        value: formatOrderCurrency(
                          order.hargaOngkirMarkup,
                          currency,
                        ),
                      ),
                      _InfoRow(
                        label: 'Total tagihan',
                        value: formatOrderCurrency(
                          order.totalPembayaran,
                          currency,
                        ),
                        emphasize: true,
                      ),
                      _InfoRow(
                        label: 'Keuntungan',
                        value: formatOrderCurrency(
                          order.totalKeuntungan,
                          currency,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoSection(
                    title: 'Pembayaran',
                    rows: [
                      _InfoRow(
                        label: 'DP tercatat',
                        value: formatOrderCurrency(payment.dp, currency),
                      ),
                      _InfoRow(
                        label: 'Tanggal DP',
                        value: _formatOptionalDate(order.dpTanggal),
                      ),
                      _InfoRow(
                        label: 'Metode DP',
                        value: _display(order.dpMetode),
                      ),
                      _InfoRow(
                        label: 'Pelunasan tercatat',
                        value: formatOrderCurrency(
                          payment.settlement,
                          currency,
                        ),
                      ),
                      _InfoRow(
                        label: 'Tanggal pelunasan',
                        value: _formatOptionalDate(order.pelunasanTanggal),
                      ),
                      _InfoRow(
                        label: 'Metode pelunasan',
                        value: _display(order.pelunasanMetode),
                      ),
                      _InfoRow(
                        label: 'Sisa tagihan',
                        value: formatOrderCurrency(payment.remaining, currency),
                        emphasize: true,
                      ),
                    ],
                  ),
                  if (_hasText(order.catatan) ||
                      _hasText(order.dpCatatan) ||
                      _hasText(order.pelunasanCatatan)) ...[
                    const SizedBox(height: 12),
                    _InfoSection(
                      title: 'Catatan',
                      rows: [
                        if (_hasText(order.catatan))
                          _InfoRow(label: 'Pesanan', value: order.catatan!),
                        if (_hasText(order.dpCatatan))
                          _InfoRow(label: 'DP', value: order.dpCatatan!),
                        if (_hasText(order.pelunasanCatatan))
                          _InfoRow(
                            label: 'Pelunasan',
                            value: order.pelunasanCatatan!,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _display(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? '—' : text;
  }

  static String _formatOptionalDate(String? value) {
    if (!_hasText(value)) return '—';
    final formatted = formatOrderDate(value!);
    return formatted.isEmpty ? value : formatted;
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navyDark,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              rows[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: emphasize ? AppColors.navyDark : AppColors.text,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      height: 1.35,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}
