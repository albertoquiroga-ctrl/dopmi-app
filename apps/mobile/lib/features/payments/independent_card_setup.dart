import '../adoption/community_repository.dart';
import 'guardian_method_setup.dart';
import 'guardian_repository.dart';

class IndependentCardSetupResult {
  const IndependentCardSetupResult(this.receipt, {this.uncertain = false});
  // Only the public operation receipt leaves the coordinator, never a secret.
  final Json receipt;
  final bool uncertain;
}

class IndependentCardSetup {
  IndependentCardSetup({required this.repository, required this.sdk});
  final GuardianRepository repository;
  final GuardianMethodSetup sdk;

  Future<IndependentCardSetupResult?> run(
    Json intent, {
    required bool Function() current,
  }) async {
    if (!current()) return null;
    final key = intent['key'] as String;
    Json result;
    try {
      result = await repository.submit(intent);
    } catch (_) {
      if (!current() || intent['presentation'] != 'native_card') rethrow;
      final status = await repository.nativeSavedCardStatus(key);
      if (!current()) return null;
      if (status == null) throw const FormatException('Alta no confirmada');
      return IndependentCardSetupResult(
        savedCardReceipt(status),
        uncertain: status['status'] != 'saved',
      );
    }
    if (!current()) return null;
    if (result['presentation'] == 'native_card') {
      final secret = result['setup_client_secret'];
      var uncertain = false;
      if (secret is String) {
        try {
          if (!sdk.available) {
            throw const FormatException('Método no disponible');
          }
          await sdk.present(secret, current: current);
        } catch (_) {
          uncertain = true;
        }
      }
      if (!current()) return null;
      final status = await repository.nativeSavedCardStatus(key);
      if (!current()) return null;
      if (status == null) throw const FormatException('Alta no confirmada');
      return IndependentCardSetupResult(
        savedCardReceipt(status),
        uncertain: uncertain && status['status'] != 'saved',
      );
    }
    // An existing hosted intent retains its original channel. This branch is
    // reached before presenting the SDK, never as recovery from an SDK failure.
    if (intent['presentation'] == 'native_card' &&
        result['presentation'] != 'hosted_checkout') {
      throw const FormatException('Canal de tarjeta no confirmado');
    }
    final checkout = result['checkout_url'];
    if (checkout is String) await repository.openCheckout(checkout);
    if (!current()) return null;
    return IndependentCardSetupResult(savedCardReceipt(result));
  }
}
