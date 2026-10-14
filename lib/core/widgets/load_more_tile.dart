import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';

class LoadMoreTile extends StatelessWidget {
  const LoadMoreTile({
    required this.onPressed,
    this.isLoading = false,
    this.errorMessage,
    this.label = 'Muat 15 data lainnya',
    super.key,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final String? errorMessage;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    child: Center(
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null) ...[
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.expand_more),
                  label: Text(errorMessage == null ? label : 'Coba lagi'),
                ),
              ],
            ),
    ),
  );
}
