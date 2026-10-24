import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show
        defaultTargetPlatform,
        debugPrint,
        kIsWeb,
        TargetPlatform;
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseSupported =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (firebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    debugPrint('Firebase is not configured for this platform.');
  }

  runApp(const DailyBriefApp());
}
