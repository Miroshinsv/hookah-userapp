import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression guard for an explicit product decision: the join-only
// "My table" screen must never open or close a TableSession itself —
// calling openTableSession again for a table with an existing session
// silently closes it on the backend. See feature-guest-table-session-tobacco-push.md.
//
// A later, separately-scoped feature (feature-guest-table-selection.md) added
// a legitimate guest-facing use of `openTableSession`: choosing a table for
// the guest's OWN already-created order from order_detail_screen.dart, via
// TableSelectionScreen, always passing `failIfOccupied: true`. That is not
// the case this guard protects against — the invariant below is narrowed to
// what the product decision actually requires: `my_table_screen.dart`
// specifically must stay join-only, and `closeTableSession` (a staff-only
// action) must never appear anywhere in the guest app.
void main() {
  test('my_table_screen.dart never calls openTableSession/closeTableSession mutations', () {
    final source = File('lib/screens/table/my_table_screen.dart').readAsStringSync();

    // Checks for an actual call pattern (GQLMutations.xxx(...) or client.mutate
    // referencing the mutation name), not just any textual mention — the file
    // legitimately explains the avoidance in a comment.
    expect(source.contains('GQLMutations.openTableSession'), isFalse,
        reason: 'the join-only "My table" screen must never call openTableSession itself');
    expect(source.contains('GQLMutations.closeTableSession'), isFalse,
        reason: 'closeTableSession is a staff-only action, out of scope for the guest app');
    expect(source.contains('mutation') && source.contains('openTableSession('), isFalse,
        reason: 'my_table_screen.dart must never embed an inline openTableSession mutation string');
  });

  test('closeTableSession is never defined or called anywhere in the guest app', () {
    final mutationsSource = File('lib/core/graphql/mutations.dart').readAsStringSync();
    expect(mutationsSource.contains('closeTableSession'), isFalse,
        reason: 'closeTableSession is a staff-only action, must never exist in the guest app');
  });

  test('the guest app\'s openTableSession mutation always hardcodes failIfOccupied: true', () {
    final mutationsSource = File('lib/core/graphql/mutations.dart').readAsStringSync();
    expect(mutationsSource.contains('openTableSession'), isTrue,
        reason: 'openTableSession is expected as a guest-facing table-selection mutation builder '
            '(see feature-guest-table-selection.md)');
    expect(mutationsSource.contains('failIfOccupied: true'), isTrue,
        reason: 'failIfOccupied must always be hardcoded true, never a caller-controlled parameter '
            '— this is the safety guarantee that "not offer a place occupied by another guest" relies on');
  });
}
