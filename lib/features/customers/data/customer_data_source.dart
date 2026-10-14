import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/customer.dart';

class CustomerQuerySnapshot {
  const CustomerQuerySnapshot({
    required this.customers,
    required this.isFromCache,
    required this.lastDocument,
  });

  final List<Customer> customers;
  final bool isFromCache;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

abstract interface class CustomerDataSource {
  Stream<CustomerQuerySnapshot> watchFirstCustomers({required int limitCount});

  Future<CustomerQuerySnapshot> fetchCustomers({
    required DocumentSnapshot<Map<String, dynamic>> startAfterDocument,
    required int limitCount,
  });
}

final customerDataSourceProvider = Provider<CustomerDataSource>(
  (ref) => FirestoreCustomerDataSource(FirebaseFirestore.instance),
);

class FirestoreCustomerDataSource implements CustomerDataSource {
  const FirestoreCustomerDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  Query<Map<String, dynamic>> get _customersQuery =>
      _firestore.collection(Customer.collectionName).orderBy('nama');

  @override
  Stream<CustomerQuerySnapshot> watchFirstCustomers({
    required int limitCount,
  }) => _customersQuery
      .limit(limitCount)
      .snapshots(includeMetadataChanges: true)
      .map(_toCustomerQuerySnapshot);

  @override
  Future<CustomerQuerySnapshot> fetchCustomers({
    required DocumentSnapshot<Map<String, dynamic>> startAfterDocument,
    required int limitCount,
  }) async {
    final snapshot = await _customersQuery
        .startAfterDocument(startAfterDocument)
        .limit(limitCount)
        .get();
    return _toCustomerQuerySnapshot(snapshot);
  }

  CustomerQuerySnapshot _toCustomerQuerySnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final customers = snapshot.docs.map(Customer.fromFirestore).toList();

    return CustomerQuerySnapshot(
      customers: customers,
      isFromCache: snapshot.metadata.isFromCache,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }
}
