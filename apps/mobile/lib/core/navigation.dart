import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'design_tokens.dart';

class DopmiDestination {
  const DopmiDestination(this.label, this.path, this.asset, this.branch);
  final String label, path, asset;
  final int branch;
}

const donorDestinations = [
  DopmiDestination('Adoptar', '/adoptions', 'rtab-home.svg', 0),
  DopmiDestination('Apoyar', '/rescue-cases', 'tab-donate.svg', 1),
  DopmiDestination('Favoritos', '/messages', 'icon-heart.svg', 6),
  DopmiDestination('Perfil', '/profile', 'tab-profile.svg', 2),
];
const rescuerDestinations = [
  DopmiDestination('Inicio', '/rescuer', 'rtab-home.svg', 3),
  DopmiDestination('Casos', '/my-cases', 'rtab-cases.svg', 4),
  DopmiDestination('Publicar', '/publish', 'rtab-publish.svg', 5),
  DopmiDestination('Mensajes', '/messages', 'rtab-messages.svg', 6),
  DopmiDestination('Perfil', '/profile', 'rtab-profile.svg', 2),
];

class DopmiNavigationHost extends InheritedWidget {
  const DopmiNavigationHost({
    super.key,
    required this.shell,
    required super.child,
  });
  final StatefulNavigationShell shell;
  static StatefulNavigationShell? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DopmiNavigationHost>()?.shell;
  @override
  bool updateShouldNotify(DopmiNavigationHost oldWidget) =>
      shell != oldWidget.shell;
}

/// Same component is used in the real shell and in visual acceptance captures.
class DopmiBottomBar extends StatelessWidget {
  const DopmiBottomBar({
    super.key,
    required this.rescuer,
    required this.selectedPath,
    required this.onSelected,
  });
  final bool rescuer;
  final String selectedPath;
  final ValueChanged<DopmiDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final destinations = rescuer ? rescuerDestinations : donorDestinations;
    if (!rescuer) {
      return SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            heightFactor: 1,
            child: Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DopmiTokens.ink,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5215110d),
                    offset: Offset(0, 8),
                    blurRadius: 24,
                  ),
                  BoxShadow(
                    color: Color(0x3315110d),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    _NavigationItem(
                      destination: destinations[index],
                      selected: selectedPath == destinations[index].path,
                      rescuer: false,
                      onPressed: () => onSelected(destinations[index]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final safe = MediaQuery.paddingOf(context).bottom;
        final textScaler = MediaQuery.textScalerOf(context);
        final items = destinations.where((d) => d.path != '/publish').toList();
        var minimum = 48.0;
        for (final d in items) {
          final painter = TextPainter(
            text: TextSpan(
              text: d.label,
              style: DefaultTextStyle.of(context).style.copyWith(
                fontSize: 9,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            textScaler: textScaler,
            textDirection: Directionality.of(context),
          )..layout();
          if (painter.width + 8 > minimum) minimum = painter.width + 8;
          painter.dispose();
        }
        final regular = constraints.maxWidth / 5 >= minimum;
        final columns = (constraints.maxWidth / minimum).floor().clamp(1, 4);
        final rows = regular ? 1 : (items.length / columns).ceil();
        final surfaceHeight =
            78.0 + (rows - 1) * 52 + safe + (regular ? 0 : 29);
        final publish = destinations.firstWhere((d) => d.path == '/publish');
        return SizedBox(
          height: surfaceHeight + 19,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 19,
                child: CustomPaint(painter: const _RescuerNavigationSurface()),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: safe + 8,
                child: regular
                    ? Row(
                        children: [
                          for (final d in destinations)
                            Expanded(
                              child: d.path == '/publish'
                                  ? const SizedBox(width: 58, height: 52)
                                  : _NavigationItem(
                                      destination: d,
                                      selected: selectedPath == d.path,
                                      rescuer: true,
                                      onPressed: () => onSelected(d),
                                    ),
                            ),
                        ],
                      )
                    : Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (final d in items)
                            SizedBox(
                              width: (constraints.maxWidth - 8) / columns,
                              child: _NavigationItem(
                                destination: d,
                                selected: selectedPath == d.path,
                                rescuer: true,
                                onPressed: () => onSelected(d),
                              ),
                            ),
                        ],
                      ),
              ),
              Positioned(
                top: 0,
                left: (constraints.maxWidth - 58) / 2,
                child: Semantics(
                  button: true,
                  selected: selectedPath == '/publish',
                  label: 'Publicar',
                  child: Material(
                    color: DopmiTokens.purple,
                    shape: const CircleBorder(),
                    elevation: 8,
                    shadowColor: const Color(0x617c3aed),
                    child: InkWell(
                      onTap: () => onSelected(publish),
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/navigation/${publish.asset}',
                            width: 26,
                            height: 26,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.rescuer,
    required this.onPressed,
  });
  final DopmiDestination destination;
  final bool selected, rescuer;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final color = selected && rescuer
        ? const Color(0xff151423)
        : selected
        ? DopmiTokens.ink
        : rescuer
        ? const Color(0xff4f4e5c)
        : const Color(0xffe3e2e2);
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          splashFactory: NoSplash.splashFactory,
          highlightColor: rescuer ? Colors.transparent : null,
          hoverColor: rescuer ? Colors.transparent : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: rescuer ? 52 : 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: rescuer ? 28 : 48,
                  height: rescuer ? 28 : 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected && !rescuer
                        ? DopmiTokens.yellow
                        : rescuer
                        ? Colors.transparent
                        : const Color(0xff3a342e),
                  ),
                  child: SvgPicture.asset(
                    'assets/navigation/${destination.asset}',
                    width:
                        rescuer ||
                            destination.path == '/profile' ||
                            destination.path == '/messages'
                        ? 20
                        : 22,
                    height:
                        rescuer ||
                            destination.path == '/profile' ||
                            destination.path == '/messages'
                        ? 20
                        : 22,
                    colorFilter: ColorFilter.mode(
                      rescuer && !selected ? const Color(0xff8a8799) : color,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                if (rescuer) ...[
                  const SizedBox(height: 3),
                  Text(
                    destination.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.2,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RescuerNavigationSurface extends CustomPainter {
  const _RescuerNavigationSurface();
  @override
  void paint(Canvas canvas, Size size) {
    final surface = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          topLeft: const Radius.circular(28),
          topRight: const Radius.circular(28),
        ),
      );
    final notch = Path()
      ..addOval(Rect.fromCircle(center: Offset(size.width / 2, 0), radius: 36));
    final path = Path.combine(PathOperation.difference, surface, notch);
    canvas.drawShadow(path, const Color(0x1415110d), 8, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RescuerNavigationSurface oldDelegate) => false;
}
