class LoungePhoto {
  final String id;
  final String url;

  const LoungePhoto({required this.id, required this.url});

  factory LoungePhoto.fromJson(Map<String, dynamic> json) => LoungePhoto(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

class StaffMember {
  final String id;
  final String firstName;
  final String lastName;
  final List<String> roles;
  final String? photoUrl;

  const StaffMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.roles,
    this.photoUrl,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        roles: (json['roles'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        photoUrl: json['photoUrl'] as String?,
      );

  static const _roleLabels = {
    'hookah_master': 'Кальянный мастер',
    'hostess': 'Хостес',
    'waiter': 'Официант',
    'admin': 'Администратор',
    'owner': 'Владелец',
  };

  String get displayRoles {
    final visible = roles.where((r) => r != 'owner' && r != 'deputy').toList();
    if (visible.isEmpty) return '—';
    return visible.map((r) => _roleLabels[r] ?? r).join(', ');
  }
}

class LoungeMapItem {
  final String id;
  final String name;
  final String? shortAddress;
  final double latitude;
  final double longitude;
  final double? rating;
  final bool is24Hours;
  final String status;
  final double? distanceKm;

  const LoungeMapItem({
    required this.id,
    required this.name,
    this.shortAddress,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.is24Hours = false,
    required this.status,
    this.distanceKm,
  });

  factory LoungeMapItem.fromJson(Map<String, dynamic> json) => LoungeMapItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        shortAddress: json['shortAddress'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        rating: (json['rating'] as num?)?.toDouble(),
        is24Hours: json['is24Hours'] as bool? ?? false,
        status: json['status'] as String? ?? 'closed',
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      );
}

class LoungesPageResult {
  final List<LoungeMapItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const LoungesPageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory LoungesPageResult.fromJson(Map<String, dynamic> json) =>
      LoungesPageResult(
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => LoungeMapItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      );
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
  final String? ownerUserId;
  final bool chatEnabled;
  final bool mediaEnabled;
  final List<LoungePhoto> photos;

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
    this.ownerUserId,
    this.chatEnabled = false,
    this.mediaEnabled = false,
    this.photos = const [],
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
        ownerUserId: json['ownerUserId'] as String?,
        chatEnabled: json['chatEnabled'] as bool? ?? false,
        mediaEnabled: json['mediaEnabled'] as bool? ?? false,
        photos: (json['photos'] as List<dynamic>?)
                ?.map((p) => LoungePhoto.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
