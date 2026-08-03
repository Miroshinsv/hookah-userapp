class MenuCategory {
  final String categoryId;
  final String loungeId;
  final String name;
  final int sortOrder;

  const MenuCategory({
    required this.categoryId,
    required this.loungeId,
    required this.name,
    this.sortOrder = 0,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
        categoryId: json['categoryId'] as String? ?? '',
        loungeId: json['loungeId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

class MenuItem {
  final String itemId;
  final String loungeId;
  final String? categoryId;
  final String name;
  final double price;
  final bool stopped;
  final bool available;

  const MenuItem({
    required this.itemId,
    required this.loungeId,
    this.categoryId,
    required this.name,
    required this.price,
    this.stopped = false,
    this.available = true,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        itemId: json['itemId'] as String? ?? '',
        loungeId: json['loungeId'] as String? ?? '',
        categoryId: json['categoryId'] as String?,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        stopped: json['stopped'] as bool? ?? false,
        available: json['available'] as bool? ?? true,
      );
}
