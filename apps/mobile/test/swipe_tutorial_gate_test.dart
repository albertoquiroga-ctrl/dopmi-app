import 'dart:async';

import 'package:dopmi_mobile/features/adoption/swipe_tutorial_gate.dart';
import 'package:dopmi_mobile/features/adoption/swipe_tutorial.dart';
import 'package:dopmi_mobile/features/adoption/swipe_tutorial_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TutorialReceipts implements SwipeTutorialStore {
  final done = <String>{};
  final reads = <String>[];
  final writes = <String>[];
  Future<bool>? delayed;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<bool> completed(String actor) async {
    reads.add(actor);
    if (failRead) throw StateError('offline');
    return delayed == null ? done.contains(actor) : await delayed!;
  }

  @override
  Future<void> complete(String actor) async {
    writes.add(actor);
    done.add(actor);
    if (failWrite) throw StateError('offline');
  }
}

class MountedCatalog extends StatefulWidget {
  const MountedCatalog(this.onMount, {super.key});
  final VoidCallback onMount;
  @override
  State<MountedCatalog> createState() => _MountedCatalogState();
}

class _MountedCatalogState extends State<MountedCatalog> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const Text('Catálogo real');
}

void main() {
  late TutorialReceipts receipts;
  late ProviderContainer container;
  setUp(() {
    receipts = TutorialReceipts();
    container = ProviderContainer(
      overrides: [swipeTutorialStoreProvider.overrideWithValue(receipts)],
    );
  });
  tearDown(() => container.dispose());

  Future<void> render(
    WidgetTester tester, {
    String? actor = 'one',
    bool eligible = true,
    bool ready = true,
    VoidCallback? onCatalog,
  }) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: SwipeTutorialGate(
          actor: actor,
          eligible: eligible,
          ready: ready,
          child: MountedCatalog(onCatalog ?? () {}),
        ),
      ),
    ),
  );

  testWidgets(
    'teaching never mounts real cards or their view/action callbacks',
    (tester) async {
      var catalogMounts = 0;
      final read = Completer<bool>();
      receipts.delayed = read.future;
      await render(tester, onCatalog: () => catalogMounts++);
      await tester.pump();
      expect(catalogMounts, 0);
      read.complete(false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(SwipeTutorial), findsOneWidget);
      expect(catalogMounts, 0);
      tester.widget<SwipeTutorial>(find.byType(SwipeTutorial)).onDone();
      await tester.pump();
      expect(catalogMounts, 1);
      expect(receipts.writes, ['one']);
    },
  );

  testWidgets(
    'completion stays done on next entry; another actor learns once',
    (tester) async {
      await render(tester);
      await tester.pump();
      await tester.pump();
      tester.widget<SwipeTutorial>(find.byType(SwipeTutorial)).onDone();
      await tester.pump();
      await render(tester, actor: null);
      await render(tester);
      await tester.pump();
      await tester.pump();
      expect(find.byType(SwipeTutorial), findsNothing);
      await render(tester, actor: 'two');
      await tester.pump();
      await tester.pump();
      expect(find.byType(SwipeTutorial), findsOneWidget);
      expect(receipts.writes, ['one']);
    },
  );

  testWidgets('guest, rescuer or a preceding modal do not read or teach', (
    tester,
  ) async {
    await render(tester, actor: null);
    await tester.pump();
    await render(tester, eligible: false);
    await tester.pump();
    expect(receipts.reads, isEmpty);
    expect(find.text('Catálogo real'), findsOneWidget);
    await render(tester);
    await tester.pump();
    await tester.pump();
    expect(receipts.reads, ['one']);
    expect(find.byType(SwipeTutorial), findsOneWidget);
  });

  testWidgets(
    'initial location resolves first; later refresh keeps practice progress',
    (tester) async {
      await render(tester, ready: false);
      await tester.pump();
      expect(find.byType(SwipeTutorial), findsNothing);
      await render(tester);
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(find.text('Probar guardar'));
      await tester.tap(find.text('Probar guardar'));
      await tester.pump();
      expect(find.text('Desliza a la izquierda'), findsOneWidget);
      await render(tester, ready: false);
      await tester.pump();
      expect(find.text('Desliza a la izquierda'), findsOneWidget);
      await render(tester);
      await tester.pump();
      expect(find.text('Desliza a la izquierda'), findsOneWidget);
      expect(receipts.reads, ['one']);
      expect(receipts.writes, isEmpty);
    },
  );

  testWidgets(
    'completed tutorial preserves catalog state across tabs and location startup',
    (tester) async {
      receipts.done.add('one');
      var mounts = 0;
      await render(tester, ready: false, onCatalog: () => mounts++);
      await tester.pump();
      await tester.pump();
      expect(mounts, 1);
      await render(tester, onCatalog: () => mounts++);
      await tester.pump();
      await tester.pump();
      expect(mounts, 1);
      await render(tester, eligible: false, onCatalog: () => mounts++);
      await render(tester, onCatalog: () => mounts++);
      expect(find.text('Catálogo real'), findsOneWidget);
      expect(mounts, 1);
      expect(receipts.reads, ['one']);
    },
  );

  testWidgets(
    'read failure preserves this shell but remount retries without a receipt',
    (tester) async {
      receipts.failRead = true;
      var mounts = 0;
      await render(tester, onCatalog: () => mounts++);
      await tester.pump();
      await tester.pump();
      expect(mounts, 1);
      await render(tester, eligible: false, onCatalog: () => mounts++);
      await render(tester, onCatalog: () => mounts++);
      expect(find.text('Catálogo real'), findsOneWidget);
      expect(mounts, 1);
      expect(receipts.reads, ['one']);
      expect(receipts.writes, isEmpty);
      expect(receipts.done, isEmpty);
      receipts.failRead = false;
      await tester.pumpWidget(const SizedBox());
      await render(tester);
      await tester.pump();
      await tester.pump();
      expect(receipts.reads, ['one', 'one']);
      expect(find.byType(SwipeTutorial), findsOneWidget);
      expect(receipts.writes, isEmpty);
    },
  );

  for (final change in ['actor', 'route']) {
    testWidgets('late receipt cannot show tutorial after $change changes', (
      tester,
    ) async {
      final pending = Completer<bool>();
      receipts.delayed = pending.future;
      await render(tester);
      await tester.pump();
      receipts.delayed = null;
      receipts.done.add('two');
      await render(
        tester,
        actor: change == 'actor' ? 'two' : 'one',
        eligible: change != 'route',
      );
      await tester.pump();
      pending.complete(false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(SwipeTutorial), findsNothing);
      expect(receipts.writes, isEmpty);
      expect(find.text('Catálogo real'), findsOneWidget);
    });
  }

  testWidgets(
    'network errors do not lock discovery or complete another owner',
    (tester) async {
      receipts.failRead = true;
      await render(tester);
      await tester.pump();
      await tester.pump();
      expect(find.text('Catálogo real'), findsOneWidget);
      expect(receipts.writes, isEmpty);
      receipts.failRead = false;
      receipts.failWrite = true;
      await render(tester, actor: 'two');
      await tester.pump();
      await tester.pump();
      final oldDone = tester
          .widget<SwipeTutorial>(find.byType(SwipeTutorial))
          .onDone;
      await render(tester, actor: 'three', eligible: false);
      oldDone();
      await tester.pump();
      expect(receipts.writes, isEmpty);
      await render(tester, actor: 'two');
      await tester.pump();
      await tester.pump();
      tester.widget<SwipeTutorial>(find.byType(SwipeTutorial)).onDone();
      await tester.pump();
      expect(find.text('Catálogo real'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
