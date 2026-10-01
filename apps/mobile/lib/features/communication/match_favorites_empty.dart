import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';

class MatchFavoritesEmpty extends StatelessWidget {
  const MatchFavoritesEmpty({super.key});
  Widget photo(
    String asset,
    double angle,
    double top,
    double left,
    double bottomOpacity,
  ) => Positioned(
    top: top,
    left: left,
    width: 78,
    height: 92,
    child: Transform.rotate(
      angle: angle * math.pi / 180,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1f15110d),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xff15110d).withValues(alpha: .1),
                      const Color(0xff15110d).withValues(alpha: bottomOpacity),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    child: Column(
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 140,
            height: 110,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                photo('assets/onboarding/rocky.png', -12, 10, 8, .35),
                photo('assets/onboarding/luna-card.png', 10, 14, 56, .35),
                photo('assets/onboarding/toby.png', 0, 0, 34, .30),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(206),
          child: Text(
            'Es tiempo de compartir una nueva aventura',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59f7cb2d),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: FilledButton(
            onPressed: () => context.go('/adoptions'),
            style: FilledButton.styleFrom(
              backgroundColor: yellow,
              foregroundColor: ink,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.fromLTRB(20, 0, 22, 0),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Explorar'),
                const SizedBox(width: 10),
                ExcludeSemantics(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0x1415110d),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '→',
                        style: TextStyle(fontSize: 16, color: ink),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
