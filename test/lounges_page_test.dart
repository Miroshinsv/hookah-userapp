import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/graphql/queries.dart';
import 'package:user_app/core/models/lounge.dart';

void main() {
  group('GQLQueries.loungesPage', () {
    test('embeds all provided params in the query string', () {
      final query = GQLQueries.loungesPage(
        latitude: 55.7558,
        longitude: 37.6173,
        zoom: 12,
        search: 'кальян',
        page: 2,
        pageSize: 50,
        openNow: true,
        is24HoursOnly: true,
        minRating: 4.5,
        sortNearest: true,
      );

      expect(query, contains('loungesPage'));
      expect(query, contains('latitude: 55.7558'));
      expect(query, contains('longitude: 37.6173'));
      expect(query, contains('zoom: 12'));
      expect(query, contains('page: 2'));
      expect(query, contains('pageSize: 50'));
      expect(query, contains('openNow: true'));
      expect(query, contains('is24HoursOnly: true'));
      expect(query, contains('minRating: 4.5'));
      expect(query, contains('sortNearest: true'));
      expect(query, contains(r'"кальян"'));
    });

    test('escapes special characters in search via jsonEncode', () {
      final query = GQLQueries.loungesPage(
        latitude: 0,
        longitude: 0,
        zoom: 10,
        search: 'test "quoted" value',
      );

      expect(query, contains(r'test \"quoted\" value'));
    });

    test('defaults minRating to 0 (no filter) when not provided', () {
      final query = GQLQueries.loungesPage(
        latitude: 0,
        longitude: 0,
        zoom: 10,
      );

      expect(query, contains('minRating: 0'));
    });
  });

  group('LoungeMapItem.fromJson', () {
    test('parses a fully populated item', () {
      final item = LoungeMapItem.fromJson({
        'id': '1',
        'name': 'Test Lounge',
        'shortAddress': 'ул. Тестовая, 1',
        'latitude': 55.7558,
        'longitude': 37.6173,
        'rating': 4.5,
        'is24Hours': false,
        'status': 'open',
        'distanceKm': 1.2,
      });

      expect(item.id, '1');
      expect(item.name, 'Test Lounge');
      expect(item.shortAddress, 'ул. Тестовая, 1');
      expect(item.latitude, 55.7558);
      expect(item.longitude, 37.6173);
      expect(item.rating, 4.5);
      expect(item.is24Hours, false);
      expect(item.status, 'open');
      expect(item.distanceKm, 1.2);
    });

    test('parses an item with null optional fields', () {
      final item = LoungeMapItem.fromJson({
        'id': '2',
        'name': 'Minimal Lounge',
        'shortAddress': null,
        'latitude': 55.0,
        'longitude': 37.0,
        'rating': null,
        'is24Hours': true,
        'status': '24h',
        'distanceKm': null,
      });

      expect(item.shortAddress, isNull);
      expect(item.rating, isNull);
      expect(item.distanceKm, isNull);
      expect(item.is24Hours, true);
      expect(item.status, '24h');
    });
  });

  group('LoungesPageResult.fromJson', () {
    test('parses a full loungesPage payload with pagination metadata', () {
      final result = LoungesPageResult.fromJson({
        'items': [
          {
            'id': '1',
            'name': 'A',
            'shortAddress': 'Addr A',
            'latitude': 55.1,
            'longitude': 37.1,
            'rating': 5.0,
            'is24Hours': false,
            'status': 'closed',
            'distanceKm': 0.5,
          },
          {
            'id': '2',
            'name': 'B',
            'shortAddress': null,
            'latitude': 55.2,
            'longitude': 37.2,
            'rating': null,
            'is24Hours': true,
            'status': '24h',
            'distanceKm': null,
          },
        ],
        'total': 42,
        'page': 1,
        'pageSize': 20,
        'totalPages': 3,
      });

      expect(result.items, hasLength(2));
      expect(result.items[0].name, 'A');
      expect(result.items[1].rating, isNull);
      expect(result.total, 42);
      expect(result.page, 1);
      expect(result.pageSize, 20);
      expect(result.totalPages, 3);
    });

    test('parses an empty response gracefully', () {
      final result = LoungesPageResult.fromJson(const {});

      expect(result.items, isEmpty);
      expect(result.total, 0);
      expect(result.page, 1);
    });
  });
}
