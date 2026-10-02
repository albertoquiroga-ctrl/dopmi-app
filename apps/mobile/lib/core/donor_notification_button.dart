import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'reference_focus_outline.dart';
import 'ui.dart';

/// Shared DonorChromeTop notification control from the reference.
class DonorNotificationButton extends StatelessWidget {
  const DonorNotificationButton({super.key});

  @override
  Widget build(BuildContext context) => ReferenceFocusOutline(
    radius: 21,
    child: SizedBox(
      width: 42,
      height: 42,
      child: IconButton(
        tooltip: 'Notificaciones',
        onPressed: () => context.push('/notifications'),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          side: const BorderSide(color: Color(0xffd9d3ca), width: 1.5),
          shape: const CircleBorder(),
        ),
        icon: SvgPicture.asset(
          'assets/profile/icon-bell.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
        ),
      ),
    ),
  );
}
