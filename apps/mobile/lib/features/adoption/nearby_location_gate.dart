import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/identity_controller.dart';
import 'nearby_location_controller.dart';

/// Explain first; only the affirmative action can request native permission.
Future<void> requestNearbyLocation(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(nearbyLocationControllerProvider);
  if (!controller.beginExplanation()) return;
  final actor = controller.ownerId;
  final navigator = Navigator.of(context, rootNavigator: true);
  DialogRoute<bool>? route;
  void changed() {
    if ((!controller.isAdopter || controller.ownerId != actor) &&
        route?.isActive == true) {
      navigator.removeRoute(route!);
    }
  }

  controller.addListener(changed);
  try {
    if (!await controller.markPromptSeen(expectedOwner: actor) ||
        !context.mounted) {
      return;
    }
    route = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mascotas cerca de ti'),
        content: const Text(
          'Para mostrarte mascotas cercanas, Dopmi necesita acceder a tu ubicación aproximada mientras usas la app. Te mostraremos adopciones en un radio de 20 km.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('nearby-location-dismiss'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            key: const ValueKey('nearby-location-allow'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Permitir ubicación'),
          ),
        ],
      ),
    );
    final accepted = await navigator.push(route);
    if (accepted == true && context.mounted && controller.isAdopter) {
      await controller.requestCurrentLocation(expectedOwner: actor);
    }
  } finally {
    controller.removeListener(changed);
    controller.endExplanation();
  }
}

/// Wrap the authenticated adopter home after legal consent, never Rescatista.
class NearbyLocationGate extends ConsumerStatefulWidget {
  const NearbyLocationGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<NearbyLocationGate> createState() => _NearbyLocationGateState();
}

class _NearbyLocationGateState extends ConsumerState<NearbyLocationGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(configProvider).mapsEnabled) {
        unawaited(
          ref.read(nearbyLocationControllerProvider).refreshIfAllowed(),
        );
      }
    });
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
      if (mounted && !controller.promptSeen) setState(() {});
    } else if (state != AppLifecycleState.inactive) {
      // A system permission sheet can make iOS inactive. It is not background use.
      controller.cancelForegroundRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(configProvider).mapsEnabled) return widget.child;
    final controller = ref.watch(nearbyLocationControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.ready &&
            controller.isAdopter &&
            !controller.promptSeen &&
            !controller.explaining) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !controller.promptSeen) {
              unawaited(requestNearbyLocation(context, ref));
            }
          });
        }
        return widget.child;
      },
    );
  }
}
