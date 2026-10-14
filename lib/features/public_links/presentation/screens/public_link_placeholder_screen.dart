import 'package:flutter/material.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';

class PublicLinkPlaceholderScreen extends StatelessWidget {
  const PublicLinkPlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_outlined, size: 52, color: AppColors.navy),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Route publik sudah dipisahkan dari area admin. Validasi token dan data belum dijalankan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              const StatusBadge(label: 'Route contoh • tanpa akses Firestore'),
            ],
          ),
        ),
      ),
    );
  }
}
