import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<YOLOResult> results;

  BoundingBoxPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var result in results) {
      final box = result.boundingBox;

      final rect = Rect.fromLTWH(
        box.left,
        box.top,
        box.width,
        box.height,
      );

      canvas.drawRect(rect, paint);

      final textSpan = TextSpan(
        text: '${result.className} ${(result.confidence * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          backgroundColor: Colors.white,
        ),
      );

      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(box.left, box.top - 14));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.results != results;
  }
}
