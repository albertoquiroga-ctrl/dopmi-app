import 'package:dopmi_mobile/features/adoption/community_repository.dart';

import '../test/community_test.dart' show FakeCommunity;

const bccdMessagesLunaGroupId = 'bccd0000-0000-4000-8000-000000000001';
const bccdMessagesRockyGroupId = 'bccd0000-0000-4000-8000-000000000002';
const bccdMessagesLunaThreadId = 'bccd0000-0000-4000-8000-000000000101';
const bccdMessagesRockyThreadId = 'bccd0000-0000-4000-8000-000000000102';

/// Capture-only equivalents of the six verified Source bccd Messages states.
/// Filters are changed by UI taps; they never change global selector badges.
/// The empty Source state keeps both active pets and its chrome badge of two.
class BccdMessagesCaptureCommunity extends FakeCommunity {
  BccdMessagesCaptureCommunity({this.empty = false, DateTime? now}) {
    final today = (now ?? DateTime.now()).toLocal();
    final lunaTime = DateTime(today.year, today.month, today.day, 10, 36);
    final rockyTime = DateTime(today.year, today.month, today.day, 9, 36);
    threadItems = empty
        ? <Json>[]
        : [
            _thread(
              bccdMessagesLunaThreadId,
              bccdMessagesLunaGroupId,
              'Luna',
              'Ana P.',
              'Perfecto. ¿Cuándo podrías visitarnos para conocerla?',
              'luna-card.png',
              lunaTime,
              unread: 1,
            ),
            _thread(
              bccdMessagesRockyThreadId,
              bccdMessagesRockyGroupId,
              'Rocky',
              'Carlos M.',
              '¿Puedo visitarlo este fin de semana?',
              'rocky.png',
              rockyTime,
            ),
          ];
  }

  final bool empty;

  @override
  Future<int> unreadNotificationCount() async => 2;

  @override
  Future<String> photoUrl(String path) async => bccdMessagesPhotoUrl(path);

  @override
  Future<DataPage<Json>> rescuerInbox(int page, {bool history = false}) async {
    final groups = history
        ? <Json>[]
        : [
            _pet(
              bccdMessagesLunaGroupId,
              'Luna',
              'luna-card.png',
              unread: empty ? 0 : 1,
              threads: empty ? 0 : 1,
            ),
            _pet(
              bccdMessagesRockyGroupId,
              'Rocky',
              'rocky.png',
              threads: empty ? 0 : 1,
            ),
          ];
    return DataPage(
      groups.skip((page - 1) * 20).take(20).toList(),
      groups.length,
    );
  }

  @override
  Future<DataPage<Json>> rescuerThreads(
    int page, {
    String? groupId,
    bool unreadOnly = false,
    bool history = false,
  }) async {
    final rows = history
        ? <Json>[]
        : threadItems
              .where(
                (row) =>
                    (groupId == null || row['group_id'] == groupId) &&
                    (!unreadOnly || (row['unread_count'] as int) > 0),
              )
              .toList();
    return DataPage(rows.skip((page - 1) * 20).take(20).toList(), rows.length);
  }

  static Json _pet(
    String id,
    String name,
    String photo, {
    int unread = 0,
    int threads = 0,
  }) => {
    'id': id,
    'post_id': id,
    'case_id': null,
    'pet_name': name,
    'photo': 'bccd-messages/$photo',
    'photo_path': 'bccd-messages/$photo',
    'unread_count': unread,
    'thread_count': threads,
    'threads_total': threads,
  };

  static Json _thread(
    String id,
    String groupId,
    String pet,
    String person,
    String preview,
    String photo,
    DateTime updated, {
    int unread = 0,
  }) => {
    'id': id,
    'post_id': groupId,
    'group_id': groupId,
    'case_id': null,
    'owner_id': 'one',
    'adopter_id': id == bccdMessagesLunaThreadId ? 'two' : 'three',
    'pet_name': pet,
    'participant_name': person,
    'last_message': preview,
    'updated_at': updated.toUtc().toIso8601String(),
    'photo': 'bccd-messages/$photo',
    'photo_path': 'bccd-messages/$photo',
    'unread_count': unread,
    'status': 'active',
  };
}

String bccdMessagesPhotoUrl(String path) =>
    'https://fixture.invalid/bccd-messages/${path.split('/').last}';

/// Resolve these basenames against the existing capture-only photo client.
/// luna-card.png: assets/onboarding; rocky.png: tool/fixtures (Source bytes).
const bccdMessagesPhotoAssets = ['luna-card.png', 'rocky.png'];
