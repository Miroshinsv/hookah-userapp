import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/table.dart';

void main() {
  group('TableItem.fromJson', () {
    test('parses a full response', () {
      final table = TableItem.fromJson({
        'tableId': '1',
        'loungeId': '2',
        'x': 100.5,
        'y': 50,
        'rotation': 90,
        'seats': 2,
        'label': 'VIP-1',
        'properties': ['tv', 'playstation'],
      });

      expect(table.tableId, '1');
      expect(table.loungeId, '2');
      expect(table.x, 100.5);
      expect(table.y, 50.0);
      expect(table.rotation, 90.0);
      expect(table.seats, 2);
      expect(table.label, 'VIP-1');
      expect(table.properties, ['tv', 'playstation']);
    });

    test('handles missing optional fields', () {
      final table = TableItem.fromJson({
        'tableId': '1',
        'loungeId': '2',
        'seats': 1,
      });

      expect(table.label, isNull);
      expect(table.properties, isEmpty);
      expect(table.x, 0.0);
      expect(table.y, 0.0);
      expect(table.rotation, 0.0);
    });
  });
}
