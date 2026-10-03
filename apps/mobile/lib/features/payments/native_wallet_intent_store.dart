import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../adoption/community_repository.dart';
import 'guardian_repository.dart';
import 'native_wallet_repository.dart';

class NativeWalletIntentStore {
  NativeWalletIntentStore(this.preferences, this.owner);
  final SharedPreferences preferences;
  final String owner;
  String get _storageKey => 'dopmi-native-wallet:$owner:intent';

  Json? read() {
    final raw = preferences.getString(_storageKey);
    if (raw == null) return null;
    return _intent(jsonDecode(raw));
  }

  Future<Json> reserve(Json value) async {
    final intent = _intent(value);
    final existing = read();
    if (existing != null) {
      if (existing['key'] != intent['key'] ||
          existing['wallet_type'] != intent['wallet_type']) {
        throw const FormatException(
          'Retoma la solicitud de billetera pendiente.',
        );
      }
      return existing;
    }
    if (!await preferences.setString(_storageKey, jsonEncode(intent))) {
      throw const FormatException(
        'No pudimos conservar tu solicitud. Intenta de nuevo.',
      );
    }
    return intent;
  }

  // A late response must not discard a newer intent, and cancellation of the
  // native sheet is not evidence that the server authorization is terminal.
  Future<void> finish(Json value) async {
    final receipt = nativeWalletReceipt(value);
    final current = read();
    if (current == null ||
        current['key'] != receipt['key'] ||
        current['wallet_type'] != receipt['wallet_type'] ||
        !['saved', 'expired'].contains(receipt['status'])) {
      throw const FormatException('La solicitud de billetera sigue pendiente.');
    }
    if (!await preferences.remove(_storageKey)) {
      throw const FormatException('No pudimos actualizar tu solicitud.');
    }
  }
}

Json _intent(Object? value) {
  if (value is! Map || value['consent_version'] != savedCardConsent) {
    throw const FormatException('Solicitud de billetera incompleta.');
  }
  final receipt = nativeWalletReceipt({
    'key': value['key'],
    'wallet_type': value['wallet_type'],
    'status': 'pending',
    'card_id': null,
  });
  return {
    'key': receipt['key'],
    'wallet_type': receipt['wallet_type'],
    'consent_version': savedCardConsent,
  };
}
