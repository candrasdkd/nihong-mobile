import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nihong_store_inbox_data_source.dart';
import 'models/nihong_store_order.dart';

final nihongStoreInboxRepositoryProvider = Provider<NihongStoreInboxRepository>(
  (ref) =>
      NihongStoreInboxRepository(ref.watch(nihongStoreInboxDataSourceProvider)),
);

class NihongStoreInboxRepository {
  const NihongStoreInboxRepository(this._dataSource);

  final NihongStoreInboxDataSource _dataSource;

  Stream<NihongStoreInboxSnapshot> watchOrders({required int limitCount}) =>
      _dataSource.watchOrders(limitCount: limitCount);

  Future<NihongStoreOrder> updateItemAvailability({
    required String orderId,
    required int itemIndex,
    required String availability,
  }) => _dataSource.updateItemAvailability(
    orderId: orderId,
    itemIndex: itemIndex,
    availability: availability,
  );

  Future<void> rejectInboxOrder({required String orderId, String? reason}) =>
      _dataSource.rejectInboxOrder(orderId: orderId, reason: reason);

  Future<NihongStoreAssignmentResult> assignOrderToSchedule({
    required NihongStoreOrder order,
    required String scheduleId,
  }) => _dataSource.assignOrderToSchedule(order: order, scheduleId: scheduleId);
}
