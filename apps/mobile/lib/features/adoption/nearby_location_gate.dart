import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/identity_controller.dart';
import 'nearby_location_controller.dart';

/// Explain once; only an affirmative action can request native permission.
Future<void> requestNearbyLocation(
  BuildContext context,
  WidgetRef ref, {
  foundation.ValueListenable<bool>? promptAllowed,
}) async {
  if (promptAllowed?.value == false) return;
  final controller = ref.read(nearbyLocationControllerProvider);
  if (!controller.beginExplanation()) return;
  final actor = controller.ownerId, role = controller.locationRole;
  final rescuer = controller.isRescuer;
  final navigator = Navigator.of(context, rootNavigator: true);
  DialogRoute<bool>? route;
  bool sameScope() =>
      controller.canUseLocation &&
      controller.ownerId == actor &&
      controller.locationRole == role;
  bool closeQueued = false;
  void changed() {
    if ((!sameScope() || promptAllowed?.value == false) &&
        route?.isActive == true &&
        !closeQueued) {
      closeQueued = true;
      // Route eligibility may change while the authenticated shell is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        closeQueued = false;
        if ((!sameScope() || promptAllowed?.value == false) &&
            route?.isActive == true &&
            navigator.mounted) {
          navigator.removeRoute(route!);
        }
      });
    }
  }

  bool ownsExplanation = true;
  void endOwnExplanation() {
    if (!ownsExplanation) return;
    ownsExplanation = false;
    controller.endExplanation();
  }

  controller.addListener(changed);
  promptAllowed?.addListener(changed);
  try {
    if (!sameScope() || !context.mounted || promptAllowed?.value == false) {
      return;
    }
    var accepted = true;
    if (!controller.promptSeen) {
      route = DialogRoute<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            rescuer ? 'Encuentra adoptantes cercanos' : 'Mascotas cerca de ti',
          ),
          content: Text(
            rescuer
                ? 'Para encontrar adoptantes cercanos para tus mascotas, Dopmi necesita acceder a tu ubicación precisa mientras usas la app. Será el punto inicial de cada mascota y podrás cambiarlo en el mapa. Su ubicación exacta no se muestra públicamente.'
                : 'Para mostrarte mascotas cercanas, Dopmi necesita acceder a tu ubicación precisa mientras usas la app. Te mostraremos adopciones en un radio de 25 km.',
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
      final answer = navigator.push(route);
      final marked = controller.markPromptSeen(expectedOwner: actor);
      accepted = await answer == true && await marked;
    }
    endOwnExplanation();
    if (accepted &&
        context.mounted &&
        sameScope() &&
        promptAllowed?.value != false) {
      await controller.requestCurrentLocation(expectedOwner: actor);
      if (rescuer &&
          context.mounted &&
          sameScope() &&
          controller.error != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(controller.error!),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: () {
                if (sameScope() && promptAllowed?.value != false) {
                  unawaited(
                    requestNearbyLocation(
                      context,
                      ref,
                      promptAllowed: promptAllowed,
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    }
  } finally {
    controller.removeListener(changed);
    promptAllowed?.removeListener(changed);
    endOwnExplanation();
  }
}

/// Observe the authenticated shell; route eligibility only controls the popup.
class NearbyLocationGate extends ConsumerStatefulWidget {
  const NearbyLocationGate({
    super.key,
    required this.child,
    this.promptAllowed = true,
  });
  final Widget child;
  final bool promptAllowed;
  @override
  ConsumerState<NearbyLocationGate> createState() => _NearbyLocationGateState();
}

class _NearbyLocationGateState extends ConsumerState<NearbyLocationGate>
    with WidgetsBindingObserver {
  late final _promptAllowance = foundation.ValueNotifier(widget.promptAllowed);

  @override
  void didUpdateWidget(NearbyLocationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _promptAllowance.value = widget.promptAllowed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(configProvider).mapsEnabled) {
        final controller = ref.read(nearbyLocationControllerProvider);
        final point = controller.isRescuer
            ? controller.publicationDefault
            : controller.selection;
        if (controller.ready && point == null && controller.error == null) {
          unawaited(controller.refreshIfAllowed());
        }
      }
    });
  }

  @override
  void dispose() {
    _promptAllowance.value = false;
    _promptAllowance.dispose();
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
        if (widget.promptAllowed &&
            controller.ready &&
            controller.canUseLocation &&
            !controller.promptSeen &&
            !controller.explaining) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.promptAllowed && !controller.promptSeen) {
              unawaited(
                requestNearbyLocation(
                  context,
                  ref,
                  promptAllowed: _promptAllowance,
                ),
              );
            }
          });
        }
        return widget.child;
      },
    );
  }
}
