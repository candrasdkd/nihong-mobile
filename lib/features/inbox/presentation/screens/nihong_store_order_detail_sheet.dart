import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../auth/data/nihong_store_auth_repository.dart';
import '../../data/nihong_store_inbox_repository.dart';
import '../../data/models/nihong_store_order.dart';
import '../nihong_store_order_formatters.dart';

class NihongStoreOrderDetailSheet extends ConsumerStatefulWidget {
  const NihongStoreOrderDetailSheet({required this.order, super.key});

  final NihongStoreOrder order;

  @override
  ConsumerState<NihongStoreOrderDetailSheet> createState() =>
      _NihongStoreOrderDetailSheetState();
}

class _NihongStoreOrderDetailSheetState
    extends ConsumerState<NihongStoreOrderDetailSheet> {
  late NihongStoreOrder _order;
  final Set<int> _savingItemIndices = {};
  bool _isRejecting = false;

  NihongStoreOrder get order => _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    final pieces = order.items.fold<int>(
      0,
      (total, item) => total + item.jumlah,
    );

    return FractionallySizedBox(
      heightFactor: 0.94,
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
                      'Detail pesanan NihongStore',
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
                                Icons.storefront_outlined,
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
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              order.statusLabel,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Checkout ${formatNihongStoreDateTime(order.createdAt)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: 'Informasi pemesan',
                    rows: [
                      _DetailRow(
                        label: 'Nama',
                        value: _display(order.namaPelanggan),
                      ),
                      _DetailRow(
                        label: 'Telepon',
                        value: _display(order.noTelponPelanggan),
                      ),
                      _DetailRow(
                        label: 'Alamat',
                        value: _display(order.alamatPelanggan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: 'Barang (${order.items.length} jenis • $pieces pcs)',
                    child: order.items.isEmpty
                        ? const Text(
                            'Tidak ada rincian barang.',
                            style: TextStyle(color: AppColors.textMuted),
                          )
                        : Column(
                            children: [
                              for (
                                var index = 0;
                                index < order.items.length;
                                index++
                              ) ...[
                                if (index > 0)
                                  const Divider(height: 20, thickness: 0.7),
                                _ItemDetail(
                                  item: order.items[index],
                                  canManage: order.status == 'inbox',
                                  isSaving: _savingItemIndices.contains(index),
                                  onAvailabilityChanged: order.status == 'inbox'
                                      ? (availability) => _setAvailability(
                                          index,
                                          availability,
                                        )
                                      : null,
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: 'Pembayaran dan berat',
                    rows: [
                      _DetailRow(
                        label: 'Status pembayaran',
                        value: _display(order.paymentStatus),
                      ),
                      _DetailRow(
                        label: 'Estimasi total',
                        value: formatNihongStoreRupiah(
                          order.totalEstimasiHargaIdr,
                        ),
                        emphasize: true,
                      ),
                      _DetailRow(
                        label: 'Estimasi Yen',
                        value: formatNihongStoreYen(
                          order.totalEstimasiHargaYen,
                        ),
                      ),
                      _DetailRow(
                        label: 'Berat total',
                        value: formatNihongStoreWeight(order.totalKg),
                      ),
                    ],
                  ),
                  if (order.assignedScheduleId != null ||
                      order.assignedScheduleRoute != null) ...[
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: 'Jadwal handcarry',
                      rows: [
                        _DetailRow(
                          label: 'Rute',
                          value: _display(order.assignedScheduleRoute),
                        ),
                        _DetailRow(
                          label: 'Keberangkatan',
                          value: _formatScheduleDate(
                            order.assignedScheduleDate,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_hasText(order.catatan)) ...[
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: 'Catatan pesanan',
                      child: Text(
                        order.catatan!.trim(),
                        style: const TextStyle(height: 1.45),
                      ),
                    ),
                  ],
                  if (order.timeline.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: 'Linimasa',
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < order.timeline.length;
                            index++
                          )
                            _TimelineRow(
                              entry: order.timeline[index],
                              isLast: index == order.timeline.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (order.status == 'inbox')
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isRejecting ? null : _rejectOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    icon: _isRejecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(
                      _isRejecting ? 'Membatalkan pesanan…' : 'Tolak pesanan',
                    ),
                  ),
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

  static bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;

  static String _formatScheduleDate(String? value) {
    if (!_hasText(value)) return '—';
    final formatted = formatNihongStoreDate(value);
    return formatted == '—' ? value! : formatted;
  }

  Future<void> _setAvailability(int itemIndex, String availability) async {
    setState(() => _savingItemIndices.add(itemIndex));
    try {
      final updatedOrder = await ref
          .read(nihongStoreInboxRepositoryProvider)
          .updateItemAvailability(
            orderId: order.id,
            itemIndex: itemIndex,
            availability: availability,
          );
      if (!mounted) return;
      setState(() => _order = updatedOrder);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status barang disimpan: $availability.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _savingItemIndices.remove(itemIndex));
    }
  }

  Future<void> _rejectOrder() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tolak pesanan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesanan ${order.no.isEmpty ? order.id : order.no} akan ditandai dibatalkan dan pelanggan menerima status terbaru.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kembali'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text),
            child: const Text('Tolak pesanan'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    setState(() => _isRejecting = true);
    try {
      await ref
          .read(nihongStoreInboxRepositoryProvider)
          .rejectInboxOrder(orderId: order.id, reason: reason);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _isRejecting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  String _errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is NihongStoreAccessException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _ItemDetail extends StatelessWidget {
  const _ItemDetail({
    required this.item,
    required this.canManage,
    required this.isSaving,
    this.onAvailabilityChanged,
  });

  final NihongStoreOrderItem item;
  final bool canManage;
  final bool isSaving;
  final ValueChanged<String>? onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final available =
        item.status != 'Stok habis' && item.status != 'Dibatalkan';
    final quantity = item.jumlah > 0 ? item.jumlah : 1;
    final idrTotal = item.hargaIdr == null ? null : item.hargaIdr! * quantity;
    final yenTotal = item.hargaYen == null ? null : item.hargaYen! * quantity;
    final metadata = [
      if (_hasText(item.kodeBarang)) 'Kode ${item.kodeBarang!.trim()}',
      if (_hasText(item.warna)) 'Warna ${item.warna!.trim()}',
      if (_hasText(item.ukuran)) 'Ukuran ${item.ukuran!.trim()}',
    ].join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemImage(url: item.imageUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.namaBarang.isEmpty
                          ? 'Barang tanpa nama'
                          : item.namaBarang,
                      style: const TextStyle(
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('×$quantity'),
                ],
              ),
              if (metadata.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  metadata,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_hasText(item.catatan)) ...[
                const SizedBox(height: 3),
                Text(
                  item.catatan!.trim(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Text(
                [
                  if (idrTotal != null) formatNihongStoreRupiah(idrTotal),
                  if (yenTotal != null) formatNihongStoreYen(yenTotal),
                ].join(' • ').ifEmpty('Harga belum dicatat'),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.status?.trim().isNotEmpty == true
                          ? item.status!.trim()
                          : available
                          ? 'Ketersediaan belum diperbarui'
                          : 'Stok habis',
                      style: TextStyle(
                        color: available ? AppColors.success : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canManage && onAvailabilityChanged != null)
                    PopupMenuButton<String>(
                      tooltip: 'Ubah ketersediaan',
                      enabled: !isSaving,
                      onSelected: onAvailabilityChanged,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'Tersedia',
                          child: Text('Tandai tersedia'),
                        ),
                        PopupMenuItem(
                          value: 'Stok habis',
                          child: Text('Tandai stok habis'),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.navy,
                              ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return const _ImagePlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _ImagePlaceholder(),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.shopping_bag_outlined, color: AppColors.textMuted),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, this.rows = const [], this.child});

  final String title;
  final List<_DetailRow> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              rows[index],
            ],
          ],
          if (child != null) ...[const SizedBox(height: 10), child!],
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: emphasize ? AppColors.navy : AppColors.navyDark,
            fontSize: 13,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});

  final NihongStoreOrderTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.circle, size: 10, color: AppColors.orange),
            if (!isLast)
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.only(top: 3),
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.status.isEmpty ? 'Pembaruan pesanan' : entry.status,
                style: const TextStyle(
                  color: AppColors.navyDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (entry.note.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  entry.note,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                formatNihongStoreDateTime(entry.at),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
