import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';

enum StatusBadgeTone { neutral, success, warning, error }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.tone = StatusBadgeTone.neutral,
    super.key,
  });

  final String label;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (tone) {
      StatusBadgeTone.neutral => (
        AppColors.navy,
        AppColors.navy.withValues(alpha: 0.08),
      ),
      StatusBadgeTone.success => (
        AppColors.success,
        AppColors.success.withValues(alpha: 0.1),
      ),
      StatusBadgeTone.warning => (
        AppColors.warning,
        AppColors.warning.withValues(alpha: 0.1),
      ),
      StatusBadgeTone.error => (
        AppColors.error,
        AppColors.error.withValues(alpha: 0.1),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
