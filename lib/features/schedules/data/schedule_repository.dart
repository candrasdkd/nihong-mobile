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

final schedulePreOrdersProvider =
    StreamProvider.family<SchedulePreOrderQuerySnapshot, String>(
      (ref, scheduleId) =>
          ref.watch(scheduleRepositoryProvider).watchPreOrders(scheduleId),
    );

class ScheduleRepository {
  const ScheduleRepository(this._dataSource);

  final ScheduleDataSource _dataSource;

  Stream<DepartureScheduleQuerySnapshot> watchSchedules() =>
      _dataSource.watchSchedules();

  Stream<ScheduleJastiperQuerySnapshot> watchJastipers() =>
      _dataSource.watchJastipers();

  Stream<DepartureScheduleDocumentSnapshot> watchSchedule(String id) =>
      _dataSource.watchSchedule(id);

  Stream<SchedulePreOrderQuerySnapshot> watchPreOrders(String scheduleId) =>
      _dataSource.watchPreOrders(scheduleId);

  Future<void> createSchedule(DepartureScheduleDraft draft) =>
      _dataSource.createSchedule(draft);

  Future<void> updateSchedule(String id, DepartureScheduleDraft draft) =>
      _dataSource.updateSchedule(id, draft);
}
