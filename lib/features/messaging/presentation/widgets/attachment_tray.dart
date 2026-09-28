import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/theme/join_theme.dart';

/// What the teacher can attach to a message.
enum AttachmentChoice { document, photo, camera, idCard }

/// The tray that opens from the paperclip.
///
/// Laid out the way a consumer messaging app lays it out, with one row
/// replaced: where a payments app puts money, this puts an ID card. That is
/// the design note's point and it is a good one - the slot people already
/// reach for without reading is given to the thing this app is actually for.
///
/// Audio and Contact are drawn and disabled rather than omitted. The design
/// shows them, and leaving them out entirely would look like the tray was
/// half-built; showing them greyed with a reason says they were considered
/// and are not part of this product. Neither has any use in sending an ID
/// card to an office, and both would need a new runtime permission and a new
/// inline-transport path to exist at all.
Future<AttachmentChoice?> showAttachmentTray(BuildContext context) {
  return showModalBottomSheet<AttachmentChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext c) => const _Tray(),
  );
}

class _Tray extends StatelessWidget {
  const _Tray();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        // Material, not a decorated Container. A ListTile paints its
        // background and its tap ripple onto the nearest Material ancestor, so
        // inside a coloured Container every row here would look dead to the
        // touch - no ripple, no pressed state - while still working. Flutter
        // asserts about this in debug, which is how it was caught.
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          clipBehavior: Clip.antiAlias,
          // Scrollable, because six rows plus a handle do not fit a short
          // viewport - a phone in landscape, or one with the system text
          // size turned up, which is common among the people using this.
          // Without it the ID Card row is the one clipped off the bottom,
          // because it is last.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                _Row(
                  icon: Icons.description_outlined,
                  tint: const Color(0xFF5C6BC0),
                  label: 'Document',
                  onTap: () =>
                      Navigator.of(context).pop(AttachmentChoice.document),
                ),
                _Row(
                  icon: Icons.photo_library_outlined,
                  tint: const Color(0xFFE91E63),
                  label: 'Photos & videos',
                  onTap: () =>
                      Navigator.of(context).pop(AttachmentChoice.photo),
                ),
                _Row(
                  icon: Icons.photo_camera_outlined,
                  tint: const Color(0xFFEF5350),
                  label: 'Camera',
                  onTap: () =>
                      Navigator.of(context).pop(AttachmentChoice.camera),
                ),
                const _Row(
                  icon: Icons.mic_none_outlined,
                  tint: Color(0xFFFFA726),
                  label: 'Audio',
                  unavailable: 'Not used in this app',
                ),
                const _Row(
                  icon: Icons.person_outline,
                  tint: Color(0xFF29B6F6),
                  label: 'Contact',
                  unavailable: 'Not used in this app',
                ),
                const Divider(height: 1),
                _Row(
                  icon: Icons.badge_outlined,
                  tint: JoinTheme.header,
                  label: 'ID Card',
                  subtitle: 'Send a student ID card',
                  highlighted: true,
                  onTap: () =>
                      Navigator.of(context).pop(AttachmentChoice.idCard),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tint,
    required this.label,
    this.subtitle,
    this.onTap,
    this.unavailable,
    this.highlighted = false,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Why this row cannot be used. Present means disabled.
  final String? unavailable;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bool enabled = unavailable == null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ListTile(
        onTap: enabled ? onTap : null,
        tileColor: highlighted ? JoinTheme.accentSoft : null,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: tint, size: 21),
        ),
        title: Text(
          label,
          style: AppTypography.section.copyWith(
            fontSize: 15,
            fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: (subtitle ?? unavailable) == null
            ? null
            : Text(
                subtitle ?? unavailable!,
                style: AppTypography.support.copyWith(fontSize: 12),
              ),
      ),
    );
  }
}
