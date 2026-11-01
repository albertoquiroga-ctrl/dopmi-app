import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/identity_controller.dart';
import 'location_map_picker.dart';
import 'nearby_location_controller.dart';

/// Wrap an authenticated home after legal consent, in either account mode.
class NearbyLocationGate extends ConsumerStatefulWidget {
  const NearbyLocationGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<NearbyLocationGate> createState() => _NearbyLocationGateState();
}

class _NearbyLocationGateState extends ConsumerState<NearbyLocationGate>
    with WidgetsBindingObserver {
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(configProvider).mapsEnabled) return;
    final controller = ref.read(nearbyLocationControllerProvider);
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.refreshIfAllowed());
    } else {
      controller.cancelForegroundRefresh();
    }
  }

  Future<void> offer(NearbyLocationController controller) async {
    final actor = controller.ownerId;
    try {
      if (!mounted ||
          !await controller.markPromptSeen(expectedOwner: actor) ||
          !mounted) {
        return;
      }
      final result = await chooseLocationOnMap(
        context,
        initial: controller.selection,
        requireAddress: false,
      );
      if (!mounted) return;
      controller.replace(result, expectedOwner: actor);
    } finally {
      _opening = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(configProvider).mapsEnabled) return widget.child;
    final controller = ref.watch(nearbyLocationControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!_opening &&
            controller.ready &&
            !controller.promptSeen &&
            controller.ownerId != null) {
          _opening = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(offer(controller));
          });
        }
        return widget.child;
      },
    );
  }
}
