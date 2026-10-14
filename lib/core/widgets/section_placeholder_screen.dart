import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import 'status_badge.dart';

class SectionPlaceholderScreen extends StatelessWidget {
  const SectionPlaceholderScreen({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                    child: Icon(icon, color: AppColors.navy, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 18),
                  const StatusBadge(label: 'Belum terhubung ke data'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
