import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/formatting/safe_calendar_date.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../data/models/order_doc.dart';
import '../../data/orders_data_source.dart';
import '../../domain/order_calculations.dart';
import '../order_formatters.dart';
import '../providers/orders_view_model.dart';
import '../widgets/order_status_badge.dart';
import 'order_detail_sheet.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const _filters = [
    _OrderStatusFilter(label: 'Semua'),
    _OrderStatusFilter(label: 'Belum Membayar', status: OrderStatuses.unpaid),
    _OrderStatusFilter(label: 'DP Terbayar', status: OrderStatuses.depositPaid),
    _OrderStatusFilter(label: 'Selesai', status: OrderStatuses.completed),
  ];

  final _searchController = TextEditingController();
  String? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan')),
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
                  hintText: 'Cari nomor, pelanggan, atau barang',
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
              height: 52,
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
                  return ChoiceChip(
                    label: Text(filter.label),
                    selected: _selectedStatus == filter.status,
                    onSelected: (_) => setState(() {
                      _selectedStatus = filter.status;
                    }),
                    selectedColor: AppColors.navy.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: _selectedStatus == filter.status
                          ? AppColors.navy
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: _selectedStatus == filter.status
                          ? AppColors.navy.withValues(alpha: 0.22)
                          : AppColors.border,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: ordersAsync.when(
                loading: () => const AppLoadingView(message: 'Memuat pesanan…'),
                error: (error, _) => _OrdersLoadError(
                  message: _errorMessage(error),
                  onRetry: () => ref.invalidate(ordersStreamProvider),
                ),
                data: _buildOrders,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrders(OrderQuerySnapshot snapshot) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredOrders = snapshot.orders
        .where((order) {
          if (_selectedStatus != null &&
              order.displayStatus != _selectedStatus) {
            return false;
          }
          if (query.isEmpty) return true;

          final searchableValues = [
            order.no,
            order.namaPelanggan,
            order.namaBarang,
            order.kategori,
            order.catatan,
            order.displayStatus,
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
          const Expanded(child: _EmptyOrders()),
        ],
      );
    }

    if (filteredOrders.isEmpty) {
      return Column(
        children: [
          if (snapshot.isFromCache) const _CacheNotice(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '0 dari ${snapshot.orders.length} pesanan',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: _NoMatchingOrders()),
        ],
      );
    }

    return Column(
      children: [
        if (snapshot.isFromCache) const _CacheNotice(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filteredOrders.length} dari ${snapshot.orders.length} pesanan',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: filteredOrders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              return _OrderCard(
                order: order,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => OrderDetailSheet(order: order),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _errorMessage(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Akses daftar pesanan ditolak oleh Firestore Rules.',
        'unauthenticated' =>
          'Sesi login berakhir. Masuk kembali untuk melihat pesanan.',
        'unavailable' || 'network-request-failed' =>
          'Koneksi ke Firestore terputus. Periksa jaringan lalu coba lagi.',
        _ => 'Daftar pesanan gagal dimuat. Coba lagi.',
      };
    }
    return 'Daftar pesanan gagal dimuat. Coba lagi.';
  }
}

class _OrderStatusFilter {
  const _OrderStatusFilter({required this.label, this.status});

  final String label;
  final String? status;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderDoc order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final payment = getPaymentSummary(
      total: order.totalPembayaran,
      dpNominal: order.dpNominal,
      pelunasanNominal: order.pelunasanNominal,
    );
    final date = SafeCalendarDate.formatFullIndonesian(order.tanggal);

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.no.isEmpty ? 'Pesanan' : order.no,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navyDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          date.isEmpty ? 'Tanggal belum dicatat' : date,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OrderStatusBadge(status: order.displayStatus),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                order.namaPelanggan.isEmpty
                    ? 'Pelanggan belum dicatat'
                    : order.namaPelanggan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                order.namaBarang.isEmpty
                    ? 'Barang belum dicatat'
                    : order.namaBarang,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.scale_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    formatOrderWeight(order.jumlahKg),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatOrderCurrency(
                          order.totalPembayaran,
                          order.tipeNominal,
                        ),
                        style: const TextStyle(
                          color: AppColors.navyDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Sisa ${formatOrderCurrency(payment.remaining, order.tipeNominal)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CacheNotice extends StatelessWidget {
  const _CacheNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    color: AppColors.warning.withValues(alpha: 0.1),
    child: const Text(
      'Menampilkan data tersimpan. Perubahan terbaru mungkin belum tersedia.',
      style: TextStyle(color: AppColors.warning, fontSize: 12),
    ),
  );
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) => const _OrdersMessage(
    icon: Icons.receipt_long_outlined,
    title: 'Belum ada pesanan',
    message: 'Pesanan yang tersimpan akan muncul di sini.',
  );
}

class _NoMatchingOrders extends StatelessWidget {
  const _NoMatchingOrders();

  @override
  Widget build(BuildContext context) => const _OrdersMessage(
    icon: Icons.search_off_outlined,
    title: 'Pesanan tidak ditemukan',
    message: 'Coba ubah kata pencarian atau filter status.',
  );
}

class _OrdersMessage extends StatelessWidget {
  const _OrdersMessage({
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.navy.withValues(alpha: 0.55)),
          const SizedBox(height: 12),
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

class _OrdersLoadError extends StatelessWidget {
  const _OrdersLoadError({required this.message, required this.onRetry});

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
            size: 44,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
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
