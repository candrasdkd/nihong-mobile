import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../auth/presentation/providers/auth_view_model.dart';
import '../../../auth/presentation/providers/nihong_store_auth_view_model.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);
    final storeAuthState = ref.watch(nihongStoreAuthViewModelProvider);
    final isSigningOut = authState.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.navy,
                child: Icon(Icons.person_outline, color: Colors.white),
              ),
              title: Text(authState.user?.email ?? 'Akun operasional'),
              subtitle: Text(
                storeAuthState.isConnected
                    ? 'Firebase utama dan NihongStore terhubung'
                    : storeAuthState.errorMessage ??
                          'Sesi NihongStore belum terverifikasi',
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isSigningOut
                ? null
                : () => ref.read(authViewModelProvider.notifier).signOut(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.4),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: Text(isSigningOut ? 'Mengeluarkan sesi…' : 'Keluar'),
          ),
          const SizedBox(height: 20),
          _MenuItem(
            icon: Icons.calendar_month_outlined,
            label: 'Jadwal keberangkatan',
            onTap: () => context.push('/schedules'),
          ),
          _MenuItem(
            icon: Icons.people_outline,
            label: 'Pelanggan',
            onTap: () => context.push('/customers'),
          ),
          _MenuItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Kas',
            onTap: () => context.push('/cash'),
          ),
          _MenuItem(
            icon: Icons.storefront_outlined,
            label: 'Inbox NihongStore',
            onTap: () => context.push('/inbox'),
          ),
          _MenuItem(
            icon: Icons.badge_outlined,
            label: 'Jastiper',
            onTap: () => context.push('/jastipers'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.navy),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
