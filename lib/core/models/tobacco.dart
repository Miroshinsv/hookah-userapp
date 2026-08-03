class HookahTobacco {
  final String tobaccoId;
  final String loungeId;
  final String name;
  final int strength;
  final double price;
  final String? createdAt;
  final String? updatedAt;

  const HookahTobacco({
    required this.tobaccoId,
    required this.loungeId,
    required this.name,
    required this.strength,
    required this.price,
    this.createdAt,
    this.updatedAt,
  });

  factory HookahTobacco.fromJson(Map<String, dynamic> json) => HookahTobacco(
        tobaccoId: json['tobaccoId'] as String? ?? '',
        loungeId: json['loungeId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        strength: (json['strength'] as num?)?.toInt() ?? 0,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );
}
