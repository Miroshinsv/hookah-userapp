import 'dart:convert';

class ScheduleParser {
  static const _days = {
    'mon': 'Пн',
    'tue': 'Вт',
    'wed': 'Ср',
    'thu': 'Чт',
    'fri': 'Пт',
    'sat': 'Сб',
    'sun': 'Вс',
  };

  // Ключ текущего дня по weekday (1=Пн … 7=Вс)
  static const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// Полное расписание на неделю: {'Пн': '12:00-23:00', ...}
  static Map<String, String> parse(String? scheduleJson) {
    if (scheduleJson == null || scheduleJson.isEmpty) return {};
    try {
      final raw = jsonDecode(scheduleJson) as Map<String, dynamic>;
      final result = <String, String>{};
      for (final key in _days.keys) {
        if (raw.containsKey(key)) {
          result[_days[key]!] = raw[key] as String;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Часы работы сегодня, например "12:00-23:00", или null если нет данных
  static String? todayHours(String? scheduleJson) {
    if (scheduleJson == null || scheduleJson.isEmpty) return null;
    try {
      final raw = jsonDecode(scheduleJson) as Map<String, dynamic>;
      final key = _dayKeys[DateTime.now().weekday - 1];
      return raw[key] as String?;
    } catch (_) {
      return null;
    }
  }

  /// true — заведение открыто прямо сейчас
  static bool isOpenNow(String? scheduleJson) {
    final hours = todayHours(scheduleJson);
    if (hours == null) return false;
    return _inRange(hours, DateTime.now());
  }

  static bool _inRange(String range, DateTime now) {
    final parts = range.split('-');
    if (parts.length != 2) return false;
    final start = _parseTime(parts[0].trim(), now);
    final end = _parseTime(parts[1].trim(), now);
    if (start == null || end == null) return false;
    final cur = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    // Работа через полночь: конец меньше начала (например 20:00–02:00)
    if (end.isBefore(start)) {
      return cur.isAfter(start) || cur.isBefore(end);
    }
    return cur.isAfter(start) && cur.isBefore(end);
  }

  static DateTime? _parseTime(String t, DateTime date) {
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(date.year, date.month, date.day, h, m);
  }
}
