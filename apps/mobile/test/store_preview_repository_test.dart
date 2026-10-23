import 'dart:async';

import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> previewCatalog({bool links = false}) => {
  'enabled': true,
  'preview': true,
  'expires_at': DateTime.now()
      .add(const Duration(hours: 1))
      .toUtc()
      .toIso8601String(),
  'external_links_enabled': links,
  'items': [
    {
      'id': 'preview-one',
      'name': 'Alimento TEST adulto',
      'brand': 'Marca TEST',
      'species': 'dog',
      'age': 'adult',
      'size': 'small',
      'weight_kg': 10,
      'asset_key': 'croquetas-banner-pet',
      'merchant_name': 'Dopmi TEST',
    },
  ],
};

void main() {
  test('anonymous OFF never calls preview, selected actor uses explicit TEST catalog', () async {
    String? actor;
    final calls = <String>[];
    final repository = RpcStoreRepository(
      currentUser: () => actor,
      changes: const Stream.empty(),
      rpc: (name, params) async {
        calls.add(name);
        return name == 'dopmi_store_catalog'
            ? {'enabled': false, 'items': []}
            : previewCatalog();
      },
    );
    expect((await repository.catalog()).enabled, false);
    expect(calls, ['dopmi_store_catalog']);
    actor = 'selected';
    final result = await repository.catalog();
    expect(result.enabled, true);
    expect(result.preview, true);
    expect(result.products.single.assetKey, 'croquetas-banner-pet');
    expect(result.externalLinksEnabled, false);
    expect(await repository.productLink('preview-one'), isNull);
    expect(calls, [
      'dopmi_store_catalog',
      'dopmi_store_catalog',
      'dopmi_store_preview_catalog',
    ]);
  });

  test('ordinary account, expired response and disabled stale inventory stay closed', () async {
    final repository = RpcStoreRepository(
      currentUser: () => 'ordinary',
      changes: const Stream.empty(),
      rpc: (name, _) async => name == 'dopmi_store_catalog'
          ? {'enabled': false, 'items': []}
          : {
              'enabled': false,
              'preview': true,
              'items': [
                {'stale': 'private'},
              ],
            },
    );
    final result = await repository.catalog();
    expect(result.enabled, false);
    expect(result.products, isEmpty);
    final expired = previewCatalog()..['expires_at'] = '2020-01-01T00:00:00Z';
    expect(StoreCatalog.fromJson(expired).products, isEmpty);
    expect(
      StoreCatalog.fromJson(previewCatalog()..remove('expires_at')).enabled,
      false,
    );
  });

  test(
    'account changes and superseded requests cannot deliver a private response',
    () async {
      String? actor = 'first';
      final pending = Completer<dynamic>();
      final repository = RpcStoreRepository(
        currentUser: () => actor,
        changes: const Stream.empty(),
        rpc: (name, _) async {
          if (name == 'dopmi_store_catalog') {
            return {'enabled': false, 'items': []};
          }
          // The RPC boundary yields the decoded response, not a Future stored
          // as the value of a mixed Map/Future conditional expression.
          return await pending.future;
        },
      );
      final first = repository.catalog();
      await Future<void>.delayed(Duration.zero);
      actor = 'second';
      final rejection = expectLater(first, throwsStateError);
      pending.complete(previewCatalog());
      await rejection;
      expect(await repository.productLink('preview-one'), isNull);
    },
  );

  test(
    'preview link revalidates through separate RPC and rejects revoked result',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      var revoked = false;
      final repository = RpcStoreRepository(
        currentUser: () => 'selected',
        changes: const Stream.empty(),
        rpc: (name, params) async {
          calls.add((name, params));
          if (name == 'dopmi_store_catalog') {
            return {'enabled': false, 'items': []};
          }
          if (name == 'dopmi_store_preview_catalog') {
            return previewCatalog(links: true);
          }
          return revoked ? null : 'https://qa.example.test/exact';
        },
      );
      await repository.catalog();
      expect(await repository.productLink('not-in-this-catalog'), isNull);
      expect(
        await repository.productLink('preview-one'),
        Uri.parse('https://qa.example.test/exact'),
      );
      expect(calls.last.$1, 'dopmi_store_preview_product_link');
      expect(calls.last.$2, {'p_id': 'preview-one'});
      revoked = true;
      expect(await repository.productLink('preview-one'), isNull);
    },
  );

  test(
    'a slower earlier request cannot replace a newer closed catalog',
    () async {
      final pending = Completer<dynamic>();
      var publicCalls = 0;
      final repository = RpcStoreRepository(
        currentUser: () => 'selected',
        changes: const Stream.empty(),
        rpc: (name, _) async {
          if (name == 'dopmi_store_catalog' && ++publicCalls == 1) {
            return pending.future;
          }
          return name == 'dopmi_store_catalog'
              ? {'enabled': false, 'items': []}
              : {'enabled': false, 'preview': true, 'items': []};
        },
      );
      final first = repository.catalog();
      final rejection = expectLater(first, throwsStateError);
      expect((await repository.catalog()).enabled, false);
      pending.complete({'enabled': false, 'items': []});
      await rejection;
      expect(await repository.productLink('preview-one'), isNull);
    },
  );

  test(
    'TEST response rejects arbitrary asset paths and commercial-looking names',
    () async {
      final payload = previewCatalog();
      final repository = RpcStoreRepository(
        currentUser: () => 'selected',
        changes: const Stream.empty(),
        rpc: (name, _) async => name == 'dopmi_store_catalog'
            ? {'enabled': false, 'items': []}
            : payload,
      );
      (payload['items'] as List).single['asset_key'] = '../private';
      await expectLater(repository.catalog(), throwsFormatException);
      (payload['items'] as List).single['asset_key'] = 'croquetas-banner-pet';
      (payload['items'] as List).single['name'] = 'Producto comercial';
      await expectLater(repository.catalog(), throwsFormatException);
    },
  );
}
