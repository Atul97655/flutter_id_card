import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/parent/application/parent_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The colours of the parent screens.
///
/// Their own small palette rather than the operator app's glass theme: a
/// parent opens this a handful of times a year and should see a clean, bright,
/// friendly screen with obvious buttons, not a dense work tool.
abstract final class ParentColors {
  static const Color ink = Color(0xFF14213D);
  static const Color inkSoft = Color(0xFF5B6784);
  static const Color brand = Color(0xFF4F46E5);
  static const Color brandDeep = Color(0xFF3730A3);
  static const Color accent = Color(0xFF06B6A4);
  static const Color success = Color(0xFF12A150);
  static const Color warn = Color(0xFFE08A00);
  static const Color danger = Color(0xFFD64550);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE6E9F2);

  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  static const LinearGradient page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFEEF0FF), Color(0xFFF8F9FD)],
  );
}

/// Full-screen backdrop for every parent screen.
class ParentBackground extends StatelessWidget {
  const ParentBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ParentColors.page),
      child: child,
    );
  }
}

/// The app's mark: a rounded tile holding an ID card with a tick.
///
/// Drawn in code so it is sharp at any size, adds nothing to the download, and
/// needs no asset to be present. (The launcher icon is a separate PNG; this is
/// what the screens use.)
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: ParentColors.hero,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ParentColors.brand.withValues(alpha: 0.35),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final RRect card = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.52),
        width: w * 0.5,
        height: h * 0.62,
      ),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(card, Paint()..color = Colors.white);

    final Paint tint = Paint()..color = ParentColors.brand.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(w * 0.5, h * 0.42), w * 0.075, tint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.395, h * 0.5, w * 0.21, h * 0.1),
        Radius.circular(w * 0.05),
      ),
      tint,
    );

    final Paint line = Paint()
      ..color = ParentColors.brand.withValues(alpha: 0.35)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.035;
    canvas.drawLine(
      Offset(w * 0.4, h * 0.67),
      Offset(w * 0.6, h * 0.67),
      line,
    );

    // The tick badge: the "done" the whole app is about.
    final Offset badge = Offset(w * 0.72, h * 0.72);
    canvas.drawCircle(badge, w * 0.14, Paint()..color = ParentColors.accent);
    final Paint tick = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.045;
    final Path path = Path()
      ..moveTo(badge.dx - w * 0.055, badge.dy)
      ..lineTo(badge.dx - w * 0.01, badge.dy + w * 0.045)
      ..lineTo(badge.dx + w * 0.06, badge.dy - w * 0.04);
    canvas.drawPath(path, tick);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

/// One-tap switch between English and Hindi.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ParentStrings s = ref.watch(parentStringsProvider);
    return Material(
      color: ParentColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: ParentColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => ref.read(parentLangProvider.notifier).toggle(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.translate_rounded,
                size: 16,
                color: ParentColors.brand,
              ),
              const SizedBox(width: 6),
              Text(
                s.switchLanguage,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: ParentColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big, full-width, gradient button. Sized for thumbs, including small ones.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.onHero = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  /// On the purple hero card the button is white with purple text; elsewhere
  /// it is the brand gradient.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !busy;
    final Color fg = onHero ? ParentColors.brandDeep : Colors.white;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            gradient: onHero ? null : ParentColors.hero,
            color: onHero ? Colors.white : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: onHero
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: ParentColors.brand.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(icon, color: fg, size: 22),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
