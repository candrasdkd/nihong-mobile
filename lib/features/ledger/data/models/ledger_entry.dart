import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firestore/firestore_mapper.dart';

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.tanggal,
    required this.tipe,
    required this.jumlah,
    this.kategori,
    this.keterangan,
    this.metode,
    this.rekening,
    this.catatan,
    this.revision,
    this.capitalAdvanceId,
    this.capitalRole,
    this.voidedAt,
    this.voidedBy,
    this.createdAt,
    this.updatedAt,
  });

  static const collectionName = 'ledger';

  final String id;
  final String tanggal;
  final String tipe;
  final String? kategori;
  final String? keterangan;
  final String? metode;
  final String? rekening;
  final double jumlah;
  final String? catatan;
  final Object? revision;
  final String? capitalAdvanceId;
  final String? capitalRole;
  final Object? voidedAt;
  final String? voidedBy;
  final Object? createdAt;
  final Object? updatedAt;

  factory LedgerEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => LedgerEntry.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory LedgerEntry.fromMap(Map<String, dynamic> data, {String? id}) =>
      LedgerEntry(
        id: id ?? FirestoreMapper.string(data['id']),
        tanggal: FirestoreMapper.string(data['tanggal']),
        tipe: FirestoreMapper.string(data['tipe']),
        kategori: FirestoreMapper.nullableString(data['kategori']),
        keterangan: FirestoreMapper.nullableString(data['keterangan']),
        metode: FirestoreMapper.nullableString(data['metode']),
        rekening: FirestoreMapper.nullableString(data['rekening']),
        jumlah: FirestoreMapper.number(data['jumlah']),
        catatan: FirestoreMapper.nullableString(data['catatan']),
        revision: data['revision'],
        capitalAdvanceId: FirestoreMapper.nullableString(
          data['capitalAdvanceId'],
        ),
        capitalRole: FirestoreMapper.nullableString(data['capitalRole']),
        voidedAt: data['voidedAt'],
        voidedBy: FirestoreMapper.nullableString(data['voidedBy']),
        createdAt: data['createdAt'],
        updatedAt: data['updatedAt'],
      );

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'tanggal': tanggal,
      'tipe': tipe,
      'jumlah': jumlah,
    };
    FirestoreMapper.putOptional(data, 'kategori', kategori);
    FirestoreMapper.putOptional(data, 'keterangan', keterangan);
    FirestoreMapper.putOptional(data, 'metode', metode);
    FirestoreMapper.putOptional(data, 'rekening', rekening);
    FirestoreMapper.putOptional(data, 'catatan', catatan);
    FirestoreMapper.putOptional(data, 'revision', revision);
    FirestoreMapper.putOptional(data, 'capitalAdvanceId', capitalAdvanceId);
    FirestoreMapper.putOptional(data, 'capitalRole', capitalRole);
    FirestoreMapper.putOptional(data, 'voidedAt', voidedAt);
    FirestoreMapper.putOptional(data, 'voidedBy', voidedBy);
    FirestoreMapper.putOptional(data, 'createdAt', createdAt);
    FirestoreMapper.putOptional(data, 'updatedAt', updatedAt);
    return data;
  }
}
