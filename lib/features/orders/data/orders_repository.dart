import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'orders_data_source.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref.watch(ordersDataSourceProvider)),
);

class OrdersRepository {
  const OrdersRepository(this._dataSource);

  final OrdersDataSource _dataSource;

  Stream<OrderQuerySnapshot> watchOrders() => _dataSource.watchOrders();
}
