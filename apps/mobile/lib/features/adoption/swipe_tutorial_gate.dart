import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'swipe_tutorial.dart';
import 'swipe_tutorial_store.dart';

/// Mount the real catalog only after the first-use explanation is resolved.
/// In particular, no real card can record a view or receive a demo gesture.
class SwipeTutorialGate extends ConsumerStatefulWidget {
  const SwipeTutorialGate({
    super.key,
    required this.actor,
    required this.eligible,
    this.ready = true,
    required this.child,
  });
  final String? actor;
  final bool eligible;

  /// Initial prerequisites only. Later location refreshes keep practice intact.
  final bool ready;
  final Widget child;

  @override
  ConsumerState<SwipeTutorialGate> createState() => _SwipeTutorialGateState();
}

class _SwipeTutorialGateState extends ConsumerState<SwipeTutorialGate> {
  SwipeTutorialStore? _store;
  int _revision = 0;
  bool _started = false, _finished = false, _teaching = false, _showing = false;

  void _reset() {
    _revision++;
    _started = _finished = _teaching = _showing = false;
  }

  @override
  void didUpdateWidget(SwipeTutorialGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor != widget.actor) {
      _reset();
    } else if (oldWidget.eligible != widget.eligible) {
      _revision++;
      // Keep the authenticated shell mounted after completing or bypassing
      // this presentation check. Tabs must preserve their catalog and requests.
      if (!_finished) _started = _teaching = _showing = false;
    }
  }

  bool _current(int revision, String actor, SwipeTutorialStore store) =>
      mounted &&
      _revision == revision &&
      widget.eligible &&
      widget.actor == actor &&
      identical(_store, store);

  Future<void> _read(
    int revision,
    String actor,
    SwipeTutorialStore store,
  ) async {
    if (!_current(revision, actor, store)) return;
    var completed = true;
    try {
      completed = await store.completed(actor);
    } catch (_) {
      // A tutorial preference must never turn a transient Auth read into a
      // login error. This shell bypasses teaching; a later login/restart reads
      // again because no completion receipt is written on failure.
    }
    if (!_current(revision, actor, store)) return;
    setState(() {
      _finished = completed;
      _teaching = !completed;
    });
  }

  void _complete(int revision, String actor, SwipeTutorialStore store) {
    if (!_current(revision, actor, store) || !_teaching) return;
    setState(() {
      _teaching = false;
      _finished = true;
    });
    // The store keeps a scoped local receipt before attempting its network
    // sync. Its failure cannot hold the user inside the explanation.
    unawaited(
      Future.sync(() => store.complete(actor)).catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(swipeTutorialStoreProvider);
    if (!identical(_store, store)) {
      _store = store;
      _reset();
    }
    final actor = widget.actor;
    if (!widget.eligible || actor == null) return widget.child;
    final revision = _revision;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_read(revision, actor, store));
      });
    }
    if (_finished) return widget.child;
    if (_teaching && (widget.ready || _showing)) {
      _showing = true;
      return SwipeTutorial(
        key: ValueKey('swipe-tutorial:$actor:$revision'),
        onDone: () => _complete(revision, actor, store),
      );
    }
    return const Scaffold(body: Center(child: Text('Cargando…')));
  }
}
