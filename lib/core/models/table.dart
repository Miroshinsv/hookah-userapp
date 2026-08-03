import 'dart:convert';

class TableItem {
  final String tableId;
  final String loungeId;
  final double x;
  final double y;
  final double rotation;
  final int seats;
  final String? label;
  final List<String> properties;

  const TableItem({
    required this.tableId,
    required this.loungeId,
    required this.x,
    required this.y,
    required this.rotation,
    required this.seats,
    this.label,
    this.properties = const [],
  });

  factory TableItem.fromJson(Map<String, dynamic> json) => TableItem(
        tableId: json['tableId'] as String? ?? '',
        loungeId: json['loungeId'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        seats: (json['seats'] as num?)?.toInt() ?? 0,
        label: json['label'] as String?,
        properties: _parseProperties(json['properties']),
      );

  // Бэкенд отдаёт `properties` как String (gql.String в схеме), содержащий
  // JSON-массив свойств (например '["tv","playstation"]"), а не как настоящий
  // GraphQL-список — распаковываем вручную.
  static List<String> _parseProperties(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }
}
