import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'meta_lifecycle_measurement.dart';

/// Device-scoped lifecycle measurement is independent of account CAPI consent.
final metaLifecycleControllerProvider = Provider<MetaLifecycleController?>(
  (ref) => null,
);
