import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/formatting/safe_calendar_date.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../pre_orders/data/models/pre_order.dart';
import '../../data/models/departure_schedule.dart';
import '../../data/schedule_repository.dart';

class ScheduleDetailScreen extends ConsumerWidget {
  const ScheduleDetailScreen({required this.scheduleId, super.key});

  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleDocumentProvider(scheduleId));

    return scheduleAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Detail jadwal')),
        body: const AppLoadingView(message: 'Memuat jadwal…'),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Detail jadwal')),
        body: _DetailError(
          message: _scheduleErrorMessage(error),
          onRetry: () => ref.invalidate(scheduleDocumentProvider(scheduleId)),
        ),
      ),
      data: (snapshot) {
        final schedule = snapshot.schedule;
        if (schedule == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail jadwal')),
            body: const _ScheduleNotFound(),
          );
        }
        return _ScheduleDetailContent(
          schedule: schedule,
          isFromCache: snapshot.isFromCache,
        );
      },
    );
  }
}

class _ScheduleDetailContent extends ConsumerWidget {
  const _ScheduleDetailContent({
    required this.schedule,
    required this.isFromCache,
  });

  final DepartureSchedule schedule;
  final bool isFromCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preOrdersAsync = ref.watch(schedulePreOrdersProvider(schedule.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail jadwal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (isFromCache) const _ScheduleDetailCacheNotice(),
            _ScheduleOverviewCard(schedule: schedule),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pre-order terkait',
                    style: TextStyle(
                      color: AppColors.navyDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Jadwal ${schedule.id}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            preOrdersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: AppLoadingView(message: 'Memuat pre-order…'),
              ),
              error: (error, _) => _DetailError(
                message: _preOrderErrorMessage(error),
                onRetry: () =>
                    ref.invalidate(schedulePreOrdersProvider(schedule.id)),
              ),
              data: (snapshot) {
                if (snapshot.isFromCache) {
                  return Column(
                    children: [
                      const _ScheduleDetailCacheNotice(),
                      _PreOrderResults(preOrders: snapshot.preOrders),
                    ],
                  );
                }
                return _PreOrderResults(preOrders: snapshot.preOrders);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleOverviewCard extends StatelessWidget {
  const _ScheduleOverviewCard({required this.schedule});

  final DepartureSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final remaining = schedule.slotBeratKg - schedule.beratTerpakai;
    final ratio = schedule.slotBeratKg <= 0
        ? (schedule.beratTerpakai > 0 ? 1.0 : 0.0)
        : schedule.beratTerpakai / schedule.slotBeratKg;
    final progress = ratio.clamp(0.0, 1.0).toDouble();
    final progressColor = ratio >= 0.9
        ? AppColors.error
        : ratio >= 0.75
        ? AppColors.warning
        : AppColors.navyLight;
    final feeFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    schedule.rute,
                    style: const TextStyle(
                      color: AppColors.navyDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusBadge(
                  label: schedule.status,
                  tone: schedule.status == 'Open'
                      ? StatusBadgeTone.success
                      : StatusBadgeTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailValue(
              icon: Icons.badge_outlined,
              label: 'Jastiper',
              value: schedule.namaJastiper,
            ),
            const SizedBox(height: 12),
            _DetailValue(
              icon: Icons.inventory_2_outlined,
              label: 'Last drop',
              value: _formatDate(schedule.tanggalLastDrop),
            ),
            const SizedBox(height: 12),
            _DetailValue(
              icon: Icons.flight_takeoff_outlined,
              label: 'Tanggal keberangkatan',
              value: _formatDate(schedule.tanggalBerangkat),
            ),
            const Divider(height: 26),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kapasitas bagasi',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${_formatKg(schedule.beratTerpakai)} / ${_formatKg(schedule.slotBeratKg)} kg',
                  style: const TextStyle(
                    color: AppColors.navyDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: progress,
                color: progressColor,
                backgroundColor: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              remaining < 0
                  ? 'Kapasitas lebih ${_formatKg(-remaining)} kg'
                  : 'Sisa ${_formatKg(remaining)} kg',
              style: TextStyle(
                color: remaining < 0 ? AppColors.error : AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const Divider(height: 26),
            _DetailValue(
              icon: Icons.payments_outlined,
              label: 'Fee jastiper',
              value: '${feeFormat.format(schedule.hargaFeeJastiper)} / kg',
            ),
            if ((schedule.catatan ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailValue(
                icon: Icons.notes_outlined,
                label: 'Catatan',
                value: schedule.catatan!.trim(),
              ),
            ],
          ],
        ),
      ),
    );
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
      Icon(icon, size: 19, color: AppColors.navy),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(
              value.isEmpty ? 'Belum diisi' : value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PreOrderResults extends StatelessWidget {
  const _PreOrderResults({required this.preOrders});

  final List<PreOrder> preOrders;

  @override
  Widget build(BuildContext context) {
    if (preOrders.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.inbox_outlined, color: AppColors.textMuted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Belum ada pre-order pada jadwal ini.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final preOrder in preOrders) ...[
          _PreOrderCard(preOrder: preOrder),
          if (preOrder != preOrders.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PreOrderCard extends StatelessWidget {
  const _PreOrderCard({required this.preOrder});

  final PreOrder preOrder;

  @override
  Widget build(BuildContext context) {
    final statusTone = switch (preOrder.status) {
      'Pending' => StatusBadgeTone.warning,
      'Selesai' => StatusBadgeTone.success,
      'Dibatalkan' => StatusBadgeTone.error,
      _ => StatusBadgeTone.neutral,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    preOrder.namaPelanggan.isEmpty
                        ? 'Pelanggan belum diketahui'
                        : preOrder.namaPelanggan,
                    style: const TextStyle(
                      color: AppColors.navyDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusBadge(label: preOrder.status, tone: statusTone),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.scale_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  '${_formatKg(preOrder.totalKg)} kg',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  '${preOrder.items.length} barang',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleDetailCacheNotice extends StatelessWidget {
  const _ScheduleDetailCacheNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'Menampilkan data cache; koneksi atau data terbaru belum dikonfirmasi.',
      style: TextStyle(color: AppColors.warning, fontSize: 12),
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

class _ScheduleNotFound extends StatelessWidget {
  const _ScheduleNotFound();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Jadwal ini tidak ditemukan atau sudah dihapus.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted),
      ),
    ),
  );
}

String _formatDate(String value) {
  final formatted = SafeCalendarDate.formatFullIndonesian(value);
  return formatted.isEmpty ? 'Tanggal belum diisi' : formatted;
}

String _formatKg(double value) {
  final rounded = value.toStringAsFixed(2);
  return rounded.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _scheduleErrorMessage(Object error) =>
    'Jadwal gagal dimuat. Periksa akses Firestore dan koneksi, lalu coba lagi.';

String _preOrderErrorMessage(Object error) =>
    'Pre-order pada jadwal ini gagal dimuat. Periksa koneksi lalu coba lagi.';
