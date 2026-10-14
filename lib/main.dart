import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/firebase/nihong_store_firebase_options.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    // Native config files create the default Firebase app on iOS and Android.
    await Firebase.initializeApp();
  }
  await Firebase.initializeApp(
    name: NihongStoreFirebaseOptions.appName,
    options: NihongStoreFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: NihongJastipApp()));
}
