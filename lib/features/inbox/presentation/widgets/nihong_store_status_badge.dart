import 'package:flutter/material.dart';

import '../../../../core/widgets/status_badge.dart';

class NihongStoreStatusBadge extends StatelessWidget {
  const NihongStoreStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'inbox' => StatusBadgeTone.warning,
      'assigned' => StatusBadgeTone.success,
      'rejected' => StatusBadgeTone.error,
      _ => StatusBadgeTone.neutral,
    };

    final label = switch (status) {
      'inbox' => 'Menunggu Jadwal',
      'assigned' => 'Terjadwal',
      'rejected' => 'Dibatalkan',
      _ => status,
    };

    return StatusBadge(label: label, tone: tone);
  }
}
