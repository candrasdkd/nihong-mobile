import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/firestore/firestore_page_size.dart';
import '../../../../core/formatting/safe_calendar_date.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/load_more_tile.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/departure_schedule.dart';
import '../providers/schedules_view_model.dart';
import 'schedule_form_sheet.dart';

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm({DepartureSchedule? schedule}) async {
    final saved = await showScheduleForm(context, initial: schedule);
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          schedule == null
              ? 'Jadwal berhasil dibuat.'
              : 'Jadwal berhasil diperbarui.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schedulesViewModelProvider);
    final viewModel = ref.read(schedulesViewModelProvider.notifier);
    final schedules = state.filteredSchedules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal keberangkatan'),
        actions: [
          IconButton(
            tooltip: 'Buat jadwal',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: viewModel.setQuery,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Cari rute atau nama jastiper',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: state.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _searchController.clear();
                            viewModel.setQuery('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in const ['Open', 'Closed', 'Semua'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: state.statusFilter == filter,
                        onSelected: (_) => viewModel.setStatusFilter(filter),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: state.statusFilter == filter
                              ? Colors.white
                              : AppColors.navy,
                        ),
                        selectedColor: AppColors.navy,
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.border),
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.flight_takeoff_outlined,
                    color: AppColors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${state.openCount} terbuka • ${state.schedules.length} data dimuat',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${schedules.length} cocok',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (state.isSchedulesFromCache) const _ScheduleCacheNotice(),
            if (state.scheduleErrorMessage != null)
              _ScheduleErrorNotice(
                message: state.scheduleErrorMessage!,
                onRetry: viewModel.retry,
              ),
            if (state.jastiperErrorMessage != null)
              _ScheduleErrorNotice(
                message:
                    '${state.jastiperErrorMessage} Form jadwal belum dapat memuat pilihan jastiper.',
                onRetry: viewModel.retry,
              ),
            if (state.isLoadingSchedules && state.schedules.isEmpty)
              const Expanded(child: AppLoadingView(message: 'Memuat jadwal…'))
            else if (state.scheduleErrorMessage != null &&
                state.schedules.isEmpty)
              Expanded(
                child: _ScheduleLoadError(
                  message: state.scheduleErrorMessage!,
                  onRetry: viewModel.retry,
                ),
              )
            else if (schedules.isEmpty)
              Expanded(
                child: state.hasMoreSchedules
                    ? NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 240) {
                            viewModel.loadMoreSchedules();
                          }
                          return false;
                        },
                        child: ListView(
                          children: [
                            SizedBox(
                              height: 240,
                              child: _EmptySchedules(
                                hasSchedules: state.schedules.isNotEmpty,
                                statusFilter: state.statusFilter,
                                query: state.query,
                              ),
                            ),
                            LoadMoreTile(
                              onPressed: viewModel.loadMoreSchedules,
                              isLoading: state.isLoadingMoreSchedules,
                              errorMessage: state.scheduleErrorMessage,
                              label:
                                  'Muat ${FirestorePageSize.value} jadwal lainnya',
                            ),
                          ],
                        ),
                      )
                    : _EmptySchedules(
                        hasSchedules: state.schedules.isNotEmpty,
                        statusFilter: state.statusFilter,
                        query: state.query,
                      ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    if (state.isLoadingSchedules)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 240) {
                            viewModel.loadMoreSchedules();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount:
                              schedules.length +
                              (state.hasMoreSchedules ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index >= schedules.length) {
                              return LoadMoreTile(
                                onPressed: viewModel.loadMoreSchedules,
                                isLoading: state.isLoadingMoreSchedules,
                                errorMessage: state.scheduleErrorMessage,
                                label:
                                    'Muat ${FirestorePageSize.value} jadwal lainnya',
                              );
                            }
                            return _ScheduleCard(
                              schedule: schedules[index],
                              onOpen: () => context.push(
                                '/schedules/${schedules[index].id}',
                              ),
                              onEdit: () =>
                                  _openForm(schedule: schedules[index]),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onOpen,
    required this.onEdit,
  });

  final DepartureSchedule schedule;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final total = schedule.slotBeratKg;
    final used = schedule.beratTerpakai;
    final remaining = total - used;
    final percentage = total <= 0 ? (used > 0 ? 1.0 : 0.0) : used / total;
    final progress = percentage.clamp(0.0, 1.0).toDouble();
    final progressColor = percentage >= 0.9
        ? AppColors.error
        : percentage >= 0.75
        ? AppColors.warning
        : AppColors.navyLight;
    final statusTone = schedule.status == 'Open'
        ? StatusBadgeTone.success
        : StatusBadgeTone.neutral;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.flight_outlined,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.rute.isEmpty
                            ? 'Rute belum diisi'
                            : schedule.rute,
                        style: const TextStyle(
                          color: AppColors.navyDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schedule.namaJastiper.isEmpty
                            ? 'Jastiper belum diisi'
                            : schedule.namaJastiper,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(label: schedule.status, tone: statusTone),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Edit jadwal',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ScheduleDate(
                    label: 'Last drop',
                    date: schedule.tanggalLastDrop,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScheduleDate(
                    label: 'Berangkat',
                    date: schedule.tanggalBerangkat,
                    icon: Icons.flight_takeoff_outlined,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.scale_outlined,
                  size: 17,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Kapasitas terpakai',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${_formatKg(used)} / ${_formatKg(total)} kg',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    remaining < 0
                        ? 'Kapasitas lebih ${_formatKg(-remaining)} kg'
                        : 'Sisa ${_formatKg(remaining)} kg',
                    style: TextStyle(
                      color: remaining < 0
                          ? AppColors.error
                          : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: const Text('Detail'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleDate extends StatelessWidget {
  const _ScheduleDate({
    required this.label,
    required this.date,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String date;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.orange),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        SafeCalendarDate.formatFullIndonesian(date).isEmpty
            ? 'Tanggal belum diisi'
            : SafeCalendarDate.formatFullIndonesian(date),
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _ScheduleCacheNotice extends StatelessWidget {
  const _ScheduleCacheNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.warning),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Menampilkan data cache; koneksi atau data terbaru belum dikonfirmasi.',
            style: TextStyle(color: AppColors.warning, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ScheduleErrorNotice extends StatelessWidget {
  const _ScheduleErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

class _ScheduleLoadError extends StatelessWidget {
  const _ScheduleLoadError({required this.message, required this.onRetry});

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
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
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

class _EmptySchedules extends StatelessWidget {
  const _EmptySchedules({
    required this.hasSchedules,
    required this.statusFilter,
    required this.query,
  });

  final bool hasSchedules;
  final String statusFilter;
  final String query;

  @override
  Widget build(BuildContext context) {
    final title = hasSchedules
        ? 'Tidak ada jadwal yang cocok'
        : 'Belum ada jadwal';
    final message = query.trim().isNotEmpty
        ? 'Coba kata kunci lain atau ubah filter status.'
        : statusFilter == 'Semua'
        ? 'Jadwal keberangkatan akan muncul di sini.'
        : 'Tidak ada jadwal dengan status $statusFilter.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navyDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatKg(double value) {
  final rounded = value.toStringAsFixed(2);
  return rounded.replaceFirst(RegExp(r'\.?0+$'), '');
}
