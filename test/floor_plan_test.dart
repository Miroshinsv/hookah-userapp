import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/floor_plan.dart';
import 'package:user_app/core/models/table_session.dart';

void main() {
  group('FloorPlan.fromJson', () {
    test('parses a fully populated walls blob', () {
      final blob = jsonEncode({
        'walls': [
          {
            'points': [
              {'x': 100, 'y': 80},
              {'x': 300, 'y': 80},
              {'x': 300, 'y': 200},
            ],
          },
        ],
        'windows': [
          {'x1': 120, 'y1': 80, 'x2': 180, 'y2': 80},
        ],
        'doors': [
          {'x1': 280, 'y1': 80, 'x2': 320, 'y2': 80, 'swing': 'r'},
        ],
        'zones': [
          {'x': 50, 'y': 50, 'w': 200, 'h': 150, 'name': 'Летняя веранда', 'color': '#3b82f6'},
        ],
      });

      final floorPlan = FloorPlan.fromJson({'walls': blob, 'updatedAt': '2026-08-26T10:00:00Z'});

      expect(floorPlan.walls, hasLength(1));
      expect(floorPlan.walls.first.points, hasLength(3));
      expect(floorPlan.windows, hasLength(1));
      expect(floorPlan.windows.first.x1, 120);
      expect(floorPlan.doors, hasLength(1));
      expect(floorPlan.doors.first.swing, 'r');
      expect(floorPlan.zones, hasLength(1));
      expect(floorPlan.zones.first.name, 'Летняя веранда');
      expect(floorPlan.zones.first.color.toARGB32(), 0xFF3b82f6);
      expect(floorPlan.updatedAt, '2026-08-26T10:00:00Z');
    });

    test('empty walls string produces an empty floor plan without throwing', () {
      final floorPlan = FloorPlan.fromJson({'walls': ''});

      expect(floorPlan.walls, isEmpty);
      expect(floorPlan.windows, isEmpty);
      expect(floorPlan.doors, isEmpty);
      expect(floorPlan.zones, isEmpty);
    });

    test('"[]" walls string produces an empty floor plan without throwing', () {
      final floorPlan = FloorPlan.fromJson({'walls': '[]'});

      expect(floorPlan.walls, isEmpty);
    });

    test('malformed JSON walls string does not throw and yields an empty plan', () {
      final floorPlan = FloorPlan.fromJson({'walls': 'not json at all'});

      expect(floorPlan.walls, isEmpty);
    });

    test('zone with malformed color falls back to a default color without throwing', () {
      final blob = jsonEncode({
        'zones': [
          {'x': 0, 'y': 0, 'w': 10, 'h': 10, 'name': 'Bad', 'color': 'not-a-color'},
        ],
      });

      final floorPlan = FloorPlan.fromJson({'walls': blob});

      expect(floorPlan.zones, hasLength(1));
      expect(floorPlan.zones.first.color, isNotNull);
    });
  });

  group('classifyTableOccupancy', () {
    test('no active session for the table -> free', () {
      expect(classifyTableOccupancy(null), TableOccupancyStatus.free);
    });

    test('empty bookedFor -> occupied now', () {
      const session = TableSession(
        sessionId: 's1',
        tableId: 't1',
        guestCount: 2,
        status: 'open',
        bookedFor: '',
        openedAt: '1000',
      );
      expect(classifyTableOccupancy(session), TableOccupancyStatus.occupiedNow);
    });

    test('"0" bookedFor -> occupied now', () {
      const session = TableSession(
        sessionId: 's1',
        tableId: 't1',
        guestCount: 2,
        status: 'open',
        bookedFor: '0',
        openedAt: '1000',
      );
      expect(classifyTableOccupancy(session), TableOccupancyStatus.occupiedNow);
    });

    test('bookedFor exactly 30 minutes after openedAt -> occupied now (inclusive boundary)', () {
      const session = TableSession(
        sessionId: 's1',
        tableId: 't1',
        guestCount: 2,
        status: 'open',
        bookedFor: '2800', // 1000 + 1800
        openedAt: '1000',
      );
      expect(classifyTableOccupancy(session), TableOccupancyStatus.occupiedNow);
    });

    test('bookedFor 1 second past the 30-minute boundary -> future booking', () {
      const session = TableSession(
        sessionId: 's1',
        tableId: 't1',
        guestCount: 2,
        status: 'open',
        bookedFor: '2801', // 1000 + 1801
        openedAt: '1000',
      );
      expect(classifyTableOccupancy(session), TableOccupancyStatus.futureBooking);
    });

    test('malformed numeric timestamps fail safe to occupied now', () {
      const session = TableSession(
        sessionId: 's1',
        tableId: 't1',
        guestCount: 2,
        status: 'open',
        bookedFor: 'not-a-number',
        openedAt: '1000',
      );
      expect(classifyTableOccupancy(session), TableOccupancyStatus.occupiedNow);
    });
  });
}
