import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/nihong_store_auth_repository.dart';
import '../../../core/firestore/firestore_mapper.dart';
import 'models/pre_order.dart';

class PreOrderQuerySnapshot {
  const PreOrderQuerySnapshot({
    required this.preOrders,
    required this.isFromCache,
  });

  final List<PreOrder> preOrders;
  final bool isFromCache;
}

class PreOrderConversionResult {
  const PreOrderConversionResult({
    required this.orderId,
    required this.wasCreated,
  });

  final String orderId;
  final bool wasCreated;
}

abstract interface class PreOrderDataSource {
  Stream<PreOrderQuerySnapshot> watchPreOrders();

  Future<String> createPreOrder(PreOrder preOrder);

  Future<void> updatePreOrder(PreOrder preOrder);

  Future<void> setItemChecked(String id, int itemIndex, bool checked);

  Future<void> deletePreOrder(String id);

  Future<void> cancelNihongStorePreOrder(String id, {String? reason});

  Future<PreOrderConversionResult> convertPreOrderToOrder(
    String id, {
    required String orderDate,
  });
}

final preOrderDataSourceProvider = Provider<PreOrderDataSource>(
  (ref) => FirestorePreOrderDataSource(
    FirebaseFirestore.instance,
    ref.watch(nihongStoreFirestoreProvider),
    ref.watch(nihongStoreAuthRepositoryProvider),
  ),
);

class FirestorePreOrderDataSource implements PreOrderDataSource {
  const FirestorePreOrderDataSource(
    this._firestore,
    this._storeFirestore,
    this._storeAuth,
  );

  final FirebaseFirestore _firestore;
  final FirebaseFirestore _storeFirestore;
  final NihongStoreAuthRepository _storeAuth;

  @override
  Stream<PreOrderQuerySnapshot> watchPreOrders() => _firestore
      .collection(PreOrder.collectionName)
      .orderBy('createdAt', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => PreOrderQuerySnapshot(
          preOrders: snapshot.docs.map(PreOrder.fromFirestore).toList(),
          isFromCache: snapshot.metadata.isFromCache,
        ),
      );

  @override
  Future<String> createPreOrder(PreOrder preOrder) async {
    _validateWeight(preOrder.totalKg);
    if (preOrder.idJadwal.isEmpty) {
      throw StateError('Pilih jadwal keberangkatan.');
    }

    final scheduleRef = _firestore
        .collection('departure_schedules')
        .doc(preOrder.idJadwal);
    final preOrderRef = _firestore.collection(PreOrder.collectionName).doc();
    final payload = preOrder.toFirestore()
      ..remove('createdAt')
      ..remove('updatedAt')
      ..remove('convertedOrderId')
      ..['status'] = 'Pending'
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final scheduleSnapshot = await transaction.get(scheduleRef);
      if (!scheduleSnapshot.exists) {
        throw StateError('Jadwal keberangkatan tidak ditemukan.');
      }
      transaction.set(preOrderRef, payload);
      transaction.update(scheduleRef, {
        'beratTerpakai': FieldValue.increment(preOrder.totalKg),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return preOrderRef.id;
  }

  @override
  Future<void> updatePreOrder(PreOrder preOrder) async {
    _validateWeight(preOrder.totalKg);
    if (preOrder.id.isEmpty || preOrder.idJadwal.isEmpty) {
      throw StateError('Data booking tidak lengkap.');
    }

    final preOrderRef = _firestore
        .collection(PreOrder.collectionName)
        .doc(preOrder.id);
    final newScheduleRef = _firestore
        .collection('departure_schedules')
        .doc(preOrder.idJadwal);

    await _firestore.runTransaction((transaction) async {
      final preOrderSnapshot = await transaction.get(preOrderRef);
      if (!preOrderSnapshot.exists) {
        throw StateError('Booking tidak ditemukan.');
      }
      final current = preOrderSnapshot.data() ?? const <String, dynamic>{};
      if (current['status'] == 'Selesai' ||
          current['convertedOrderId'] != null) {
        throw StateError('Booking yang sudah dikonversi tidak dapat diubah.');
      }
      if (current['status'] == 'Dibatalkan' ||
          current['nihongStoreCancellationState'] == 'pending') {
        throw StateError('Booking yang dibatalkan tidak dapat diubah.');
      }

      final oldScheduleId = FirestoreMapper.string(current['idJadwal']);
      if (oldScheduleId.isEmpty) {
        throw StateError('Jadwal booking lama tidak valid.');
      }
      final oldWeight = FirestoreMapper.number(current['totalKg']);
      final oldScheduleRef = _firestore
          .collection('departure_schedules')
          .doc(oldScheduleId);
      final oldScheduleSnapshot = await transaction.get(oldScheduleRef);
      final newScheduleSnapshot = oldScheduleId == preOrder.idJadwal
          ? oldScheduleSnapshot
          : await transaction.get(newScheduleRef);
      if (!oldScheduleSnapshot.exists || !newScheduleSnapshot.exists) {
        throw StateError('Jadwal booking tidak ditemukan.');
      }

      final update = preOrder.toFirestore()
        ..remove('createdAt')
        ..['updatedAt'] = FieldValue.serverTimestamp();
      transaction.update(preOrderRef, update);

      if (oldScheduleId == preOrder.idJadwal) {
        final delta = preOrder.totalKg - oldWeight;
        if (delta != 0) {
          transaction.update(oldScheduleRef, {
            'beratTerpakai': FieldValue.increment(delta),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        transaction.update(oldScheduleRef, {
          'beratTerpakai': FieldValue.increment(-oldWeight),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(newScheduleRef, {
          'beratTerpakai': FieldValue.increment(preOrder.totalKg),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<void> setItemChecked(String id, int itemIndex, bool checked) async {
    final preOrderRef = _firestore.collection(PreOrder.collectionName).doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(preOrderRef);
      if (!snapshot.exists) throw StateError('Booking tidak ditemukan.');
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] == 'Selesai' || data['convertedOrderId'] != null) {
        throw StateError('Checklist booking yang sudah dikonversi terkunci.');
      }
      if (data['status'] == 'Dibatalkan' ||
          data['nihongStoreCancellationState'] == 'pending') {
        throw StateError('Checklist booking yang dibatalkan terkunci.');
      }
      final items = FirestoreMapper.mapList(data['items']);
      if (itemIndex < 0 || itemIndex >= items.length) {
        throw StateError('Barang tidak ditemukan. Muat ulang booking.');
      }
      items[itemIndex] = {...items[itemIndex], 'checked': checked};
      transaction.update(preOrderRef, {
        'items': items,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  @override
  Future<void> deletePreOrder(String id) async {
    final preOrderRef = _firestore.collection(PreOrder.collectionName).doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(preOrderRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] == 'Selesai' || data['convertedOrderId'] != null) {
        throw StateError('Booking yang sudah dikonversi tidak dapat dihapus.');
      }
      if (FirestoreMapper.string(data['nihongStoreOrderId']).isNotEmpty) {
        throw StateError(
          'Booking NihongStore harus dibatalkan melalui alur sinkronisasi.',
        );
      }
      final scheduleId = FirestoreMapper.string(data['idJadwal']);
      final scheduleRef = _firestore
          .collection('departure_schedules')
          .doc(scheduleId);
      final scheduleSnapshot = await transaction.get(scheduleRef);
      if (!scheduleSnapshot.exists) {
        throw StateError('Jadwal booking tidak ditemukan.');
      }
      transaction.delete(preOrderRef);
      transaction.update(scheduleRef, {
        'beratTerpakai': FieldValue.increment(
          -FirestoreMapper.number(data['totalKg']),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> cancelNihongStorePreOrder(String id, {String? reason}) async {
    final cleanReason = reason?.trim() ?? '';
    final preOrderRef = _firestore.collection(PreOrder.collectionName).doc(id);
    final preparation = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(preOrderRef);
      if (!snapshot.exists) throw StateError('Booking tidak ditemukan.');
      final data = snapshot.data() ?? const <String, dynamic>{};
      final storeOrderId = FirestoreMapper.nullableString(
        data['nihongStoreOrderId'],
      );
      if (storeOrderId == null || storeOrderId.isEmpty) {
        throw StateError('Booking ini bukan pesanan NihongStore.');
      }
      if (data['status'] == 'Selesai' || data['convertedOrderId'] != null) {
        throw StateError(
          'Booking yang sudah dikonversi tidak dapat dibatalkan.',
        );
      }

      final syncPending = data['nihongStoreCancellationState'] == 'pending';
      if (data['status'] == 'Dibatalkan' && !syncPending) {
        return (
          storeOrderId: storeOrderId,
          shouldSync: false,
          reason: FirestoreMapper.string(data['nihongStoreCancellationReason']),
        );
      }

      if (!syncPending) {
        if (data['status'] != 'Pending') {
          throw StateError('Status booking tidak mendukung pembatalan.');
        }
        final scheduleId = FirestoreMapper.string(data['idJadwal']);
        if (scheduleId.isEmpty) {
          throw StateError('Jadwal booking tidak valid.');
        }
        final scheduleRef = _firestore
            .collection('departure_schedules')
            .doc(scheduleId);
        final scheduleSnapshot = await transaction.get(scheduleRef);
        if (!scheduleSnapshot.exists) {
          throw StateError('Jadwal booking tidak ditemukan.');
        }
        transaction.update(scheduleRef, {
          'beratTerpakai': FieldValue.increment(
            -FirestoreMapper.number(data['totalKg']),
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(preOrderRef, {
          'status': 'Dibatalkan',
          'nihongStoreCancellationState': 'pending',
          if (cleanReason.isNotEmpty)
            'nihongStoreCancellationReason': cleanReason,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      return (
        storeOrderId: storeOrderId,
        shouldSync: true,
        reason: syncPending
            ? FirestoreMapper.string(data['nihongStoreCancellationReason'])
            : cleanReason,
      );
    });

    if (!preparation.shouldSync) return;
    final user = _storeAuth.currentUser;
    if (user == null) {
      throw const NihongStoreAccessException(
        'Booking dibatalkan secara internal. Masuk ke NihongStore untuk menyinkronkan status pembatalan.',
      );
    }
    await _storeAuth.verifyAdminAccess(user);

    final storeOrderRef = _storeFirestore
        .collection('nihongstore_orders')
        .doc(preparation.storeOrderId);
    await _storeFirestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(storeOrderRef);
      if (!snapshot.exists) {
        throw StateError(
          'Booking dibatalkan secara internal, tetapi pesanan NihongStore tidak ditemukan untuk sinkronisasi.',
        );
      }
      final data = snapshot.data() ?? const <String, dynamic>{};
      final assignedPreOrderId = data['assignedPreOrderId']?.toString();
      final status = data['status']?.toString();
      if (status == 'rejected' &&
          data['displayStatus'] == 'Dibatalkan' &&
          assignedPreOrderId == id) {
        return;
      }
      if (status != 'assigned' || assignedPreOrderId != id) {
        throw StateError(
          'Booking dibatalkan secara internal, tetapi status pesanan NihongStore sudah berubah. Periksa pesanan sebelum mencoba ulang.',
        );
      }

      final timeline = FirestoreMapper.mapList(data['timeline']);
      final savedReason = preparation.reason;
      final note = savedReason.isEmpty
          ? 'Booking Nihong Jastip dibatalkan oleh admin.'
          : 'Booking Nihong Jastip dibatalkan: $savedReason';
      final update = <String, dynamic>{
        'status': 'rejected',
        'displayStatus': 'Dibatalkan',
        'timeline': [
          ...timeline,
          {
            'status': 'Dibatalkan',
            'note': note,
            'at': DateTime.now().toIso8601String(),
          },
        ],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (savedReason.isNotEmpty) {
        update['catatan'] = '[Ditolak: $savedReason]';
      }
      transaction.update(storeOrderRef, update);
    });

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(preOrderRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] != 'Dibatalkan' ||
          data['nihongStoreCancellationState'] != 'pending') {
        return;
      }
      transaction.update(preOrderRef, {
        'nihongStoreCancellationState': FieldValue.delete(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  @override
  Future<PreOrderConversionResult> convertPreOrderToOrder(
    String id, {
    required String orderDate,
  }) async {
    final preOrderRef = _firestore.collection(PreOrder.collectionName).doc(id);
    final orderRef = _firestore.collection('orders').doc();
    final summaryRef = _firestore
        .collection('orders_monthly_summaries')
        .doc(orderDate.substring(0, 7));
    final now = DateTime.now();
    final result = await _firestore.runTransaction((transaction) async {
      final preOrderSnapshot = await transaction.get(preOrderRef);
      if (!preOrderSnapshot.exists) {
        throw StateError('Booking tidak ditemukan.');
      }
      final data = preOrderSnapshot.data() ?? const <String, dynamic>{};
      final alreadyCreatedId = FirestoreMapper.nullableString(
        data['convertedOrderId'],
      );
      final storeOrderId = FirestoreMapper.nullableString(
        data['nihongStoreOrderId'],
      );
      if (alreadyCreatedId != null && alreadyCreatedId.isNotEmpty) {
        return (
          orderId: alreadyCreatedId,
          wasCreated: false,
          storeOrderId: storeOrderId,
        );
      }
      if (data['status'] == 'Selesai') {
        throw StateError(
          'Booking sudah selesai dan tidak memiliki ID pesanan.',
        );
      }
      if (data['status'] == 'Dibatalkan' ||
          data['nihongStoreCancellationState'] == 'pending') {
        throw StateError('Booking yang dibatalkan tidak dapat dikonversi.');
      }

      final items = FirestoreMapper.mapList(data['items']);
      final namaBarang = items
          .map((item) => FirestoreMapper.string(item['namaBarang']))
          .join('\n');
      final idPelanggan = FirestoreMapper.string(data['idPelanggan']);
      final namaPelanggan = FirestoreMapper.string(data['namaPelanggan']);
      final totalKg = FirestoreMapper.number(data['totalKg']);
      final totalPembayaran = 0.0;
      final totalKeuntungan = 0.0;
      final customerRef = idPelanggan.isEmpty
          ? null
          : _firestore.collection('customer').doc(idPelanggan);

      transaction.set(orderRef, {
        'no': 'PO-${now.millisecondsSinceEpoch}',
        'tanggal': orderDate,
        'idPelanggan': idPelanggan,
        'namaPelanggan': namaPelanggan,
        'namaBarang': namaBarang,
        'kategori': '',
        'pengiriman': FirestoreMapper.string(data['rute']),
        'jumlahKg': totalKg,
        'kgCeil': totalKg.ceilToDouble(),
        'hargaJastip': 0,
        'hargaJastipMarkup': 0,
        'hargaOngkir': 0,
        'hargaOngkirMarkup': 0,
        'totalPembayaran': totalPembayaran,
        'totalKeuntungan': totalKeuntungan,
        'status': 'Belum Membayar',
        'catatan': FirestoreMapper.string(data['catatan']),
        'revision': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _firestore.collection('metadata').doc('orders_revision'),
        {'revision': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      transaction.update(preOrderRef, {
        'status': 'Selesai',
        'items': items.map((item) => {...item, 'checked': true}).toList(),
        'convertedOrderId': orderRef.id,
        if (storeOrderId != null) 'nihongStoreStatusSyncState': 'pending',
        'updatedAt': now.millisecondsSinceEpoch,
      });
      transaction.set(summaryRef, {
        'revenueIdr': FieldValue.increment(totalPembayaran),
        'revenueJpy': FieldValue.increment(0),
        'profitIdr': FieldValue.increment(totalKeuntungan),
        'profitJpy': FieldValue.increment(0),
        'orderCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      if (customerRef != null) {
        transaction.set(customerRef, {
          'totalSpendIdr': FieldValue.increment(totalPembayaran),
          'totalSpendJpy': FieldValue.increment(0),
          'orderCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
      return (
        orderId: orderRef.id,
        wasCreated: true,
        storeOrderId: storeOrderId,
      );
    });

    if (result.storeOrderId != null) {
      await _syncStoreTimeline(result.storeOrderId!, result.orderId);
      await _markStoreStatusSynced(id, result.orderId);
    }
    return PreOrderConversionResult(
      orderId: result.orderId,
      wasCreated: result.wasCreated,
    );
  }

  Future<void> _syncStoreTimeline(String storeOrderId, String orderId) async {
    final user = _storeAuth.currentUser;
    if (user == null) {
      throw const NihongStoreAccessException(
        'Pesanan resmi sudah dibuat, tetapi sesi NihongStore tidak aktif untuk menyinkronkan status.',
      );
    }
    await _storeAuth.verifyAdminAccess(user);

    final orderRef = _storeFirestore
        .collection('nihongstore_orders')
        .doc(storeOrderId);
    await _storeFirestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) {
        throw StateError(
          'Pesanan resmi sudah dibuat, tetapi pesanan NihongStore tidak ditemukan untuk sinkronisasi.',
        );
      }
      final data = snapshot.data() ?? const <String, dynamic>{};
      final assignedOrderId = data['assignedOrderId']?.toString();
      if (assignedOrderId == orderId &&
          data['displayStatus'] == 'Diproses di Jepang') {
        return;
      }
      if (assignedOrderId != null &&
          assignedOrderId.isNotEmpty &&
          assignedOrderId != orderId) {
        throw StateError(
          'Status NihongStore sudah terhubung ke pesanan lain. Periksa kembali sebelum mencoba ulang.',
        );
      }

      final timeline = FirestoreMapper.mapList(data['timeline']);
      transaction.update(orderRef, {
        'displayStatus': 'Diproses di Jepang',
        'assignedOrderId': orderId,
        'timeline': [
          ...timeline,
          {
            'status': 'Diproses di Jepang',
            'note':
                'Booking telah dikonversi menjadi pesanan resmi dan sedang dibelanjakan oleh jastiper di Tokyo.',
            'at': DateTime.now().toIso8601String(),
          },
        ],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<void> _markStoreStatusSynced(String preOrderId, String orderId) async {
    final preOrderRef = _firestore
        .collection(PreOrder.collectionName)
        .doc(preOrderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(preOrderRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['convertedOrderId'] != orderId ||
          data['nihongStoreStatusSyncState'] != 'pending') {
        return;
      }
      transaction.update(preOrderRef, {
        'nihongStoreStatusSyncState': FieldValue.delete(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _validateWeight(double value) {
    if (!value.isFinite || value < 0) {
      throw StateError('Berat booking harus berupa angka nol atau lebih.');
    }
  }
}
