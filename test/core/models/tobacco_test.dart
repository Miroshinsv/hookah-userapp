import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/tobacco.dart';

void main() {
  group('HookahTobacco.fromJson', () {
    test('parses a full response', () {
      final tobacco = HookahTobacco.fromJson({
        'tobaccoId': '1',
        'loungeId': '2',
        'name': 'Al Fakher — Two Apples',
        'strength': 6,
        'price': 350.0,
        'createdAt': '2026-08-01T10:00:00Z',
        'updatedAt': '2026-08-02T10:00:00Z',
      });

      expect(tobacco.tobaccoId, '1');
      expect(tobacco.loungeId, '2');
      expect(tobacco.name, 'Al Fakher — Two Apples');
      expect(tobacco.strength, 6);
      expect(tobacco.price, 350.0);
      expect(tobacco.createdAt, '2026-08-01T10:00:00Z');
      expect(tobacco.updatedAt, '2026-08-02T10:00:00Z');
    });

    test('handles missing optional fields with safe defaults', () {
      final tobacco = HookahTobacco.fromJson({'tobaccoId': '1', 'loungeId': '2'});

      expect(tobacco.name, '');
      expect(tobacco.strength, 0);
      expect(tobacco.price, 0.0);
      expect(tobacco.createdAt, isNull);
      expect(tobacco.updatedAt, isNull);
    });
  });
}
