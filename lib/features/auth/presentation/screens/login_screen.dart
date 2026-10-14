import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_colors.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../providers/auth_view_model.dart';
import '../providers/nihong_store_auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authViewModelProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final storeAuthState = ref.watch(nihongStoreAuthViewModelProvider);
    final storeErrorMessage = storeAuthState.errorMessage;
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.navy,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.flight_takeoff,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Nihong Jastip',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navyDark,
                                ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Masuk untuk mengelola operasional titip Jepang.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 24),
                          if (authState.errorMessage case final message?) ...[
                            _AuthErrorBanner(message: message),
                            const SizedBox(height: 16),
                          ],
                          if (authState.status != AuthStatus.error &&
                              storeErrorMessage != null) ...[
                            _AuthErrorBanner(
                              message: 'NihongStore: $storeErrorMessage',
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            style: const TextStyle(fontSize: 16),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Email wajib diisi.';
                              if (!email.contains('@') || email.endsWith('@')) {
                                return 'Masukkan alamat email yang valid.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !isLoading,
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            style: const TextStyle(fontSize: 16),
                            onFieldSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              labelText: 'Kata sandi',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _passwordVisible
                                    ? 'Sembunyikan kata sandi'
                                    : 'Tampilkan kata sandi',
                                onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Kata sandi wajib diisi.'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: isLoading ? null : _signIn,
                            icon: isLoading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              isLoading ? 'Memeriksa sesi…' : 'Masuk',
                            ),
                          ),
                          if (isLoading) ...[
                            const SizedBox(height: 12),
                            const AppLoadingView(
                              message: 'Menghubungkan ke Firebase…',
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Text(
                            'Akun dan kata sandi akan diverifikasi pada Firebase utama serta NihongStore.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
