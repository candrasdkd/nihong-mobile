import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/nihong_store_inbox_data_source.dart';
import '../../data/nihong_store_inbox_repository.dart';

final nihongStoreInboxStreamProvider = StreamProvider.autoDispose
    .family<NihongStoreInboxSnapshot, int>(
      (ref, limitCount) => ref
          .watch(nihongStoreInboxRepositoryProvider)
          .watchOrders(limitCount: limitCount),
    );
