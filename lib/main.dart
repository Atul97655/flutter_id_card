import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_id_card/app.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Data entry is a portrait, one-handed task and the card preview is authored
  // for portrait. Locking it avoids re-laying out the form mid-entry.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Deliberately not fatal: the app must run - and take entries - even when
  // Firebase is missing or unreachable. See FirebaseBootstrap.
  await FirebaseBootstrap.instance.initialise();

  runApp(
    const ProviderScope(
      child: IdCardApp(),
    ),
  );
}
