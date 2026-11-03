import 'dart:async';

import 'package:dopmi_mobile/features/adoption/discovery_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server history survives another client and stays scoped to account/environment', () async {
    final server = <String, Set<String>>{};
    DiscoveryHistory client(String scope) => DiscoveryHistory(
      scope: scope,
      isCurrent: () => true,
      read: () async => Set<String>.from(server[scope] ?? <String>{}),
      mark: (id) async {
        (server[scope] ??= {}).add(id);
      },
      reset: () async {
        server[scope] = {};
      },
    );
    final first = client('prod:one');
    await first.restore();
    await first.remember('pet');
    final otherPhone = client('prod:one');
    await otherPhone.restore();
    expect(otherPhone.seen, {'pet'});
    for (final scope in ['prod:two', 'test:one']) {
      final other = client(scope);
      await other.restore();
      expect(other.seen, isEmpty);
    }
    await otherPhone.restart();
    await first.restore();
    expect(first.seen, isEmpty);
    final newCycle = client('prod:one');
    await newCycle.restore();
    expect(newCycle.seen, isEmpty);
  });

  test(
    'a delayed history response cannot restore the previous cycle or account',
    () async {
      for (final change in ['restart', 'account']) {
        final pending = Completer<Set<String>>();
        var current = true;
        final history = DiscoveryHistory(
          scope: 'prod:one',
          isCurrent: () => current,
          read: () => pending.future,
        );
        final restoring = history.restore();
        await Future<void>.delayed(Duration.zero);
        if (change == 'restart') {
          await history.restart();
        } else {
          current = false;
        }
        pending.complete({'old-pet'});
        await restoring;
        expect(history.seen, isEmpty);
      }
    },
  );

  test(
    'restart waits for an already-sent mark and cancels old queued marks',
    () async {
      final pending = Completer<void>();
      final operations = <String>[];
      final history = DiscoveryHistory(
        scope: 'prod:one',
        isCurrent: () => true,
        mark: (id) async {
          operations.add('mark:$id');
          await pending.future;
          operations.add('done:$id');
        },
        reset: () async {
          operations.add('reset');
        },
      );
      final first = history.remember('front');
      await Future<void>.delayed(Duration.zero);
      final queued = history.remember('next');
      final restarting = history.restart();
      await Future<void>.delayed(Duration.zero);
      expect(operations, ['mark:front']);
      pending.complete();
      await Future.wait([first, queued, restarting]);
      expect(operations, ['mark:front', 'done:front', 'reset']);
      expect(history.seen, isEmpty);
    },
  );

  test(
    'failed marks retain the local exclusion and retry on explicit restore',
    () async {
      var fail = true, calls = 0;
      final server = <String>{};
      final history = DiscoveryHistory(
        scope: 'prod:one',
        isCurrent: () => true,
        mark: (id) async {
          calls++;
          if (fail) throw StateError('offline');
          server.add(id);
        },
        read: () async => Set.of(server),
      );
      await expectLater(history.remember('front'), throwsStateError);
      expect(history.seen, {'front'});
      await history.remember('front');
      expect(calls, 1);
      fail = false;
      await history.restore();
      expect(calls, 2);
      expect(history.seen, {'front'});
    },
  );

  test(
    'guest history works in RAM and restarting does not require a backend',
    () async {
      final history = DiscoveryHistory(
        scope: 'prod:guest',
        isCurrent: () => true,
      );
      await history.restore();
      await history.remember('front');
      await history.restore();
      expect(history.seen, {'front'});
      await history.restart();
      expect(history.seen, isEmpty);
    },
  );
}
