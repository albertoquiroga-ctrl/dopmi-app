import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/content_links.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class LinkFixture implements ContentLinkSource {
  final initial = Completer<Uri?>();
  final stream = StreamController<Uri>.broadcast();
  @override
  Future<Uri?> latest() => initial.future;
  @override
  Stream<Uri> get events => stream.stream;
}

const id = '11111111-2222-3333-4444-555555555555';

void main() {
  test('content links accept only public UUID routes, excluding auth/payment and private targets', () {
    for (final kind in PublicContent.values) {
      final uri = publicContentLink(kind, id);
      expect(contentLinkDestination(uri), '/${uri.pathSegments.join('/')}');
    }
    for (final value in [
      'io.dopmi.app://auth/callback?code=secret',
      'io.dopmi.app://payments/return',
      'io.dopmi.app://content/messages/$id',
      'io.dopmi.app://content/people/not-a-uuid',
      'io.dopmi.app://content/people/$id?token=secret',
      'io.dopmi.app://content/people/$id#private',
      'io.dopmi.app://user@content/people/$id',
      'https://content/people/$id',
      'io.dopmi.app://content/people/$id/extra',
    ]) {
      expect(contentLinkDestination(Uri.parse(value)), isNull);
    }
  });

  for (final cold in [true, false]) {
    testWidgets('public link routes through actual app, cold=$cold', (
      tester,
    ) async {
      final links = LinkFixture();
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          contentLinkSourceProvider.overrideWithValue(links),
          routerInitialLocationProvider.overrideWithValue('/adoptions'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await links.stream.close();
        await identity.changes.close();
      });
      if (cold) {
        links.initial.complete(publicContentLink(PublicContent.profile, id));
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ContentLinkListener(child: DopmiApp()),
        ),
      );
      await tester.pumpAndSettle();
      if (!cold) {
        links.stream.add(publicContentLink(PublicContent.profile, id));
        await tester.pumpAndSettle();
        links.initial.complete(publicContentLink(PublicContent.adoption, id));
        await tester.pumpAndSettle();
      }
      expect(container.read(routerProvider).state.uri.path, '/people/$id');
      expect(find.text('Refugio Luna'), findsOneWidget);
      links.stream.add(Uri.parse('io.dopmi.app://auth/callback?code=secret'));
      links.stream.add(Uri.parse('io.dopmi.app://content/messages/$id'));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/people/$id');
      await tester.pumpWidget(const SizedBox());
      links.stream.add(publicContentLink(PublicContent.adoption, id));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
