import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/providers/sync_providers.dart';
import 'package:flutter_id_card/shared/router/app_router.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class IdCardApp extends ConsumerWidget {
  const IdCardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    // Keeps the background sync worker running in step with the session.
    // Watched here, at the root, so it stays alive across every screen rather
    // than starting and stopping as the operator navigates.
    ref.watch(syncLifecycleProvider);

    return MaterialApp.router(
      title: 'ID Card System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        // Operators run this on tablets that often have display scaling cranked
        // up. Clamping keeps the form usable without letting a 2.0x setting
        // push the save button off screen.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
