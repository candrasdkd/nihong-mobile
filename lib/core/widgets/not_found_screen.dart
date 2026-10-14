import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/app_colors.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_off_outlined,
                size: 56,
                color: AppColors.navy,
              ),
              const SizedBox(height: 16),
              Text(
                'Halaman tidak ditemukan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Alamat yang dibuka tidak tersedia. Kembali ke halaman beranda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Ke beranda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
