import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_data_source.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(customerDataSourceProvider)),
);

class CustomerRepository {
  const CustomerRepository(this._dataSource);

  final CustomerDataSource _dataSource;

  Stream<CustomerQuerySnapshot> watchCustomers() =>
      _dataSource.watchCustomers();
}
