class SessionItem {
  final String itemId;
  final String sessionId;
  final String loungeId;
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;
  final String status;
  final String? createdAt;

  const SessionItem({
    required this.itemId,
    required this.sessionId,
    required this.loungeId,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.status,
    this.createdAt,
  });

  factory SessionItem.fromJson(Map<String, dynamic> json) => SessionItem(
        itemId: json['itemId'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        loungeId: json['loungeId'] as String? ?? '',
        menuItemId: json['menuItemId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        status: json['status'] as String? ?? 'new',
        createdAt: json['createdAt'] as String?,
      );
}
