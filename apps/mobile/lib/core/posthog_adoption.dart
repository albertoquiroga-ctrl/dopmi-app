import 'dart:convert';

import 'package:http/http.dart' as http;

class PostHogAdoptionAnalytics {
  PostHogAdoptionAnalytics._(
    this._token,
    this._endpoint,
    this._platform,
    this._environment,
    this._client,
  );

  static PostHogAdoptionAnalytics? configure({
    required String token,
    required String region,
    required String platform,
    required String environment,
    http.Client? client,
  }) {
    final host = switch (region) {
      'us' => 'us.i.posthog.com',
      'eu' => 'eu.i.posthog.com',
      _ => null,
    };
    if (host == null ||
        !RegExp(r'^phc_[A-Za-z0-9]+$').hasMatch(token) ||
        !const {'android', 'ios'}.contains(platform) ||
        !const {'production', 'test'}.contains(environment)) {
      return null;
    }
    return PostHogAdoptionAnalytics._(
      token,
      Uri.https(host, '/i/v0/e/'),
      platform,
      environment,
      client ?? http.Client(),
    );
  }

  static const allowed = {
    'adoption_editor_started',
    'adoption_form_opened',
    'adoption_draft_resumed',
    'adoption_photo_ready',
    'adoption_details_reached',
    'adoption_preview_reached',
    'adoption_main_photo_camera',
    'adoption_main_photo_gallery',
    'adoption_photo_prep_failed',
    'adoption_photo_picker_cancelled',
    'adoption_photo_picker_denied',
    'adoption_photo_picker_failed',
    'adoption_photo_read_failed',
    'adoption_photo_process_failed',
    'adoption_photo_upload_failed',
    'adoption_photo_attach_save_failed',
    'adoption_photo_attached',
    'adoption_continue_needs_photo',
    'adoption_continue_needs_story',
    'adoption_continue_needs_location',
    'adoption_continue_needs_other',
    'adoption_submit_attempted',
    'adoption_submit_validation_failed',
    'adoption_submit_save_failed',
    'adoption_submit_transition_failed',
    'adoption_submit_accepted',
  };

  final String _token;
  final Uri _endpoint;
  final String _platform;
  final String _environment;
  final http.Client _client;

  Future<void> capture(String event, String attempt, DateTime timestamp) async {
    if (!allowed.contains(event)) return;
    final request = http.Request('POST', _endpoint)
      ..followRedirects = false
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'api_key': _token,
        'event': event,
        'distinct_id': attempt,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'properties': {
          r'$process_person_profile': false,
          r'$geoip_disable': true,
          'platform': _platform,
          'environment': _environment,
        },
      });
    try {
      await (() async {
        final response = await _client.send(request);
        await response.stream.drain<void>();
      })().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Optional analytics never changes the publication flow or retries.
    }
  }

  void close() => _client.close();
}
