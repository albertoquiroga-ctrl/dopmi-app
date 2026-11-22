import 'package:supabase_flutter/supabase_flutter.dart';

import 'attribution_action_barrier.dart';
import 'measurement.dart';

typedef ReadValueMeasurement = MeasurementController? Function();

enum ConfirmedValueOperation {
  contact('adoption_contact_created'),
  reply('rescuer_first_reply'),
  adoption('adoption_marked_adopted');

  const ConfirmedValueOperation(this.event);
  final String event;
}

class ConfirmedValueResult<T> {
  const ConfirmedValueResult(this.value, {this.signals});
  final T value;
  final Object? signals;
}

/// Capture consent before dispatch; a later opt-in never backfills an action.
/// Only one payload-free name belonging to this operation can reach the SDK.
Future<T> confirmedValueAction<T>({
  required String? Function() currentActor,
  required ReadValueMeasurement? readMeasurement,
  required ConfirmedValueOperation operation,
  required Future<ConfirmedValueResult<T>> Function() dispatch,
}) async {
  ({
    MeasurementController controller,
    String actor,
    String namespace,
    int revision,
  })?
  snapshot;
  try {
    final actor = currentActor();
    final controller = readMeasurement?.call();
    if (actor != null &&
        controller != null &&
        controller.ownerId == actor &&
        controller.analyticsConsentCurrent) {
      snapshot = (
        controller: controller,
        actor: actor,
        namespace: controller.namespace,
        revision: controller.analyticsRevision,
      );
    }
  } catch (_) {
    // Optional measurement lookup must not prevent a product operation.
  }

  final result = await dispatch();
  final before = snapshot;
  final signals = result.signals;
  if (before == null ||
      signals is! List ||
      signals.length != 1 ||
      signals.single != operation.event) {
    return result.value;
  }
  try {
    final controller = readMeasurement?.call();
    if (identical(controller, before.controller) &&
        controller != null &&
        currentActor() == before.actor &&
        controller.ownerId == before.actor &&
        controller.namespace == before.namespace &&
        controller.analyticsRevision == before.revision &&
        controller.analyticsConsentCurrent) {
      await controller.event(operation.event);
    }
  } catch (_) {
    // An accepted product write must never become a failed write due to analytics.
  }
  return result.value;
}

/// A missing additive RPC is the only safe reason to call its legacy contract.
/// Both requests retain the actor checked by the attribution/session barrier.
/// An optional primary transport receives that same actor and token, and must
/// preserve the primary envelope before this helper reports confirmed signals.
Future<({Object? value, bool confirmed})> confirmedValueRpc(
  SupabaseClient client, {
  required String primary,
  required String legacy,
  required Map<String, dynamic> params,
  Map<String, dynamic>? legacyParams,
  PrepareAttributableAction? beforeAttributableAction,
  Future<Object?> Function(String owner, String accessToken)? dispatchPrimary,
}) async {
  final actor = client.auth.currentSession?.user.id;
  final token = await attributionActionToken(client, beforeAttributableAction);
  try {
    if (actor == null || client.auth.currentSession?.user.id != actor) {
      throw StateError('La sesión cambió. Vuelve a intentarlo.');
    }
    final value = dispatchPrimary == null
        ? await client
              .rpc(primary, params: params)
              .setHeader('Authorization', 'Bearer $token')
        : await dispatchPrimary(actor, token);
    return (value: value, confirmed: true);
  } on PostgrestException catch (error) {
    if (error.code != 'PGRST202') rethrow;
    if (client.auth.currentSession?.user.id != actor) {
      throw StateError('La sesión cambió. Vuelve a intentarlo.');
    }
    final value = await client
        .rpc(legacy, params: legacyParams ?? params)
        .setHeader('Authorization', 'Bearer $token');
    return (value: value, confirmed: false);
  }
}
