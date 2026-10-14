import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.errorMessage,
  });

  final CustomersStatus status;
  final List<Customer> customers;
  final String query;
  final bool isFromCache;
  final String? errorMessage;

  bool get isLoading => status == CustomersStatus.loading;

  List<Customer> get filteredCustomers {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return customers;

    return customers
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
  }

  CustomersState copyWith({
    CustomersStatus? status,
    List<Customer>? customers,
    String? query,
    bool? isFromCache,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => CustomersState(
    status: status ?? this.status,
    customers: customers ?? this.customers,
    query: query ?? this.query,
    isFromCache: isFromCache ?? this.isFromCache,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );
}

final customersViewModelProvider =
    NotifierProvider<CustomersViewModel, CustomersState>(
      CustomersViewModel.new,
    );

class CustomersViewModel extends Notifier<CustomersState> {
  StreamSubscription<CustomerQuerySnapshot>? _subscription;
  int _streamGeneration = 0;
  bool _isDisposed = false;

  @override
  CustomersState build() {
    final repository = ref.watch(customerRepositoryProvider);
    _isDisposed = false;
    _subscribe(repository);
    ref.onDispose(() {
      _isDisposed = true;
      _streamGeneration++;
      unawaited(_subscription?.cancel());
    });
    return const CustomersState();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void retry() {
    state = state.copyWith(
      status: CustomersStatus.loading,
      clearErrorMessage: true,
    );
    _subscribe(ref.read(customerRepositoryProvider));
  }

  void _subscribe(CustomerRepository repository) {
    final generation = ++_streamGeneration;
    unawaited(_subscription?.cancel());
    _subscription = repository.watchCustomers().listen(
      (snapshot) {
        if (_isDisposed || generation != _streamGeneration) return;
        state = CustomersState(
          status: CustomersStatus.data,
          customers: snapshot.customers,
          query: state.query,
          isFromCache: snapshot.isFromCache,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isDisposed || generation != _streamGeneration) return;
        state = state.copyWith(
          status: CustomersStatus.error,
          errorMessage: _messageFor(error),
        );
      },
    );
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
