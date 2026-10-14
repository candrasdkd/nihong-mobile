import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'orders_data_source.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref.watch(ordersDataSourceProvider)),
);

class OrdersRepository {
  const OrdersRepository(this._dataSource);

  final OrdersDataSource _dataSource;

  Stream<OrderQuerySnapshot> watchOrders({required int limitCount}) =>
      _dataSource.watchOrders(limitCount: limitCount);

  Future<OrderQuerySnapshot> searchOrdersByCustomerNamePrefix({
    required String prefix,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    required int limitCount,
  }) => _dataSource.searchOrdersByCustomerNamePrefix(
    prefix: prefix,
    startAfterDocument: startAfterDocument,
    limitCount: limitCount,
  );
}
