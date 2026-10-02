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
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffe3e4ed))),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep the reference's five columns when every label fits. Larger
            // system text gets more room without splitting destination names.
            var minimumWidth = 48.0;
            for (final destination in destinations) {
              final painter = TextPainter(
                text: TextSpan(
                  text: destination.label,
                  style: DefaultTextStyle.of(context).style.copyWith(
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final width = painter.width + 8;
              if (width > minimumWidth) minimumWidth = width;
              painter.dispose();
            }
            final columns = (constraints.maxWidth / minimumWidth).floor().clamp(
              1,
              destinations.length,
            );
            return Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final destination in destinations)
                  SizedBox(
                    width: constraints.maxWidth / columns,
                    child: _NavigationItem(
                      destination: destination,
                      selected: selectedPath == destination.path,
                      rescuer: true,
                      onPressed: () => onSelected(destination),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
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
        ? DopmiTokens.purple
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
            constraints: BoxConstraints(minHeight: rescuer ? 56 : 48),
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
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
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
