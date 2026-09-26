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
  DopmiDestination('Perfil', '/profile', 'tab-profile.svg', 2),
];
const rescuerDestinations = [
  DopmiDestination('Inicio', '/rescuer', 'rtab-home.svg', 3),
  DopmiDestination('Casos', '/my-cases', 'rtab-cases.svg', 4),
  DopmiDestination('Publicar', '/my-adoptions', 'rtab-publish.svg', 5),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: rescuer
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(18, 4, 18, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: rescuer ? null : BorderRadius.circular(999),
            border: rescuer
                ? const Border(top: BorderSide(color: DopmiTokens.line))
                : null,
            boxShadow: rescuer
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x2415110d),
                      offset: Offset(0, 8),
                      blurRadius: 24,
                    ),
                  ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: rescuer ? 0 : 10,
              vertical: 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final destination in destinations)
                  Expanded(
                    child: _NavigationItem(
                      destination: destination,
                      selected: selectedPath == destination.path,
                      rescuer: rescuer,
                      onPressed: () => onSelected(destination),
                    ),
                  ),
              ],
            ),
          ),
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
        : DopmiTokens.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected && !rescuer
                        ? DopmiTokens.yellow
                        : Colors.transparent,
                  ),
                  child: SvgPicture.asset(
                    'assets/navigation/${destination.asset}',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destination.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
