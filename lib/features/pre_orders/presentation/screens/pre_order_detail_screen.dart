import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/formatting/safe_calendar_date.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/pre_order.dart';
import '../providers/pre_orders_view_model.dart';
import 'pre_order_form_sheet.dart';

class PreOrderDetailScreen extends ConsumerWidget {
  const PreOrderDetailScreen({required this.preOrderId, super.key});

  final String preOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(preOrdersViewModelProvider);
    PreOrder? preOrder;
    for (final item in state.preOrders) {
      if (item.id == preOrderId) {
        preOrder = item;
        break;
      }
    }

    if (preOrder == null && state.isLoading) {
      return const Scaffold(body: AppLoadingView(message: 'Memuat booking…'));
    }
    if (preOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail booking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.errorMessage ?? 'Booking tidak ditemukan.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final booking = preOrder;
    final isPending =
        booking.status == 'Pending' && booking.convertedOrderId == null;
    final checkedCount = booking.items.where((item) => item.checked).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail booking'),
        actions: [
          if (isPending)
            IconButton(
              tooltip: 'Edit booking',
              onPressed: () => _edit(context, ref, booking),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            booking.namaPelanggan,
                            style: const TextStyle(
                              color: AppColors.navyDark,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: booking.status,
                          tone: isPending
                              ? StatusBadgeTone.warning
                              : booking.status == 'Dibatalkan'
                              ? StatusBadgeTone.error
                              : StatusBadgeTone.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailValue(
                      icon: Icons.flight_takeoff_outlined,
                      label: 'Jadwal',
                      value:
                          '${booking.rute} • ${SafeCalendarDate.formatFullIndonesian(booking.tanggalBerangkat)}',
                    ),
                    const SizedBox(height: 12),
                    _DetailValue(
                      icon: Icons.badge_outlined,
                      label: 'Jastiper',
                      value: booking.namaJastiper,
                    ),
                    const SizedBox(height: 12),
                    _DetailValue(
                      icon: Icons.scale_outlined,
                      label: 'Total berat',
                      value: '${_formatKg(booking.totalKg)} kg',
                    ),
                    if (booking.noTelponPelanggan?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      _DetailValue(
                        icon: Icons.phone_outlined,
                        label: 'Telepon pelanggan',
                        value: booking.noTelponPelanggan!,
                      ),
                    ],
                    if (booking.catatan?.isNotEmpty == true) ...[
                      const Divider(height: 24),
                      Text(
                        booking.catatan!,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Checklist barang',
                            style: TextStyle(
                              color: AppColors.navyDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '$checkedCount/${booking.items.length}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (booking.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Belum ada barang pada booking ini.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    for (var index = 0; index < booking.items.length; index++)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(booking.items[index].namaBarang),
                        subtitle:
                            booking.items[index].catatan?.isNotEmpty == true
                            ? Text(booking.items[index].catatan!)
                            : null,
                        value: booking.items[index].checked,
                        onChanged: isPending
                            ? (checked) => _setChecked(
                                context,
                                ref,
                                booking.id,
                                index,
                                checked ?? false,
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            if (booking.convertedOrderId?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Card(
                color: AppColors.success.withValues(alpha: 0.06),
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.success,
                  ),
                  title: const Text('Sudah dikonversi menjadi pesanan'),
                  subtitle: Text('ID pesanan: ${booking.convertedOrderId}'),
                ),
              ),
              if (booking.nihongStoreOrderId?.isNotEmpty == true &&
                  booking.nihongStoreStatusSyncState == 'pending') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _retryStoreStatusSync(context, ref, booking),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sinkronkan status NihongStore'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            if (booking.nihongStoreCancellationState == 'pending') ...[
              OutlinedButton.icon(
                onPressed: () =>
                    _retryNihongStoreCancellation(context, ref, booking),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                icon: const Icon(Icons.sync),
                label: const Text('Coba sinkronkan pembatalan'),
              ),
            ] else if (isPending) ...[
              FilledButton.icon(
                onPressed: () => _convert(context, ref, booking),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Konversi ke pesanan'),
              ),
              const SizedBox(height: 8),
              if (booking.nihongStoreOrderId?.isNotEmpty == true)
                OutlinedButton.icon(
                  onPressed: () => _cancelNihongStore(context, ref, booking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Batalkan dan beri tahu pelanggan'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _delete(context, ref, booking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus booking'),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Harga jastip dan ongkir pada pesanan baru dimulai dari Rp 0 dan dapat dilengkapi setelah konversi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    PreOrder booking,
  ) async {
    final saved = await showPreOrderFormSheet(context, ref, initial: booking);
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking berhasil diperbarui.')),
      );
    }
  }

  Future<void> _setChecked(
    BuildContext context,
    WidgetRef ref,
    String bookingId,
    int itemIndex,
    bool checked,
  ) async {
    try {
      await ref
          .read(preOrdersViewModelProvider.notifier)
          .setItemChecked(bookingId, itemIndex, checked);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PreOrder booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus booking?'),
        content: Text(
          'Booking ${booking.namaPelanggan} akan dihapus dan ${_formatKg(booking.totalKg)} kg dikembalikan ke kapasitas jadwal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(preOrdersViewModelProvider.notifier)
          .deletePreOrder(booking.id);
      if (context.mounted) context.pop();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _cancelNihongStore(
    BuildContext context,
    WidgetRef ref,
    PreOrder booking,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan booking NihongStore?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking ${booking.namaPelanggan} akan dibatalkan, beratnya dikembalikan ke kapasitas jadwal, dan statusnya disinkronkan ke NihongStore.',
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
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Batalkan booking'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !context.mounted) return;
    await _performNihongStoreCancellation(context, ref, booking, reason);
  }

  Future<void> _retryNihongStoreCancellation(
    BuildContext context,
    WidgetRef ref,
    PreOrder booking,
  ) => _performNihongStoreCancellation(
    context,
    ref,
    booking,
    booking.nihongStoreCancellationReason,
  );

  Future<void> _performNihongStoreCancellation(
    BuildContext context,
    WidgetRef ref,
    PreOrder booking,
    String? reason,
  ) async {
    try {
      await ref
          .read(preOrdersViewModelProvider.notifier)
          .cancelNihongStorePreOrder(booking.id, reason: reason);
      if (context.mounted) context.pop();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    }
  }

  Future<void> _retryStoreStatusSync(
    BuildContext context,
    WidgetRef ref,
    PreOrder booking,
  ) async {
    try {
      final result = await ref
          .read(preOrdersViewModelProvider.notifier)
          .convertPreOrderToOrder(booking.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status NihongStore tersinkron untuk ${result.orderId}.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    }
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _convert(
    BuildContext context,
    WidgetRef ref,
    PreOrder booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konversi menjadi pesanan?'),
        content: Text(
          'Booking ${booking.namaPelanggan} akan menjadi satu pesanan resmi. Semua barang akan ditandai selesai dan kapasitas jadwal tetap terpakai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Konversi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final result = await ref
          .read(preOrdersViewModelProvider.notifier)
          .convertPreOrderToOrder(booking.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.wasCreated
                  ? 'Pesanan dibuat: ${result.orderId}'
                  : 'Booking sudah pernah dikonversi: ${result.orderId}',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.navyLight),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

String _formatKg(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
