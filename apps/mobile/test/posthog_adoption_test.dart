import 'dart:convert';

import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/core/posthog_adoption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PostHog is disabled without an approved project configuration', () {
    expect(
      PostHogAdoptionAnalytics.configure(
        token: '',
        region: 'us',
        platform: 'android',
        environment: 'production',
      ),
      isNull,
    );
    expect(
      PostHogAdoptionAnalytics.configure(
        token: 'phc_test',
        region: 'https://unrelated.example',
        platform: 'android',
        environment: 'production',
      ),
      isNull,
    );
  });

  test(
    'PostHog sends only opted-in, anonymous adoption attempt events',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <http.Request>[];
      final firebase = AnalyticsSpy();
      var authenticatedOwner = 'private-account-id';
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        firebase,
        DiagnosticsSpy(),
        postHog: PostHogAdoptionAnalytics.configure(
          token: 'phc_test',
          region: 'eu',
          platform: 'android',
          environment: 'production',
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('{"status":1}', 200);
          }),
        ),
        authenticatedOwner: () => authenticatedOwner,
      );
      addTearDown(controller.dispose);
      await controller.owner(authenticatedOwner);
      await controller.setAnalytics(true);
      expect(controller.adoptionAttempt(authenticatedOwner), isNull);
      await controller.setAnalytics(false);
      await controller.setAdoptionAnalytics(true);

      final attempt = controller.adoptionAttempt(authenticatedOwner)!;
      final another = controller.adoptionAttempt(authenticatedOwner)!;
      await attempt('sign_up_completed');
      await attempt('adoption_editor_started');
      await attempt('adoption_photo_ready');
      await another('adoption_editor_started');
      expect(firebase.events, isEmpty);
      expect(requests, hasLength(3));

      final captures = requests.map((request) {
        expect(request.url.toString(), 'https://eu.i.posthog.com/i/v0/e/');
        expect(request.method, 'POST');
        expect(request.followRedirects, isFalse);
        expect(request.body, isNot(contains(authenticatedOwner)));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body.keys,
          unorderedEquals([
            'api_key',
            'event',
            'distinct_id',
            'timestamp',
            'properties',
          ]),
        );
        expect(body['api_key'], 'phc_test');
        expect(body['properties'], {
          r'$process_person_profile': false,
          r'$geoip_disable': true,
          'platform': 'android',
          'environment': 'production',
        });
        return body;
      }).toList();
      expect(captures.map((body) => body['event']), [
        'adoption_editor_started',
        'adoption_photo_ready',
        'adoption_editor_started',
      ]);
      expect(captures[0]['distinct_id'], captures[1]['distinct_id']);
      expect(captures[0]['distinct_id'], isNot(captures[2]['distinct_id']));

      final queued = attempt('adoption_details_reached');
      await controller.setAdoptionAnalytics(false);
      await queued;
      await controller.setAdoptionAnalytics(true);
      await attempt('adoption_preview_reached');
      expect(requests, hasLength(3));

      final active = controller.adoptionAttempt(authenticatedOwner)!;
      authenticatedOwner = 'different-account';
      await active('adoption_submit_accepted');
      await controller.owner(authenticatedOwner);
      expect(controller.adoptionAttempt(authenticatedOwner), isNull);
      expect(requests, hasLength(3));
    },
  );
}
