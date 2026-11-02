import 'dart:async';

import 'location_selection.dart';
import 'nearby_location_controller.dart';

/// One initial suggestion for a new editor, never a live pet-location tracker.
class PublicationLocationDefault {
  PublicationLocationDefault({
    required this.source,
    required this.lookup,
    required this.mayApply,
    required this.apply,
  }) : _owner = source.ownerId;

  final NearbyLocationController source;
  final PlaceLookup lookup;
  final bool Function() mayApply;
  final void Function(SelectedLocation) apply;
  final String? _owner;
  bool _started = false, _disposed = false, _resolving = false;
  bool _requestedRefresh = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    source.addListener(_changed);
    scheduleMicrotask(_changed);
  }

  void _changed() {
    if (_disposed || _resolving || !mayApply()) return;
    if (_owner == null || source.ownerId != _owner || !source.isRescuer) return;
    final point = source.publicationDefault;
    if (point == null) {
      if (source.ready && !source.busy && !_requestedRefresh) {
        _requestedRefresh = true;
        // This path can read an already-authorized fix, never open an OS prompt.
        unawaited(source.refreshIfAllowed());
      }
      return;
    }
    _resolving = true;
    unawaited(_describe(point));
  }

  Future<void> _describe(SelectedLocation point) async {
    var selection = point;
    try {
      final address = await lookup
          .describe(point.coordinates)
          .timeout(const Duration(seconds: 8));
      selection = SelectedLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        city: address.city,
        region: address.region,
      );
    } catch (_) {
      // The precise point is still usable. The map can resolve or edit its zone.
    }
    _resolving = false;
    if (_disposed) return;
    if (source.ownerId == _owner &&
        identical(source.publicationDefault, point) &&
        mayApply()) {
      apply(selection);
      dispose();
    } else {
      // A foreground refresh may have replaced the fix while lookup was pending.
      _changed();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) source.removeListener(_changed);
  }
}
