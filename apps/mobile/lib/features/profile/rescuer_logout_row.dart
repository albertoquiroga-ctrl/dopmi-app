import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RescuerLogoutRow extends StatefulWidget {
  const RescuerLogoutRow({super.key, required this.onLogout});
  final Future<void> Function() onLogout;
  @override
  State<RescuerLogoutRow> createState() => _RescuerLogoutRowState();
}

class _RescuerLogoutRowState extends State<RescuerLogoutRow> {
  bool busy = false;
  Future<void> logout() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: !busy,
    child: Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffffd4d8)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: busy ? null : logout,
          borderRadius: BorderRadius.circular(20),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SvgPicture.asset(
                    'assets/profile/icon-logout.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Color(0xffd92d20),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      letterSpacing: 0,
                      color: Color(0xffd92d20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Cerrando sesión',
                    ),
                  )
                else
                  ExcludeSemantics(
                    child: SvgPicture.asset(
                      'assets/profile/icon-chevron-right.svg',
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Color(0xffd92d20),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
