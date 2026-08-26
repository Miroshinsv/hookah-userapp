import '../utils/logger.dart';

const _tag = 'TableSession';

class TableSession {
  final String sessionId;
  final String tableId;
  final String? orderId;
  final int guestCount;
  final String status;
  final String? bookedFor;
  final String? openedAt;

  const TableSession({
    required this.sessionId,
    required this.tableId,
    this.orderId,
    required this.guestCount,
    required this.status,
    this.bookedFor,
    this.openedAt,
  });

  factory TableSession.fromJson(Map<String, dynamic> json) => TableSession(
        sessionId: json['sessionId'] as String? ?? '',
        tableId: json['tableId'] as String? ?? '',
        orderId: json['orderId'] as String?,
        guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        bookedFor: json['bookedFor'] as String?,
        openedAt: json['openedAt'] as String?,
      );
}

enum TableOccupancyStatus { free, occupiedNow, futureBooking }

// Порог "занято прямо сейчас" vs "бронь на будущее" — 30 минут, в секундах.
const _futureBookingThresholdSeconds = 30 * 60;

// Правило классификации стола — должно повторять один в один правило
// backend/веб-админки (см. ТЗ). Сравнение всегда идёт с `openedAt`
// (моментом создания записи), а не с текущим временем на устройстве гостя.
TableOccupancyStatus classifyTableOccupancy(TableSession? session) {
  if (session == null) return TableOccupancyStatus.free;

  final bookedForRaw = session.bookedFor;
  if (bookedForRaw == null || bookedForRaw.isEmpty || bookedForRaw == '0') {
    return TableOccupancyStatus.occupiedNow;
  }

  final openedAtRaw = session.openedAt;
  final bookedFor = int.tryParse(bookedForRaw);
  final openedAt = openedAtRaw == null ? null : int.tryParse(openedAtRaw);
  if (bookedFor == null || openedAt == null) {
    AppLogger.w(_tag,
        'malformed timestamps tableId=${session.tableId} bookedFor=$bookedForRaw openedAt=$openedAtRaw — treating as occupied (fail-safe)');
    return TableOccupancyStatus.occupiedNow;
  }

  final diff = bookedFor - openedAt;
  return diff <= _futureBookingThresholdSeconds
      ? TableOccupancyStatus.occupiedNow
      : TableOccupancyStatus.futureBooking;
}
