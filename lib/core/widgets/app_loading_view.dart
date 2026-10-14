import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({this.message = 'Memuat…', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
