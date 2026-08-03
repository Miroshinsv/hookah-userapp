import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression guard for an explicit product decision: the guest app must only
// ever join an already-open TableSession, never open or close one itself —
// calling openTableSession again for a table with an existing session
// silently closes it on the backend. See the plan's Context/Findings.
void main() {
  test('my_table_screen.dart never calls openTableSession/closeTableSession mutations', () {
    final source = File('lib/screens/table/my_table_screen.dart').readAsStringSync();

    // Checks for an actual call pattern (GQLMutations.xxx(...) or client.mutate
    // referencing the mutation name), not just any textual mention — the file
    // legitimately explains the avoidance in a comment.
    expect(source.contains('GQLMutations.openTableSession'), isFalse,
        reason: 'guest app must never call openTableSession — it auto-closes an existing session');
    expect(source.contains('GQLMutations.closeTableSession'), isFalse,
        reason: 'closeTableSession is a staff-only action, out of scope for the guest app');
    expect(source.contains('mutation') && source.contains('openTableSession('), isFalse,
        reason: 'guest app must never embed an inline openTableSession mutation string');
  });

  test('mutations.dart never defines openTableSession/closeTableSession builders', () {
    final source = File('lib/core/graphql/mutations.dart').readAsStringSync();

    expect(source.contains('openTableSession'), isFalse);
    expect(source.contains('closeTableSession'), isFalse);
  });
}
