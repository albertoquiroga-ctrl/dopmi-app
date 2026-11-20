import 'package:supabase_flutter/supabase_flutter.dart';

typedef PrepareAttributableAction = Future<void> Function(String actor);

/// Optional measurement gets at most ten seconds before the product continues.
/// A timed-out registration is not evidence of a successful attribution.
/// Authentication changes are product errors and must never fail open.
Future<String> attributionActionToken(
  SupabaseClient client,
  PrepareAttributableAction? prepare, {
  Duration preparationTimeout = const Duration(seconds: 10),
}) async {
  final actor = client.auth.currentSession?.user.id;
  if (actor == null) {
    throw StateError('La sesión cambió. Vuelve a intentarlo.');
  }
  if (prepare != null) {
    try {
      await prepare(actor).timeout(preparationTimeout);
    } catch (_) {
      // Consent, referrer availability, and measurement transport cannot block
      // a valid adoption or message. The server records only confirmed events.
    }
  }
  final session = await client.auth.getSession();
  if (session == null ||
      session.user.id != actor ||
      client.auth.currentSession?.user.id != actor) {
    throw StateError('La sesión cambió. Vuelve a intentarlo.');
  }
  // Pin this request to the checked actor, even if auth changes while the SDK
  // prepares its HTTP request. A refreshed token from the same actor is valid.
  return session.accessToken;
}
