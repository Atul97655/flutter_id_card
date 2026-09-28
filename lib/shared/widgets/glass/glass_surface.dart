import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';

/// How hard a glass surface works.
///
/// This exists because real blur is not free. `BackdropFilter` forces the
/// compositor to save the layer behind it, blur it, and draw it back - once
/// per filter, every frame. One of those on a header costs nothing you would
/// notice. Twenty of them, one per row of a scrolling list, is how a cheap
/// Android tablet drops to fifteen frames a second.
///
/// So a surface declares what it is, and gets the cheapest treatment that
/// still looks right in that position.
enum GlassDepth {
  /// No blur. A gradient, a hairline border and a shadow.
  ///
  /// Looks identical to real glass when the thing behind it is a smooth page
  /// gradient - which, on every screen in this app, it is. This is the right
  /// choice for anything that repeats: list rows, stat tiles, message
  /// bubbles, cards inside a scroll view.
  flat,

  /// Real blur, lightly.
  ///
  /// For chrome that does not repeat and does overlap moving content: a
  /// header, the bottom navigation bar, a composer.
  frosted,

  /// Real blur, heavily. Dialogs and sheets, where the content behind is
  /// meant to recede.
  deep,
}

/// A frosted surface.
///
/// The one primitive every other glass widget is built from. Everything it
/// draws is a token - the fill, the border, the sheen, the shadow - so a
/// change to the design system moves every surface in the app at once, which
/// was the whole point of centralising them.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.depth = GlassDepth.flat,
    this.radius,
    this.padding,
    this.margin,
    this.fill,
    this.borderColor,
    this.shadows,
    this.sheen = true,
    this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final GlassDepth depth;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Overrides the default translucent white. Used for tinted surfaces - a
  /// status card, an outgoing message.
  final Color? fill;

  final Color? borderColor;
  final List<BoxShadow>? shadows;

  /// The top-left highlight. Off for very small surfaces, where a diagonal
  /// gradient across 28 logical pixels just looks like a smudge.
  final bool sheen;

  final VoidCallback? onTap;
  final double? width;
  final double? height;

  double get _blurSigma => switch (depth) {
    GlassDepth.flat => 0,
    GlassDepth.frosted => 14,
    GlassDepth.deep => 26,
  };

  @override
  Widget build(BuildContext context) {
    final BorderRadius r = radius ?? AppRadius.cardR;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? AppColors.glassFill,
        borderRadius: r,
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
          width: 1,
        ),
        gradient: sheen ? AppGradients.glassSheen : null,
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    if (_blurSigma > 0) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: surface,
      );
    }

    // The clip goes OUTSIDE the blur: a BackdropFilter with no clip blurs the
    // entire layer behind it, not just the area under this widget, which
    // shows up as the whole screen going soft the moment one card appears.
    Widget result = ClipRRect(borderRadius: r, child: surface);

    if (onTap != null) {
      result = _Pressable(onTap: onTap!, radius: r, child: result);
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadows ?? AppShadows.card,
      ),
      child: result,
    );
  }
}

/// Press feedback for a glass surface.
///
/// A scale rather than a ripple. An ink splash needs an opaque Material to
/// paint on, and on a translucent surface it either disappears or smears -
/// so the whole surface dips instead, which reads correctly on glass and
/// costs one animation.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    required this.radius,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius radius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
