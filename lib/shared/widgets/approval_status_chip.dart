import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';

/// The review state of one entry, as a compact pill.
///
/// Shared by the admin review queue and the teacher's own submission list -
/// they must read identically, because an operator ringing the office about a
/// card describes what they see on their screen.
///
/// Colour is always paired with a distinct icon: the pending/approved pair is
/// orange/green, which is exactly the combination red-green colour blindness
/// collapses.
class ApprovalStatusChip extends StatelessWidget {
  const ApprovalStatusChip({
    super.key,
    required this.status,
    this.dense = false,
  });

  final ApprovalStatus status;

  /// Tighter padding and a smaller glyph, for use inside a list row.
  final bool dense;

  static (Color, IconData) visualsFor(ApprovalStatus status) =>
      switch (status) {
        ApprovalStatus.pending => (
            StatusColors.pending,
            Icons.pending_actions,
          ),
        ApprovalStatus.approved => (StatusColors.synced, Icons.verified),
        ApprovalStatus.rejected => (
            StatusColors.failed,
            Icons.cancel_outlined,
          ),
        ApprovalStatus.printed => (StatusColors.printed, Icons.print_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = visualsFor(status);
    final double glyph = dense ? 12 : 14;

    // Animated so a status arriving over sync visibly changes rather than
    // silently swapping while the operator is looking at the row.
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.decelerate,
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
          Icon(icon, size: glyph, color: color),
          SizedBox(width: dense ? 4 : 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: dense ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
