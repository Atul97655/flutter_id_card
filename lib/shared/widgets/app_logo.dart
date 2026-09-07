import 'package:flutter/material.dart';

/// Official app logo for "ID entity".
///
/// Displays the branded app mark asset (`assets/images/app_icon.png`)
/// with crisp scaling, rounded squircle corners, and a subtle drop shadow.
/// Retains a vector painter fallback for test/headless environments.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.onDark = false,
  });

  final double size;

  /// Inverts/adjusts styling if placed on a dark/coloured background.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final double radius = size * 0.22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: onDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return _FallbackLogo(size: size, onDark: onDark);
          },
        ),
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({
    required this.size,
    required this.onDark,
  });

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(
          cardColor: onDark ? Colors.white : scheme.primary,
          accentColor: onDark ? scheme.primary : Colors.white,
          detailColor: onDark
              ? scheme.primary.withValues(alpha: 0.45)
              : Colors.white70,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({
    required this.cardColor,
    required this.accentColor,
    required this.detailColor,
  });

  final Color cardColor;
  final Color accentColor;
  final Color detailColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Card body, in the 54:86 proportion of a real vertical ID card.
    final double cardW = w * 0.66;
    final double cardH = cardW * 86 / 54;
    final Rect card = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: cardW,
      height: cardH.clamp(0, h),
    );
    final RRect body = RRect.fromRectAndRadius(card, Radius.circular(w * 0.07));

    canvas.drawRRect(body, Paint()..color = cardColor);

    // Header band.
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      Rect.fromLTWH(card.left, card.top, card.width, card.height * 0.22),
      Paint()..color = accentColor.withValues(alpha: 0.9),
    );
    canvas.restore();

    // Photo block.
    final double photoW = card.width * 0.42;
    final double photoH = photoW * 1.25;
    final Rect photo = Rect.fromLTWH(
      card.left + (card.width - photoW) / 2,
      card.top + card.height * 0.30,
      photoW,
      photoH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(photo, Radius.circular(w * 0.02)),
      Paint()..color = accentColor,
    );

    // Head-and-shoulders glyph inside the photo block.
    final Paint glyph = Paint()..color = cardColor;
    canvas.drawCircle(
      Offset(photo.center.dx, photo.top + photo.height * 0.33),
      photo.width * 0.20,
      glyph,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          photo.left + photo.width * 0.18,
          photo.top + photo.height * 0.58,
          photo.width * 0.64,
          photo.height * 0.30,
        ),
        Radius.circular(photo.width * 0.16),
      ),
      glyph,
    );

    // Two text rows below the photo.
    final Paint line = Paint()
      ..color = detailColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = card.height * 0.035;

    final double firstRowY = photo.bottom + card.height * 0.10;
    canvas.drawLine(
      Offset(card.left + card.width * 0.18, firstRowY),
      Offset(card.right - card.width * 0.18, firstRowY),
      line,
    );
    final double secondRowY = firstRowY + card.height * 0.09;
    canvas.drawLine(
      Offset(card.left + card.width * 0.28, secondRowY),
      Offset(card.right - card.width * 0.28, secondRowY),
      line,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      oldDelegate.cardColor != cardColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.detailColor != detailColor;
}
