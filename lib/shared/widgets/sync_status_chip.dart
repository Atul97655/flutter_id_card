import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';

/// Compact status pill.
///
/// Each status carries its own icon as well as its own colour: the pending
/// orange and failed red are hard to tell apart with red-green colour vision
/// deficiency, and this indicator is the operator's only signal that a day's
/// work has actually left the device.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.status, this.dense = false});

  final SyncStatus status;
  final bool dense;

  static Color colorFor(SyncStatus status) => switch (status) {
        SyncStatus.pending => StatusColors.pending,
        SyncStatus.syncing => StatusColors.syncing,
        SyncStatus.synced => StatusColors.synced,
        SyncStatus.failed => StatusColors.failed,
      };

  static IconData iconFor(SyncStatus status) => switch (status) {
        SyncStatus.pending => Icons.schedule,
        SyncStatus.syncing => Icons.sync,
        SyncStatus.synced => Icons.cloud_done,
        SyncStatus.failed => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final Color color = colorFor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(iconFor(status), size: dense ? 12 : 14, color: color),
          SizedBox(width: dense ? 4 : 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10.5 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
