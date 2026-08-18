class OrderMenuItem {
  final String id;
  final String menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String status;

  const OrderMenuItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.status,
  });

  factory OrderMenuItem.fromJson(Map<String, dynamic> json) => OrderMenuItem(
        id: json['id'] as String? ?? '',
        menuItemId: json['menuItemId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'new',
      );
}

class OrderHookahItem {
  final String id;
  final String name;
  final String? flavor;
  final int quantity;
  final double unitPrice;
  final String status;

  const OrderHookahItem({
    required this.id,
    required this.name,
    this.flavor,
    required this.quantity,
    required this.unitPrice,
    required this.status,
  });

  factory OrderHookahItem.fromJson(Map<String, dynamic> json) => OrderHookahItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        flavor: json['flavor'] as String?,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'new',
      );
}

// Статусы заказа, для которых backend ещё разрешает addOrderItems — после
// completed/canceled* дозаказ отклоняется независимо от роли (см. order.txt).
const _editableOrderStatuses = {'new', 'in_progress', 'calculation'};

class Order {
  final String id;
  final String loungeId;
  final String? flavor;
  final String? comment;
  final String? phone;
  final String? arrivalAt;
  final String status;
  final String? createdAt;
  final List<OrderMenuItem> menuItems;
  final List<OrderHookahItem> hookahItems;
  final double? subtotal;
  final double? finalTotal;

  const Order({
    required this.id,
    required this.loungeId,
    this.flavor,
    this.comment,
    this.phone,
    this.arrivalAt,
    required this.status,
    this.createdAt,
    this.menuItems = const [],
    this.hookahItems = const [],
    this.subtotal,
    this.finalTotal,
  });

  bool get isEditable => _editableOrderStatuses.contains(status);

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String? ?? '',
        loungeId: json['loungeId'] as String? ?? '',
        flavor: json['flavor'] as String?,
        comment: json['comment'] as String?,
        phone: json['phone'] as String?,
        arrivalAt: json['arrivalAt'] as String?,
        status: json['status'] as String? ?? 'new',
        createdAt: json['createdAt'] as String?,
        menuItems: (json['menuItems'] as List<dynamic>?)
                ?.map((e) => OrderMenuItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        hookahItems: (json['hookahItems'] as List<dynamic>?)
                ?.map((e) => OrderHookahItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        subtotal: (json['subtotal'] as num?)?.toDouble(),
        finalTotal: (json['finalTotal'] as num?)?.toDouble(),
      );

  Order copyWith({
    String? status,
    List<OrderMenuItem>? menuItems,
    List<OrderHookahItem>? hookahItems,
    double? subtotal,
    double? finalTotal,
  }) =>
      Order(
        id: id,
        loungeId: loungeId,
        flavor: flavor,
        comment: comment,
        phone: phone,
        arrivalAt: arrivalAt,
        status: status ?? this.status,
        createdAt: createdAt,
        menuItems: menuItems ?? this.menuItems,
        hookahItems: hookahItems ?? this.hookahItems,
        subtotal: subtotal ?? this.subtotal,
        finalTotal: finalTotal ?? this.finalTotal,
      );
}
