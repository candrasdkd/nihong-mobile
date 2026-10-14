import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firestore/firestore_mapper.dart';

class Customer {
  const Customer({
    required this.id,
    required this.nama,
    this.alamat,
    this.telpon,
    this.alamatPengirimanIndonesia,
    this.alamatPengirimanJepang,
    this.createdAt,
    this.updatedAt,
  });

  static const collectionName = 'customer';

  final String id;
  final String nama;
  final String? alamat;
  final String? telpon;
  final IndonesiaDeliveryAddress? alamatPengirimanIndonesia;
  final JapanDeliveryAddress? alamatPengirimanJepang;

  /// Kept in its original Firestore representation for lossless legacy writes.
  final Object? createdAt;
  final Object? updatedAt;

  factory Customer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => Customer.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory Customer.fromMap(Map<String, dynamic> data, {String? id}) {
    final indonesia = FirestoreMapper.map(data['alamatPengirimanIndonesia']);
    final jepang = FirestoreMapper.map(data['alamatPengirimanJepang']);

    return Customer(
      id: id ?? FirestoreMapper.string(data['id']),
      nama: FirestoreMapper.string(data['nama']),
      alamat: FirestoreMapper.nullableString(data['alamat']),
      telpon: FirestoreMapper.nullableString(data['telpon']),
      alamatPengirimanIndonesia: indonesia == null
          ? null
          : IndonesiaDeliveryAddress.fromMap(indonesia),
      alamatPengirimanJepang: jepang == null
          ? null
          : JapanDeliveryAddress.fromMap(jepang),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{'nama': nama};
    FirestoreMapper.putOptional(data, 'alamat', alamat);
    FirestoreMapper.putOptional(data, 'telpon', telpon);
    FirestoreMapper.putOptional(
      data,
      'alamatPengirimanIndonesia',
      alamatPengirimanIndonesia?.toFirestore(),
    );
    FirestoreMapper.putOptional(
      data,
      'alamatPengirimanJepang',
      alamatPengirimanJepang?.toFirestore(),
    );
    FirestoreMapper.putOptional(data, 'createdAt', createdAt);
    FirestoreMapper.putOptional(data, 'updatedAt', updatedAt);
    return data;
  }
}

class IndonesiaDeliveryAddress {
  const IndonesiaDeliveryAddress({
    this.namaPenerima,
    this.alamatPenerima,
    this.kodePos,
    this.noHp,
  });

  final String? namaPenerima;
  final String? alamatPenerima;
  final String? kodePos;
  final String? noHp;

  factory IndonesiaDeliveryAddress.fromMap(Map<String, dynamic> data) =>
      IndonesiaDeliveryAddress(
        namaPenerima: FirestoreMapper.nullableString(data['namaPenerima']),
        alamatPenerima: FirestoreMapper.nullableString(data['alamatPenerima']),
        kodePos: FirestoreMapper.nullableString(data['kodePos']),
        noHp: FirestoreMapper.nullableString(data['noHp']),
      );

  Map<String, dynamic> toFirestore() => {
    if (namaPenerima != null) 'namaPenerima': namaPenerima,
    if (alamatPenerima != null) 'alamatPenerima': alamatPenerima,
    if (kodePos != null) 'kodePos': kodePos,
    if (noHp != null) 'noHp': noHp,
  };
}

class JapanDeliveryAddress {
  const JapanDeliveryAddress({
    this.namaPenerima,
    this.alamatPenerimaRomaji,
    this.alamatPenerimaKanji,
    this.namaPenerimaRomaji,
    this.alamatPenerima,
    this.kodePos,
    this.noHpAktif,
    this.jamPenerimaPaket,
  });

  final String? namaPenerima;
  final String? alamatPenerimaRomaji;
  final String? alamatPenerimaKanji;

  /// Legacy aliases retained because existing customer docs can still contain them.
  final String? namaPenerimaRomaji;
  final String? alamatPenerima;
  final String? kodePos;
  final String? noHpAktif;
  final String? jamPenerimaPaket;

  factory JapanDeliveryAddress.fromMap(Map<String, dynamic> data) =>
      JapanDeliveryAddress(
        namaPenerima: FirestoreMapper.nullableString(data['namaPenerima']),
        alamatPenerimaRomaji: FirestoreMapper.nullableString(
          data['alamatPenerimaRomaji'],
        ),
        alamatPenerimaKanji: FirestoreMapper.nullableString(
          data['alamatPenerimaKanji'],
        ),
        namaPenerimaRomaji: FirestoreMapper.nullableString(
          data['namaPenerimaRomaji'],
        ),
        alamatPenerima: FirestoreMapper.nullableString(data['alamatPenerima']),
        kodePos: FirestoreMapper.nullableString(data['kodePos']),
        noHpAktif: FirestoreMapper.nullableString(data['noHpAktif']),
        jamPenerimaPaket: FirestoreMapper.nullableString(
          data['jamPenerimaPaket'],
        ),
      );

  Map<String, dynamic> toFirestore() => {
    if (namaPenerima != null) 'namaPenerima': namaPenerima,
    if (alamatPenerimaRomaji != null)
      'alamatPenerimaRomaji': alamatPenerimaRomaji,
    if (alamatPenerimaKanji != null) 'alamatPenerimaKanji': alamatPenerimaKanji,
    if (namaPenerimaRomaji != null) 'namaPenerimaRomaji': namaPenerimaRomaji,
    if (alamatPenerima != null) 'alamatPenerima': alamatPenerima,
    if (kodePos != null) 'kodePos': kodePos,
    if (noHpAktif != null) 'noHpAktif': noHpAktif,
    if (jamPenerimaPaket != null) 'jamPenerimaPaket': jamPenerimaPaket,
  };
}
