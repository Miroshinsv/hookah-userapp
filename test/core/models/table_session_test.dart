import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/table_session.dart';

void main() {
  group('TableSession.fromJson', () {
    test('parses a full response', () {
      final session = TableSession.fromJson({
        'sessionId': '10',
        'tableId': '1',
        'orderId': '5',
        'guestCount': 3,
        'status': 'open',
        'openedAt': '2026-08-03T12:00:00Z',
      });

      expect(session.sessionId, '10');
      expect(session.tableId, '1');
      expect(session.orderId, '5');
      expect(session.guestCount, 3);
      expect(session.status, 'open');
      expect(session.openedAt, '2026-08-03T12:00:00Z');
    });

    test('handles missing optional fields', () {
      final session = TableSession.fromJson({
        'sessionId': '10',
        'tableId': '1',
        'guestCount': 1,
        'status': 'open',
      });

      expect(session.orderId, isNull);
      expect(session.openedAt, isNull);
    });
  });
}
