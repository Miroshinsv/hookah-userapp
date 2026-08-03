import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/utils/camera_move_debouncer.dart';

void main() {
  group('CameraMoveDebouncer', () {
    test('coalesces rapid schedule() calls into a single callback', () {
      fakeAsync((async) {
        final debouncer = CameraMoveDebouncer();
        var callCount = 0;

        debouncer.schedule(() => callCount++);
        async.elapse(const Duration(milliseconds: 200));
        debouncer.schedule(() => callCount++);
        async.elapse(const Duration(milliseconds: 200));
        debouncer.schedule(() => callCount++);

        // Still within the debounce window — nothing should have fired yet.
        expect(callCount, 0);

        async.elapse(const Duration(milliseconds: 500));

        expect(callCount, 1);
      });
    });

    test('fires again after a new schedule() once the delay has elapsed', () {
      fakeAsync((async) {
        final debouncer = CameraMoveDebouncer();
        var callCount = 0;

        debouncer.schedule(() => callCount++);
        async.elapse(const Duration(milliseconds: 500));
        expect(callCount, 1);

        debouncer.schedule(() => callCount++);
        async.elapse(const Duration(milliseconds: 500));
        expect(callCount, 2);
      });
    });

    test('dispose() cancels a pending callback so it never fires', () {
      fakeAsync((async) {
        final debouncer = CameraMoveDebouncer();
        var callCount = 0;

        debouncer.schedule(() => callCount++);
        debouncer.dispose();
        async.elapse(const Duration(seconds: 1));

        expect(callCount, 0);
      });
    });

    test('respects a custom delay', () {
      fakeAsync((async) {
        final debouncer = CameraMoveDebouncer();
        var callCount = 0;

        debouncer.schedule(() => callCount++, delay: const Duration(seconds: 2));
        async.elapse(const Duration(milliseconds: 500));
        expect(callCount, 0);

        async.elapse(const Duration(milliseconds: 1600));
        expect(callCount, 1);
      });
    });
  });
}
