import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/order_doc.dart';

class OrderQuerySnapshot {
  const OrderQuerySnapshot({
    required this.orders,
    required this.isFromCache,
    required this.lastDocument,
  });

  final List<OrderDoc> orders;
  final bool isFromCache;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

abstract interface class OrdersDataSource {
  Stream<OrderQuerySnapshot> watchOrders({required int limitCount});

  Future<OrderQuerySnapshot> searchOrdersByCustomerNamePrefix({
    required String prefix,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    required int limitCount,
  });
}

final ordersDataSourceProvider = Provider<OrdersDataSource>(
  (ref) => FirestoreOrdersDataSource(FirebaseFirestore.instance),
);

class FirestoreOrdersDataSource implements OrdersDataSource {
  const FirestoreOrdersDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<OrderQuerySnapshot> watchOrders({required int limitCount}) =>
      _firestore
          .collection(OrderDoc.collectionName)
          .orderBy('tanggal', descending: true)
          .limit(limitCount)
          .snapshots(includeMetadataChanges: true)
          .map(_toOrderQuerySnapshot);

  @override
  Future<OrderQuerySnapshot> searchOrdersByCustomerNamePrefix({
    required String prefix,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    required int limitCount,
  }) async {
    var query = _firestore
        .collection(OrderDoc.collectionName)
        .orderBy('namaPelanggan')
        .startAt([prefix])
        .endAt(['$prefix\uf8ff']);
    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.limit(limitCount).get();
    return _toOrderQuerySnapshot(snapshot);
  }

  OrderQuerySnapshot _toOrderQuerySnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => OrderQuerySnapshot(
    orders: snapshot.docs.map(OrderDoc.fromFirestore).toList(),
    isFromCache: snapshot.metadata.isFromCache,
    lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
  );
}
