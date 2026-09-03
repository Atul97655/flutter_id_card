import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Starts Firebase without letting a misconfiguration take the app down.
///
/// This app is offline-first by design, so the entire data-entry, photo and
/// PDF pipeline has to work whether or not Firebase came up. Rather than
/// `await Firebase.initializeApp()` in `main` and crash on a missing
/// `google-services.json`, we record the failure and let the UI degrade:
/// sync and login are disabled and a banner explains why, but an operator can
/// still capture and print cards.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static final FirebaseBootstrap instance = FirebaseBootstrap._();

  bool _ready = false;
  Object? _error;

  /// True once Firebase has initialised and Firestore has been configured.
  bool get isReady => _ready;

  /// Non-null when initialisation failed. Surfaced verbatim in the debug
  /// banner so setup problems are diagnosable without a log dump.
  Object? get error => _error;

  String get statusMessage {
    if (_ready) return 'Firebase connected';
    if (_error == null) return 'Firebase not initialised';
    return 'Firebase unavailable: $_error';
  }

  Future<void> initialise() async {
    if (_ready) return;
    try {
      // No explicit FirebaseOptions: on Android the values are read from
      // android/app/google-services.json by the Google Services Gradle plugin.
      // Run `flutterfire configure` to generate firebase_options.dart if you
      // later add iOS/web/desktop targets, then pass options here.
      await Firebase.initializeApp();

      // Offline persistence is what makes an operator's day survive a dead
      // mobile signal: reads are served from the local cache and writes are
      // replayed when the connection returns.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _ready = true;
      _error = null;
    } on Object catch (e, stack) {
      _ready = false;
      _error = e;
      // Not fatal - see the class doc. Logged only in debug so a release build
      // does not leak project details into logcat.
      if (kDebugMode) {
        debugPrint('Firebase init failed (continuing offline): $e\n$stack');
      }
    }
  }
}
