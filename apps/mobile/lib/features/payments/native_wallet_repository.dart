import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../adoption/community_repository.dart';
import 'guardian_repository.dart';

final nativeWalletRepositoryProvider = Provider<NativeWalletRepository>(
  (ref) => NativeWalletRepository(Supabase.instance.client),
);

class NativeWalletRepository {
  NativeWalletRepository(this.client);
  final SupabaseClient client;

  Future<Json?> state() async {
    final result = await client.rpc('dopmi_saved_wallet_state');
    return result == null ? null : nativeWalletReceipt(result);
  }

  // The SDK secret is transient. Only the minimal owner receipt may be stored.
  Future<Json> submit(Json intent) async {
    if (intent['consent_version'] != savedCardConsent ||
        !['apple_pay', 'google_pay'].contains(intent['wallet_type']) ||
        !_uuid.hasMatch(intent['key'] is String ? intent['key'] : '')) {
      throw const FormatException('Solicitud de billetera incompleta');
    }
    final response = await client.functions.invoke(
      'guardian-client',
      body: {
        'action': 'add_wallet',
        'key': intent['key'],
        'wallet_type': intent['wallet_type'],
        'consent': true,
        'consent_version': savedCardConsent,
      },
    );
    if (response.status != 200) {
      throw const FormatException('Billetera no confirmada');
    }
    final receipt = nativeWalletReceipt(response.data);
    if (receipt['key'] != intent['key'] ||
        receipt['wallet_type'] != intent['wallet_type']) {
      throw const FormatException('Billetera no confirmada');
    }
    final secret = (response.data as Map)['setup_client_secret'];
    if (secret != null &&
        (receipt['status'] != 'pending' ||
            secret is! String ||
            !RegExp(r'^seti_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$')
                .hasMatch(secret))) {
      throw const FormatException('Autorización de billetera no confirmada');
    }
    return {...receipt, 'setup_client_secret': secret};
  }
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

Json nativeWalletReceipt(Object? value) {
  if (value is! Map ||
      value['key'] is! String ||
      !_uuid.hasMatch(value['key']) ||
      !['apple_pay', 'google_pay'].contains(value['wallet_type']) ||
      !['pending', 'saved', 'expired', 'attention'].contains(value['status']) ||
      (value['status'] == 'saved'
          ? value['card_id'] is! String ||
                !RegExp(r'^pm_[A-Za-z0-9]+$').hasMatch(value['card_id'])
          : value['card_id'] != null)) {
    throw const FormatException('Comprobante de billetera no confirmado');
  }
  return {
    'key': value['key'],
    'wallet_type': value['wallet_type'],
    'status': value['status'],
    'card_id': value['card_id'],
  };
}
