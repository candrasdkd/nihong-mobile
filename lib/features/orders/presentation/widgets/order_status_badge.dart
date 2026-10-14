import 'package:flutter/material.dart';

import '../../../../core/widgets/status_badge.dart';
import '../../domain/order_calculations.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      OrderStatuses.completed => StatusBadgeTone.success,
      OrderStatuses.depositPaid => StatusBadgeTone.warning,
      OrderStatuses.unpaid => StatusBadgeTone.error,
      _ => StatusBadgeTone.neutral,
    };

    return StatusBadge(label: status, tone: tone);
  }
}
