import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pre_order_data_source.dart';
import 'models/pre_order.dart';

final preOrderRepositoryProvider = Provider<PreOrderRepository>(
  (ref) => PreOrderRepository(ref.watch(preOrderDataSourceProvider)),
);

class PreOrderRepository {
  const PreOrderRepository(this._dataSource);

  final PreOrderDataSource _dataSource;

  Stream<PreOrderQuerySnapshot> watchPreOrders({required int limitCount}) =>
      _dataSource.watchPreOrders(limitCount: limitCount);

  Future<String> createPreOrder(PreOrder preOrder) =>
      _dataSource.createPreOrder(preOrder);

  Future<void> updatePreOrder(PreOrder preOrder) =>
      _dataSource.updatePreOrder(preOrder);

  Future<void> setItemChecked(String id, int itemIndex, bool checked) =>
      _dataSource.setItemChecked(id, itemIndex, checked);

  Future<void> deletePreOrder(String id) => _dataSource.deletePreOrder(id);

  Future<void> cancelNihongStorePreOrder(String id, {String? reason}) =>
      _dataSource.cancelNihongStorePreOrder(id, reason: reason);

  Future<PreOrderConversionResult> convertPreOrderToOrder(
    String id, {
    required String orderDate,
  }) => _dataSource.convertPreOrderToOrder(id, orderDate: orderDate);
}
