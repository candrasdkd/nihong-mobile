import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'schedule_data_source.dart';
import 'models/departure_schedule_draft.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(scheduleDataSourceProvider)),
);

final scheduleDocumentProvider =
    StreamProvider.family<DepartureScheduleDocumentSnapshot, String>(
      (ref, id) => ref.watch(scheduleRepositoryProvider).watchSchedule(id),
    );

typedef SchedulePreOrdersRequest = ({String scheduleId, int limitCount});

final schedulePreOrdersProvider = StreamProvider.autoDispose
    .family<SchedulePreOrderQuerySnapshot, SchedulePreOrdersRequest>(
      (ref, request) => ref
          .watch(scheduleRepositoryProvider)
          .watchPreOrders(request.scheduleId, limitCount: request.limitCount),
    );

class ScheduleRepository {
  const ScheduleRepository(this._dataSource);

  final ScheduleDataSource _dataSource;

  Stream<DepartureScheduleQuerySnapshot> watchSchedules({
    required int limitCount,
  }) => _dataSource.watchSchedules(limitCount: limitCount);

  Stream<ScheduleJastiperQuerySnapshot> watchJastipers({
    required int limitCount,
  }) => _dataSource.watchJastipers(limitCount: limitCount);

  Stream<DepartureScheduleDocumentSnapshot> watchSchedule(String id) =>
      _dataSource.watchSchedule(id);

  Stream<SchedulePreOrderQuerySnapshot> watchPreOrders(
    String scheduleId, {
    required int limitCount,
  }) => _dataSource.watchPreOrders(scheduleId, limitCount: limitCount);

  Future<void> createSchedule(DepartureScheduleDraft draft) =>
      _dataSource.createSchedule(draft);

  Future<void> updateSchedule(String id, DepartureScheduleDraft draft) =>
      _dataSource.updateSchedule(id, draft);
}
