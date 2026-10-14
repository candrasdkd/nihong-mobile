import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/pre_order.dart';
import '../../data/pre_order_data_source.dart';
import '../../data/pre_order_repository.dart';

enum PreOrdersStatus { loading, data, error }

class PreOrdersState {
  const PreOrdersState({
    this.status = PreOrdersStatus.loading,
    this.preOrders = const [],
    this.query = '',
    this.statusFilter = 'Semua',
    this.isFromCache = false,
    this.errorMessage,
  });

  final PreOrdersStatus status;
  final List<PreOrder> preOrders;
  final String query;
  final String statusFilter;
  final bool isFromCache;
  final String? errorMessage;

  bool get isLoading => status == PreOrdersStatus.loading;

  List<PreOrder> get filteredPreOrders {
    final normalizedQuery = query.trim().toLowerCase();
    return preOrders
        .where((preOrder) {
          final matchesStatus =
              statusFilter == 'Semua' || preOrder.status == statusFilter;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              [
                preOrder.namaPelanggan,
                preOrder.namaJastiper,
                preOrder.rute,
                preOrder.tanggalBerangkat,
                preOrder.catatan,
                ...preOrder.items.map((item) => item.namaBarang),
              ].any(
                (value) =>
                    value?.toLowerCase().contains(normalizedQuery) ?? false,
              );
          return matchesStatus && matchesQuery;
        })
        .toList(growable: false);
  }

  PreOrdersState copyWith({
    PreOrdersStatus? status,
    List<PreOrder>? preOrders,
    String? query,
    String? statusFilter,
    bool? isFromCache,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => PreOrdersState(
    status: status ?? this.status,
    preOrders: preOrders ?? this.preOrders,
    query: query ?? this.query,
    statusFilter: statusFilter ?? this.statusFilter,
    isFromCache: isFromCache ?? this.isFromCache,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );
}

final preOrdersViewModelProvider =
    NotifierProvider<PreOrdersViewModel, PreOrdersState>(
      PreOrdersViewModel.new,
    );

class PreOrdersViewModel extends Notifier<PreOrdersState> {
  StreamSubscription<PreOrderQuerySnapshot>? _subscription;
  int _generation = 0;
  bool _isDisposed = false;

  @override
  PreOrdersState build() {
    final repository = ref.watch(preOrderRepositoryProvider);
    _isDisposed = false;
    _subscribe(repository);
    ref.onDispose(() {
      _isDisposed = true;
      _generation++;
      unawaited(_subscription?.cancel());
    });
    return const PreOrdersState();
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void setStatusFilter(String status) =>
      state = state.copyWith(statusFilter: status);

  void retry() {
    state = state.copyWith(
      status: PreOrdersStatus.loading,
      clearErrorMessage: true,
    );
    _subscribe(ref.read(preOrderRepositoryProvider));
  }

  Future<String?> savePreOrder(PreOrder preOrder, {String? existingId}) async {
    final repository = ref.read(preOrderRepositoryProvider);
    if (existingId == null) return repository.createPreOrder(preOrder);
    await repository.updatePreOrder(
      PreOrder(
        id: existingId,
        idJadwal: preOrder.idJadwal,
        namaJastiper: preOrder.namaJastiper,
        rute: preOrder.rute,
        tanggalBerangkat: preOrder.tanggalBerangkat,
        idPelanggan: preOrder.idPelanggan,
        namaPelanggan: preOrder.namaPelanggan,
        noTelponPelanggan: preOrder.noTelponPelanggan,
        pic: preOrder.pic,
        items: preOrder.items,
        totalKg: preOrder.totalKg,
        status: preOrder.status,
        catatan: preOrder.catatan,
        nihongStoreOrderId: preOrder.nihongStoreOrderId,
        nihongStoreOrderNo: preOrder.nihongStoreOrderNo,
        nihongStoreCancellationState: preOrder.nihongStoreCancellationState,
        nihongStoreCancellationReason: preOrder.nihongStoreCancellationReason,
        nihongStoreStatusSyncState: preOrder.nihongStoreStatusSyncState,
        convertedOrderId: preOrder.convertedOrderId,
        deliveryAddressShareToken: preOrder.deliveryAddressShareToken,
        deliveryAddressShareCreatedAt: preOrder.deliveryAddressShareCreatedAt,
        productShareToken: preOrder.productShareToken,
        createdAt: preOrder.createdAt,
        updatedAt: preOrder.updatedAt,
      ),
    );
    return existingId;
  }

  Future<void> setItemChecked(String id, int itemIndex, bool checked) => ref
      .read(preOrderRepositoryProvider)
      .setItemChecked(id, itemIndex, checked);

  Future<void> deletePreOrder(String id) =>
      ref.read(preOrderRepositoryProvider).deletePreOrder(id);

  Future<void> cancelNihongStorePreOrder(String id, {String? reason}) => ref
      .read(preOrderRepositoryProvider)
      .cancelNihongStorePreOrder(id, reason: reason);

  Future<PreOrderConversionResult> convertPreOrderToOrder(String id) => ref
      .read(preOrderRepositoryProvider)
      .convertPreOrderToOrder(id, orderDate: _todayYmd());

  void _subscribe(PreOrderRepository repository) {
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = repository.watchPreOrders().listen(
      (snapshot) {
        if (_isDisposed || generation != _generation) return;
        state = state.copyWith(
          status: PreOrdersStatus.data,
          preOrders: snapshot.preOrders,
          isFromCache: snapshot.isFromCache,
          clearErrorMessage: true,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isDisposed || generation != _generation) return;
        state = state.copyWith(
          status: PreOrdersStatus.error,
          errorMessage: _messageFor(error),
        );
      },
    );
  }

  String _todayYmd() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _messageFor(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'Akses booking ditolak oleh Firestore Rules.',
        'unauthenticated' =>
          'Sesi login berakhir. Masuk kembali untuk mengelola booking.',
        'unavailable' || 'network-request-failed' =>
          'Koneksi ke Firestore terputus. Periksa jaringan lalu coba lagi.',
        _ => 'Data booking gagal dimuat. Coba lagi.',
      };
    }
    return error.toString().replaceFirst('Bad state: ', '');
  }
}
