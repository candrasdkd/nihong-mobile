import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/departure_schedule.dart';
import '../../data/models/departure_schedule_draft.dart';
import '../../data/models/schedule_jastiper.dart';
import '../../data/schedule_data_source.dart';
import '../../data/schedule_repository.dart';

class SchedulesState {
  const SchedulesState({
    this.schedules = const [],
    this.jastipers = const [],
    this.isLoadingSchedules = true,
    this.isLoadingJastipers = true,
    this.isSchedulesFromCache = false,
    this.isJastipersFromCache = false,
    this.scheduleErrorMessage,
    this.jastiperErrorMessage,
    this.query = '',
    this.statusFilter = 'Open',
  });

  final List<DepartureSchedule> schedules;
  final List<ScheduleJastiper> jastipers;
  final bool isLoadingSchedules;
  final bool isLoadingJastipers;
  final bool isSchedulesFromCache;
  final bool isJastipersFromCache;
  final String? scheduleErrorMessage;
  final String? jastiperErrorMessage;
  final String query;
  final String statusFilter;

  List<DepartureSchedule> get filteredSchedules {
    final normalizedQuery = query.trim().toLowerCase();
    return schedules
        .where((schedule) {
          final matchesStatus =
              statusFilter == 'Semua' || schedule.status == statusFilter;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              schedule.rute.toLowerCase().contains(normalizedQuery) ||
              schedule.namaJastiper.toLowerCase().contains(normalizedQuery) ||
              (schedule.catatan?.toLowerCase().contains(normalizedQuery) ??
                  false);
          return matchesStatus && matchesQuery;
        })
        .toList(growable: false);
  }

  int get openCount => schedules.where((item) => item.status == 'Open').length;

  SchedulesState copyWith({
    List<DepartureSchedule>? schedules,
    List<ScheduleJastiper>? jastipers,
    bool? isLoadingSchedules,
    bool? isLoadingJastipers,
    bool? isSchedulesFromCache,
    bool? isJastipersFromCache,
    String? scheduleErrorMessage,
    String? jastiperErrorMessage,
    bool clearScheduleError = false,
    bool clearJastiperError = false,
    String? query,
    String? statusFilter,
  }) => SchedulesState(
    schedules: schedules ?? this.schedules,
    jastipers: jastipers ?? this.jastipers,
    isLoadingSchedules: isLoadingSchedules ?? this.isLoadingSchedules,
    isLoadingJastipers: isLoadingJastipers ?? this.isLoadingJastipers,
    isSchedulesFromCache: isSchedulesFromCache ?? this.isSchedulesFromCache,
    isJastipersFromCache: isJastipersFromCache ?? this.isJastipersFromCache,
    scheduleErrorMessage: clearScheduleError
        ? null
        : scheduleErrorMessage ?? this.scheduleErrorMessage,
    jastiperErrorMessage: clearJastiperError
        ? null
        : jastiperErrorMessage ?? this.jastiperErrorMessage,
    query: query ?? this.query,
    statusFilter: statusFilter ?? this.statusFilter,
  );
}

final schedulesViewModelProvider =
    NotifierProvider<SchedulesViewModel, SchedulesState>(
      SchedulesViewModel.new,
    );

class SchedulesViewModel extends Notifier<SchedulesState> {
  StreamSubscription<DepartureScheduleQuerySnapshot>? _schedulesSubscription;
  StreamSubscription<ScheduleJastiperQuerySnapshot>? _jastipersSubscription;
  int _schedulesGeneration = 0;
  int _jastipersGeneration = 0;
  bool _isDisposed = false;

  @override
  SchedulesState build() {
    final repository = ref.watch(scheduleRepositoryProvider);
    _isDisposed = false;
    _subscribeSchedules(repository, showLoading: false);
    _subscribeJastipers(repository, showLoading: false);
    ref.onDispose(() {
      _isDisposed = true;
      _schedulesGeneration++;
      _jastipersGeneration++;
      unawaited(_schedulesSubscription?.cancel());
      unawaited(_jastipersSubscription?.cancel());
    });
    return const SchedulesState();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
  }

  void retry() {
    _subscribeSchedules(ref.read(scheduleRepositoryProvider));
    _subscribeJastipers(ref.read(scheduleRepositoryProvider));
  }

  Future<void> saveSchedule({
    String? id,
    required String idJastiper,
    required String rute,
    required String tanggalBerangkat,
    required String tanggalLastDrop,
    required double slotBeratKg,
    required String status,
    required String catatan,
    required double hargaFeeJastiper,
  }) async {
    final jastiper = _findJastiper(idJastiper);
    if (jastiper == null) {
      throw StateError('Pilih jastiper yang masih terdaftar.');
    }

    final draft = DepartureScheduleDraft(
      idJastiper: jastiper.id,
      namaJastiper: jastiper.nama,
      rute: rute,
      tanggalBerangkat: tanggalBerangkat,
      tanggalLastDrop: tanggalLastDrop,
      slotBeratKg: slotBeratKg,
      status: status,
      catatan: catatan,
      hargaFeeJastiper: hargaFeeJastiper,
    );
    final repository = ref.read(scheduleRepositoryProvider);
    if (id == null) {
      await repository.createSchedule(draft);
    } else {
      await repository.updateSchedule(id, draft);
    }
  }

  ScheduleJastiper? _findJastiper(String id) {
    for (final jastiper in state.jastipers) {
      if (jastiper.id == id) return jastiper;
    }
    return null;
  }

  void _subscribeSchedules(
    ScheduleRepository repository, {
    bool showLoading = true,
  }) {
    final generation = ++_schedulesGeneration;
    unawaited(_schedulesSubscription?.cancel());
    if (showLoading) {
      state = state.copyWith(
        isLoadingSchedules: true,
        clearScheduleError: true,
      );
    }
    _schedulesSubscription = repository.watchSchedules().listen(
      (snapshot) {
        if (_isDisposed || generation != _schedulesGeneration) return;
        state = state.copyWith(
          schedules: snapshot.schedules,
          isLoadingSchedules: false,
          isSchedulesFromCache: snapshot.isFromCache,
          clearScheduleError: true,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isDisposed || generation != _schedulesGeneration) return;
        state = state.copyWith(
          isLoadingSchedules: false,
          scheduleErrorMessage: _messageFor(error, label: 'jadwal'),
        );
      },
    );
  }

  void _subscribeJastipers(
    ScheduleRepository repository, {
    bool showLoading = true,
  }) {
    final generation = ++_jastipersGeneration;
    unawaited(_jastipersSubscription?.cancel());
    if (showLoading) {
      state = state.copyWith(
        isLoadingJastipers: true,
        clearJastiperError: true,
      );
    }
    _jastipersSubscription = repository.watchJastipers().listen(
      (snapshot) {
        if (_isDisposed || generation != _jastipersGeneration) return;
        state = state.copyWith(
          jastipers: snapshot.jastipers,
          isLoadingJastipers: false,
          isJastipersFromCache: snapshot.isFromCache,
          clearJastiperError: true,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isDisposed || generation != _jastipersGeneration) return;
        state = state.copyWith(
          isLoadingJastipers: false,
          jastiperErrorMessage: _messageFor(error, label: 'jastiper'),
        );
      },
    );
  }

  String _messageFor(Object error, {required String label}) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Akses data $label ditolak oleh Firestore Rules.',
        'unauthenticated' =>
          'Sesi login berakhir. Masuk kembali untuk melihat $label.',
        'unavailable' || 'network-request-failed' =>
          'Koneksi ke Firestore terputus saat memuat $label.',
        _ => 'Data $label gagal dimuat. Coba lagi.',
      };
    }
    return 'Data $label gagal dimuat. Coba lagi.';
  }
}
