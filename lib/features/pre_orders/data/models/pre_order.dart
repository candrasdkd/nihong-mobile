import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firestore/firestore_mapper.dart';

class PreOrder {
  const PreOrder({
    required this.id,
    required this.idJadwal,
    required this.namaJastiper,
    required this.rute,
    required this.tanggalBerangkat,
    required this.idPelanggan,
    required this.namaPelanggan,
    required this.items,
    required this.totalKg,
    required this.status,
    this.noTelponPelanggan,
    this.pic,
    this.catatan,
    this.nihongStoreOrderId,
    this.nihongStoreOrderNo,
    this.nihongStoreCancellationState,
    this.nihongStoreCancellationReason,
    this.nihongStoreStatusSyncState,
    this.convertedOrderId,
    this.deliveryAddressShareToken,
    this.deliveryAddressShareCreatedAt,
    this.productShareToken,
    this.createdAt,
    this.updatedAt,
  });

  static const collectionName = 'pre_orders';

  final String id;
  final String idJadwal;
  final String namaJastiper;
  final String rute;
  final String tanggalBerangkat;
  final String idPelanggan;
  final String namaPelanggan;
  final String? noTelponPelanggan;
  final String? pic;
  final List<PreOrderItem> items;
  final double totalKg;
  final String status;
  final String? catatan;
  final String? nihongStoreOrderId;
  final String? nihongStoreOrderNo;
  final String? nihongStoreCancellationState;
  final String? nihongStoreCancellationReason;
  final String? nihongStoreStatusSyncState;
  final String? convertedOrderId;
  final String? deliveryAddressShareToken;
  final Object? deliveryAddressShareCreatedAt;
  final String? productShareToken;
  final Object? createdAt;
  final Object? updatedAt;

  factory PreOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => PreOrder.fromMap(snapshot.data() ?? const {}, id: snapshot.id);

  factory PreOrder.fromMap(Map<String, dynamic> data, {String? id}) => PreOrder(
    id: id ?? FirestoreMapper.string(data['id']),
    idJadwal: FirestoreMapper.string(data['idJadwal']),
    namaJastiper: FirestoreMapper.string(data['namaJastiper']),
    rute: FirestoreMapper.string(data['rute']),
    tanggalBerangkat: FirestoreMapper.string(data['tanggalBerangkat']),
    idPelanggan: FirestoreMapper.string(data['idPelanggan']),
    namaPelanggan: FirestoreMapper.string(data['namaPelanggan']),
    noTelponPelanggan: FirestoreMapper.nullableString(
      data['noTelponPelanggan'],
    ),
    pic: FirestoreMapper.nullableString(data['pic']),
    items: FirestoreMapper.mapList(
      data['items'],
    ).map(PreOrderItem.fromMap).toList(growable: false),
    totalKg: FirestoreMapper.number(data['totalKg']),
    status: FirestoreMapper.string(data['status'], fallback: 'Pending'),
    catatan: FirestoreMapper.nullableString(data['catatan']),
    nihongStoreOrderId: FirestoreMapper.nullableString(
      data['nihongStoreOrderId'],
    ),
    nihongStoreOrderNo: FirestoreMapper.nullableString(
      data['nihongStoreOrderNo'],
    ),
    nihongStoreCancellationState: FirestoreMapper.nullableString(
      data['nihongStoreCancellationState'],
    ),
    nihongStoreCancellationReason: FirestoreMapper.nullableString(
      data['nihongStoreCancellationReason'],
    ),
    nihongStoreStatusSyncState: FirestoreMapper.nullableString(
      data['nihongStoreStatusSyncState'],
    ),
    convertedOrderId: FirestoreMapper.nullableString(data['convertedOrderId']),
    deliveryAddressShareToken: FirestoreMapper.nullableString(
      data['deliveryAddressShareToken'],
    ),
    deliveryAddressShareCreatedAt: data['deliveryAddressShareCreatedAt'],
    productShareToken: FirestoreMapper.nullableString(
      data['productShareToken'],
    ),
    createdAt: data['createdAt'],
    updatedAt: data['updatedAt'],
  );

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'idJadwal': idJadwal,
      'namaJastiper': namaJastiper,
      'rute': rute,
      'tanggalBerangkat': tanggalBerangkat,
      'idPelanggan': idPelanggan,
      'namaPelanggan': namaPelanggan,
      'items': items.map((item) => item.toFirestore()).toList(),
      'totalKg': totalKg,
      'status': status,
    };
    FirestoreMapper.putOptional(data, 'noTelponPelanggan', noTelponPelanggan);
    FirestoreMapper.putOptional(data, 'pic', pic);
    FirestoreMapper.putOptional(data, 'catatan', catatan);
    FirestoreMapper.putOptional(data, 'nihongStoreOrderId', nihongStoreOrderId);
    FirestoreMapper.putOptional(data, 'nihongStoreOrderNo', nihongStoreOrderNo);
    FirestoreMapper.putOptional(
      data,
      'nihongStoreCancellationState',
      nihongStoreCancellationState,
    );
    FirestoreMapper.putOptional(
      data,
      'nihongStoreCancellationReason',
      nihongStoreCancellationReason,
    );
    FirestoreMapper.putOptional(
      data,
      'nihongStoreStatusSyncState',
      nihongStoreStatusSyncState,
    );
    FirestoreMapper.putOptional(data, 'convertedOrderId', convertedOrderId);
    FirestoreMapper.putOptional(
      data,
      'deliveryAddressShareToken',
      deliveryAddressShareToken,
    );
    FirestoreMapper.putOptional(
      data,
      'deliveryAddressShareCreatedAt',
      deliveryAddressShareCreatedAt,
    );
    FirestoreMapper.putOptional(data, 'productShareToken', productShareToken);
    FirestoreMapper.putOptional(data, 'createdAt', createdAt);
    FirestoreMapper.putOptional(data, 'updatedAt', updatedAt);
    return data;
  }
}

class PreOrderItem {
  const PreOrderItem({
    required this.namaBarang,
    required this.checked,
    this.kategori,
    this.catatan,
  });

  final String namaBarang;
  final String? kategori;
  final String? catatan;
  final bool checked;

  factory PreOrderItem.fromMap(Map<String, dynamic> data) => PreOrderItem(
    namaBarang: FirestoreMapper.string(data['namaBarang']),
    kategori: FirestoreMapper.nullableString(data['kategori']),
    catatan: FirestoreMapper.nullableString(data['catatan']),
    checked: FirestoreMapper.optionalBool(data['checked']) ?? false,
  );

  Map<String, dynamic> toFirestore() => {
    'namaBarang': namaBarang,
    if (kategori != null) 'kategori': kategori,
    if (catatan != null) 'catatan': catatan,
    'checked': checked,
  };
}
