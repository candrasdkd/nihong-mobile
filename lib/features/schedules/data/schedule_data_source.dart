import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pre_orders/data/models/pre_order.dart';
import 'models/departure_schedule.dart';
import 'models/departure_schedule_draft.dart';
import 'models/schedule_jastiper.dart';

class DepartureScheduleQuerySnapshot {
  const DepartureScheduleQuerySnapshot({
    required this.schedules,
    required this.isFromCache,
  });

  final List<DepartureSchedule> schedules;
  final bool isFromCache;
}

class ScheduleJastiperQuerySnapshot {
  const ScheduleJastiperQuerySnapshot({
    required this.jastipers,
    required this.isFromCache,
  });

  final List<ScheduleJastiper> jastipers;
  final bool isFromCache;
}

class DepartureScheduleDocumentSnapshot {
  const DepartureScheduleDocumentSnapshot({
    required this.schedule,
    required this.isFromCache,
  });

  final DepartureSchedule? schedule;
  final bool isFromCache;
}

class SchedulePreOrderQuerySnapshot {
  const SchedulePreOrderQuerySnapshot({
    required this.preOrders,
    required this.isFromCache,
  });

  final List<PreOrder> preOrders;
  final bool isFromCache;
}

abstract interface class ScheduleDataSource {
  Stream<DepartureScheduleQuerySnapshot> watchSchedules();

  Stream<ScheduleJastiperQuerySnapshot> watchJastipers();

  Stream<DepartureScheduleDocumentSnapshot> watchSchedule(String id);

  Stream<SchedulePreOrderQuerySnapshot> watchPreOrders(String scheduleId);

  Future<void> createSchedule(DepartureScheduleDraft draft);

  Future<void> updateSchedule(String id, DepartureScheduleDraft draft);
}

final scheduleDataSourceProvider = Provider<ScheduleDataSource>(
  (ref) => FirestoreScheduleDataSource(FirebaseFirestore.instance),
);

class FirestoreScheduleDataSource implements ScheduleDataSource {
  const FirestoreScheduleDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<DepartureScheduleQuerySnapshot> watchSchedules() => _firestore
      .collection(DepartureSchedule.collectionName)
      .orderBy('tanggalBerangkat')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => DepartureScheduleQuerySnapshot(
          schedules: snapshot.docs
              .map(DepartureSchedule.fromFirestore)
              .toList(),
          isFromCache: snapshot.metadata.isFromCache,
        ),
      );

  @override
  Stream<ScheduleJastiperQuerySnapshot> watchJastipers() => _firestore
      .collection('jastipers')
      .orderBy('nama')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => ScheduleJastiperQuerySnapshot(
          jastipers: snapshot.docs.map(ScheduleJastiper.fromFirestore).toList(),
          isFromCache: snapshot.metadata.isFromCache,
        ),
      );

  @override
  Stream<DepartureScheduleDocumentSnapshot> watchSchedule(String id) =>
      _firestore
          .collection(DepartureSchedule.collectionName)
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => DepartureScheduleDocumentSnapshot(
              schedule: snapshot.exists
                  ? DepartureSchedule.fromFirestore(snapshot)
                  : null,
              isFromCache: snapshot.metadata.isFromCache,
            ),
          );

  @override
  Stream<SchedulePreOrderQuerySnapshot> watchPreOrders(String scheduleId) =>
      _firestore
          .collection(PreOrder.collectionName)
          .where('idJadwal', isEqualTo: scheduleId)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => SchedulePreOrderQuerySnapshot(
              preOrders: snapshot.docs.map(PreOrder.fromFirestore).toList(),
              isFromCache: snapshot.metadata.isFromCache,
            ),
          );

  @override
  Future<void> createSchedule(DepartureScheduleDraft draft) async {
    final timestamp = FieldValue.serverTimestamp();
    await _firestore.collection(DepartureSchedule.collectionName).add({
      ...draft.toFirestore(),
      'beratTerpakai': 0,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
  }

  @override
  Future<void> updateSchedule(String id, DepartureScheduleDraft draft) =>
      _firestore.collection(DepartureSchedule.collectionName).doc(id).update({
        ...draft.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
