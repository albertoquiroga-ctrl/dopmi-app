import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../rescue/rescue_repository.dart' show pesos;
import 'community_repository.dart';

class PublicProfileMetrics extends StatelessWidget {
  const PublicProfileMetrics({
    super.key,
    required this.name,
    required this.metrics,
  });
  final String name;
  final Json metrics;
  String count(String key) => metrics[key] is int && (metrics[key] as int) >= 0
      ? '${metrics[key]}'
      : '—';
  Widget icon(String asset, double size, Color color) => SvgPicture.asset(
    'assets/profile/$asset.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
  Widget hero(String key, String label, String hint, String asset, bool dark) {
    final foreground = dark ? Colors.white : ink;
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: const Alignment(-.342, -.94),
          end: const Alignment(.342, .94),
          colors: dark
              ? const [Color(0xff2a241e), ink]
              : const [Color(0xffffe9a3), yellow, Color(0xfff0bf18)],
          stops: dark ? null : const [0, .55, 1],
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HeroHighlight(dark: dark)),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: dark ? .12 : .28),
              ),
              child: Center(child: icon(asset, 18, foreground)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count(key),
                  style: TextStyle(
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.36,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 16 / 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    height: 12.8 / 11,
                    fontWeight: FontWeight.w500,
                    color: foreground.withValues(alpha: dark ? .78 : .72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget stat(String value, String label, String hint, String asset) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe6e2dd)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0a15110d),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xfffff6cf),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: icon(asset, 16, const Color(0xff6b5000))),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -.66,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 11,
                height: 12.8 / 11,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final funded = metrics['funded_cents'];
    final money = funded is int && funded >= 0
        ? pesos(funded)
              .replaceAll(' MXN', '')
              .replaceFirst(RegExp(r'\.00$'), '')
        : '—';
    return DefaultTextStyle.merge(
      style: const TextStyle(letterSpacing: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final single =
              MediaQuery.textScalerOf(context).scale(14) > 20 ||
              constraints.maxWidth < 280;
          Widget grid(List<Widget> cards) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i += single ? 1 : 2) ...[
                if (i > 0) const SizedBox(height: 10),
                if (single)
                  cards[i]
                else
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[i]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[i + 1]),
                      ],
                    ),
                  ),
              ],
            ],
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Numeralia de lo que ${name.trim().split(' ').first} ha impulsado en Dopmi.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 16),
                grid([
                  hero(
                    'active_donation_cases',
                    'Donaciones activas',
                    'Con meta abierta ahora',
                    'tab-donate',
                    false,
                  ),
                  hero(
                    'active_adoptions',
                    'Adopciones activas',
                    'Buscando hogar',
                    'tab-adoption',
                    true,
                  ),
                ]),
                const SizedBox(height: 16),
                grid([
                  stat(
                    count('published_donation_cases'),
                    'Casos de donación',
                    'Historial público',
                    'notif-case',
                  ),
                  stat(
                    count('published_adoptions'),
                    'Publicaciones de adopción',
                    'En todo el historial',
                    'notif-pet',
                  ),
                  stat(money, 'Recaudado', 'Neto asignado', 'icon-donation-in'),
                  stat(
                    count('completed_needs'),
                    'Necesidades cubiertas',
                    'Metas completadas',
                    'check-circle',
                  ),
                  stat(
                    count('helped_pets'),
                    'Mascotas ayudadas',
                    'Adopción y donación',
                    'empty-impact-paw',
                  ),
                  stat(
                    count('closed_cases'),
                    'Casos cerrados',
                    'Historial concluido',
                    'icon-verified',
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroHighlight extends CustomPainter {
  const _HeroHighlight({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
    );
    // CSS ellipse: 80% 90% at the upper-right corner, fading at 55%.
    canvas.translate(size.width, 0);
    canvas.scale(size.width * .8, size.height * .9);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: dark ? .12 : .55),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, .55],
      ).createShader(const Rect.fromLTRB(-1, -1, 1, 1));
    canvas.drawRect(const Rect.fromLTRB(-1.25, 0, 0, 1 / .9), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroHighlight oldDelegate) => oldDelegate.dark != dark;
}
