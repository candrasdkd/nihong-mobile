import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firestore/firestore_mapper.dart';

class ScheduleJastiper {
  const ScheduleJastiper({required this.id, required this.nama});

  factory ScheduleJastiper.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => ScheduleJastiper.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory ScheduleJastiper.fromMap(Map<String, dynamic> data, {String? id}) =>
      ScheduleJastiper(
        id: id ?? FirestoreMapper.string(data['id']),
        nama: FirestoreMapper.string(data['nama']),
      );

  final String id;
  final String nama;
}
