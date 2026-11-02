import 'dart:async';

import 'package:dopmi_mobile/features/adoption/location_map_picker.dart';
import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// The platform seam belongs to the locked Google Maps dependency under test.
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;

/// Keep the native view at its original camera while controller readiness waits.
class DelayedReadyMap extends maps.MethodChannelGoogleMapsFlutter {
  final ready = Completer<void>();
  final cameraUpdates = <CameraUpdate>[];
  final channels = <MethodChannel>[];
  CameraPosition? nativeInitialCamera;

  @override
  Future<void> updateGroundOverlays(
    maps.GroundOverlayUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> init(int mapId) {
    final channel = ensureChannelInitialized(mapId);
    channels.add(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    return ready.future;
  }

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required maps.MapWidgetConfiguration widgetConfiguration,
    maps.MapObjects mapObjects = const maps.MapObjects(),
    maps.MapConfiguration mapConfiguration = const maps.MapConfiguration(),
  }) {
    if (nativeInitialCamera == null) {
      nativeInitialCamera = widgetConfiguration.initialCameraPosition;
      onPlatformViewCreated(creationId);
    }
    return const SizedBox(key: ValueKey('delayed-native-map'));
  }

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    cameraUpdates.add(cameraUpdate);
  }

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    cameraUpdates.add(cameraUpdate);
  }
}

void main() {
  testWidgets(
    'a device point arriving before native readiness updates both marker and camera',
    (tester) async {
      final previousPlatform = maps.GoogleMapsFlutterPlatform.instance;
      final platform = DelayedReadyMap();
      maps.GoogleMapsFlutterPlatform.instance = platform;
      final container = ProviderContainer();
      final point = ValueNotifier<ApproximateLocation?>(null);
      addTearDown(() async {
        if (!platform.ready.isCompleted) platform.ready.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        for (final channel in platform.channels) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        }
        maps.GoogleMapsFlutterPlatform.instance = previousPlatform;
        point.dispose();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<ApproximateLocation?>(
                valueListenable: point,
                builder: (context, value, _) => Consumer(
                  builder: (context, ref, _) => SizedBox(
                    height: 260,
                    child: ref.read(locationMapBuilderProvider)(
                      context,
                      value,
                      (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(platform.nativeInitialCamera?.target, const LatLng(23.6, -102.5));
      expect(platform.ready.isCompleted, isFalse);

      // Inject the GPS result at the map's existing public builder seam. The
      // real _NativeLocationMap remains mounted; only native readiness is fake.
      point.value = const ApproximateLocation(25.686614, -100.316113);
      await tester.pump();
      const expected = LatLng(25.686614, -100.316113);
      final mapGesture = tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .gestureRecognizers
          .single
          .constructor();
      expect(mapGesture, isA<EagerGestureRecognizer>());
      mapGesture.dispose();
      expect(
        tester
            .widget<GoogleMap>(find.byType(GoogleMap))
            .markers
            .single
            .position,
        expected,
      );
      expect(platform.cameraUpdates, isEmpty);

      platform.ready.complete();
      await tester.pumpAndSettle();
      expect(
        platform.cameraUpdates.map((update) => update.toJson()),
        contains(equals(CameraUpdate.newLatLngZoom(expected, 12).toJson())),
        reason: 'The selected marker must not leave the native camera at its old origin.',
      );
      platform.cameraUpdates.clear();
      // A repeated explicit GPS choice must recenter even if the fix is the same.
      point.value = ApproximateLocation(25.686614, -100.316113);
      await tester.pumpAndSettle();
      expect(
        platform.cameraUpdates.map((update) => update.toJson()),
        contains(equals(CameraUpdate.newLatLngZoom(expected, 12).toJson())),
        reason:
            'A new GPS result must recenter a map the user may have panned.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
