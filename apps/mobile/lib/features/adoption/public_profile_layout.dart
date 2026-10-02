import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';

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

class _PublicHeaderButton extends StatelessWidget {
  const _PublicHeaderButton({
    required this.label,
    required this.asset,
    required this.action,
  });
  final String label, asset;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Center(
    child: ReferenceFocusOutline(
      radius: 20,
      outlineInset: const EdgeInsets.all(4),
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: label,
          onPressed: action,
          style: IconButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            overlayColor: Colors.transparent,
          ),
          icon: SvgPicture.asset(
            asset,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
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
  });
  final Widget avatar;
  final String name, city, bio;
  final int caseCount;
  final bool verified;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: avatar),
        const SizedBox(height: 18),
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
                  fontSize: 26,
                  height: 1.25,
                  letterSpacing: -.52,
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
                    fontSize: 14,
                    height: 1.55,
                    letterSpacing: 0,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
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
          const SizedBox(height: 12),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
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
  });
  final String instagram, facebook;
  final ValueChanged<String> open;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Redes sociales',
        style: TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final entry in [
            ('Instagram', instagram, 'icon-instagram'),
            ('Facebook', facebook, 'icon-facebook'),
          ])
            if (entry.$2.isNotEmpty)
              ReferenceFocusOutline(
                radius: 999,
                child: OutlinedButton.icon(
                  onPressed: () => open(entry.$2),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    backgroundColor: Colors.white,
                    foregroundColor: ink,
                    side: const BorderSide(color: Color(0xffe6e2dd)),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      height: 1.175,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  icon: SvgPicture.asset(
                    'assets/profile/${entry.$3}.svg',
                    width: 18,
                    height: 18,
                  ),
                  label: Text(entry.$1),
                ),
              ),
        ],
      ),
    ],
  );
}

class PublicProfileTabs extends StatelessWidget {
  const PublicProfileTabs({
    super.key,
    required this.selected,
    required this.select,
    required this.report,
  });
  final int selected;
  final ValueChanged<int> select;
  final VoidCallback? report;
  Widget tab(int index, String label) => ReferenceFocusOutline(
    radius: 0,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: selected == index ? yellow : Colors.transparent,
          ),
        ),
      ),
      child: TextButton(
        onPressed: () => select(index),
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.only(top: 10, bottom: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: selected == index ? const Color(0xff6b5000) : muted,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.171428571,
            fontWeight: selected == index ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        child: Text(label),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffe6e2dd))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttons = [
            tab(0, 'Actividad'),
            tab(1, 'En adopción'),
            tab(2, 'Casos'),
          ];
          final reportButton = Tooltip(
            message: 'Reportar',
            child: TextButton(
              onPressed: report,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.only(top: 10, bottom: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: muted,
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.171428571,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Reportar'),
            ),
          );
          final requiredWidth =
              ['Actividad', 'En adopción', 'Casos', 'Reportar']
                  .map((label) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final width = painter.width;
                    painter.dispose();
                    return width;
                  })
                  .fold<double>(48, (total, width) => total + width);
          if (requiredWidth > constraints.maxWidth) {
            return Wrap(spacing: 16, children: [...buttons, reportButton]);
          }
          return Row(
            children: [
              buttons[0],
              const SizedBox(width: 16),
              buttons[1],
              const SizedBox(width: 16),
              buttons[2],
              const SizedBox(width: 16),
              const Spacer(),
              reportButton,
              const Spacer(),
            ],
          );
        },
      ),
    ),
  );
}
