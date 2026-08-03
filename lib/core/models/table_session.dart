class TableSession {
  final String sessionId;
  final String tableId;
  final String? orderId;
  final int guestCount;
  final String status;
  final String? openedAt;

  const TableSession({
    required this.sessionId,
    required this.tableId,
    this.orderId,
    required this.guestCount,
    required this.status,
    this.openedAt,
  });

  factory TableSession.fromJson(Map<String, dynamic> json) => TableSession(
        sessionId: json['sessionId'] as String? ?? '',
        tableId: json['tableId'] as String? ?? '',
        orderId: json['orderId'] as String?,
        guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        openedAt: json['openedAt'] as String?,
      );
}
