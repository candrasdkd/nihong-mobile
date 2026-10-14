import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../orders/domain/order_calculations.dart';
import '../../../orders/presentation/providers/orders_view_model.dart';
import '../../../pre_orders/presentation/providers/pre_orders_view_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('EEEE, d MMMM y', 'id_ID').format(DateTime.now());
    final ordersAsync = ref.watch(ordersStreamProvider);
    final orderSnapshot = ordersAsync.asData?.value;
    final preOrdersState = ref.watch(preOrdersViewModelProvider);
    final activeOrders = orderSnapshot?.orders
        .where((order) => order.displayStatus != OrderStatuses.completed)
        .length;
    final pendingBookings = preOrdersState.status == PreOrdersStatus.data
        ? preOrdersState.preOrders
              .where((preOrder) => preOrder.status == 'Pending')
              .length
        : null;
    final isLoading = ordersAsync.isLoading || preOrdersState.isLoading;
    final hasError =
        ordersAsync.hasError || preOrdersState.status == PreOrdersStatus.error;
    final isUsingCache =
        (orderSnapshot?.isFromCache ?? false) || preOrdersState.isFromCache;
    final syncBadge = switch ((hasError, isLoading, isUsingCache)) {
      (true, _, _) => const StatusBadge(
        label: 'Data terbatas',
        tone: StatusBadgeTone.warning,
      ),
      (false, true, _) => const StatusBadge(label: 'Memuat data'),
      (false, false, true) => const StatusBadge(
        label: 'Data tersimpan',
        tone: StatusBadgeTone.warning,
      ),
      _ => const StatusBadge(
        label: 'Data real-time',
        tone: StatusBadgeTone.success,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nihong Jastip'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: syncBadge),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(today, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text(
            'Selamat datang 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 18),
          Card(
            color: AppColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pantau operasional',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ringkasan pesanan dan booking diperbarui otomatis.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Ringkasan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Pesanan aktif',
                  value: _countLabel(
                    activeOrders,
                    isLoading: ordersAsync.isLoading,
                  ),
                  detail: _countDetail(
                    activeOrders,
                    isLoading: ordersAsync.isLoading,
                    hasError: ordersAsync.hasError,
                    noun: 'belum selesai',
                  ),
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Booking pending',
                  value: _countLabel(
                    pendingBookings,
                    isLoading: preOrdersState.isLoading,
                  ),
                  detail: _countDetail(
                    pendingBookings,
                    isLoading: preOrdersState.isLoading,
                    hasError: preOrdersState.status == PreOrdersStatus.error,
                    noun: 'menunggu proses',
                  ),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Akses cepat', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _QuickAction(
            icon: Icons.calendar_month_outlined,
            title: 'Jadwal keberangkatan',
            subtitle: 'Lihat jadwal dan kapasitas',
            onTap: () => context.push('/schedules'),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.people_outline,
            title: 'Pelanggan',
            subtitle: 'Buka direktori pelanggan',
            onTap: () => context.push('/customers'),
          ),
        ],
      ),
    );
  }

  static String _countLabel(int? count, {required bool isLoading}) {
    if (count != null) return '$count';
    return isLoading ? '…' : '—';
  }

  static String _countDetail(
    int? count, {
    required bool isLoading,
    required bool hasError,
    required String noun,
  }) {
    if (hasError) return 'Gagal memuat data';
    if (isLoading && count == null) return 'Memuat data';
    if (count == null) return 'Data belum tersedia';
    return noun;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.navy),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        leading: CircleAvatar(
          backgroundColor: AppColors.navy.withValues(alpha: 0.08),
          child: Icon(icon, color: AppColors.navy),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
