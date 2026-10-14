import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/firestore/firestore_page_size.dart';
import '../../../../core/formatting/safe_calendar_date.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/load_more_tile.dart';
import '../../data/models/order_doc.dart';
import '../../data/orders_data_source.dart';
import '../../data/orders_repository.dart';
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
  int _limitCount = FirestorePageSize.value;
  bool _isLoadingMore = false;
  OrderQuerySnapshot? _lastSnapshot;
  String? _loadMoreError;
  Timer? _nameSearchTimer;
  List<OrderDoc> _globalNameSearchOrders = [];
  DocumentSnapshot<Map<String, dynamic>>? _nameSearchLastDocument;
  String _nameSearchPrefix = '';
  bool _isSearchingNames = false;
  bool _isLoadingMoreNames = false;
  bool _hasMoreNameSearchResults = false;
  String? _nameSearchError;
  int _nameSearchGeneration = 0;

  @override
  void dispose() {
    _nameSearchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = ordersStreamProvider(_limitCount);
    final ordersAsync = ref.watch(ordersProvider);
    ref.listen(ordersProvider, (previous, next) {
      if (next.hasValue) {
        _lastSnapshot = next.value;
        _isLoadingMore = false;
      } else if (next.hasError && _isLoadingMore) {
        _isLoadingMore = false;
        _loadMoreError = _errorMessage(next.error!);
        _limitCount -= FirestorePageSize.value;
      }
    });
    final snapshot = ordersAsync.asData?.value ?? _lastSnapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang pesanan',
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
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
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
              child: snapshot == null
                  ? ordersAsync.hasError
                        ? _OrdersLoadError(
                            message: _errorMessage(ordersAsync.error!),
                            onRetry: _reload,
                          )
                        : const AppLoadingView(message: 'Memuat pesanan…')
                  : _buildOrders(
                      snapshot,
                      isLoadingMore: _isLoadingMore && ordersAsync.isLoading,
                      loadMoreError:
                          _loadMoreError ??
                          (ordersAsync.hasError
                              ? _errorMessage(ordersAsync.error!)
                              : null),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrders(
    OrderQuerySnapshot snapshot, {
    required bool isLoadingMore,
    String? loadMoreError,
  }) {
    final query = _searchController.text.trim().toLowerCase();
    final hasMoreLoadedOrders =
        snapshot.orders.length >= _limitCount ||
        isLoadingMore ||
        loadMoreError != null;
    final hasMoreNameResults =
        _isSearchingNames ||
        _isLoadingMoreNames ||
        _hasMoreNameSearchResults ||
        _nameSearchError != null;
    final hasMore = query.isEmpty ? hasMoreLoadedOrders : hasMoreNameResults;
    final searchError = _nameSearchError ?? loadMoreError;
    final isAnyLoadingMore =
        isLoadingMore || _isSearchingNames || _isLoadingMoreNames;

    final filteredLoadedOrders = snapshot.orders
        .where((order) {
          if (_selectedStatus != null &&
              order.displayStatus != _selectedStatus) {
            return false;
          }
          if (query.isEmpty) return true;

          return order.namaPelanggan.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final matchingOrdersById = <String, OrderDoc>{
      for (final order in filteredLoadedOrders) order.id: order,
    };
    if (query.isNotEmpty) {
      for (final order in _globalNameSearchOrders) {
        if (_selectedStatus == null || order.displayStatus == _selectedStatus) {
          matchingOrdersById.putIfAbsent(order.id, () => order);
        }
      }
    }
    final filteredOrders = matchingOrdersById.values.toList(growable: false);

    if (snapshot.orders.isEmpty && query.isEmpty) {
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
          if (_isSearchingNames)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '0 hasil • ${snapshot.orders.length} data dimuat',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (!_isSearchingNames)
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 220, child: _NoMatchingOrders()),
                  if (hasMore)
                    LoadMoreTile(
                      onPressed: () => _loadMoreForCurrentQuery(snapshot),
                      isLoading: isAnyLoadingMore,
                      errorMessage: searchError,
                      label: _loadMoreLabel(query),
                    ),
                ],
              ),
            ),
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
              query.isEmpty
                  ? '${filteredOrders.length} hasil • ${snapshot.orders.length} data dimuat'
                  : '${filteredOrders.length} hasil • awalan nama dicari di semua pesanan',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 240) {
                _loadMoreForCurrentQuery(snapshot);
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: filteredOrders.length + (hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= filteredOrders.length) {
                  return LoadMoreTile(
                    onPressed: () => _loadMoreForCurrentQuery(snapshot),
                    isLoading: isAnyLoadingMore,
                    errorMessage: searchError,
                    label: _loadMoreLabel(query),
                  );
                }
                final order = filteredOrders[index];
                return _OrderCard(
                  order: order,
                  onTap: () => _showOrderDetails(order),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showOrderDetails(OrderDoc order) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => OrderDetailSheet(order: order),
    );
    if (mounted) _reload();
  }

  void _onSearchChanged(String value) {
    final prefix = value.trim().toUpperCase();
    _nameSearchTimer?.cancel();
    final generation = ++_nameSearchGeneration;
    _nameSearchPrefix = prefix;
    _globalNameSearchOrders = [];
    _nameSearchLastDocument = null;
    _hasMoreNameSearchResults = false;
    _isLoadingMoreNames = false;
    _nameSearchError = null;
    _isSearchingNames = prefix.isNotEmpty;
    setState(() {});

    if (prefix.isEmpty) return;
    _nameSearchTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_fetchNameSearchPage(prefix, generation));
    });
  }

  Future<void> _fetchNameSearchPage(String prefix, int generation) async {
    if (!mounted || generation != _nameSearchGeneration) return;
    final cursor = _nameSearchLastDocument;
    setState(() {
      _isSearchingNames = cursor == null;
      _isLoadingMoreNames = cursor != null;
      _nameSearchError = null;
    });

    try {
      final page = await ref
          .read(ordersRepositoryProvider)
          .searchOrdersByCustomerNamePrefix(
            prefix: prefix,
            startAfterDocument: cursor,
            limitCount: FirestorePageSize.value,
          );
      if (!mounted || generation != _nameSearchGeneration) return;

      if (cursor == null) {
        _globalNameSearchOrders = page.orders;
      } else {
        final existingIds = _globalNameSearchOrders
            .map((order) => order.id)
            .toSet();
        for (final order in page.orders) {
          if (existingIds.add(order.id)) _globalNameSearchOrders.add(order);
        }
      }
      _nameSearchLastDocument = page.lastDocument;
      _hasMoreNameSearchResults = page.orders.length >= FirestorePageSize.value;
      setState(() {
        _isSearchingNames = false;
        _isLoadingMoreNames = false;
      });
    } catch (error) {
      if (!mounted || generation != _nameSearchGeneration) return;
      setState(() {
        _isSearchingNames = false;
        _isLoadingMoreNames = false;
        _nameSearchError = _errorMessage(error);
      });
    }
  }

  void _loadMoreForCurrentQuery(OrderQuerySnapshot snapshot) {
    if (_searchController.text.trim().isEmpty) {
      _loadMore(snapshot);
      return;
    }
    if (_isSearchingNames || _isLoadingMoreNames) return;

    if (_hasMoreNameSearchResults ||
        (_nameSearchError != null && _nameSearchLastDocument == null)) {
      unawaited(_fetchNameSearchPage(_nameSearchPrefix, _nameSearchGeneration));
    }
  }

  String _loadMoreLabel(String query) {
    if (query.isEmpty) return 'Muat pesanan lainnya';
    if (_isSearchingNames ||
        _isLoadingMoreNames ||
        _hasMoreNameSearchResults ||
        (_nameSearchError != null && _nameSearchLastDocument == null)) {
      return 'Muat hasil nama berikutnya';
    }
    return 'Muat pesanan lainnya';
  }

  void _loadMore([OrderQuerySnapshot? currentSnapshot]) {
    final snapshot = currentSnapshot ?? _lastSnapshot;
    if (_isLoadingMore ||
        snapshot == null ||
        snapshot.orders.length < _limitCount) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
      _limitCount += FirestorePageSize.value;
    });
  }

  void _reload() {
    final limitCount = _limitCount;
    setState(() {
      _lastSnapshot = null;
      _isLoadingMore = false;
      _loadMoreError = null;
    });
    ref.invalidate(ordersStreamProvider(limitCount));
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
