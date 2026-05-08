class StaffMember {
  final String id;
  final String firstName;
  final String lastName;
  final String role;

  const StaffMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        role: json['role'] as String? ?? '',
      );

  String get displayRole {
    const map = {
      'hookah_master': 'Кальянный мастер',
      'hostess': 'Хостес',
      'waiter': 'Официант',
      'admin': 'Администратор',
      'owner': 'Владелец',
    };
    return map[role] ?? role;
  }
}

class Lounge {
  final String id;
  final String name;
  final String? description;
  final String? schedule;
  final double? rating;
  final String? shortAddress;
  final String? phone;
  final double latitude;
  final double longitude;
  final List<StaffMember> staff;

  const Lounge({
    required this.id,
    required this.name,
    this.description,
    this.schedule,
    this.rating,
    this.shortAddress,
    this.phone,
    required this.latitude,
    required this.longitude,
    this.staff = const [],
  });

  factory Lounge.fromJson(Map<String, dynamic> json) => Lounge(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        schedule: json['schedule'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        shortAddress: json['shortAddress'] as String?,
        phone: json['phone'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        staff: (json['staff'] as List<dynamic>?)
                ?.map((s) => StaffMember.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
