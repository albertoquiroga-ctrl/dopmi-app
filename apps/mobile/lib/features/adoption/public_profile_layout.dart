import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';

class PublicProfileContacts extends StatelessWidget {
  const PublicProfileContacts({
    super.key,
    required this.email,
    required this.phone,
    required this.address,
    required this.website,
    this.interactive = true,
  });
  final String email, phone, address, website;
  final bool interactive;
  Future<void> open(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos abrir este contacto.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos abrir este contacto.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = Uri.tryParse(website);
    final items = [
      if (email.isNotEmpty)
        (
          'assets/profile/icon-mail.svg',
          'Correo',
          email,
          Uri(scheme: 'mailto', path: email),
        ),
      if (phone.isNotEmpty)
        (
          'assets/profile/icon-phone.svg',
          'Teléfono',
          phone,
          Uri(scheme: 'tel', path: phone),
        ),
      if (address.isNotEmpty)
        ('assets/profile/location.svg', 'Dirección', address, null),
      if (website.isNotEmpty)
        (
          'assets/profile/globe.svg',
          'Web',
          website,
          link != null &&
                  link.scheme == 'https' &&
                  link.host.isNotEmpty &&
                  link.userInfo.isEmpty
              ? link
              : null,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final item in items)
            Tooltip(
              message: '${item.$2}: ${item.$3}',
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1415110d),
                      offset: Offset(0, 2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: !interactive
                      ? null
                      : item.$4 != null
                      ? () => open(context, item.$4!)
                      : () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(item.$2),
                            content: SelectableText(item.$3),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    maximumSize: const Size(48, 48),
                  ),
                  icon: SvgPicture.asset(
                    item.$1,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Color(0xff5c574f),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PublicProfileFrame extends StatelessWidget {
  const PublicProfileFrame({
    super.key,
    required this.child,
    required this.share,
  });
  final Widget child;
  final VoidCallback share;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      automaticallyImplyLeading: false,
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
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _PublicHeaderButton(
          label: 'Regresar',
          asset: 'assets/profile/back.svg',
          action: () => context.canPop()
              ? context.pop()
              : context.go('/saved?kind=rescuer'),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _PublicHeaderButton(
            label: 'Compartir',
            asset: 'assets/onboarding/send.svg',
            action: share,
          ),
        ),
      ],
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
        children: [child],
      ),
    ),
  );
}

class _PublicHeaderButton extends StatefulWidget {
  const _PublicHeaderButton({
    required this.label,
    required this.asset,
    required this.action,
  });
  final String label, asset;
  final VoidCallback action;
  @override
  State<_PublicHeaderButton> createState() => _PublicHeaderButtonState();
}

class _PublicHeaderButtonState extends State<_PublicHeaderButton> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => Center(
    child: ReferenceFocusOutline(
      radius: 20,
      outlineInset: const EdgeInsets.all(4),
      child: MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hovered)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xfff0ede7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              IconButton(
                tooltip: widget.label,
                onPressed: widget.action,
                style: IconButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: Colors.transparent,
                ),
                icon: SvgPicture.asset(
                  widget.asset,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PublicProfileIdentity extends StatelessWidget {
  const PublicProfileIdentity({
    super.key,
    required this.avatar,
    required this.name,
    required this.city,
    required this.bio,
    required this.caseCount,
    required this.verified,
    this.showCaseCount = false,
  });
  final Widget avatar;
  final String name, city, bio;
  final int caseCount;
  final bool verified;
  final bool showCaseCount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: avatar),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              if (verified)
                SvgPicture.asset(
                  'assets/profile/icon-verified.svg',
                  width: 20,
                  height: 20,
                  semanticsLabel: 'Rescatista verificado',
                ),
            ],
          ),
        ),
        if (city.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/profile/location.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(muted, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  city,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    letterSpacing: 0,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        if (showCaseCount)
          Text(
            '$caseCount casos publicados',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.2,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              letterSpacing: 0,
              color: muted,
            ),
          ),
        ],
      ],
    ),
  );
}

class PublicProfileSocials extends StatelessWidget {
  const PublicProfileSocials({
    super.key,
    required this.instagram,
    required this.facebook,
    required this.open,
    this.interactive = true,
  });
  final String instagram, facebook;
  final ValueChanged<String> open;
  final bool interactive;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: LayoutBuilder(
      builder: (context, box) {
        final buttons = [
          for (final entry in [
            ('Instagram', instagram, 'icon-instagram'),
            ('Facebook', facebook, 'icon-facebook'),
          ])
            if (entry.$2.isNotEmpty)
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0f15110d),
                      offset: Offset(0, 2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: interactive ? () => open(entry.$2) : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    foregroundColor: ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/profile/${entry.$3}.svg',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: Text(entry.$1)),
                    ],
                  ),
                ),
              ),
        ];
        if (MediaQuery.textScalerOf(context).scale(13) > 20 ||
            box.maxWidth < 240) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final button in buttons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: button,
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: buttons[i]),
            ],
          ],
        );
      },
    ),
  );
}

class PublicProfileTabs extends StatelessWidget {
  const PublicProfileTabs({
    super.key,
    required this.selected,
    required this.select,
    required this.report,
    this.showReport = true,
  });
  final int selected;
  final ValueChanged<int> select;
  final VoidCallback? report;
  final bool showReport;
  Widget tab(int index, String label) => ReferenceFocusOutline(
    radius: 0,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: selected == index ? ink : Colors.transparent,
          ),
        ),
      ),
      child: TextButton(
        onPressed: () => select(index),
        style: TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: selected == index ? ink : muted,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label, maxLines: 1, softWrap: false),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xffe6e2dd))),
          ),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final labels = ['Resumen', 'Adopci\u00f3n', 'Apoyo'];
              var minimumTabWidth = 0.0;
              for (final label in labels) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final measured = painter.width + 12;
                if (measured > minimumTabWidth) minimumTabWidth = measured;
                painter.dispose();
              }
              final requiredWidth = minimumTabWidth * 3;
              final width = requiredWidth > bounds.maxWidth
                  ? requiredWidth
                  : bounds.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(child: tab(i, labels[i])),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (showReport)
          ReferenceFocusOutline(
            radius: 0,
            child: TextButton(onPressed: report, child: const Text('Reportar')),
          ),
      ],
    ),
  );
}
