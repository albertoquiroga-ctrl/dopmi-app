import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';

class NotificationFrame extends StatelessWidget {
  const NotificationFrame({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      toolbarHeight: 68,
      leadingWidth: 60,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: const ColoredBox(
            color: Color(0xf5ffffff),
            child: SizedBox.expand(),
          ),
        ),
      ),
      shape: const Border(bottom: BorderSide(color: Color(0xffe6e2dd))),
      leading: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Center(child: NotificationBackButton()),
      ),
      title: const Text(
        'Notificaciones',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -.36,
          color: ink,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          88 + MediaQuery.paddingOf(context).top,
          16,
          32,
        ),
        children: children,
      ),
    ),
  );
}

class NotificationBackButton extends StatefulWidget {
  const NotificationBackButton({super.key});
  @override
  State<NotificationBackButton> createState() => _NotificationBackState();
}

class _NotificationBackState extends State<NotificationBackButton> {
  bool hovering = false;
  @override
  Widget build(BuildContext context) => ReferenceFocusOutline(
    radius: 20,
    outlineInset: const EdgeInsets.all(4),
    child: MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hovering ? const Color(0xfff0ede7) : Colors.transparent,
              ),
            ),
            IconButton(
              tooltip: 'Regresar',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
              style: IconButton.styleFrom(
                overlayColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              icon: SvgPicture.asset(
                'assets/profile/back.svg',
                width: 20,
                height: 20,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NotificationPagination extends StatelessWidget {
  const NotificationPagination({
    super.key,
    required this.page,
    required this.total,
    required this.change,
  });
  final int page, total;
  final ValueChanged<int> change;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Página anterior',
          onPressed: page > 1 ? () => change(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            'Página $page de ${(total + 19) ~/ 20}',
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: page * 20 < total ? () => change(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}
