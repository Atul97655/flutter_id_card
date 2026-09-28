import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';

/// The primary action: a gradient pill that dips when pressed.
///
/// Not a themed `FilledButton`. The reference design puts a gradient, a
/// coloured glow and an inner highlight on this, none of which
/// `ButtonStyle` expresses, and faking them with a themed button meant
/// reaching past the theme in every screen anyway.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.busy = false,
    this.gradient,
    this.expand = true,
  });

  final String label;

  /// Null disables the button. A disabled action loses its glow, because a
  /// glowing button nobody can press is a button people keep pressing.
  final VoidCallback? onPressed;

  final IconData? icon;
  final IconData? trailingIcon;
  final bool busy;
  final LinearGradient? gradient;
  final bool expand;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.busy;
    final LinearGradient g = widget.gradient ?? AppGradients.action;

    final Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.busy)
          const SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.onDark),
            ),
          )
        else ...<Widget>[
          if (widget.icon != null) ...<Widget>[
            Icon(widget.icon, size: 19, color: AppColors.onDark),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              widget.label,
              style: AppTypography.button,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.trailingIcon != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Icon(widget.trailingIcon, size: 18, color: AppColors.onDark),
          ],
        ],
      ],
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.5,
          duration: const Duration(milliseconds: 160),
          child: Container(
            height: 56,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: g,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: enabled ? AppShadows.glow(g.colors.last) : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // The inner highlight along the top edge - what makes the
                // pill look lit rather than merely coloured.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: <Color>[Color(0x2BFFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded-square tinted icon tile.
///
/// The single most repeated shape in the reference designs - it sits before
/// every stat, every form field, every utility row. Having it as one widget
/// is what keeps them all the same size, which is most of why those screens
/// look tidy.
class GlassIconTile extends StatelessWidget {
  const GlassIconTile({
    super.key,
    required this.icon,
    this.tint = AppColors.royal,
    this.background,
    this.size = 44,
  });

  final IconData icon;
  final Color tint;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Icon(icon, size: size * 0.48, color: tint),
    );
  }
}

/// A status pill: soft tinted surface, saturated icon and label.
class GlassStatusBadge extends StatelessWidget {
  const GlassStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.tint,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 13 : 15, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTypography.badge.copyWith(
              color: color,
              fontSize: compact ? 11.5 : 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// One figure in a row of statistics: icon tile, number, label.
class GlassStat extends StatelessWidget {
  const GlassStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GlassIconTile(icon: icon, tint: tint, size: 40),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: AppTypography.stat),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.statLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (onTap == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}

/// A row inside a glass panel: icon tile, title, optional subtitle, chevron.
///
/// The workhorse of the Profile screen and half the admin section.
class GlassListRow extends StatelessWidget {
  const GlassListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tint = AppColors.royal,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color tint;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.fieldR,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            GlassIconTile(icon: icon, tint: tint),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTypography.section.copyWith(color: titleColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.support,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (showChevron && trailing == null)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}
