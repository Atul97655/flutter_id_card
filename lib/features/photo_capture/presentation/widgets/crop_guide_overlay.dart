import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';

/// Dims everything outside the 1.2 : 1.5 in crop box and draws framing guides
/// inside it.
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
  });

  final bool showEyeLine;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CropGuidePainter(
          showEyeLine: showEyeLine,
          borderColor: borderColor,
        ),
      ),
    );
  }
}

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter({required this.showEyeLine, required this.borderColor});

  final bool showEyeLine;
  final Color borderColor;

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
      ..strokeWidth = 2
      ..color = borderColor;
    canvas.drawRRect(rounded, stroke);

    // Corner ticks, which read as a viewfinder rather than a plain rectangle.
    final Paint corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
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
        ..color = borderColor.withValues(alpha: 0.55)
        ..strokeWidth = 1;

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

    // Size caption.
    final TextPainter label = TextPainter(
      text: const TextSpan(
        text: '1.2 x 1.5 in  -  keep the eyes on the line',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    label.paint(
      canvas,
      Offset((size.width - label.width) / 2, box.bottom + 12),
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
      oldDelegate.borderColor != borderColor;
}
