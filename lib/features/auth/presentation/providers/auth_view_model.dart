import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import 'nihong_store_auth_view_model.dart';

enum AuthStatus { loading, signedIn, signedOut, error }

class AuthViewState {
  const AuthViewState._({required this.status, this.user, this.errorMessage});

  const AuthViewState.loading() : this._(status: AuthStatus.loading);

  const AuthViewState.signedIn(User user)
    : this._(status: AuthStatus.signedIn, user: user);

  const AuthViewState.signedOut() : this._(status: AuthStatus.signedOut);

  const AuthViewState.error(String message, {User? user})
    : this._(status: AuthStatus.error, user: user, errorMessage: message);

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.signedIn && user != null;
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthViewState>(
  AuthViewModel.new,
);

class AuthViewModel extends Notifier<AuthViewState> {
  StreamSubscription<User?>? _authSubscription;
  bool _loginInProgress = false;
  int _restoreGeneration = 0;

  @override
  AuthViewState build() {
    final repository = ref.watch(authRepositoryProvider);
    ref.listen<NihongStoreAuthState>(nihongStoreAuthViewModelProvider, (
      previous,
      storeState,
    ) {
      if (_loginInProgress || state.status != AuthStatus.signedIn) return;
      if (storeState.status == NihongStoreAuthStatus.disconnected ||
          storeState.status == NihongStoreAuthStatus.error) {
        unawaited(_expireMainSession(repository));
      }
    });
    _authSubscription?.cancel();
    _authSubscription = repository.authStateChanges().listen(
      (user) {
        if (_loginInProgress) return;
        if (user == null) {
          _restoreGeneration++;
          state = const AuthViewState.signedOut();
        } else {
          final generation = ++_restoreGeneration;
          unawaited(_restoreStoreSession(repository, user, generation));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AuthViewState.error(
          _messageFor(error),
          user: repository.currentUser,
        );
      },
    );
    ref.onDispose(() => _authSubscription?.cancel());
    return const AuthViewState.loading();
  }

  Future<void> signIn({required String email, required String password}) async {
    _loginInProgress = true;
    final generation = ++_restoreGeneration;
    state = const AuthViewState.loading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signIn(email: email, password: password);
      final storeConnected = await ref
          .read(nihongStoreAuthViewModelProvider.notifier)
          .signIn(email: email, password: password);
      if (!storeConnected) {
        await _signOutQuietly(repository);
        if (generation == _restoreGeneration) {
          state = const AuthViewState.signedOut();
        }
        return;
      }
      if (generation == _restoreGeneration) {
        state = AuthViewState.signedIn(user);
      }
    } on Object catch (error) {
      if (generation == _restoreGeneration) {
        state = AuthViewState.error(
          _messageFor(error),
          user: ref.read(authRepositoryProvider).currentUser,
        );
      }
    } finally {
      _loginInProgress = false;
    }
  }

  Future<void> signOut() async {
    _loginInProgress = true;
    final generation = ++_restoreGeneration;
    state = const AuthViewState.loading();
    final repository = ref.read(authRepositoryProvider);
    try {
      final errors = await Future.wait<Object?>([
        _capture(() => repository.signOut()),
        _capture(
          () => ref.read(nihongStoreAuthViewModelProvider.notifier).signOut(),
        ),
      ]);
      if (generation != _restoreGeneration) return;
      final mainError = errors.first;
      state = mainError == null
          ? const AuthViewState.signedOut()
          : AuthViewState.error(
              _messageFor(mainError),
              user: repository.currentUser,
            );
    } finally {
      _loginInProgress = false;
    }
  }

  Future<void> _restoreStoreSession(
    AuthRepository repository,
    User user,
    int generation,
  ) async {
    state = const AuthViewState.loading();
    final storeConnected = await ref
        .read(nihongStoreAuthViewModelProvider.notifier)
        .verifyRestoredSession(expectedEmail: user.email);
    if (generation != _restoreGeneration) return;
    if (storeConnected) {
      state = AuthViewState.signedIn(user);
    } else {
      await _signOutQuietly(repository);
      if (generation == _restoreGeneration) {
        state = const AuthViewState.signedOut();
      }
    }
  }

  Future<void> _expireMainSession(AuthRepository repository) async {
    if (state.status != AuthStatus.signedIn) return;
    final generation = ++_restoreGeneration;
    state = const AuthViewState.loading();
    await _signOutQuietly(repository);
    if (generation == _restoreGeneration) {
      state = const AuthViewState.signedOut();
    }
  }

  Future<void> _signOutQuietly(AuthRepository repository) async {
    try {
      await repository.signOut();
    } on Object {
      // The session remains blocked by the router until both projects validate.
    }
  }

  Future<Object?> _capture(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on Object catch (error) {
      return error;
    }
  }

  String _messageFor(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Terjadi kendala saat menghubungi layanan autentikasi. Coba lagi.';
    }

    return switch (error.code) {
      'invalid-email' => 'Format email belum benar.',
      'user-disabled' => 'Akun ini dinonaktifkan. Hubungi administrator.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email atau kata sandi tidak cocok.',
      'too-many-requests' =>
        'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
      'network-request-failed' =>
        'Koneksi internet bermasalah. Periksa jaringan lalu coba lagi.',
      'invalid-api-key' || 'app-not-authorized' =>
        'Konfigurasi Firebase Auth project utama tidak cocok.',
      'operation-not-allowed' =>
        'Login email dan kata sandi belum diaktifkan pada Firebase.',
      _ => 'Gagal masuk. Coba lagi atau hubungi administrator.',
    };
  }
}
