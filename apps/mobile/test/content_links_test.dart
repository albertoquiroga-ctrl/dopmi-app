import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/content_links.dart';
import 'package:dopmi_mobile/features/adoption/catalog_screens.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  test('the production adoption URL is canonical and opens the pet', () {
    final uri = Uri.parse('https://www.dopmi.org/adoptions/$id');
    expect(
      publicContentLink(PublicContent.adoption, id, production: true),
      uri,
    );
    expect(contentLinkDestination(uri), '/adoptions/$id');
    expect(
      publicContentLink(PublicContent.adoption, id).toString(),
      'io.dopmi.app://content/adoptions/$id',
    );
    expect(
      publicContentLink(
        PublicContent.rescueCase,
        id,
        production: true,
      ).toString(),
      'io.dopmi.app://content/rescue-cases/$id',
    );
  });

  test('the production profile URL is canonical and opens the owner', () {
    final uri = Uri.parse('https://www.dopmi.org/people/$id');
    expect(publicContentLink(PublicContent.profile, id, production: true), uri);
    expect(contentLinkDestination(uri), '/people/$id');
    expect(
      publicContentLink(PublicContent.profile, id).toString(),
      'io.dopmi.app://content/people/$id',
    );
  });

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
      'http://www.dopmi.org/adoptions/$id',
      'https://www.dopmi.org.evil.test/adoptions/$id',
      'https://www.dopmi.org/adoptions/$id?token=private',
      'https://www.dopmi.org/adoptions/$id#private',
      'https://user@www.dopmi.org/adoptions/$id',
      'https://www.dopmi.org:8443/adoptions/$id',
      'https://www.dopmi.org/adoptions/not-a-uuid',
      'http://www.dopmi.org/people/$id',
      'https://www.dopmi.org.evil.test/people/$id',
      'https://www.dopmi.org/people/$id?token=private',
      'https://www.dopmi.org/people/$id#private',
      'https://user@www.dopmi.org/people/$id',
      'https://www.dopmi.org:8443/people/$id',
      'https://www.dopmi.org/people/not-a-uuid',
    ]) {
      expect(contentLinkDestination(Uri.parse(value)), isNull);
    }
  });

  testWidgets('Compartir perfil sends an HTTPS URL on its own line', (
    tester,
  ) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'dev.fluttercommunity.plus/share/dismissed';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(
            const AppConfig(
              url: 'https://ysaoeuidcvgtlmphmeyb.supabase.co',
              key: 'sb_publishable_fixture',
              redirect: 'io.dopmi.app://auth/callback',
              environment: 'production',
            ),
          ),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        ],
        child: const MaterialApp(home: PublicProfileScreen(id)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Compartir'));
    await tester.pumpAndSettle();
    expect(
      calls.single.arguments['text'],
      'Conoce este perfil en DopMi.\nhttps://www.dopmi.org/people/$id',
    );
  });

  testWidgets('Compartir sends an HTTPS URL on its own line', (tester) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'dev.fluttercommunity.plus/share/dismissed';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final community = FakeCommunity();
    community.post = Adoption({...community.post.data, 'id': id});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(
            const AppConfig(
              url: 'https://ysaoeuidcvgtlmphmeyb.supabase.co',
              key: 'sb_publishable_fixture',
              redirect: 'io.dopmi.app://auth/callback',
              environment: 'production',
            ),
          ),
          communityRepositoryProvider.overrideWithValue(community),
        ],
        child: const MaterialApp(home: AdoptionDetailScreen(id)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Compartir'));
    await tester.pumpAndSettle();
    expect(
      calls.single.arguments['text'],
      'Conoce la historia de Luna en DopMi.\nhttps://www.dopmi.org/adoptions/$id',
    );
  });

  for (final cold in [true, false]) {
    for (final production in [true, false]) {
      testWidgets(
        'public link routes through actual app, cold=$cold production=$production',
        (tester) async {
          final links = LinkFixture();
          final identity = FakeIdentityRepository()
            ..user = const Identity(
              'one',
              'fixture@example.test',
              verified: true,
            );
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
            links.initial.complete(
              publicContentLink(
                PublicContent.profile,
                id,
                production: production,
              ),
            );
          }
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const ContentLinkListener(child: DopmiApp()),
            ),
          );
          await tester.pumpAndSettle();
          if (!cold) {
            links.stream.add(
              publicContentLink(
                PublicContent.profile,
                id,
                production: production,
              ),
            );
            await tester.pumpAndSettle();
            links.initial.complete(
              publicContentLink(PublicContent.adoption, id),
            );
            await tester.pumpAndSettle();
          }
          expect(container.read(routerProvider).state.uri.path, '/people/$id');
          expect(find.text('Refugio Luna'), findsOneWidget);
          links.stream.add(
            Uri.parse('io.dopmi.app://auth/callback?code=secret'),
          );
          links.stream.add(Uri.parse('io.dopmi.app://content/messages/$id'));
          await tester.pumpAndSettle();
          expect(container.read(routerProvider).state.uri.path, '/people/$id');
          await tester.pumpWidget(const SizedBox());
          links.stream.add(publicContentLink(PublicContent.adoption, id));
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
