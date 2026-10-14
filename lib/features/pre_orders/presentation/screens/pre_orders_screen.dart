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

class PreOrdersScreen extends ConsumerWidget {
  const PreOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(preOrdersViewModelProvider);
    final viewModel = ref.read(preOrdersViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Booking'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                onChanged: viewModel.setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari pelanggan, jadwal, atau barang',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: state.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () => viewModel.setQuery(''),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in const [
                    'Semua',
                    'Pending',
                    'Selesai',
                    'Dibatalkan',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: state.statusFilter == filter,
                        onSelected: (_) => viewModel.setStatusFilter(filter),
                      ),
                    ),
                ],
              ),
            ),
            if (state.isFromCache) const _CacheNotice(),
            Expanded(child: _body(context, ref, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, PreOrdersState state) {
    if (state.isLoading && state.preOrders.isEmpty) {
      return const AppLoadingView(message: 'Memuat booking…');
    }
    if (state.status == PreOrdersStatus.error && state.preOrders.isEmpty) {
      return _LoadError(
        message: state.errorMessage ?? 'Daftar booking gagal dimuat.',
        onRetry: () => ref.read(preOrdersViewModelProvider.notifier).retry(),
      );
    }

    final bookings = state.filteredPreOrders;
    if (bookings.isEmpty) {
      return _EmptyBookings(
        hasFilters: state.query.isNotEmpty || state.statusFilter != 'Semua',
        onCreate: () => _openForm(context, ref),
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(preOrdersViewModelProvider.notifier).retry(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _PreOrderCard(
          preOrder: bookings[index],
          onTap: () => context.push('/preorders/${bookings[index].id}'),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final saved = await showPreOrderFormSheet(context, ref);
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking berhasil dibuat.')));
    }
  }
}

class _PreOrderCard extends StatelessWidget {
  const _PreOrderCard({required this.preOrder, required this.onTap});

  final PreOrder preOrder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checked = preOrder.items.where((item) => item.checked).length;
    final count = preOrder.items.length;
    final statusTone = switch (preOrder.status) {
      'Pending' => StatusBadgeTone.warning,
      'Dibatalkan' => StatusBadgeTone.error,
      _ => StatusBadgeTone.success,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      preOrder.namaPelanggan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navyDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(label: preOrder.status, tone: statusTone),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${preOrder.rute} • ${SafeCalendarDate.formatFullIndonesian(preOrder.tanggalBerangkat)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoPill(
                    icon: Icons.shopping_bag_outlined,
                    label: '$count barang • $checked dicek',
                  ),
                  _InfoPill(
                    icon: Icons.scale_outlined,
                    label: '${_formatKg(preOrder.totalKg)} kg',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Jastiper ${preOrder.namaJastiper}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(99),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.navyLight),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.hasFilters, required this.onCreate});

  final bool hasFilters;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.navyLight,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilters ? 'Booking tidak ditemukan' : 'Belum ada booking',
            style: const TextStyle(
              color: AppColors.navyDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Ubah kata pencarian atau filter status.'
                : 'Buat booking baru untuk mulai mencatat titipan.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Buat booking'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.error,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

class _CacheNotice extends StatelessWidget {
  const _CacheNotice();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Text(
      'Menampilkan data tersimpan di perangkat.',
      style: TextStyle(color: AppColors.warning, fontSize: 12),
    ),
  );
}

String _formatKg(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
