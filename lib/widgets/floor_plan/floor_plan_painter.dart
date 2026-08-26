import 'package:flutter/material.dart';

import '../../core/models/floor_plan.dart';

// Отрисовывает план помещения (зоны/стены/окна/двери) в тех же условных
// единицах координат, что и `x`/`y` из `floorPlan`/`tables` — масштабирование
// и позиционирование в реальные пиксели экрана делает вызывающий виджет
// (InteractiveViewer + фиксированный размер холста), не этот painter.
class FloorPlanPainter extends CustomPainter {
  final FloorPlan floorPlan;

  FloorPlanPainter(this.floorPlan) : super(repaint: null);

  static const _wallColor = Color(0xFF424242);
  static const _windowColor = Color(0xFF64B5F6);
  static const _doorColor = Color(0xFF8D6E63);

  @override
  void paint(Canvas canvas, Size size) {
    _paintZones(canvas);
    _paintWalls(canvas);
    _paintOpenings(canvas, floorPlan.windows, _windowColor);
    _paintOpenings(canvas, floorPlan.doors, _doorColor, dashed: true);
  }

  void _paintZones(Canvas canvas) {
    for (final zone in floorPlan.zones) {
      final rect = Rect.fromLTWH(zone.x, zone.y, zone.w, zone.h);
      final fillPaint = Paint()
        ..color = zone.color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      final borderPaint = Paint()
        ..color = zone.color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRect(rect, borderPaint);

      if (zone.name.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: zone.name,
            style: TextStyle(color: zone.color.withValues(alpha: 0.9), fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: zone.w);
        textPainter.paint(canvas, Offset(zone.x + 4, zone.y + 4));
      }
    }
  }

  void _paintWalls(Canvas canvas) {
    final paint = Paint()
      ..color = _wallColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final wall in floorPlan.walls) {
      if (wall.points.length < 2) continue;
      final path = Path()..moveTo(wall.points.first.dx, wall.points.first.dy);
      for (final point in wall.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintOpenings(Canvas canvas, List<FloorPlanOpening> openings, Color color,
      {bool dashed = false}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final opening in openings) {
      final start = Offset(opening.x1, opening.y1);
      final end = Offset(opening.x2, opening.y2);
      if (!dashed) {
        canvas.drawLine(start, end, paint);
        continue;
      }
      _drawDashedLine(canvas, start, end, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 4.0;
    const gapLength = 3.0;
    final total = (end - start).distance;
    if (total == 0) return;
    final direction = (end - start) / total;
    var covered = 0.0;
    while (covered < total) {
      final segmentEnd = (covered + dashLength).clamp(0, total).toDouble();
      canvas.drawLine(
        start + direction * covered,
        start + direction * segmentEnd,
        paint,
      );
      covered += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) =>
      oldDelegate.floorPlan.updatedAt != floorPlan.updatedAt ||
      !identical(oldDelegate.floorPlan, floorPlan);
}
