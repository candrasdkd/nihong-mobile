import 'dart:convert';

import '../../pre_orders/data/models/pre_order.dart';
import 'models/nihong_store_order.dart';

abstract final class NihongStoreAssignmentRules {
  static List<NihongStoreOrderItem> itemsForBooking(NihongStoreOrder order) {
    final available = order.items
        .where(
          (item) => item.status != 'Stok habis' && item.status != 'Dibatalkan',
        )
        .toList(growable: false);
    return available.isNotEmpty ? available : order.items;
  }

  static double estimateWeightKg(NihongStoreOrder order) {
    final items = itemsForBooking(order);
    final itemWeight = items.fold<double>(0, (sum, item) {
      final weight =
          item.beratKg != null && item.beratKg!.isFinite && item.beratKg! > 0
          ? item.beratKg!
          : 0.3;
      final quantity = item.jumlah > 0 ? item.jumlah : 1;
      return sum + weight * quantity;
    });
    final roundedWeight = double.parse(itemWeight.toStringAsFixed(2));
    if (roundedWeight > 0) return roundedWeight;
    if (order.totalKg.isFinite && order.totalKg > 0) return order.totalKg;
    return 0.5;
  }

  static List<PreOrderItem> toPreOrderItems(
    NihongStoreOrder order,
  ) => itemsForBooking(order)
      .map((item) {
        final quantity = item.jumlah > 0 ? item.jumlah : 1;
        final details = [
          if (_hasText(item.kodeBarang)) '[${item.kodeBarang!.trim()}]',
          if (_hasText(item.warna)) 'Warna: ${item.warna!.trim()}',
          if (_hasText(item.ukuran)) 'Size: ${item.ukuran!.trim()}',
          if (item.status == 'Stok habis') '[STOK HABIS]',
        ].join(' - ');

        return PreOrderItem(
          namaBarang:
              '${item.namaBarang} (x$quantity)${details.isEmpty ? '' : ' ($details)'}',
          kategori: 'NihongStore',
          catatan: item.catatan ?? '',
          checked: false,
        );
      })
      .toList(growable: false);

  static String documentId(String sourceId) {
    final encoded = base64Url.encode(utf8.encode(sourceId)).replaceAll('=', '');
    return 'nihongstore_$encoded';
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;
}
