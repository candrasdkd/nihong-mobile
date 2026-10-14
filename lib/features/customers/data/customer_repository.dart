import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_data_source.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(customerDataSourceProvider)),
);

class CustomerRepository {
  const CustomerRepository(this._dataSource);

  final CustomerDataSource _dataSource;

  Stream<CustomerQuerySnapshot> watchFirstCustomers({
    required int limitCount,
  }) => _dataSource.watchFirstCustomers(limitCount: limitCount);

  Future<CustomerQuerySnapshot> searchCustomersByNamePrefix({
    required String prefix,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    required int limitCount,
  }) => _dataSource.searchCustomersByNamePrefix(
    prefix: prefix,
    startAfterDocument: startAfterDocument,
    limitCount: limitCount,
  );

  Future<CustomerQuerySnapshot> fetchCustomers({
    required DocumentSnapshot<Map<String, dynamic>> startAfterDocument,
    required int limitCount,
  }) => _dataSource.fetchCustomers(
    startAfterDocument: startAfterDocument,
    limitCount: limitCount,
  );
}
