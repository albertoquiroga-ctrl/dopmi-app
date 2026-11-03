import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/ui.dart';
import '../identity/identity_controller.dart';
import 'location_selection.dart';
import 'location_service.dart';

typedef LocationMapBuilder = Widget Function(
  BuildContext context,
  ApproximateLocation? point,
  ValueChanged<ApproximateLocation> select,
);

final locationMapBuilderProvider = Provider<LocationMapBuilder>(
  (_) =>
      (context, point, select) =>
          _NativeLocationMap(point: point, select: select),
);

Future<SelectedLocation?> chooseLocationOnMap(
  BuildContext context, {
  SelectedLocation? initial,
  String city = '',
  String region = '',
  bool requireAddress = true,
}) {
  if (!ProviderScope.containerOf(
    context,
    listen: false,
  ).read(configProvider).mapsEnabled) {
    return Future.value(null);
  }
  return showModalBottomSheet<SelectedLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: ColoredBox(
          color: const Color(0xf2ffffff),
          child: LocationMapPicker(
            initial: initial,
            city: city,
            region: region,
            requireAddress: requireAddress,
          ),
        ),
      ),
    ),
  );
}

class LocationMapPicker extends ConsumerStatefulWidget {
  const LocationMapPicker({
    super.key,
    this.initial,
    this.city = '',
    this.region = '',
    this.requireAddress = true,
  });
  final SelectedLocation? initial;
  final String city, region;
  final bool requireAddress;
  @override
  ConsumerState<LocationMapPicker> createState() => _LocationMapPickerState();
}

class _LocationMapPickerState extends ConsumerState<LocationMapPicker>
    with WidgetsBindingObserver {
  late final query = TextEditingController(
    text: [widget.city, widget.region].where((s) => s.isNotEmpty).join(', '),
  );
  late final city = TextEditingController(
    text: widget.initial?.city ?? widget.city,
  );
  late final region = TextEditingController(
    text: widget.initial?.region ?? widget.region,
  );
  late ApproximateLocation? point = widget.initial?.coordinates;
  late bool followDevice = widget.initial?.followDevice ?? false;
  late final identity = ref.read(identityControllerProvider);
  late final environment = ref.read(configProvider).environment;
  late final server = ref.read(configProvider).url;
  late final String? owner = identity.identity?.id;
  int revision = 0;
  bool busy = false, ownerChanged = false;
  String? error;
  String progress = 'Identificando la zona…';
  LocationSettingsTarget? settingsTarget;

  bool get sameEnvironment =>
      ref.read(configProvider).environment == environment &&
      ref.read(configProvider).url == server;

  bool current(int version) =>
      mounted &&
      !ownerChanged &&
      sameEnvironment &&
      revision == version &&
      ref.read(identityControllerProvider).identity?.id == owner;

  @override
  void initState() {
    super.initState();
    identity.addListener(identityChanged);
    WidgetsBinding.instance.addObserver(this);
    if (widget.initial != null &&
        widget.requireAddress &&
        (city.text.trim().isEmpty || region.text.trim().isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          resolve(
            (_) => ref
                .read(placeLookupProvider)
                .describe(widget.initial!.coordinates),
            preservePoint: true,
          );
        }
      });
    }
  }

  void identityChanged() {
    if (!mounted || identity.identity?.id == owner) return;
    revision++;
    setState(() {
      ownerChanged = true;
      point = null;
      city.clear();
      region.clear();
      query.clear();
      busy = false;
      error = 'La cuenta cambió. Cierra el mapa y vuelve a abrirlo.';
    });
  }

  Future<void> resolve(
    Future<SelectedLocation> Function(int version) action, {
    bool preservePoint = false,
    String progressMessage = 'Identificando la zona…',
  }) async {
    final version = ++revision;
    setState(() {
      busy = true;
      error = null;
      settingsTarget = null;
      progress = progressMessage;
    });
    try {
      final result = await action(version).timeout(const Duration(seconds: 20));
      if (!current(version)) return;
      setState(() {
        if (!preservePoint) {
          point = result.coordinates;
          followDevice = false;
        }
        city.text = result.city;
        region.text = result.region;
      });
    } catch (cause) {
      if (!current(version)) return;
      // A timeout does not cancel the native Future. Its eventual result must
      // not change this selection after the user has already seen an error.
      revision++;
      setState(() {
        busy = false;
        error = cause is LocationException ? cause.message : 'No pudimos identificar la zona. Puedes elegirla en el mapa y escribir ciudad y estado.';
        settingsTarget = cause is LocationException
            ? cause.settingsTarget
            : null;
      });
    } finally {
      if (current(version)) setState(() => busy = false);
    }
  }

  void select(ApproximateLocation value) {
    if (ownerChanged) return;
    setState(() {
      point = value;
      followDevice = false;
      city.clear();
      region.clear();
    });
    resolve(
      (_) => ref.read(placeLookupProvider).describe(value),
      preservePoint: true,
    );
  }

  Future<void> search() => resolve(
    (_) => ref.read(placeLookupProvider).search(query.text),
    progressMessage: 'Buscando la zona…',
  );

  Future<void> locate() {
    return resolve(
      (version) async {
        final value = await ref.read(locationServiceProvider).current();
        // Keep a usable selected zone even if the native address lookup fails.
        if (!current(version)) {
          throw const LocationException('La selección cambió.');
        }
        if (current(version)) {
          setState(() {
            progress = 'Identificando la zona…';
            if (point == null) {
              point = value;
              followDevice = true;
              city.clear();
              region.clear();
            }
          });
        }
        final address = await ref.read(placeLookupProvider).describe(value);
        if (current(version)) {
          setState(() {
            point = value;
            followDevice = true;
          });
        }
        return address;
      },
      preservePoint: true,
      progressMessage: 'Obteniendo tu ubicación…',
    );
  }

  @override
  void dispose() {
    revision++;
    identity.removeListener(identityChanged);
    WidgetsBinding.instance.removeObserver(this);
    query.dispose();
    city.dispose();
    region.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive) {
      revision++;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ownerChanged ||
        !sameEnvironment ||
        !ref.watch(configProvider).mapsEnabled) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Notice(
                ownerChanged
                    ? 'La cuenta cambió. Cierra el mapa y vuelve a abrirlo.'
                    : !sameEnvironment
                    ? 'El entorno cambió. Cierra el mapa y vuelve a abrirlo.'
                    : 'El mapa aún no está disponible. Puedes continuar con ciudad y estado.',
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar mapa'),
              ),
            ],
          ),
        ),
      );
    }
    final addressReady =
        !widget.requireAddress ||
        (city.text.trim().isNotEmpty && region.text.trim().isNotEmpty);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ubicación',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar mapa',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.requireAddress
                          ? 'Selecciona el punto de la mascota. Se guarda de forma privada; públicamente mostramos sólo la zona.'
                          : 'Encuentra mascotas en adopción cercanas. Puedes elegir una zona sin activar el GPS.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('location-map-query'),
                      controller: query,
                      decoration: const InputDecoration(
                        labelText: 'Buscar ciudad o zona',
                      ),
                      onChanged: (_) => setState(() {
                        revision++;
                        busy = false;
                        error = null;
                        settingsTarget = null;
                      }),
                      onSubmitted: busy ? null : (_) => search(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: busy || query.text.trim().isEmpty
                              ? null
                              : search,
                          child: const Text('Buscar zona'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : locate,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Cerca de mi ubicación actual'),
                        ),
                      ],
                    ),
                    if (busy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Semantics(liveRegion: true, child: Text(progress)),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 260,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ref.read(locationMapBuilderProvider)(
                          context,
                          point,
                          select,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Toca el mapa para ajustar el punto. Su ubicación exacta no se muestra públicamente.',
                    ),
                    if (widget.requireAddress || point != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('location-map-city'),
                        controller: city,
                        onChanged: (_) => setState(() {
                          revision++;
                          busy = false;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Ciudad o municipio',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('location-map-region'),
                        controller: region,
                        onChanged: (_) => setState(() {
                          revision++;
                          busy = false;
                        }),
                        decoration: const InputDecoration(labelText: 'Estado'),
                      ),
                    ],
                    if (error != null) Notice(error!, isError: true),
                    if (settingsTarget != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => ref
                                  .read(locationServiceProvider)
                                  .openSettings(settingsTarget!),
                        child: const Text('Abrir ajustes de ubicación'),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('location-map-confirm'),
                      onPressed: busy || point == null || !addressReady
                          ? null
                          : () {
                              if (!sameEnvironment ||
                                  ref
                                          .read(identityControllerProvider)
                                          .identity
                                          ?.id !=
                                      owner) {
                                return;
                              }
                              Navigator.pop(
                                context,
                                SelectedLocation(
                                  latitude: point!.latitude,
                                  longitude: point!.longitude,
                                  city: city.text.trim(),
                                  region: region.text.trim(),
                                  followDevice: followDevice,
                                ),
                              );
                            },
                      child: const Text('Usar esta ubicación'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PublicationLocationField extends StatelessWidget {
  const PublicationLocationField({
    super.key,
    required this.city,
    required this.region,
    required this.selection,
    this.onChoose,
  });
  final String city, region;
  final SelectedLocation? selection;
  final VoidCallback? onChoose;
  @override
  Widget build(BuildContext context) {
    final label = [
      city.trim(),
      region.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ubicación *',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.isEmpty ? 'Elige dónde se encuentra la mascota' : label,
                ),
              ),
            ],
          ),
          if (onChoose != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('publication-location-map'),
                onPressed: onChoose,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  selection == null ? 'Elegir en mapa' : 'Cambiar ubicación',
                ),
              ),
            ),
            Text(
              selection == null
                  ? 'Selecciona la ubicación de la mascota en el mapa para continuar.'
                  : 'El punto se guarda de forma privada para calcular cercanía. Públicamente se muestran ciudad y estado.',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _NativeLocationMap extends StatefulWidget {
  const _NativeLocationMap({required this.point, required this.select});
  final ApproximateLocation? point;
  final ValueChanged<ApproximateLocation> select;
  @override
  State<_NativeLocationMap> createState() => _NativeLocationMapState();
}

class _NativeLocationMapState extends State<_NativeLocationMap> {
  GoogleMapController? controller;
  LatLng get center => widget.point == null
      ? const LatLng(23.6, -102.5)
      : LatLng(widget.point!.latitude, widget.point!.longitude);
  @override
  void didUpdateWidget(_NativeLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.point != null && !identical(oldWidget.point, widget.point)) {
      controller?.animateCamera(CameraUpdate.newLatLngZoom(center, 12));
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GoogleMap(
    gestureRecognizers: {
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
    },
    initialCameraPosition: CameraPosition(
      target: center,
      zoom: widget.point == null ? 4 : 12,
    ),
    onMapCreated: (value) {
      if (mounted) {
        controller = value;
        // A GPS result may arrive while the native view is still initializing.
        // initialCameraPosition is not reapplied when the widget updates.
        if (widget.point != null) {
          value.moveCamera(CameraUpdate.newLatLngZoom(center, 12));
        }
      } else {
        value.dispose();
      }
    },
    onTap: (value) =>
        widget.select(ApproximateLocation(value.latitude, value.longitude)),
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    mapToolbarEnabled: false,
    markers: {
      if (widget.point != null)
        Marker(markerId: const MarkerId('selected-zone'), position: center),
    },
    circles: {
      if (widget.point?.accuracyMeters != null)
        Circle(
          circleId: const CircleId('gps-accuracy'),
          center: center,
          radius: widget.point!.accuracyMeters!,
          fillColor: const Color(0x22eb6425),
          strokeWidth: 1,
          strokeColor: const Color(0xffeb6425),
        ),
    },
  );
}
