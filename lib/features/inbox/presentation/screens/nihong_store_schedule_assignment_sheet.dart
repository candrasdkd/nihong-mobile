import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/formatting/safe_calendar_date.dart';
import '../../../schedules/data/models/departure_schedule.dart';
import '../../../schedules/presentation/providers/schedules_view_model.dart';
import '../../data/nihong_store_assignment_rules.dart';
import '../../data/nihong_store_inbox_data_source.dart';
import '../../data/nihong_store_inbox_repository.dart';
import '../../data/models/nihong_store_order.dart';
import '../nihong_store_order_formatters.dart';

class NihongStoreScheduleAssignmentSheet extends ConsumerStatefulWidget {
  const NihongStoreScheduleAssignmentSheet({required this.order, super.key});

  final NihongStoreOrder order;

  @override
  ConsumerState<NihongStoreScheduleAssignmentSheet> createState() =>
      _NihongStoreScheduleAssignmentSheetState();
}

class _NihongStoreScheduleAssignmentSheetState
    extends ConsumerState<NihongStoreScheduleAssignmentSheet> {
  String? _selectedScheduleId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(schedulesViewModelProvider);
    final schedules = scheduleState.schedules
        .where((schedule) => schedule.status == 'Open')
        .toList(growable: false);
    final selected = _selectedSchedule(schedules);
    final totalKg = NihongStoreAssignmentRules.estimateWeightKg(widget.order);

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
                      'Pilih jadwal keberangkatan',
                      style: TextStyle(
                        color: AppColors.navyDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _OrderWeightCard(order: widget.order, totalKg: totalKg),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _AssignmentError(message: _errorMessage!),
              ),
            Expanded(
              child: scheduleState.isLoadingSchedules
                  ? const Center(child: CircularProgressIndicator())
                  : scheduleState.scheduleErrorMessage != null
                  ? _ScheduleError(
                      message: scheduleState.scheduleErrorMessage!,
                      onRetry: () =>
                          ref.read(schedulesViewModelProvider.notifier).retry(),
                    )
                  : schedules.isEmpty
                  ? const _NoOpenSchedules()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: schedules.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        return _ScheduleOption(
                          schedule: schedule,
                          totalKg: totalKg,
                          selected: schedule.id == _selectedScheduleId,
                          enabled: !_isSaving,
                          onTap: () => setState(() {
                            _selectedScheduleId = schedule.id;
                            _errorMessage = null;
                          }),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selected == null || _isSaving
                      ? null
                      : () => _confirmAndAssign(selected, totalKg),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.event_available_outlined),
                  label: Text(
                    _isSaving ? 'Menyimpan jadwal…' : 'Jadwalkan pesanan',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DepartureSchedule? _selectedSchedule(List<DepartureSchedule> schedules) {
    for (final schedule in schedules) {
      if (schedule.id == _selectedScheduleId) return schedule;
    }
    return null;
  }

  Future<void> _confirmAndAssign(
    DepartureSchedule schedule,
    double totalKg,
  ) async {
    final date = SafeCalendarDate.formatFullIndonesian(
      schedule.tanggalBerangkat,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi jadwal'),
        content: Text(
          'Jadwalkan pesanan ${widget.order.no.isEmpty ? widget.order.id : widget.order.no} '
          'ke ${schedule.rute} pada ${date.isEmpty ? schedule.tanggalBerangkat : date}? '
          'Berat booking ${formatNihongStoreWeight(totalKg)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, jadwalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(nihongStoreInboxRepositoryProvider)
          .assignOrderToSchedule(order: widget.order, scheduleId: schedule.id);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = _messageFor(error);
      });
    }
  }

  String _messageFor(Object error) {
    if (error is NihongStoreAssignmentSyncException) return error.message;
    if (error is StateError) return error.message.toString();
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Akses ditolak. Pastikan akun memiliki izin pada kedua project Firestore.',
        'unauthenticated' =>
          'Sesi login berakhir. Masuk kembali lalu coba lagi.',
        'unavailable' || 'network-request-failed' =>
          'Koneksi terputus. Periksa jaringan lalu coba lagi.',
        _ => 'Penjadwalan gagal disimpan. Coba lagi.',
      };
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _OrderWeightCard extends StatelessWidget {
  const _OrderWeightCard({required this.order, required this.totalKg});

  final NihongStoreOrder order;
  final double totalKg;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              order.no.isEmpty ? 'Pesanan NihongStore' : order.no,
              style: const TextStyle(
                color: AppColors.navyDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            formatNihongStoreWeight(totalKg),
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScheduleOption extends StatelessWidget {
  const _ScheduleOption({
    required this.schedule,
    required this.totalKg,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DepartureSchedule schedule;
  final double totalKg;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remainingKg = schedule.slotBeratKg - schedule.beratTerpakai;
    final date = SafeCalendarDate.formatFullIndonesian(
      schedule.tanggalBerangkat,
    );
    final capacityFits = totalKg <= remainingKg + 0.0001;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.orange : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.rute,
                      style: const TextStyle(
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${schedule.namaJastiper} • ${date.isEmpty ? schedule.tanggalBerangkat : date}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sisa ${formatNihongStoreWeight(remainingKg < 0 ? 0 : remainingKg)}'
                      '${capacityFits ? '' : ' • kapasitas kurang'}',
                      style: TextStyle(
                        color: capacityFits
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoOpenSchedules extends StatelessWidget {
  const _NoOpenSchedules();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined, size: 42, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Belum ada jadwal terbuka',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Buat jadwal keberangkatan terlebih dahulu, lalu coba lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba muat ulang'),
          ),
        ],
      ),
    ),
  );
}

class _AssignmentError extends StatelessWidget {
  const _AssignmentError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.error, fontSize: 13),
    ),
  );
}
