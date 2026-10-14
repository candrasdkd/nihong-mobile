import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firestore/firestore_mapper.dart';

class OrderDoc {
  const OrderDoc({
    required this.id,
    required this.no,
    required this.tanggal,
    required this.idPelanggan,
    required this.namaPelanggan,
    required this.namaBarang,
    required this.jumlahKg,
    required this.kgCeil,
    required this.hargaJastip,
    required this.hargaJastipMarkup,
    required this.hargaOngkirMarkup,
    required this.totalPembayaran,
    required this.totalKeuntungan,
    required this.status,
    this.revision,
    this.kategori,
    this.pengiriman,
    this.hargaOngkir,
    this.tipeNominal = 'IDR',
    this.catatan,
    this.imageUrl,
    this.dpNominal,
    this.dpTanggal,
    this.dpMetode,
    this.dpCatatan,
    this.pelunasanNominal,
    this.pelunasanTanggal,
    this.pelunasanMetode,
    this.pelunasanCatatan,
    this.createdAt,
    this.updatedAt,
  });

  static const collectionName = 'orders';

  final String id;
  final Object? revision;
  final String no;
  final String tanggal;
  final String idPelanggan;
  final String namaPelanggan;
  final String namaBarang;
  final String? kategori;
  final String? pengiriman;
  final double jumlahKg;
  final double kgCeil;
  final double hargaJastip;
  final double hargaJastipMarkup;
  final double? hargaOngkir;
  final double hargaOngkirMarkup;
  final double totalPembayaran;
  final double totalKeuntungan;
  final String status;
  final String tipeNominal;
  final String? catatan;

  /// Legacy records can contain a URL string or an array of URLs.
  final Object? imageUrl;

  final double? dpNominal;
  final String? dpTanggal;
  final String? dpMetode;
  final String? dpCatatan;
  final double? pelunasanNominal;
  final String? pelunasanTanggal;
  final String? pelunasanMetode;
  final String? pelunasanCatatan;
  final Object? createdAt;
  final Object? updatedAt;

  /// Matches the legacy status adapter used by the web order list.
  String get displayStatus =>
      status == 'Menunggu Pelunasan' ? 'DP Terbayar' : status;

  factory OrderDoc.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => OrderDoc.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory OrderDoc.fromMap(Map<String, dynamic> data, {String? id}) => OrderDoc(
    id: id ?? FirestoreMapper.string(data['id']),
    revision: data['revision'],
    no: FirestoreMapper.string(data['no']),
    tanggal: FirestoreMapper.string(data['tanggal']),
    idPelanggan: FirestoreMapper.string(data['idPelanggan']),
    namaPelanggan: FirestoreMapper.string(data['namaPelanggan']),
    namaBarang: FirestoreMapper.string(data['namaBarang']),
    kategori: FirestoreMapper.nullableString(data['kategori']),
    pengiriman: FirestoreMapper.nullableString(data['pengiriman']),
    jumlahKg: FirestoreMapper.number(data['jumlahKg']),
    kgCeil: FirestoreMapper.number(data['kgCeil']),
    hargaJastip: FirestoreMapper.number(data['hargaJastip']),
    hargaJastipMarkup: FirestoreMapper.number(data['hargaJastipMarkup']),
    hargaOngkir: data['hargaOngkir'] == null
        ? null
        : FirestoreMapper.number(data['hargaOngkir']),
    hargaOngkirMarkup: FirestoreMapper.number(data['hargaOngkirMarkup']),
    totalPembayaran: FirestoreMapper.number(data['totalPembayaran']),
    totalKeuntungan: FirestoreMapper.number(data['totalKeuntungan']),
    status: FirestoreMapper.string(data['status'], fallback: 'Belum Membayar'),
    tipeNominal: FirestoreMapper.string(data['tipeNominal'], fallback: 'IDR'),
    catatan: FirestoreMapper.nullableString(data['catatan']),
    imageUrl: data['imageUrl'],
    dpNominal: data['dpNominal'] == null
        ? null
        : FirestoreMapper.number(data['dpNominal']),
    dpTanggal: FirestoreMapper.nullableString(data['dpTanggal']),
    dpMetode: FirestoreMapper.nullableString(data['dpMetode']),
    dpCatatan: FirestoreMapper.nullableString(data['dpCatatan']),
    pelunasanNominal: data['pelunasanNominal'] == null
        ? null
        : FirestoreMapper.number(data['pelunasanNominal']),
    pelunasanTanggal: FirestoreMapper.nullableString(data['pelunasanTanggal']),
    pelunasanMetode: FirestoreMapper.nullableString(data['pelunasanMetode']),
    pelunasanCatatan: FirestoreMapper.nullableString(data['pelunasanCatatan']),
    createdAt: data['createdAt'],
    updatedAt: data['updatedAt'],
  );

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'no': no,
      'tanggal': tanggal,
      'idPelanggan': idPelanggan,
      'namaPelanggan': namaPelanggan,
      'namaBarang': namaBarang,
      'jumlahKg': jumlahKg,
      'kgCeil': kgCeil,
      'hargaJastip': hargaJastip,
      'hargaJastipMarkup': hargaJastipMarkup,
      'hargaOngkirMarkup': hargaOngkirMarkup,
      'totalPembayaran': totalPembayaran,
      'totalKeuntungan': totalKeuntungan,
      'status': status,
      'tipeNominal': tipeNominal,
    };
    FirestoreMapper.putOptional(data, 'revision', revision);
    FirestoreMapper.putOptional(data, 'kategori', kategori);
    FirestoreMapper.putOptional(data, 'pengiriman', pengiriman);
    FirestoreMapper.putOptional(data, 'hargaOngkir', hargaOngkir);
    FirestoreMapper.putOptional(data, 'catatan', catatan);
    FirestoreMapper.putOptional(data, 'imageUrl', imageUrl);
    FirestoreMapper.putOptional(data, 'dpNominal', dpNominal);
    FirestoreMapper.putOptional(data, 'dpTanggal', dpTanggal);
    FirestoreMapper.putOptional(data, 'dpMetode', dpMetode);
    FirestoreMapper.putOptional(data, 'dpCatatan', dpCatatan);
    FirestoreMapper.putOptional(data, 'pelunasanNominal', pelunasanNominal);
    FirestoreMapper.putOptional(data, 'pelunasanTanggal', pelunasanTanggal);
    FirestoreMapper.putOptional(data, 'pelunasanMetode', pelunasanMetode);
    FirestoreMapper.putOptional(data, 'pelunasanCatatan', pelunasanCatatan);
    FirestoreMapper.putOptional(data, 'createdAt', createdAt);
    FirestoreMapper.putOptional(data, 'updatedAt', updatedAt);
    return data;
  }
}
