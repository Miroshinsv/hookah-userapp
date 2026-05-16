import 'package:flutter/material.dart';

class StatusHelper {
  static String localize(String status) {
    const map = {
      'new': 'Новый',
      'in_progress': 'Готовится',
      'completed': 'Завершён',
      'canceled': 'Отменён',
      'canceled_by_staff': 'Отменён заведением',
    };
    return map[status] ?? status;
  }

  static Color color(String status) {
    switch (status) {
      case 'new':
        return Colors.blue;
      case 'in_progress':
        return Colors.amber.shade700;
      case 'completed':
        return Colors.green;
      case 'canceled':
      case 'canceled_by_staff':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
