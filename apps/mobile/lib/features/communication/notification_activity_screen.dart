import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/adoption_only_build.dart';
import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../identity/experience_controller.dart';
import '../rescue/rescue_repository.dart';
import 'notification_tile.dart';
import 'notification_frame.dart';
import 'notification_activity_repository.dart';

class NotificationActivityScreen extends ConsumerWidget {
  const NotificationActivityScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityControllerProvider);
    return ListenableBuilder(
      listenable: identity,
      builder: (_, _) {
        final id = identity.identity?.id;
        return id == null
            ? const SizedBox.shrink()
            : _Notifications(key: ValueKey(id), owner: id);
      },
    );
  }
}

class _Notifications extends ConsumerStatefulWidget {
  const _Notifications({super.key, required this.owner});
  final String owner;
  @override
  ConsumerState<_Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<_Notifications> {
  int page = 1, revision = 0;
  bool busy = false;
  String? error;
  bool get current =>
      mounted &&
      ref.read(identityControllerProvider).identity?.id == widget.owner;

  Future<DataPage<Json>> load() async {
    final data = await ref
        .read(notificationActivityRepositoryProvider)
        .page(page);
    if (!adoptionOnlyBuild) return data;
    if (!current) return const DataPage([], 0);

    // Rescue activity can refer to identity verification as well as to a
    // funding record. Use the owner's verification records to distinguish them.
    var verificationIds = <String>{};
    if (data.items.any((item) => item['rescue_id'] != null)) {
      try {
        final verification = await ref
            .read(rescueRepositoryProvider)
            .mine('verification', 1);
        if (!current) return const DataPage([], 0);
        verificationIds = verification.items.map((item) => item.id).toSet();
      } catch (_) {
        // Adoption notifications remain usable if verification is unavailable.
      }
    }
    return DataPage(
      data.items.where((item) {
        if (const {'contribution', 'guardian'}.contains(item['kind']) ||
            const {
              'history',
              'received_history',
            }.contains(item['target_kind'])) {
          return false;
        }
        final rescueId = item['rescue_id'];
        if (rescueId != null ||
            item['target_kind'] == 'rescue' ||
            item['kind'] == 'rescue') {
          return verificationIds.contains(rescueId);
        }
        return true;
      }).toList(),
      data.total,
    );
  }

  Future<void> open(Json item, VoidCallback refresh) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(notificationActivityRepositoryProvider)
          .open(item['id'] as String);
      if (!mounted || !current) return;
      refresh();
      final target = result['target_id'];
      final route = adoptionOnlyBuild && result['target_kind'] == 'rescue'
          ? (result['available'] == true &&
                    target is String &&
                    target == item['rescue_id']
                ? Uri(
                    path: '/rescue/$target',
                    queryParameters: {'kind': 'verification'},
                  ).toString()
                : null)
          : notificationActivityRoute(result);
      if (route == null) {
        setState(() => error = 'Este contenido ya no está disponible.');
      } else {
        await context.push(route);
        if (current) refresh();
      }
    } catch (_) {
      if (current) {
        setState(
          () => error = 'No pudimos abrir la notificación. Intenta de nuevo.',
        );
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => NotificationFrame(
    rescuer: ref.watch(experienceProvider).value == AccountExperience.rescuer,
    children: [
      if (error != null) Notice(error!, isError: true),
      LiveSection<DataPage<Json>>(
        key: ValueKey('${widget.owner}:$page:$revision'),
        tables: const ['dopmi_notifications'],
        load: load,
        builder: (data, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.items.isEmpty)
              const Notice(
                adoptionOnlyBuild
                    ? 'Cuando haya una respuesta o un mensaje, lo encontrarás aquí.'
                    : 'Cuando haya una respuesta, un mensaje o un +Apoyo, lo encontrarás aquí.',
              ),
            for (final item in data.items)
              NotificationTile(
                item,
                key: ValueKey(item['id']),
                rescuer:
                    ref.watch(experienceProvider).value ==
                    AccountExperience.rescuer,
                onTap: busy ? null : () => open(item, refresh),
              ),
            if (data.total > 20)
              NotificationPagination(
                page: page,
                total: data.total,
                change: (value) => setState(() {
                  page = value;
                  error = null;
                }),
              ),
          ],
        ),
      ),
    ],
  );
}
