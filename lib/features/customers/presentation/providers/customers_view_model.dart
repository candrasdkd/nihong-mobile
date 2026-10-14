import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firestore/firestore_page_size.dart';
import '../../data/customer_data_source.dart';
import '../../data/customer_repository.dart';
import '../../data/models/customer.dart';

enum CustomersStatus { loading, data, error }

class CustomersState {
  const CustomersState({
    this.status = CustomersStatus.loading,
    this.customers = const [],
    this.query = '',
    this.isFromCache = false,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final CustomersStatus status;
  final List<Customer> customers;
  final String query;
  final bool isFromCache;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isLoading => status == CustomersStatus.loading;

  List<Customer> get filteredCustomers {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return customers;

    final filteredCustomers = customers
        .where((customer) {
          final values = [
            customer.nama,
            customer.telpon,
            customer.alamat,
            customer.alamatPengirimanIndonesia?.namaPenerima,
            customer.alamatPengirimanIndonesia?.alamatPenerima,
            customer.alamatPengirimanIndonesia?.kodePos,
            customer.alamatPengirimanIndonesia?.noHp,
            customer.alamatPengirimanJepang?.namaPenerima,
            customer.alamatPengirimanJepang?.namaPenerimaRomaji,
            customer.alamatPengirimanJepang?.alamatPenerimaRomaji,
            customer.alamatPengirimanJepang?.alamatPenerima,
            customer.alamatPengirimanJepang?.alamatPenerimaKanji,
            customer.alamatPengirimanJepang?.kodePos,
            customer.alamatPengirimanJepang?.noHpAktif,
          ];
          return values.any(
            (value) => value?.toLowerCase().contains(normalizedQuery) ?? false,
          );
        })
        .toList(growable: false);
    return filteredCustomers;
  }

  CustomersState copyWith({
    CustomersStatus? status,
    List<Customer>? customers,
    String? query,
    bool? isFromCache,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => CustomersState(
    status: status ?? this.status,
    customers: customers ?? this.customers,
    query: query ?? this.query,
    isFromCache: isFromCache ?? this.isFromCache,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );
}

final customersViewModelProvider =
    NotifierProvider.autoDispose<CustomersViewModel, CustomersState>(
      CustomersViewModel.new,
    );

class CustomersViewModel extends Notifier<CustomersState> {
  StreamSubscription<CustomerQuerySnapshot>? _subscription;
  List<Customer> _firstPageCustomers = const [];
  List<Customer> _olderCustomers = [];
  List<String>? _firstPageIds;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  int _streamGeneration = 0;
  int _pageGeneration = 0;
  bool _isDisposed = false;

  @override
  CustomersState build() {
    final repository = ref.watch(customerRepositoryProvider);
    _isDisposed = false;
    _resetPagination();
    _subscribe(repository);
    ref.onDispose(() {
      _isDisposed = true;
      _streamGeneration++;
      _pageGeneration++;
      unawaited(_subscription?.cancel());
    });
    return const CustomersState();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void retry() {
    _resetPagination();
    state = state.copyWith(
      status: CustomersStatus.loading,
      customers: const [],
      isFromCache: false,
      hasMore: true,
      isLoadingMore: false,
      clearErrorMessage: true,
    );
    _subscribe(ref.read(customerRepositoryProvider));
  }

  Future<void> loadMore() async {
    final cursor = _lastDocument;
    if (!state.hasMore ||
        state.isLoadingMore ||
        cursor == null ||
        _isDisposed) {
      return;
    }

    final generation = _pageGeneration;
    state = state.copyWith(isLoadingMore: true, clearErrorMessage: true);

    try {
      final page = await ref
          .read(customerRepositoryProvider)
          .fetchCustomers(
            startAfterDocument: cursor,
            limitCount: FirestorePageSize.value,
          );
      if (_isDisposed || generation != _pageGeneration) return;

      if (page.lastDocument != null) _lastDocument = page.lastDocument;
      _appendOlderCustomers(page.customers);
      _hasMore = page.customers.length >= FirestorePageSize.value;
      final customers = _combinePages();
      state = state.copyWith(
        status: CustomersStatus.data,
        customers: customers,
        isFromCache: page.isFromCache,
        hasMore: _hasMore,
        isLoadingMore: false,
        clearErrorMessage: true,
      );
    } catch (error) {
      if (_isDisposed || generation != _pageGeneration) return;
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: _messageFor(error),
      );
    }
  }

  void _subscribe(CustomerRepository repository) {
    final generation = ++_streamGeneration;
    unawaited(_subscription?.cancel());
    _subscription = repository
        .watchFirstCustomers(limitCount: FirestorePageSize.value)
        .listen(
          (snapshot) {
            if (_isDisposed || generation != _streamGeneration) return;

            final nextIds = snapshot.customers
                .map((customer) => customer.id)
                .toList(growable: false);
            final firstPageChanged =
                _firstPageIds != null && !_sameIds(_firstPageIds!, nextIds);

            if (_firstPageIds == null || firstPageChanged) {
              if (firstPageChanged) {
                _olderCustomers = [];
                _pageGeneration++;
              }
              _lastDocument = snapshot.lastDocument;
              _hasMore = snapshot.customers.length >= FirestorePageSize.value;
            }

            _firstPageIds = nextIds;
            _firstPageCustomers = snapshot.customers;
            final customers = _combinePages();
            state = state.copyWith(
              status: CustomersStatus.data,
              customers: customers,
              isFromCache: snapshot.isFromCache,
              hasMore: _hasMore,
              isLoadingMore: firstPageChanged ? false : state.isLoadingMore,
              clearErrorMessage: true,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isDisposed || generation != _streamGeneration) return;
            final hadItems = state.customers.isNotEmpty;
            state = state.copyWith(
              status: hadItems ? CustomersStatus.data : CustomersStatus.error,
              isLoadingMore: false,
              errorMessage: _messageFor(error),
            );
          },
        );
  }

  void _appendOlderCustomers(List<Customer> customers) {
    final existingIds = _olderCustomers.map((customer) => customer.id).toSet();
    for (final customer in customers) {
      if (existingIds.add(customer.id)) _olderCustomers.add(customer);
    }
  }

  List<Customer> _combinePages() {
    final customersById = <String, Customer>{};
    for (final customer in [..._firstPageCustomers, ..._olderCustomers]) {
      customersById[customer.id] = customer;
    }
    return customersById.values.toList(growable: false);
  }

  bool _sameIds(List<String> previous, List<String> next) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      if (previous[index] != next[index]) return false;
    }
    return true;
  }

  void _resetPagination() {
    _pageGeneration++;
    _firstPageCustomers = const [];
    _olderCustomers = [];
    _firstPageIds = null;
    _lastDocument = null;
    _hasMore = true;
  }

  String _messageFor(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Akses daftar pelanggan ditolak oleh Firestore Rules.',
        'unauthenticated' =>
          'Sesi login berakhir. Masuk kembali untuk melihat pelanggan.',
        'unavailable' || 'network-request-failed' =>
          'Koneksi ke Firestore terputus. Periksa jaringan lalu coba lagi.',
        _ => 'Daftar pelanggan gagal dimuat. Coba lagi.',
      };
    }
    return 'Daftar pelanggan gagal dimuat. Coba lagi.';
  }
}
