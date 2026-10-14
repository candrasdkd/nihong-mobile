import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_mapper.dart';
import '../../../core/formatting/safe_calendar_date.dart';
import '../../auth/data/nihong_store_auth_repository.dart';
import '../../customers/data/models/customer.dart';
import '../../pre_orders/data/models/pre_order.dart';
import '../../schedules/data/models/departure_schedule.dart';
import 'nihong_store_assignment_rules.dart';
import 'models/nihong_store_order.dart';

class NihongStoreInboxSnapshot {
  const NihongStoreInboxSnapshot({
    required this.orders,
    required this.isFromCache,
  });

  final List<NihongStoreOrder> orders;
  final bool isFromCache;
}

abstract interface class NihongStoreInboxDataSource {
  Stream<NihongStoreInboxSnapshot> watchOrders({required int limitCount});

  Future<NihongStoreOrder> updateItemAvailability({
    required String orderId,
    required int itemIndex,
    required String availability,
  });

  Future<void> rejectInboxOrder({required String orderId, String? reason});

  Future<NihongStoreAssignmentResult> assignOrderToSchedule({
    required NihongStoreOrder order,
    required String scheduleId,
  });
}

final nihongStoreInboxDataSourceProvider = Provider<NihongStoreInboxDataSource>(
  (ref) => FirestoreNihongStoreInboxDataSource(
    ref.watch(nihongStoreFirestoreProvider),
    FirebaseFirestore.instance,
    ref.watch(nihongStoreAuthRepositoryProvider),
  ),
);

class NihongStoreAssignmentResult {
  const NihongStoreAssignmentResult({
    required this.preOrderId,
    required this.scheduleId,
    required this.customerId,
    required this.scheduleRoute,
    required this.formattedDepartureDate,
    required this.totalKg,
    required this.wasCreated,
  });

  final String preOrderId;
  final String scheduleId;
  final String customerId;
  final String scheduleRoute;
  final String formattedDepartureDate;
  final double totalKg;
  final bool wasCreated;
}

class NihongStoreAssignmentSyncException implements Exception {
  const NihongStoreAssignmentSyncException({
    required this.preOrderId,
    required this.message,
  });

  final String preOrderId;
  final String message;

  @override
  String toString() => message;
}

class FirestoreNihongStoreInboxDataSource
    implements NihongStoreInboxDataSource {
  const FirestoreNihongStoreInboxDataSource(
    this._firestore,
    this._internalFirestore,
    this._auth,
  );

  /// Secondary NihongStore project.
  final FirebaseFirestore _firestore;

  /// Primary Nihong Jastip project.
  final FirebaseFirestore _internalFirestore;
  final NihongStoreAuthRepository _auth;

  @override
  Stream<NihongStoreInboxSnapshot> watchOrders({
    required int limitCount,
  }) async* {
    final user = _auth.currentUser;
    if (user == null) {
      throw const NihongStoreAccessException(
        'Sesi NihongStore belum aktif. Masuk kembali untuk melihat inbox.',
      );
    }
    await _auth.verifyAdminAccess(user);

    yield* _firestore
        .collection(NihongStoreOrder.collectionName)
        .orderBy('createdAt', descending: true)
        .limit(limitCount)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => NihongStoreInboxSnapshot(
            orders: snapshot.docs.map(NihongStoreOrder.fromFirestore).toList(),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  @override
  Future<NihongStoreOrder> updateItemAvailability({
    required String orderId,
    required int itemIndex,
    required String availability,
  }) async {
    if (availability != 'Tersedia' && availability != 'Stok habis') {
      throw StateError('Pilih status barang yang tersedia.');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const NihongStoreAccessException(
        'Sesi NihongStore belum aktif. Masuk kembali untuk mengubah stok.',
      );
    }
    await _auth.verifyAdminAccess(user);

    final orderRef = _firestore
        .collection(NihongStoreOrder.collectionName)
        .doc(orderId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) throw StateError('Pesanan tidak ditemukan.');
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] != 'inbox') {
        throw StateError(
          'Ketersediaan barang hanya bisa diubah sebelum pesanan dijadwalkan.',
        );
      }

      final items = FirestoreMapper.mapList(data['items']);
      if (itemIndex < 0 || itemIndex >= items.length) {
        throw StateError('Barang tidak ditemukan. Muat ulang pesanan.');
      }
      items[itemIndex] = {...items[itemIndex], 'status': availability};

      final availableItems = items
          .where(
            (item) =>
                item['status'] != 'Stok habis' &&
                item['status'] != 'Dibatalkan',
          )
          .toList(growable: false);
      final outOfStockItems = items
          .where((item) => item['status'] == 'Stok habis')
          .toList(growable: false);
      final calculatedWeight = availableItems.fold<double>(0, (running, item) {
        final rawWeight = FirestoreMapper.number(
          item['beratKg'],
          fallback: 0.3,
        );
        final weight = rawWeight == 0 || !rawWeight.isFinite ? 0.3 : rawWeight;
        final rawQuantity = FirestoreMapper.optionalInt(item['jumlah']) ?? 1;
        final quantity = rawQuantity > 0 ? rawQuantity : 1;
        return running + weight * quantity;
      });
      final totalKg = double.parse(calculatedWeight.toStringAsFixed(2));
      final totalEstimasiHargaIdr = availableItems.fold<double>(0, (
        running,
        item,
      ) {
        final rawQuantity = FirestoreMapper.optionalInt(item['jumlah']) ?? 1;
        final quantity = rawQuantity > 0 ? rawQuantity : 1;
        return running + FirestoreMapper.number(item['hargaIdr']) * quantity;
      });
      final allOutOfStock = availableItems.isEmpty;
      final someOutOfStock = outOfStockItems.isNotEmpty && !allOutOfStock;
      final outOfStockNames = outOfStockItems
          .map((item) => FirestoreMapper.string(item['namaBarang']))
          .join(', ');
      final timelineStatus = allOutOfStock
          ? 'Stok Habis'
          : someOutOfStock
          ? 'Sebagian Stok Habis'
          : 'Ketersediaan Diperbarui';
      final timelineNote = allOutOfStock
          ? 'Semua produk dalam pesanan ditandai Stok Habis di Jepang.'
          : someOutOfStock
          ? 'Sebagian produk ($outOfStockNames) ditandai Stok Habis. Tagihan disesuaikan.'
          : 'Pembaruan ketersediaan produk titipan oleh tim Nihong Jastip.';
      final timeline = _timelineFrom(data['timeline'])
        ..add({
          'status': timelineStatus,
          'note': timelineNote,
          'at': DateTime.now().toIso8601String(),
        });
      final displayStatus = allOutOfStock
          ? 'Stok Habis'
          : someOutOfStock
          ? 'Sebagian Stok Habis'
          : (data['displayStatus']?.toString().trim().isNotEmpty ?? false) &&
                data['displayStatus'] != 'Stok Habis' &&
                data['displayStatus'] != 'Sebagian Stok Habis'
          ? data['displayStatus'].toString()
          : 'Menunggu Cek Stok';
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      final update = <String, dynamic>{
        'items': items,
        'totalKg': totalKg == 0 ? 0.5 : totalKg,
        'totalEstimasiHargaIdr': totalEstimasiHargaIdr,
        'displayStatus': displayStatus,
        'timeline': timeline,
        'updatedAt': updatedAt,
      };
      transaction.update(orderRef, update);
      return NihongStoreOrder.fromMap({...data, ...update}, id: orderId);
    });
  }

  @override
  Future<void> rejectInboxOrder({
    required String orderId,
    String? reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const NihongStoreAccessException(
        'Sesi NihongStore belum aktif. Masuk kembali untuk membatalkan pesanan.',
      );
    }
    await _auth.verifyAdminAccess(user);

    final orderRef = _firestore
        .collection(NihongStoreOrder.collectionName)
        .doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) throw StateError('Pesanan tidak ditemukan.');
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] != 'inbox') {
        throw StateError(
          'Hanya pesanan yang belum dijadwalkan yang bisa ditolak dari inbox.',
        );
      }

      final cleanReason = reason?.trim() ?? '';
      final note = cleanReason.isEmpty
          ? 'Pesanan dibatalkan oleh admin/konsumen.'
          : 'Pesanan dibatalkan: $cleanReason';
      final timeline = _timelineFrom(data['timeline'])
        ..add({
          'status': 'Dibatalkan',
          'note': note,
          'at': DateTime.now().toIso8601String(),
        });
      final update = <String, dynamic>{
        'status': 'rejected',
        'displayStatus': 'Dibatalkan',
        'timeline': timeline,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (cleanReason.isNotEmpty) {
        update['catatan'] = '[Ditolak: $cleanReason]';
      }
      transaction.update(orderRef, update);
    });
  }

  @override
  Future<NihongStoreAssignmentResult> assignOrderToSchedule({
    required NihongStoreOrder order,
    required String scheduleId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const NihongStoreAccessException(
        'Sesi NihongStore belum aktif. Masuk kembali untuk menjadwalkan pesanan.',
      );
    }
    await _auth.verifyAdminAccess(user);

    final storeOrderRef = _firestore
        .collection(NihongStoreOrder.collectionName)
        .doc(order.id);
    final storeOrderSnapshot = await storeOrderRef.get(
      const GetOptions(source: Source.server),
    );
    if (!storeOrderSnapshot.exists) {
      throw StateError(
        'Pesanan NihongStore tidak ditemukan. Muat ulang inbox.',
      );
    }
    final currentOrder = NihongStoreOrder.fromMap(
      storeOrderSnapshot.data() ?? const <String, dynamic>{},
      id: storeOrderSnapshot.id,
    );
    if (currentOrder.status == 'assigned' &&
        currentOrder.assignedScheduleId == scheduleId &&
        (currentOrder.assignedPreOrderId?.isNotEmpty ?? false)) {
      return NihongStoreAssignmentResult(
        preOrderId: currentOrder.assignedPreOrderId!,
        scheduleId: scheduleId,
        customerId: currentOrder.idPelanggan ?? '',
        scheduleRoute: currentOrder.assignedScheduleRoute ?? '',
        formattedDepartureDate: currentOrder.assignedScheduleDate ?? '',
        totalKg: NihongStoreAssignmentRules.estimateWeightKg(currentOrder),
        wasCreated: false,
      );
    }
    if (currentOrder.status != 'inbox') {
      throw StateError(
        'Pesanan sudah berubah status menjadi ${currentOrder.statusLabel}. Muat ulang inbox.',
      );
    }

    final customerId = await _resolveCustomerId(currentOrder);
    final newCustomerRef = customerId.isEmpty
        ? _internalFirestore
              .collection(Customer.collectionName)
              .doc(NihongStoreAssignmentRules.documentId(currentOrder.id))
        : null;
    final resolvedCustomerId = newCustomerRef?.id ?? customerId;
    final scheduleRef = _internalFirestore
        .collection(DepartureSchedule.collectionName)
        .doc(scheduleId);
    final preOrderRef = _internalFirestore
        .collection(PreOrder.collectionName)
        .doc(NihongStoreAssignmentRules.documentId(currentOrder.id));
    final totalKg = NihongStoreAssignmentRules.estimateWeightKg(currentOrder);

    final creation = await _internalFirestore.runTransaction((
      transaction,
    ) async {
      final scheduleSnapshot = await transaction.get(scheduleRef);
      final preOrderSnapshot = await transaction.get(preOrderRef);
      final customerSnapshot = newCustomerRef == null
          ? null
          : await transaction.get(newCustomerRef);

      if (!scheduleSnapshot.exists) {
        throw StateError('Jadwal keberangkatan tidak ditemukan.');
      }
      final schedule = DepartureSchedule.fromFirestore(scheduleSnapshot);
      if (preOrderSnapshot.exists) {
        final existing = preOrderSnapshot.data() ?? const <String, dynamic>{};
        final existingOrderId = existing['nihongStoreOrderId']?.toString();
        final existingScheduleId = existing['idJadwal']?.toString();
        if (existingOrderId != currentOrder.id ||
            existingScheduleId != scheduleId) {
          throw StateError(
            'Booking NihongStore ini sudah terhubung ke jadwal lain. Muat ulang inbox.',
          );
        }
        return (
          schedule: schedule,
          wasCreated: false,
          totalKg: FirestoreMapper.number(
            existing['totalKg'],
            fallback: totalKg,
          ),
        );
      }

      if (schedule.status != 'Open') {
        throw StateError('Jadwal ini sudah tidak terbuka. Pilih jadwal lain.');
      }
      final remainingKg = schedule.slotBeratKg - schedule.beratTerpakai;
      if (totalKg > remainingKg + 0.0001) {
        throw StateError(
          'Kapasitas jadwal tersisa ${remainingKg.toStringAsFixed(2)} kg, sedangkan pesanan memerlukan ${totalKg.toStringAsFixed(2)} kg.',
        );
      }

      final preOrder = PreOrder(
        id: preOrderRef.id,
        idJadwal: scheduleId,
        namaJastiper: schedule.namaJastiper,
        rute: schedule.rute,
        tanggalBerangkat: schedule.tanggalBerangkat,
        idPelanggan: resolvedCustomerId,
        namaPelanggan: currentOrder.namaPelanggan.trim(),
        noTelponPelanggan: currentOrder.noTelponPelanggan.trim(),
        pic: '',
        items: NihongStoreAssignmentRules.toPreOrderItems(currentOrder),
        totalKg: totalKg,
        status: 'Pending',
        catatan: _assignmentNote(currentOrder),
        nihongStoreOrderId: currentOrder.id,
        nihongStoreOrderNo: currentOrder.no.isEmpty
            ? currentOrder.id
            : currentOrder.no,
      );
      final preOrderPayload = preOrder.toFirestore()
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp();

      if (newCustomerRef != null && customerSnapshot?.exists != true) {
        transaction.set(newCustomerRef, {
          'nama': currentOrder.namaPelanggan.trim(),
          'telpon': currentOrder.noTelponPelanggan.trim(),
          'alamat': currentOrder.alamatPelanggan?.trim() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(preOrderRef, preOrderPayload);
      transaction.update(scheduleRef, {
        'beratTerpakai': FieldValue.increment(totalKg),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return (schedule: schedule, wasCreated: true, totalKg: totalKg);
    });

    final formattedDate = SafeCalendarDate.formatFullIndonesian(
      creation.schedule.tanggalBerangkat,
    );
    final assignmentResult = NihongStoreAssignmentResult(
      preOrderId: preOrderRef.id,
      scheduleId: scheduleId,
      customerId: resolvedCustomerId,
      scheduleRoute: creation.schedule.rute,
      formattedDepartureDate: formattedDate.isEmpty
          ? creation.schedule.tanggalBerangkat
          : formattedDate,
      totalKg: creation.totalKg,
      wasCreated: creation.wasCreated,
    );

    try {
      await _syncStoreOrderAssignment(
        storeOrderRef: storeOrderRef,
        assignment: assignmentResult,
      );
    } on StateError {
      if (creation.wasCreated) {
        try {
          await _rollbackUnlinkedPreOrder(
            preOrderRef: preOrderRef,
            scheduleRef: scheduleRef,
            orderId: currentOrder.id,
            scheduleId: scheduleId,
          );
        } on Object {
          // Keep the original status conflict visible; a later retry is idempotent.
        }
      }
      rethrow;
    } on FirebaseException catch (error) {
      throw NihongStoreAssignmentSyncException(
        preOrderId: preOrderRef.id,
        message:
            'Booking sudah dibuat, tetapi status NihongStore belum tersinkron. Ulangi penjadwalan pesanan yang sama untuk melanjutkan sinkronisasi (${error.code}).',
      );
    }

    return assignmentResult;
  }

  Future<String> _resolveCustomerId(NihongStoreOrder order) async {
    final existingId = order.idPelanggan?.trim();
    if (existingId?.isNotEmpty ?? false) return existingId!;

    final customers = _internalFirestore.collection(Customer.collectionName);
    final phone = order.noTelponPelanggan.trim();
    if (phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneVariants = <String>{phone};
      if (digits.isNotEmpty) {
        phoneVariants.add(digits);
        if (digits.startsWith('0')) {
          phoneVariants
            ..add('62${digits.substring(1)}')
            ..add('+62${digits.substring(1)}');
        } else if (digits.startsWith('62')) {
          phoneVariants
            ..add('0${digits.substring(2)}')
            ..add('+$digits');
        }
      }
      for (final value in phoneVariants) {
        final result = await customers
            .where('telpon', isEqualTo: value)
            .limit(1)
            .get();
        if (result.docs.isNotEmpty) return result.docs.first.id;
      }
    }

    final name = order.namaPelanggan.trim();
    if (name.isNotEmpty) {
      final result = await customers
          .where('nama', isEqualTo: name)
          .limit(1)
          .get();
      if (result.docs.isNotEmpty) return result.docs.first.id;
    }
    return '';
  }

  Future<void> _syncStoreOrderAssignment({
    required DocumentReference<Map<String, dynamic>> storeOrderRef,
    required NihongStoreAssignmentResult assignment,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(storeOrderRef);
      if (!snapshot.exists) {
        throw StateError(
          'Pesanan NihongStore tidak ditemukan. Muat ulang inbox.',
        );
      }
      final data = snapshot.data() ?? const <String, dynamic>{};
      final currentStatus = data['status']?.toString() ?? 'inbox';
      final currentPreOrderId = data['assignedPreOrderId']?.toString();
      final currentScheduleId = data['assignedScheduleId']?.toString();
      if (currentStatus == 'assigned' &&
          currentPreOrderId == assignment.preOrderId &&
          currentScheduleId == assignment.scheduleId) {
        return;
      }
      if (currentStatus != 'inbox') {
        throw StateError(
          'Status pesanan berubah saat dijadwalkan. Muat ulang inbox sebelum mencoba lagi.',
        );
      }

      final timeline = _timelineFrom(data['timeline']);
      final note =
          'Pesanan telah masuk ke Jadwal Handcarry ${assignment.scheduleRoute} '
          '(Keberangkatan: ${assignment.formattedDepartureDate}) oleh tim Nihong Jastip.';
      transaction.update(storeOrderRef, {
        'status': 'assigned',
        'displayStatus': 'Dijadwalkan Handcarry',
        'paymentStatus': 'DP Terverifikasi',
        'assignedScheduleId': assignment.scheduleId,
        'assignedScheduleRoute': assignment.scheduleRoute,
        'assignedScheduleDate': assignment.formattedDepartureDate,
        'assignedPreOrderId': assignment.preOrderId,
        'idPelanggan': assignment.customerId,
        'timeline': [
          ...timeline,
          {
            'status': 'Dijadwalkan Handcarry',
            'note': note,
            'at': DateTime.now().toIso8601String(),
          },
        ],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<void> _rollbackUnlinkedPreOrder({
    required DocumentReference<Map<String, dynamic>> preOrderRef,
    required DocumentReference<Map<String, dynamic>> scheduleRef,
    required String orderId,
    required String scheduleId,
  }) async {
    await _internalFirestore.runTransaction((transaction) async {
      final preOrderSnapshot = await transaction.get(preOrderRef);
      final scheduleSnapshot = await transaction.get(scheduleRef);
      if (!preOrderSnapshot.exists || !scheduleSnapshot.exists) return;
      final data = preOrderSnapshot.data() ?? const <String, dynamic>{};
      if (data['nihongStoreOrderId']?.toString() != orderId ||
          data['idJadwal']?.toString() != scheduleId ||
          data['status'] != 'Pending' ||
          data['convertedOrderId'] != null) {
        return;
      }
      final totalKg = FirestoreMapper.number(data['totalKg']);
      transaction.delete(preOrderRef);
      transaction.update(scheduleRef, {
        'beratTerpakai': FieldValue.increment(-totalKg),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String _assignmentNote(NihongStoreOrder order) => [
    '[NihongStore ${order.no.isEmpty ? order.id : order.no}]',
    if (order.catatan?.trim().isNotEmpty ?? false) order.catatan!.trim(),
  ].join(' ');

  List<Map<String, dynamic>> _timelineFrom(Object? value) {
    if (value is! Iterable) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}
