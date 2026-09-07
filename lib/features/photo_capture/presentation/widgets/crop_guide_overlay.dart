import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';

/// Dims everything outside the 1.2 : 1.5 in crop box and draws framing guides
/// inside it, along with a live feedback badge for face detection.
///
/// The operator needs to see the *printed* crop while shooting, not after: a
/// head that looks fine in a 16:9 viewfinder is routinely cut off once the 4:5
/// card crop is applied. The horizontal line marks where the eyes should sit
/// for passport-style framing.
class CropGuideOverlay extends StatelessWidget {
  const CropGuideOverlay({
    super.key,
    this.showEyeLine = true,
    this.borderColor = Colors.white,
    this.statusMessage = '1.2 x 1.5 in  -  keep the eyes on the line',
    this.statusColor = Colors.white,
  });

  final bool showEyeLine;
  final Color borderColor;
  final String statusMessage;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CropGuidePainter(
          showEyeLine: showEyeLine,
          borderColor: borderColor,
          statusMessage: statusMessage,
          statusColor: statusColor,
        ),
      ),
    );
  }
}

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter({
    required this.showEyeLine,
    required this.borderColor,
    required this.statusMessage,
    required this.statusColor,
  });

  final bool showEyeLine;
  final Color borderColor;
  final String statusMessage;
  final Color statusColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Largest 4:5 box that fits, with a margin so the guide never touches the
    // screen edge.
    const double margin = 0.86;
    double boxHeight = size.height * margin;
    double boxWidth = boxHeight * PhotoSpec.aspectRatio;
    if (boxWidth > size.width * margin) {
      boxWidth = size.width * margin;
      boxHeight = boxWidth / PhotoSpec.aspectRatio;
    }

    final Rect box = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: boxWidth,
      height: boxHeight,
    );
    final RRect rounded = RRect.fromRectAndRadius(box, const Radius.circular(6));

    // Scrim everywhere except the crop box.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rounded),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = borderColor;
    canvas.drawRRect(rounded, stroke);

    // Corner ticks, which read as a viewfinder rather than a plain rectangle.
    final Paint corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = borderColor;
    final double tick = boxWidth * 0.12;

    void drawCorner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(tick * dx, 0), corner);
      canvas.drawLine(origin, origin.translate(0, tick * dy), corner);
    }

    drawCorner(box.topLeft, 1, 1);
    drawCorner(box.topRight, -1, 1);
    drawCorner(box.bottomLeft, 1, -1);
    drawCorner(box.bottomRight, -1, -1);

    if (showEyeLine) {
      final Paint guide = Paint()
        ..color = borderColor.withValues(alpha: 0.65)
        ..strokeWidth = 1.2;

      // Where the face centre should land - the same fraction the auto-crop
      // targets, so the guide and the processor agree.
      final double eyeY = box.top + box.height * PhotoSpec.faceCentreYFraction;
      _dashedLine(canvas, Offset(box.left, eyeY), Offset(box.right, eyeY), guide);

      // Vertical centre line for left/right alignment.
      _dashedLine(
        canvas,
        Offset(box.center.dx, box.top),
        Offset(box.center.dx, box.bottom),
        guide,
      );
    }

    // Status pill badge with message and feedback
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: statusMessage,
        style: TextStyle(
          color: statusColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 48);

    const double pillPaddingH = 14.0;
    const double pillPaddingV = 7.0;
    final Rect pillRect = Rect.fromCenter(
      center: Offset(size.width / 2, box.bottom + 26),
      width: label.width + pillPaddingH * 2,
      height: label.height + pillPaddingV * 2,
    );

    final RRect roundedPill = RRect.fromRectAndRadius(
      pillRect,
      const Radius.circular(16),
    );

    canvas.drawRRect(
      roundedPill,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      roundedPill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = borderColor.withValues(alpha: 0.85),
    );

    label.paint(
      canvas,
      Offset(pillRect.left + pillPaddingH, pillRect.top + pillPaddingV),
    );
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const double dash = 6;
    const double gap = 5;
    final double total = (to - from).distance;
    if (total <= 0) return;
    final Offset step = (to - from) / total;

    double travelled = 0;
    while (travelled < total) {
      final double end = (travelled + dash).clamp(0, total);
      canvas.drawLine(
        from + step * travelled,
        from + step * end,
        paint,
      );
      travelled = end + gap;
    }
  }

  @override
  bool shouldRepaint(_CropGuidePainter oldDelegate) =>
      oldDelegate.showEyeLine != showEyeLine ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.statusMessage != statusMessage ||
      oldDelegate.statusColor != statusColor;
}
