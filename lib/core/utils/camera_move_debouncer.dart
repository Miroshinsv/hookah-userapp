import 'dart:async';

import 'logger.dart';

/// Coalesces rapid successive camera-move callbacks into a single delayed
/// callback, so repeated map pans/zooms don't each trigger a network reload.
class CameraMoveDebouncer {
  static const _tag = 'CameraMoveDebouncer';

  Timer? _timer;

  void schedule(
    void Function() callback, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    if (_timer != null) {
      AppLogger.d(_tag, 'rescheduling pending reload (rapid re-pan)');
      _timer!.cancel();
    }
    _timer = Timer(delay, () {
      AppLogger.d(_tag, 'debounce elapsed — firing reload');
      _timer = null;
      callback();
    });
  }

  void dispose() {
    if (_timer != null) {
      AppLogger.d(_tag, 'disposed with a pending reload — cancelling it');
    }
    _timer?.cancel();
    _timer = null;
  }
}
