import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/models/menu_item.dart';

void main() {
  group('MenuCategory.fromJson', () {
    test('parses a full response', () {
      final category = MenuCategory.fromJson({
        'categoryId': '1',
        'loungeId': '2',
        'name': 'Напитки',
        'sortOrder': 3,
      });

      expect(category.categoryId, '1');
      expect(category.loungeId, '2');
      expect(category.name, 'Напитки');
      expect(category.sortOrder, 3);
    });

    test('handles missing optional fields', () {
      final category = MenuCategory.fromJson({'categoryId': '1', 'loungeId': '2'});
      expect(category.name, '');
      expect(category.sortOrder, 0);
    });
  });

  group('MenuItem.fromJson', () {
    test('parses a full response', () {
      final item = MenuItem.fromJson({
        'itemId': '7',
        'loungeId': '2',
        'categoryId': '1',
        'name': 'Кола',
        'price': 150.0,
        'stopped': false,
        'available': true,
      });

      expect(item.itemId, '7');
      expect(item.loungeId, '2');
      expect(item.categoryId, '1');
      expect(item.name, 'Кола');
      expect(item.price, 150.0);
      expect(item.stopped, isFalse);
      expect(item.available, isTrue);
    });

    test('handles missing optional fields with safe defaults', () {
      final item = MenuItem.fromJson({'itemId': '7', 'loungeId': '2', 'name': 'Кола'});
      expect(item.categoryId, isNull);
      expect(item.price, 0.0);
      expect(item.stopped, isFalse);
      expect(item.available, isTrue);
    });
  });
}
