import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../data/nihong_store_inbox_data_source.dart';
import '../../data/models/nihong_store_order.dart';
import '../nihong_store_order_formatters.dart';
import '../providers/nihong_store_inbox_view_model.dart';
import '../widgets/nihong_store_status_badge.dart';
import 'nihong_store_schedule_assignment_sheet.dart';
import 'nihong_store_order_detail_sheet.dart';

class NihongStoreInboxScreen extends ConsumerStatefulWidget {
  const NihongStoreInboxScreen({super.key});

  @override
  ConsumerState<NihongStoreInboxScreen> createState() =>
      _NihongStoreInboxScreenState();
}

class _NihongStoreInboxScreenState
    extends ConsumerState<NihongStoreInboxScreen> {
  static const _filters = [
    _InboxStatusFilter(label: 'Menunggu Jadwal', status: 'inbox'),
    _InboxStatusFilter(label: 'Terjadwal', status: 'assigned'),
    _InboxStatusFilter(label: 'Dibatalkan', status: 'rejected'),
    _InboxStatusFilter(label: 'Semua', status: ''),
  ];

  final _searchController = TextEditingController();
  String _selectedStatus = 'inbox';
  int _limitCount = NihongStoreOrder.pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(nihongStoreInboxStreamProvider(_limitCount));
    final orderSnapshot = ordersAsync.asData?.value;
    final orders = orderSnapshot?.orders ?? const <NihongStoreOrder>[];
    final statusCounts = {
      for (final status in const ['inbox', 'assigned', 'rejected'])
        status: orders.where((order) => order.status == status).length,
      '': orders.length,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox NihongStore'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang inbox',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Cari nomor, pelanggan, telepon, atau barang',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 54,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final selected = _selectedStatus == filter.status;
                  final count = orderSnapshot == null
                      ? (ordersAsync.isLoading ? '…' : '—')
                      : '${statusCounts[filter.status] ?? 0}';
                  return ChoiceChip(
                    label: Text('${filter.label} ($count)'),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedStatus = filter.status;
                    }),
                    selectedColor: AppColors.navy.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.navy : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppColors.navy.withValues(alpha: 0.22)
                          : AppColors.border,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: ordersAsync.when(
                loading: () => const AppLoadingView(
                  message: 'Memuat pesanan NihongStore…',
                ),
                error: (error, _) => _InboxLoadError(
                  message: _errorMessage(error),
                  onRetry: _reload,
                ),
                data: _buildOrders,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrders(NihongStoreInboxSnapshot snapshot) {
    final query = _searchController.text.trim().toLowerCase();
    final hasMore = snapshot.orders.length >= _limitCount;
    final filtered = snapshot.orders
        .where((order) {
          if (_selectedStatus.isNotEmpty && order.status != _selectedStatus) {
            return false;
          }
          if (query.isEmpty) return true;
          final searchableValues = [
            order.no,
            order.namaPelanggan,
            order.noTelponPelanggan,
            order.alamatPelanggan,
            order.displayStatus,
            order.paymentStatus,
            order.catatan,
            ...order.items.map((item) => item.namaBarang),
          ];
          return searchableValues.any(
            (value) => value?.toLowerCase().contains(query) ?? false,
          );
        })
        .toList(growable: false);

    if (snapshot.orders.isEmpty) {
      return Column(
        children: [
          if (snapshot.isFromCache) const _CacheNotice(),
          const Expanded(child: _EmptyInbox()),
        ],
      );
    }

    if (filtered.isEmpty) {
      return Column(
        children: [
          if (snapshot.isFromCache) const _CacheNotice(),
          _ResultCount(count: 0, total: snapshot.orders.length),
          const Expanded(child: _NoMatchingOrders()),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _LoadMoreButton(onPressed: _loadMore),
            ),
        ],
      );
    }

    return Column(
      children: [
        if (snapshot.isFromCache) const _CacheNotice(),
        _ResultCount(count: filtered.length, total: snapshot.orders.length),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: filtered.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= filtered.length) {
                return _LoadMoreButton(onPressed: _loadMore);
              }
              final order = filtered[index];
              return _NihongStoreOrderCard(
                order: order,
                onAssign: order.status == 'inbox'
                    ? () => _assignOrder(order)
                    : null,
                onTap: () => _showOrderDetails(order),
              );
            },
          ),
        ),
      ],
    );
  }

  void _reload() => ref.invalidate(nihongStoreInboxStreamProvider(_limitCount));

  Future<void> _assignOrder(NihongStoreOrder order) async {
    final assigned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NihongStoreScheduleAssignmentSheet(order: order),
    );
    if (assigned != true || !mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pesanan berhasil dijadwalkan.')),
    );
  }

  Future<void> _showOrderDetails(NihongStoreOrder order) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NihongStoreOrderDetailSheet(order: order),
    );
    if (changed != true || !mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perubahan pesanan berhasil disimpan.')),
    );
  }

  void _loadMore() => setState(() {
    _limitCount += NihongStoreOrder.pageSize;
  });

  static String _errorMessage(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Akses pesanan ditolak. Pastikan akun terdaftar sebagai admin NihongStore.',
        'unauthenticated' =>
          'Sesi NihongStore berakhir. Masuk kembali untuk melihat inbox.',
        'unavailable' || 'network-request-failed' =>
          'Koneksi ke NihongStore terputus. Periksa jaringan lalu coba lagi.',
        _ => 'Inbox NihongStore gagal dimuat. Coba lagi.',
      };
    }
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('NihongStore') || message.contains('admins/')) {
      return message;
    }
    return 'Inbox NihongStore gagal dimuat. Coba lagi.';
  }
}

class _InboxStatusFilter {
  const _InboxStatusFilter({required this.label, required this.status});

  final String label;
  final String status;
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.expand_more),
      label: const Text('Muat 50 pesanan lainnya'),
    ),
  );
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$count dari $total pesanan terbaru',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _NihongStoreOrderCard extends StatelessWidget {
  const _NihongStoreOrderCard({
    required this.order,
    required this.onTap,
    this.onAssign,
  });

  final NihongStoreOrder order;
  final VoidCallback onTap;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(
      0,
      (total, item) => total + item.jumlah,
    );
    final visibleItems = order.items
        .take(2)
        .map((item) {
          final quantity = item.jumlah > 1 ? ' ×${item.jumlah}' : '';
          return '${item.namaBarang}$quantity';
        })
        .toList(growable: false);
    final extraItems = order.items.length - visibleItems.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.no.isEmpty ? 'Pesanan NihongStore' : order.no,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navyDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NihongStoreStatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.namaPelanggan.isEmpty
                        ? 'Pelanggan belum dicatat'
                        : order.namaPelanggan,
                    style: const TextStyle(
                      color: AppColors.navyDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (order.noTelponPelanggan.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      order.noTelponPelanggan,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _InfoPill(
                        icon: Icons.access_time,
                        label: formatNihongStoreDateTime(order.createdAt),
                      ),
                      _InfoPill(
                        icon: Icons.shopping_bag_outlined,
                        label: '$itemCount pcs',
                      ),
                      _InfoPill(
                        icon: Icons.scale_outlined,
                        label: formatNihongStoreWeight(order.totalKg),
                      ),
                    ],
                  ),
                  if (visibleItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      visibleItems.join(' • ') +
                          (extraItems > 0 ? ' • +$extraItems barang' : ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.paymentStatus?.trim().isNotEmpty == true
                              ? order.paymentStatus!.trim()
                              : 'Status pembayaran belum dicatat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatNihongStoreRupiah(order.totalEstimasiHargaIdr),
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (onAssign != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: onAssign,
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Atur jadwal'),
              ),
            ),
        ],
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
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
  );
}

class _CacheNotice extends StatelessWidget {
  const _CacheNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'Menampilkan data tersimpan. Inbox akan diperbarui saat terhubung.',
      style: TextStyle(color: AppColors.warning, fontSize: 12),
    ),
  );
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) => const _InboxMessage(
    icon: Icons.inbox_outlined,
    title: 'Belum ada pesanan',
    message: 'Pesanan baru NihongStore akan muncul di sini.',
  );
}

class _NoMatchingOrders extends StatelessWidget {
  const _NoMatchingOrders();

  @override
  Widget build(BuildContext context) => const _InboxMessage(
    icon: Icons.search_off_outlined,
    title: 'Pesanan tidak ditemukan',
    message: 'Coba ganti status atau kata pencarian.',
  );
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
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

class _InboxLoadError extends StatelessWidget {
  const _InboxLoadError({required this.message, required this.onRetry});

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
            size: 42,
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
