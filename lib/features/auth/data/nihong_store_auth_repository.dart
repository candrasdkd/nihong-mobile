import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/nihong_store_firebase_options.dart';

final nihongStoreFirebaseAppProvider = Provider<FirebaseApp>(
  (ref) => Firebase.app(NihongStoreFirebaseOptions.appName),
);

final nihongStoreAuthProvider = Provider<FirebaseAuth>(
  (ref) =>
      FirebaseAuth.instanceFor(app: ref.watch(nihongStoreFirebaseAppProvider)),
);

final nihongStoreFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instanceFor(
    app: ref.watch(nihongStoreFirebaseAppProvider),
  ),
);

final nihongStoreAuthRepositoryProvider = Provider<NihongStoreAuthRepository>(
  (ref) => NihongStoreAuthRepository(
    ref.watch(nihongStoreAuthProvider),
    ref.watch(nihongStoreFirestoreProvider),
  ),
);

class NihongStoreAuthRepository {
  const NihongStoreAuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User> signInAndVerifyAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const NihongStoreAccessException(
          'Firebase NihongStore tidak mengembalikan sesi pengguna.',
        );
      }
      await verifyAdminAccess(user);
      return user;
    } catch (_) {
      try {
        await _auth.signOut();
      } on Object {
        // Keep the original authentication or admin verification error.
      }
      rethrow;
    }
  }

  Future<User?> restoredUser() => authStateChanges().first;

  Future<void> verifyAdminAccess(User user) async {
    try {
      final snapshot = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();
      if (!snapshot.exists) {
        throw NihongStoreAccessException(
          'Akun NihongStore ${user.email ?? ''} belum terdaftar di '
          'admins/${user.uid} pada project nihongstore-6210b.',
        );
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw NihongStoreAccessException(
          'Akses dokumen admins/${user.uid} ditolak. Pastikan akun ini '
          'terdaftar sebagai admin pada project NihongStore.',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();
}

class NihongStoreAccessException implements Exception {
  const NihongStoreAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}
