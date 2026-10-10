import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'reference_focus_outline.dart';
import 'ui.dart';
import '../features/adoption/community_repository.dart';
import '../features/adoption/community_ui.dart';

/// Shared DonorChromeTop notification control from the reference.
class DonorNotificationButton extends ConsumerWidget {
  const DonorNotificationButton({super.key, this.rescuer = false});
  final bool rescuer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(communityRepositoryProvider);
    final actor = repository.userId;
    return LiveSection<int>(
      key: ValueKey(actor),
      tables: const ['dopmi_notifications'],
      load: () => repository.unreadNotificationCount(),
      statusFrame: (_) => button(context, null, null),
      builder: (count, refresh) =>
          button(context, repository.userId == actor ? count : null, refresh),
    );
  }

  Widget button(
    BuildContext context,
    int? count,
    VoidCallback? refresh,
  ) => ReferenceFocusOutline(
    radius: 21,
    child: SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Semantics(
            label: count != null && count > 0 ? '$count sin leer' : null,
            liveRegion: true,
            child: IconButton(
              tooltip: 'Notificaciones',
              onPressed: () async {
                await context.push('/notifications');
                if (context.mounted) refresh?.call();
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                overlayColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                side: BorderSide(
                  color: rescuer
                      ? const Color(0xffd9d4f0)
                      : const Color(0xffd9d3ca),
                  width: 1.5,
                ),
                shape: const CircleBorder(),
              ),
              icon: SvgPicture.asset(
                'assets/profile/icon-bell.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  rescuer ? const Color(0xff7c3aed) : ink,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          if (count != null && count > 0)
            Positioned(
              right: -3,
              top: -3,
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rescuer ? const Color(0xff7c3aed) : yellow,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: 0,
                      color: rescuer ? Colors.white : const Color(0xff111111),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
