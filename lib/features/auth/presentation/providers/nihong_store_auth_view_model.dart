import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/nihong_store_auth_repository.dart';

enum NihongStoreAuthStatus { loading, connected, disconnected, error }

class NihongStoreAuthState {
  const NihongStoreAuthState._({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const NihongStoreAuthState.loading()
    : this._(status: NihongStoreAuthStatus.loading);

  const NihongStoreAuthState.connected(User user)
    : this._(status: NihongStoreAuthStatus.connected, user: user);

  const NihongStoreAuthState.disconnected()
    : this._(status: NihongStoreAuthStatus.disconnected);

  const NihongStoreAuthState.error(String message)
    : this._(status: NihongStoreAuthStatus.error, errorMessage: message);

  final NihongStoreAuthStatus status;
  final User? user;
  final String? errorMessage;

  bool get isConnected =>
      status == NihongStoreAuthStatus.connected && user != null;
}

final nihongStoreAuthViewModelProvider =
    NotifierProvider<NihongStoreAuthViewModel, NihongStoreAuthState>(
      NihongStoreAuthViewModel.new,
    );

class NihongStoreAuthViewModel extends Notifier<NihongStoreAuthState> {
  StreamSubscription<User?>? _authSubscription;
  int _validationGeneration = 0;
  bool _operationInProgress = false;

  @override
  NihongStoreAuthState build() {
    final repository = ref.watch(nihongStoreAuthRepositoryProvider);
    _authSubscription?.cancel();
    _authSubscription = repository.authStateChanges().listen(
      (user) {
        if (_operationInProgress) return;
        final generation = ++_validationGeneration;
        if (user == null) {
          state = const NihongStoreAuthState.disconnected();
        } else {
          unawaited(_verifyUser(user, generation));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        state = NihongStoreAuthState.error(_messageFor(error));
      },
    );
    ref.onDispose(() => _authSubscription?.cancel());
    return const NihongStoreAuthState.loading();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _operationInProgress = true;
    state = const NihongStoreAuthState.loading();
    ++_validationGeneration;
    try {
      final user = await ref
          .read(nihongStoreAuthRepositoryProvider)
          .signInAndVerifyAdmin(email: email, password: password);
      state = NihongStoreAuthState.connected(user);
      return true;
    } on Object catch (error) {
      state = NihongStoreAuthState.error(_messageFor(error));
      return false;
    } finally {
      _operationInProgress = false;
    }
  }

  Future<bool> verifyRestoredSession({required String? expectedEmail}) async {
    _operationInProgress = true;
    state = const NihongStoreAuthState.loading();
    ++_validationGeneration;
    final repository = ref.read(nihongStoreAuthRepositoryProvider);
    try {
      final user = await repository.restoredUser();
      if (user == null) {
        throw const NihongStoreAccessException(
          'Sesi NihongStore belum tersimpan. Masuk kembali untuk '
          'memverifikasi akses kedua project.',
        );
      }
      if (expectedEmail != null &&
          user.email?.trim().toLowerCase() !=
              expectedEmail.trim().toLowerCase()) {
        throw const NihongStoreAccessException(
          'Akun NihongStore yang tersimpan berbeda dari akun utama. '
          'Masuk kembali dengan email yang sama.',
        );
      }
      await repository.verifyAdminAccess(user);
      state = NihongStoreAuthState.connected(user);
      return true;
    } on Object catch (error) {
      if (error is NihongStoreAccessException &&
          repository.currentUser != null) {
        try {
          await repository.signOut();
        } on Object {
          // Keep the admin verification error visible to the login screen.
        }
      }
      state = NihongStoreAuthState.error(_messageFor(error));
      return false;
    } finally {
      _operationInProgress = false;
    }
  }

  Future<void> signOut() async {
    _operationInProgress = true;
    state = const NihongStoreAuthState.loading();
    final generation = ++_validationGeneration;
    try {
      await ref.read(nihongStoreAuthRepositoryProvider).signOut();
      if (generation == _validationGeneration) {
        state = const NihongStoreAuthState.disconnected();
      }
    } on Object catch (error) {
      if (generation == _validationGeneration) {
        state = NihongStoreAuthState.error(_messageFor(error));
      }
      rethrow;
    } finally {
      _operationInProgress = false;
    }
  }

  Future<void> _verifyUser(User user, int generation) async {
    if (_operationInProgress) return;
    state = const NihongStoreAuthState.loading();
    try {
      await ref.read(nihongStoreAuthRepositoryProvider).verifyAdminAccess(user);
      if (generation == _validationGeneration) {
        state = NihongStoreAuthState.connected(user);
      }
    } on Object catch (error) {
      if (generation == _validationGeneration) {
        state = NihongStoreAuthState.error(_messageFor(error));
      }
    }
  }

  String _messageFor(Object error) {
    if (error is NihongStoreAccessException) return error.message;
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Format email NihongStore belum benar.',
        'user-disabled' =>
          'Akun NihongStore dinonaktifkan. Hubungi administrator.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email atau kata sandi tidak cocok untuk NihongStore.',
        'too-many-requests' =>
          'Terlalu banyak percobaan login NihongStore. Coba lagi nanti.',
        'network-request-failed' =>
          'Koneksi ke Firebase NihongStore gagal. Periksa jaringan.',
        'operation-not-allowed' =>
          'Login email/password belum aktif pada Firebase NihongStore.',
        _ => 'Gagal masuk ke Firebase NihongStore. Coba lagi.',
      };
    }
    if (error is FirebaseException && error.code == 'unavailable') {
      return 'Firebase NihongStore sedang tidak tersedia. Coba lagi.';
    }
    return 'Tidak dapat memverifikasi akses admin NihongStore. '
        'Pastikan rules Firestore mengizinkan pembacaan admins/{uid}.';
  }
}
