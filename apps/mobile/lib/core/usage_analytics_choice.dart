/// A preselection is presentation only; this state comes from a saved choice.
const usageAnalyticsNoticeVersion = 'usage-analytics-2026-11-21';

class UsageAnalyticsChoice {
  const UsageAnalyticsChoice({
    required this.hasChoice,
    required this.consent,
    required this.revision,
    this.noticeVersion,
  });
  final bool hasChoice, consent;
  final int revision;
  final String? noticeVersion;

  factory UsageAnalyticsChoice.fromJson(Object? value) {
    if (value is! Map ||
        value['has_choice'] is! bool ||
        value['consent'] is! bool ||
        value['revision'] is! int ||
        (value['revision'] as int) < 0 ||
        (value['has_choice'] == false && value['consent'] == true)) {
      throw const FormatException('Elección de analítica no confirmada');
    }
    return UsageAnalyticsChoice(
      hasChoice: value['has_choice'] as bool,
      consent: value['consent'] as bool,
      revision: value['revision'] as int,
      noticeVersion: value['notice_version'] as String?,
    );
  }
}

class UsageAnalyticsChoiceResult {
  const UsageAnalyticsChoiceResult({
    required this.state,
    required this.applied,
  });
  final UsageAnalyticsChoice state;
  final bool applied;
}

abstract interface class UsageAnalyticsChoiceStore {
  Future<UsageAnalyticsChoice> read(String owner);
  Future<UsageAnalyticsChoiceResult> save(
    String owner,
    bool enabled,
    int expectedRevision,
  );
}
