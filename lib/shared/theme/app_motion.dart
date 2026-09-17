import 'package:flutter/material.dart';

/// The app's motion vocabulary.
///
/// Every animated surface pulls its timing from here rather than inventing a
/// duration, so the whole app decelerates the same way. Two rules shape these
/// numbers:
///
///   * **Operators use this for hours on cheap Android tablets.** Anything
///     slower than ~300 ms starts to feel like lag rather than polish, and a
///     tablet that drops frames makes a long animation look broken. Nothing
///     here blocks input - animations are feedback, never a gate.
///   * **Motion should explain the change, not decorate it.** Things that
///     arrive slide up a little; things that swap cross-fade; things that
///     respond to a finger scale down under it.
final class AppMotion {
  const AppMotion._();

  /// Ripples, chip colour changes - anything that must feel instant.
  static const Duration fast = Duration(milliseconds: 140);

  /// The default. Card expansion, list entry, status changes.
  static const Duration normal = Duration(milliseconds: 240);

  /// Full-screen transitions and anything crossing a large distance.
  static const Duration slow = Duration(milliseconds: 340);

  /// Standard easing for something entering or settling.
  static const Curve decelerate = Curves.easeOutCubic;

  /// For something that leaves or collapses.
  static const Curve accelerate = Curves.easeInCubic;

  /// Material 3's emphasised curve - a touch of overshoot for elements that
  /// should feel physical (buttons, sheets).
  static const Curve emphasized = Curves.easeOutBack;

  /// Symmetric easing for a cross-fade, where neither end is "arriving".
  static const Curve standard = Curves.easeInOut;

  /// Per-item delay in a staggered list. Kept small: with 12 visible rows a
  /// 40 ms step already means the last row lands half a second late.
  static const Duration stagger = Duration(milliseconds: 34);

  /// Cap on stagger depth. Beyond this, items share the last slot so a long
  /// list never has a row that visibly waits.
  static const int maxStaggerIndex = 8;
}

/// Fades and lifts a child into place, optionally staggered by list position.
///
/// Used for list rows and dashboard tiles. The slide is deliberately small
/// (12 px) - a large travel distance reads as sluggish when eight of them run
/// at once.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = AppMotion.normal,
    this.offset = 12,
  });

  final Widget child;

  /// Position in a list. Later items start later, up to
  /// [AppMotion.maxStaggerIndex].
  final int index;

  final Duration duration;

  /// Vertical travel in logical pixels.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    final int step = widget.index.clamp(0, AppMotion.maxStaggerIndex);
    final Duration delay = AppMotion.stagger * step;

    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      // Not `Future.delayed(...).then` - if the widget is disposed mid-delay
      // (a fast scroll unmounting the row) forwarding a dead controller
      // throws. The mounted check is the guard.
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> eased = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.decelerate,
    );

    return AnimatedBuilder(
      animation: eased,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: eased.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - eased.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Wraps a tappable surface so it scales down under a finger.
///
/// Material's ink ripple alone is easy to miss on a low-contrast card, and on a
/// resistive tablet screen the physical feedback of the surface moving is what
/// tells an operator the tap registered. Falls back to doing nothing when
/// [onTap] is null, so a disabled row does not appear pressable.
class PressableSurface extends StatefulWidget {
  const PressableSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far down it presses. 0.97 is deliberately subtle - a deeper press
  /// looks like the layout is jumping.
  final double scale;

  final BorderRadius? borderRadius;

  @override
  State<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<PressableSurface> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.decelerate,
        child: widget.child,
      ),
    );
  }
}

/// Cross-fades between children whose size also changes, without the jump
/// `AnimatedSwitcher` alone produces when the two have different heights.
class SmoothSwitcher extends StatelessWidget {
  const SmoothSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.normal,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.decelerate,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppMotion.decelerate,
        switchOutCurve: AppMotion.accelerate,
        // The default layout builder stacks children centred, which makes a
        // shrinking list appear to float. Top-aligning keeps content anchored.
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: alignment,
          children: <Widget>[...previous, ?current],
        ),
        child: child,
      ),
    );
  }
}

/// Counts up to [value] when it changes, instead of snapping.
///
/// Used on dashboard stat tiles: a number that animates draws the eye to what
/// changed, which is the whole point of a dashboard.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.duration = AppMotion.slow,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AppMotion.decelerate,
      builder: (BuildContext context, double v, _) =>
          Text(v.round().toString(), style: style),
    );
  }
}

/// Slide-up + fade page transition, used for every pushed route.
///
/// Flutter's default on Android is a vertical slide with no fade, which on a
/// tablet reads as heavy. This is shorter and lighter, and it reverses cleanly
/// so a back gesture feels symmetrical.
Widget buildAppPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final Animation<double> eased = CurvedAnimation(
    parent: animation,
    curve: AppMotion.decelerate,
    reverseCurve: AppMotion.accelerate,
  );

  return FadeTransition(
    opacity: eased,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.035),
        end: Offset.zero,
      ).animate(eased),
      child: child,
    ),
  );
}
