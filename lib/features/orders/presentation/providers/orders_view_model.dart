import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/orders_data_source.dart';
import '../../data/orders_repository.dart';

final ordersStreamProvider = StreamProvider.autoDispose
    .family<OrderQuerySnapshot, int>(
      (ref, limitCount) => ref
          .watch(ordersRepositoryProvider)
          .watchOrders(limitCount: limitCount),
    );
