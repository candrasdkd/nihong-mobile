import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/order_doc.dart';

class OrderQuerySnapshot {
  const OrderQuerySnapshot({required this.orders, required this.isFromCache});

  final List<OrderDoc> orders;
  final bool isFromCache;
}

abstract interface class OrdersDataSource {
  Stream<OrderQuerySnapshot> watchOrders();
}

final ordersDataSourceProvider = Provider<OrdersDataSource>(
  (ref) => FirestoreOrdersDataSource(FirebaseFirestore.instance),
);

class FirestoreOrdersDataSource implements OrdersDataSource {
  const FirestoreOrdersDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<OrderQuerySnapshot> watchOrders() => _firestore
      .collection(OrderDoc.collectionName)
      .orderBy('tanggal', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => OrderQuerySnapshot(
          orders: snapshot.docs.map(OrderDoc.fromFirestore).toList(),
          isFromCache: snapshot.metadata.isFromCache,
        ),
      );
}
