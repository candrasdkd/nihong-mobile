import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firestore/firestore_mapper.dart';

class NihongStoreOrder {
  const NihongStoreOrder({
    required this.id,
    required this.no,
    required this.namaPelanggan,
    required this.noTelponPelanggan,
    required this.items,
    required this.totalKg,
    required this.status,
    this.alamatPelanggan,
    this.idPelanggan,
    this.totalEstimasiHargaIdr,
    this.totalEstimasiHargaYen,
    this.catatan,
    this.displayStatus,
    this.paymentStatus,
    this.assignedScheduleId,
    this.assignedScheduleRoute,
    this.assignedScheduleDate,
    this.assignedPreOrderId,
    this.assignedOrderId,
    this.timeline = const [],
    this.source,
    this.createdAt,
    this.updatedAt,
  });

  static const collectionName = 'nihongstore_orders';
  static const pageSize = 50;

  final String id;
  final String no;
  final String namaPelanggan;
  final String noTelponPelanggan;
  final String? alamatPelanggan;
  final String? idPelanggan;
  final List<NihongStoreOrderItem> items;
  final double totalKg;
  final double? totalEstimasiHargaIdr;
  final double? totalEstimasiHargaYen;
  final String? catatan;
  final String status;
  final String? displayStatus;
  final String? paymentStatus;
  final String? assignedScheduleId;
  final String? assignedScheduleRoute;
  final String? assignedScheduleDate;
  final String? assignedPreOrderId;
  final String? assignedOrderId;
  final List<NihongStoreOrderTimelineEntry> timeline;
  final String? source;
  final Object? createdAt;
  final Object? updatedAt;

  String get statusLabel => displayStatus?.trim().isNotEmpty == true
      ? displayStatus!.trim()
      : switch (status) {
          'inbox' => 'Menunggu Jadwal',
          'assigned' => 'Terjadwal',
          'rejected' => 'Dibatalkan',
          _ => status,
        };

  factory NihongStoreOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => NihongStoreOrder.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory NihongStoreOrder.fromMap(
    Map<String, dynamic> data, {
    String? id,
  }) => NihongStoreOrder(
    id: id ?? FirestoreMapper.string(data['id']),
    no: FirestoreMapper.string(data['no']),
    namaPelanggan: FirestoreMapper.string(data['namaPelanggan']),
    noTelponPelanggan: FirestoreMapper.string(data['noTelponPelanggan']),
    alamatPelanggan: FirestoreMapper.nullableString(data['alamatPelanggan']),
    idPelanggan: FirestoreMapper.nullableString(data['idPelanggan']),
    items: FirestoreMapper.mapList(
      data['items'],
    ).map(NihongStoreOrderItem.fromMap).toList(growable: false),
    totalKg: FirestoreMapper.number(data['totalKg']),
    totalEstimasiHargaIdr: data['totalEstimasiHargaIdr'] == null
        ? null
        : FirestoreMapper.number(data['totalEstimasiHargaIdr']),
    totalEstimasiHargaYen: data['totalEstimasiHargaYen'] == null
        ? null
        : FirestoreMapper.number(data['totalEstimasiHargaYen']),
    catatan: FirestoreMapper.nullableString(data['catatan']),
    status: FirestoreMapper.string(data['status'], fallback: 'inbox'),
    displayStatus: FirestoreMapper.nullableString(data['displayStatus']),
    paymentStatus: FirestoreMapper.nullableString(data['paymentStatus']),
    assignedScheduleId: FirestoreMapper.nullableString(
      data['assignedScheduleId'],
    ),
    assignedScheduleRoute: FirestoreMapper.nullableString(
      data['assignedScheduleRoute'],
    ),
    assignedScheduleDate: FirestoreMapper.nullableString(
      data['assignedScheduleDate'],
    ),
    assignedPreOrderId: FirestoreMapper.nullableString(
      data['assignedPreOrderId'],
    ),
    assignedOrderId: FirestoreMapper.nullableString(data['assignedOrderId']),
    timeline: FirestoreMapper.mapList(
      data['timeline'],
    ).map(NihongStoreOrderTimelineEntry.fromMap).toList(growable: false),
    source: FirestoreMapper.nullableString(data['source']),
    createdAt: data['createdAt'],
    updatedAt: data['updatedAt'],
  );
}

class NihongStoreOrderItem {
  const NihongStoreOrderItem({
    required this.namaBarang,
    required this.jumlah,
    this.kodeBarang,
    this.warna,
    this.ukuran,
    this.hargaYen,
    this.hargaIdr,
    this.beratKg,
    this.imageUrl,
    this.url,
    this.catatan,
    this.status,
  });

  final String namaBarang;
  final String? kodeBarang;
  final String? warna;
  final String? ukuran;
  final int jumlah;
  final double? hargaYen;
  final double? hargaIdr;
  final double? beratKg;
  final String? imageUrl;
  final String? url;
  final String? catatan;
  final String? status;

  factory NihongStoreOrderItem.fromMap(Map<String, dynamic> data) =>
      NihongStoreOrderItem(
        namaBarang: FirestoreMapper.string(data['namaBarang']),
        kodeBarang: FirestoreMapper.nullableString(data['kodeBarang']),
        warna: FirestoreMapper.nullableString(data['warna']),
        ukuran: FirestoreMapper.nullableString(data['ukuran']),
        jumlah: FirestoreMapper.optionalInt(data['jumlah']) ?? 1,
        hargaYen: data['hargaYen'] == null
            ? null
            : FirestoreMapper.number(data['hargaYen']),
        hargaIdr: data['hargaIdr'] == null
            ? null
            : FirestoreMapper.number(data['hargaIdr']),
        beratKg: data['beratKg'] == null
            ? null
            : FirestoreMapper.number(data['beratKg']),
        imageUrl: FirestoreMapper.nullableString(data['imageUrl']),
        url: FirestoreMapper.nullableString(data['url']),
        catatan: FirestoreMapper.nullableString(data['catatan']),
        status: FirestoreMapper.nullableString(data['status']),
      );
}

class NihongStoreOrderTimelineEntry {
  const NihongStoreOrderTimelineEntry({
    required this.status,
    required this.note,
    required this.at,
  });

  final String status;
  final String note;
  final Object? at;

  factory NihongStoreOrderTimelineEntry.fromMap(Map<String, dynamic> data) =>
      NihongStoreOrderTimelineEntry(
        status: FirestoreMapper.string(data['status']),
        note: FirestoreMapper.string(data['note']),
        at: data['at'],
      );
}
