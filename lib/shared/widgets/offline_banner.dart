import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of connectivity results from connectivity_plus.
final StreamProvider<List<ConnectivityResult>> connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((Ref ref) {
  final Connectivity conn = Connectivity();
  return conn.onConnectivityChanged;
});

/// Indicates whether the device currently has no active network interfaces.
final Provider<bool> isOfflineProvider = Provider<bool>((Ref ref) {
  final AsyncValue<List<ConnectivityResult>> results =
      ref.watch(connectivityStreamProvider);
  return results.maybeWhen(
    data: (List<ConnectivityResult> list) =>
        list.isEmpty ||
        (list.length == 1 && list.first == ConnectivityResult.none),
    orElse: () => false,
  );
});

/// Subtle, non-intrusive offline status banner.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOffline = ref.watch(isOfflineProvider);
    if (!isOffline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.amber.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ??
                  'Working offline. Entries are saved locally and will sync when connected.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
