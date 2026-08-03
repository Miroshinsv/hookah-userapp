import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/session_item.dart';

void main() {
  group('SessionItem.fromJson', () {
    test('parses a full response', () {
      final item = SessionItem.fromJson({
        'itemId': '1',
        'sessionId': '10',
        'loungeId': '2',
        'menuItemId': '7',
        'name': 'Кола',
        'price': 150.0,
        'quantity': 2,
        'status': 'new',
        'createdAt': '2026-08-03T12:00:00Z',
      });

      expect(item.itemId, '1');
      expect(item.sessionId, '10');
      expect(item.loungeId, '2');
      expect(item.menuItemId, '7');
      expect(item.name, 'Кола');
      expect(item.price, 150.0);
      expect(item.quantity, 2);
      expect(item.status, 'new');
      expect(item.createdAt, '2026-08-03T12:00:00Z');
    });

    test('handles missing optional fields with safe defaults', () {
      final item = SessionItem.fromJson({
        'itemId': '1',
        'sessionId': '10',
        'loungeId': '2',
        'menuItemId': '7',
        'name': 'Кола',
      });

      expect(item.price, 0.0);
      expect(item.quantity, 1);
      expect(item.status, 'new');
      expect(item.createdAt, isNull);
    });
  });
}
