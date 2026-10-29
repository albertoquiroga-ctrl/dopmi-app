import 'dart:convert';

import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Profile profile(String terms, String privacy, {bool adult = true}) => Profile(
  id: 'one',
  name: 'Ana',
  phone: '',
  city: '',
  mode: 'donor',
  intent: 'adopt',
  status: 'active',
  termsVersion: terms,
  privacyVersion: privacy,
  adultConfirmed: adult,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const pairs = [
    (
      environment: 'test',
      terms: 'terms-2026-10-17',
      privacy: 'privacy-2026-10-17',
      date: '17 de octubre de 2026',
    ),
    (
      environment: 'production',
      terms: 'terms-live-2026-10-28',
      privacy: 'privacy-live-2026-10-28',
      date: '28 de octubre de 2026',
    ),
  ];

  for (final pair in pairs) {
    test(
      '${pair.environment} signup and explicit acceptance send the same legal pair',
      () async {
        expect(legalVersionsForEnvironment(pair.environment), (
          terms: pair.terms,
          privacy: pair.privacy,
          date: pair.date,
        ));
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'http://127.0.0.1:54321',
          'synthetic-key',
          authOptions: const AuthClientOptions(
            autoRefreshToken: false,
            authFlowType: AuthFlowType.implicit,
          ),
          httpClient: MockClient((request) async {
            requests.add(request);
            final signup = request.url.path == '/auth/v1/signup';
            expect(
              signup || request.url.path == '/rest/v1/rpc/dopmi_accept_legal',
              true,
            );
            return http.Response(
              jsonEncode(
                signup
                    ? {
                        'id': '4687b936-6d19-4d6e-8b2b-dbe47b5f639c',
                        'aud': 'authenticated',
                        'role': 'authenticated',
                        'email': 'fixture@example.test',
                        'app_metadata': {},
                        'user_metadata': {},
                        'created_at': '2026-10-28T00:00:00Z',
                      }
                    : null,
              ),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabaseIdentityRepository(
          client,
          AppConfig(
            url: 'http://127.0.0.1:54321',
            key: 'synthetic-key',
            redirect: 'io.dopmi.app://auth/callback',
            environment: pair.environment,
          ),
          await SharedPreferences.getInstance(),
        );
        await repository.signup(
          name: 'Ana',
          email: 'fixture@example.test',
          phone: '',
          password: 'synthetic-password',
          intent: 'adopt',
        );
        await repository.acceptTerms();
        expect(requests, hasLength(2));
        expect((jsonDecode(requests.first.body) as Map)['data'], {
          'display_name': 'Ana',
          'phone': '',
          'intent': 'adopt',
          'terms_version': pair.terms,
          'terms_accepted': true,
          'privacy_version': pair.privacy,
          'adult_confirmed': true,
        });
        expect(jsonDecode(requests.last.body), {
          'accepted_terms': pair.terms,
          'accepted_privacy': pair.privacy,
          'confirms_adult': true,
        });
      },
    );

    test(
      '${pair.environment} legal gate requires its exact pair, adult confirmation and owner',
      () {
        final matching = profile(pair.terms, pair.privacy);
        expect(
          hasCurrentLegalConsent(
            matching,
            'one',
            environment: pair.environment,
          ),
          true,
        );
        expect(
          hasCurrentLegalConsent(
            matching,
            'other',
            environment: pair.environment,
          ),
          false,
        );
        expect(
          hasCurrentLegalConsent(matching, null, environment: pair.environment),
          false,
        );
        expect(
          hasCurrentLegalConsent(
            profile(pair.terms, pair.privacy, adult: false),
            'one',
            environment: pair.environment,
          ),
          false,
        );
        for (final other in pairs.where(
          (value) => value.environment != pair.environment,
        )) {
          expect(
            hasCurrentLegalConsent(
              profile(other.terms, other.privacy),
              'one',
              environment: pair.environment,
            ),
            false,
          );
          expect(
            hasCurrentLegalConsent(
              profile(pair.terms, other.privacy),
              'one',
              environment: pair.environment,
            ),
            false,
          );
          expect(
            hasCurrentLegalConsent(
              profile(other.terms, pair.privacy),
              'one',
              environment: pair.environment,
            ),
            false,
          );
        }
        expect(matching.termsVersion, pair.terms);
        expect(matching.privacyVersion, pair.privacy);
      },
    );
  }

  test('unknown environments send no signup or acceptance request and accept no prior pair', () async {
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (_) async => fail('unknown environment must stop before HTTP'),
      ),
    );
    addTearDown(client.dispose);
    for (final environment in ['', 'live', 'staging', 'Production']) {
      expect(legalVersionsForEnvironment(environment), isNull);
      final repository = SupabaseIdentityRepository(
        client,
        AppConfig(
          url: 'http://127.0.0.1:54321',
          key: 'synthetic-key',
          redirect: 'io.dopmi.app://auth/callback',
          environment: environment,
        ),
        await SharedPreferences.getInstance(),
      );
      await expectLater(
        repository.signup(
          name: 'Ana',
          email: 'fixture@example.test',
          phone: '',
          password: 'synthetic-password',
          intent: 'adopt',
        ),
        throwsFormatException,
      );
      await expectLater(repository.acceptTerms(), throwsFormatException);
      for (final pair in pairs) {
        expect(
          hasCurrentLegalConsent(
            profile(pair.terms, pair.privacy),
            'one',
            environment: environment,
          ),
          false,
        );
      }
    }
  });
}
