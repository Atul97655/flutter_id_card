import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';

/// Which backdrop a screen sits on.
enum GlassBackdrop {
  /// Pale blue into lavender. The card pipeline.
  blue,

  /// A calmer wash. Profile and settings.
  calm,

  /// Green-tinted. The conversation.
  chat,
}

/// A page with a gradient backdrop and a transparent chrome.
///
/// Every redesigned screen is one of these. It exists so that no screen has
/// to remember which gradient it belongs to, and so that the backdrop is a
/// single widget rather than a Container copied twenty-nine times - which is
/// how the old screens drifted apart from each other in the first place.
///
/// The gradient is painted once, behind everything, and nothing above it is
/// opaque. That is what makes the glass read: a frosted card only looks like
/// glass if there is something underneath worth seeing through it.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.child,
    this.backdrop = GlassBackdrop.blue,
    this.header,
    this.bottomBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });

  final Widget child;
  final GlassBackdrop backdrop;

  /// Drawn above [child], outside the scroll view. Use for a screen header
  /// that should not scroll away.
  final Widget? header;

  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  LinearGradient get _gradient => switch (backdrop) {
    GlassBackdrop.blue => AppGradients.pageBlue,
    GlassBackdrop.calm => AppGradients.pageCalm,
    GlassBackdrop.chat => AppGradients.pageChat,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBody: true,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: _gradient),
        child: Stack(
          children: <Widget>[
            // Two soft blooms, the way the reference images have them. Drawn
            // with a radial gradient rather than a blurred circle: a
            // BackdropFilter here would blur the whole page behind every
            // other surface on it.
            const Positioned(
              top: -90,
              right: -60,
              child: _Bloom(size: 260, color: Color(0x33A9C4F5)),
            ),
            const Positioned(
              bottom: -120,
              left: -80,
              child: _Bloom(size: 300, color: Color(0x2ECBC3F2)),
            ),
            SafeArea(
              bottom: false,
              child: header == null
                  ? child
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        header!,
                        Expanded(child: child),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// A screen title, its supporting line, and optional actions.
///
/// The reference designs put the title directly on the page rather than in a
/// bar. Keeping it as one widget means the title and its subtitle can never
/// drift apart in size or spacing between screens, which is most of what
/// made the old screens look like different apps.
class GlassHeader extends StatelessWidget {
  const GlassHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const <Widget>[],
    this.onDark = false,
    this.padding,
  });

  final String title;
  final String? subtitle;

  /// When set, a round glass back button is drawn before the title.
  final VoidCallback? onBack;

  final List<Widget> actions;

  /// Recolours the text for a navy header block.
  final bool onDark;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.lg,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            GlassIconButton(
              icon: Icons.arrow_back,
              onTap: onBack!,
              onDark: onDark,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: onDark
                      ? AppTypography.displayOnDark
                      : AppTypography.display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: onDark
                        ? AppTypography.displaySubOnDark
                        : AppTypography.displaySub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A circular glass button, for header actions.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.onDark = false,
    this.badge = false,
    this.tooltip,
    this.size = 44,
  });

  final IconData icon;

  /// Null disables the button and dims it. A header action that cannot be
  /// used while a save is in flight has to look unusable, or it just gets
  /// pressed repeatedly.
  final VoidCallback? onTap;

  final bool onDark;

  /// A small dot in the corner. Used for "there is something unread here",
  /// where a number would be more precision than the glance needs.
  final bool badge;

  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    Widget button = GlassSurface(
      width: size,
      height: size,
      radius: BorderRadius.circular(size / 2),
      fill: onDark ? const Color(0x2EFFFFFF) : AppColors.glassFillStrong,
      borderColor: onDark ? const Color(0x3DFFFFFF) : AppColors.glassBorder,
      shadows: onDark ? const <BoxShadow>[] : null,
      sheen: false,
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(
            icon,
            size: size * 0.46,
            color: (onDark ? AppColors.onDark : AppColors.ink).withValues(
              alpha: enabled ? 1 : 0.4,
            ),
          ),
          if (badge)
            Positioned(
              top: size * 0.24,
              right: size * 0.26,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.rejected,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
