import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/customer.dart';

class CustomerQuerySnapshot {
  const CustomerQuerySnapshot({
    required this.customers,
    required this.isFromCache,
  });

  final List<Customer> customers;
  final bool isFromCache;
}

abstract interface class CustomerDataSource {
  Stream<CustomerQuerySnapshot> watchCustomers();
}

final customerDataSourceProvider = Provider<CustomerDataSource>(
  (ref) => FirestoreCustomerDataSource(FirebaseFirestore.instance),
);

class FirestoreCustomerDataSource implements CustomerDataSource {
  const FirestoreCustomerDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<CustomerQuerySnapshot> watchCustomers() => _firestore
      .collection(Customer.collectionName)
      .orderBy('nama')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => CustomerQuerySnapshot(
          customers: snapshot.docs.map(Customer.fromFirestore).toList(),
          isFromCache: snapshot.metadata.isFromCache,
        ),
      );
}
