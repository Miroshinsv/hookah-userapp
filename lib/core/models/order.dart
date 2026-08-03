class Order {
  final String id;
  final String loungeId;
  final String? flavor;
  final String? comment;
  final String? phone;
  final String? arrivalAt;
  final String status;
  final String? createdAt;

  const Order({
    required this.id,
    required this.loungeId,
    this.flavor,
    this.comment,
    this.phone,
    this.arrivalAt,
    required this.status,
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String? ?? '',
        loungeId: json['loungeId'] as String? ?? '',
        flavor: json['flavor'] as String?,
        comment: json['comment'] as String?,
        phone: json['phone'] as String?,
        arrivalAt: json['arrivalAt'] as String?,
        status: json['status'] as String? ?? 'new',
        createdAt: json['createdAt'] as String?,
      );

  Order copyWith({String? status}) => Order(
        id: id,
        loungeId: loungeId,
        flavor: flavor,
        comment: comment,
        phone: phone,
        arrivalAt: arrivalAt,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
