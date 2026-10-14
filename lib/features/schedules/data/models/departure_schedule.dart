import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firestore/firestore_mapper.dart';

class DepartureSchedule {
  const DepartureSchedule({
    required this.id,
    required this.idJastiper,
    required this.namaJastiper,
    required this.rute,
    required this.tanggalBerangkat,
    required this.tanggalLastDrop,
    required this.slotBeratKg,
    required this.beratTerpakai,
    required this.status,
    required this.hargaFeeJastiper,
    this.catatan,
    this.createdAt,
    this.updatedAt,
  });

  static const collectionName = 'departure_schedules';

  final String id;
  final String idJastiper;
  final String namaJastiper;
  final String rute;

  /// Calendar dates stay as their original YYYY-MM-DD strings in Firestore.
  final String tanggalBerangkat;
  final String tanggalLastDrop;
  final double slotBeratKg;
  final double beratTerpakai;

  /// Kept as String to preserve unrecognized legacy status values.
  final String status;
  final String? catatan;
  final double hargaFeeJastiper;
  final Object? createdAt;
  final Object? updatedAt;

  factory DepartureSchedule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => DepartureSchedule.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory DepartureSchedule.fromMap(Map<String, dynamic> data, {String? id}) =>
      DepartureSchedule(
        id: id ?? FirestoreMapper.string(data['id']),
        idJastiper: FirestoreMapper.string(data['idJastiper']),
        namaJastiper: FirestoreMapper.string(data['namaJastiper']),
        rute: FirestoreMapper.string(data['rute']),
        tanggalBerangkat: FirestoreMapper.string(data['tanggalBerangkat']),
        tanggalLastDrop: FirestoreMapper.string(data['tanggalLastDrop']),
        slotBeratKg: FirestoreMapper.number(data['slotBeratKg']),
        beratTerpakai: FirestoreMapper.number(data['beratTerpakai']),
        status: FirestoreMapper.string(data['status'], fallback: 'Open'),
        catatan: FirestoreMapper.nullableString(data['catatan']),
        hargaFeeJastiper: FirestoreMapper.number(data['hargaFeeJastiper']),
        createdAt: data['createdAt'],
        updatedAt: data['updatedAt'],
      );

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'idJastiper': idJastiper,
      'namaJastiper': namaJastiper,
      'rute': rute,
      'tanggalBerangkat': tanggalBerangkat,
      'tanggalLastDrop': tanggalLastDrop,
      'slotBeratKg': slotBeratKg,
      'beratTerpakai': beratTerpakai,
      'status': status,
      'hargaFeeJastiper': hargaFeeJastiper,
    };
    FirestoreMapper.putOptional(data, 'catatan', catatan);
    FirestoreMapper.putOptional(data, 'createdAt', createdAt);
    FirestoreMapper.putOptional(data, 'updatedAt', updatedAt);
    return data;
  }
}
