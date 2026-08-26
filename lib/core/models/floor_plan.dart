import 'dart:convert';
import 'dart:ui';

import '../utils/logger.dart';

const _tag = 'FloorPlan';

class FloorPlanWall {
  final List<Offset> points;

  const FloorPlanWall({required this.points});

  factory FloorPlanWall.fromJson(Map<String, dynamic> json) => FloorPlanWall(
        points: (json['points'] as List<dynamic>? ?? const [])
            .map((e) => _parsePoint(e as Map<String, dynamic>))
            .toList(),
      );
}

// Общая форма для windows/doors — оба заданы отрезком (x1,y1)-(x2,y2).
// `swing` присутствует только у дверей, для выбора стола не критичен
// (согласно ТЗ), но сохраняем на случай будущей отрисовки дуги открывания.
class FloorPlanOpening {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String? swing;

  const FloorPlanOpening({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.swing,
  });

  factory FloorPlanOpening.fromJson(Map<String, dynamic> json) => FloorPlanOpening(
        x1: (json['x1'] as num?)?.toDouble() ?? 0.0,
        y1: (json['y1'] as num?)?.toDouble() ?? 0.0,
        x2: (json['x2'] as num?)?.toDouble() ?? 0.0,
        y2: (json['y2'] as num?)?.toDouble() ?? 0.0,
        swing: json['swing'] as String?,
      );
}

class FloorPlanZone {
  final double x;
  final double y;
  final double w;
  final double h;
  final String name;
  final Color color;

  const FloorPlanZone({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.name,
    required this.color,
  });

  factory FloorPlanZone.fromJson(Map<String, dynamic> json) => FloorPlanZone(
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
        w: (json['w'] as num?)?.toDouble() ?? 0.0,
        h: (json['h'] as num?)?.toDouble() ?? 0.0,
        name: json['name'] as String? ?? '',
        color: _parseColor(json['color'] as String?),
      );
}

class FloorPlan {
  final List<FloorPlanWall> walls;
  final List<FloorPlanOpening> windows;
  final List<FloorPlanOpening> doors;
  final List<FloorPlanZone> zones;
  final String? updatedAt;

  const FloorPlan({
    this.walls = const [],
    this.windows = const [],
    this.doors = const [],
    this.zones = const [],
    this.updatedAt,
  });

  static const empty = FloorPlan();

  // Бэкенд отдаёт `walls` как JSON-строку (единый блоб плана помещения), а не
  // как настоящий GraphQL-объект — распаковываем вручную. Пустая строка/"[]"
  // означает "рисовать пустой план, только со столами" (см. ТЗ) — это не
  // ошибка, поэтому не логируем как WARN.
  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    final raw = json['walls'];
    final updatedAt = json['updatedAt'] as String?;
    if (raw is! String || raw.isEmpty || raw == '[]') {
      AppLogger.d(_tag, 'empty floor plan blob — rendering tables only');
      return FloorPlan(updatedAt: updatedAt);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        AppLogger.w(_tag, 'floor plan blob decoded to non-object: ${decoded.runtimeType}');
        return FloorPlan(updatedAt: updatedAt);
      }
      final walls = (decoded['walls'] as List<dynamic>? ?? const [])
          .map((e) => FloorPlanWall.fromJson(e as Map<String, dynamic>))
          .toList();
      final windows = (decoded['windows'] as List<dynamic>? ?? const [])
          .map((e) => FloorPlanOpening.fromJson(e as Map<String, dynamic>))
          .toList();
      final doors = (decoded['doors'] as List<dynamic>? ?? const [])
          .map((e) => FloorPlanOpening.fromJson(e as Map<String, dynamic>))
          .toList();
      final zones = (decoded['zones'] as List<dynamic>? ?? const [])
          .map((e) => FloorPlanZone.fromJson(e as Map<String, dynamic>))
          .toList();
      AppLogger.d(_tag,
          'parsed floor plan walls=${walls.length} windows=${windows.length} doors=${doors.length} zones=${zones.length}');
      return FloorPlan(
        walls: walls,
        windows: windows,
        doors: doors,
        zones: zones,
        updatedAt: updatedAt,
      );
    } catch (e, st) {
      AppLogger.w(_tag, 'failed to decode floor plan blob', e, st);
      return FloorPlan(updatedAt: updatedAt);
    }
  }
}

Offset _parsePoint(Map<String, dynamic> json) => Offset(
      (json['x'] as num?)?.toDouble() ?? 0.0,
      (json['y'] as num?)?.toDouble() ?? 0.0,
    );

const _defaultZoneColor = Color(0xFF9E9E9E);

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return _defaultZoneColor;
  try {
    var value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    return Color(int.parse(value, radix: 16));
  } catch (e) {
    AppLogger.w(_tag, 'failed to parse zone color: $hex', e);
    return _defaultZoneColor;
  }
}
