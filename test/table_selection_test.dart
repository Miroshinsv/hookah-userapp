import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/graphql/mutations.dart';
import 'package:user_app/core/graphql/queries.dart';
import 'package:user_app/core/models/order.dart';
import 'package:user_app/screens/table/table_selection_screen.dart';

void main() {
  group('GQLQueries.isTablesEnabled', () {
    test('embeds loungeId', () {
      final query = GQLQueries.isTablesEnabled('5');
      expect(query, contains('isTablesEnabled'));
      expect(query, contains(r'"5"'));
    });

    test('escapes special characters in loungeId via jsonEncode', () {
      final query = GQLQueries.isTablesEnabled('l"1');
      expect(query, contains(r'l\"1'));
    });
  });

  group('GQLQueries.floorPlan', () {
    test('embeds loungeId and requests walls/updatedAt', () {
      final query = GQLQueries.floorPlan('5');
      expect(query, contains('floorPlan'));
      expect(query, contains(r'"5"'));
      expect(query, contains('walls'));
      expect(query, contains('updatedAt'));
    });
  });

  group('GQLQueries.activeSessions', () {
    test('includes bookedFor in the selection set', () {
      final query = GQLQueries.activeSessions('5');
      expect(query, contains('bookedFor'));
      expect(query, contains('openedAt'));
      expect(query, contains('tableId'));
    });
  });

  group('GQLMutations.openTableSession', () {
    test('embeds tableId/loungeId/orderId/guestCount and always sets failIfOccupied: true', () {
      final mutation = GQLMutations.openTableSession(
        tableId: '23',
        loungeId: '5',
        orderId: '789',
        guestCount: 2,
      );

      expect(mutation, contains('openTableSession'));
      expect(mutation, contains(r'tableId: "23"'));
      expect(mutation, contains(r'loungeId: "5"'));
      expect(mutation, contains(r'orderId: "789"'));
      expect(mutation, contains('guestCount: 2'));
      expect(mutation, contains('failIfOccupied: true'));
    });
  });

  group('GQLMutations.createOrder — table selection at creation', () {
    String baseCall({String? tableId, int? guestCount}) => GQLMutations.createOrder(
          loungeId: '5',
          flavor: 'Мята',
          phoneLast4: '1234',
          phoneMock: '+7 (900) ***-**-34',
          arrivalAt: '2026-08-25T20:00:00Z',
          tableId: tableId,
          guestCount: guestCount,
        );

    test('embeds tableId/guestCount when a table is provided', () {
      final mutation = baseCall(tableId: '17', guestCount: 2);
      expect(mutation, contains(r'tableId: "17"'));
      expect(mutation, contains('guestCount: 2'));
    });

    test('omits tableId/guestCount when no table is provided (unchanged legacy shape)', () {
      final mutation = baseCall();
      expect(mutation, isNot(contains('tableId:')));
      expect(mutation, isNot(contains('guestCount:')));
    });

    test('response selection set includes tableId/tableLabel/tableSeatConflict', () {
      final mutation = baseCall();
      expect(mutation, contains('tableId'));
      expect(mutation, contains('tableLabel'));
      expect(mutation, contains('tableSeatConflict'));
    });
  });

  group('TableSelectionResult', () {
    test('carries a null sessionId in pre-order mode (no session opened yet)', () {
      const result = TableSelectionResult(tableId: '17', tableLabel: 'VIP-1', guestCount: 2);
      expect(result.sessionId, isNull);
      expect(result.tableId, '17');
      expect(result.guestCount, 2);
    });

    test('carries a non-null sessionId for an existing-order selection', () {
      const result = TableSelectionResult(
        sessionId: 's1',
        tableId: '17',
        tableLabel: 'VIP-1',
        guestCount: 2,
      );
      expect(result.sessionId, 's1');
    });
  });

  group('Order.fromJson / copyWith — table fields', () {
    test('round-trips tableId/tableLabel/tableSeatConflict from a successful selection', () {
      final order = Order.fromJson({
        'id': '789',
        'loungeId': '5',
        'status': 'new',
        'tableId': '17',
        'tableLabel': 'VIP-1',
        'tableSeatConflict': false,
      });

      expect(order.tableId, '17');
      expect(order.tableLabel, 'VIP-1');
      expect(order.tableSeatConflict, isFalse);
    });

    test('parses the race-condition conflict shape: tableId null, tableSeatConflict true', () {
      final order = Order.fromJson({
        'id': '789',
        'loungeId': '5',
        'status': 'new',
        'tableId': null,
        'tableSeatConflict': true,
      });

      expect(order.tableId, isNull);
      expect(order.tableLabel, isNull);
      expect(order.tableSeatConflict, isTrue);
    });

    test('defaults tableSeatConflict to false when absent', () {
      final order = Order.fromJson({'id': '1', 'loungeId': '5', 'status': 'new'});
      expect(order.tableSeatConflict, isFalse);
      expect(order.tableId, isNull);
    });

    test('copyWith updates tableId/tableLabel after a successful table selection', () {
      const order = Order(id: '1', loungeId: '5', status: 'new');
      final updated = order.copyWith(tableId: '17', tableLabel: 'VIP-1');

      expect(updated.tableId, '17');
      expect(updated.tableLabel, 'VIP-1');
      // остальные поля не должны затрагиваться
      expect(updated.id, order.id);
      expect(updated.status, order.status);
    });
  });
}
