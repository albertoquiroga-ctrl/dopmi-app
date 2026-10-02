import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/donor_notification_button.dart';
import '../../core/ui.dart';
import '../../core/reference_focus_outline.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import 'rescue_repository.dart';

class SupportHomePage extends StatelessWidget {
  const SupportHomePage({
    super.key,
    required this.data,
    required this.page,
    required this.error,
    required this.changePage,
    this.status,
  });
  final DataPage<RescueRecord> data;
  final int page;
  final String? error;
  final ValueChanged<int> changePage;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final eligible = data.items
        .where(
          (item) => item.targetCents > 0 && item.fundedCents < item.targetCents,
        )
        .toList();
    final scaler = MediaQuery.textScalerOf(context);
    final large = scaler.scale(14) > 20;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              children: [
                SizedBox(
                  height: 42,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SvgPicture.asset(
                        'assets/profile/logo-paw.svg',
                        width: 40,
                        height: 40,
                        semanticsLabel: 'Dopmi',
                      ),
                      const DonorNotificationButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Descubre casos',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.1,
                    color: ink,
                  ),
                ),
                if (eligible.isNotEmpty || status != null)
                  const SizedBox(height: 16),
                if (error != null) Notice(error!, isError: true),
                if (status != null)
                  status!
                else if (eligible.isNotEmpty)
                  SizedBox(
                    height: 100 + scaler.scale(26.4) + (large ? 4 : 0),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: eligible.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (_, index) =>
                          SupportCaseRing(eligible[index]),
                    ),
                  )
                else
                  Semantics(
                    liveRegion: true,
                    label: 'No hay casos para apoyar. Por ahora no hay gastos aprobados disponibles.',
                    child: const SizedBox.shrink(),
                  ),
                if (data.total > 20)
                  PageControls(
                    page: page,
                    total: data.total,
                    size: 20,
                    change: changePage,
                  ),
                const SizedBox(height: 28),
                const Text(
                  'Sé un Guardián',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: -.48,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: scaler.scale(295.24)),
                    child: const Text(
                      'Con cada aporte mensual ayudarás a cubrir necesidades reales de mascotas que buscan un hogar.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.45,
                        letterSpacing: 0,
                        color: muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GuardianSupportCard(
                  height: math.max(
                    scaler.scale(300) + 180,
                    eligible.isEmpty && status == null
                        ? MediaQuery.sizeOf(context).height -
                              MediaQuery.paddingOf(context).top -
                              (106 + scaler.scale(28) * 1.1) +
                              180
                        : MediaQuery.sizeOf(context).height - 100,
                  ),
                ),
              ],
            ),
            if (!large)
              Positioned(
                left: 36,
                right: 36,
                bottom: 92 + MediaQuery.viewPaddingOf(context).bottom,
                child: const GuardianSupportDock(),
              ),
          ],
        ),
      ),
    );
  }
}

class SupportCaseRing extends ConsumerWidget {
  const SupportCaseRing(this.record, {super.key});
  final RescueRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = record.publicData['photos'] as List? ?? const [];
    final ratio = record.targetCents <= 0
        ? 0.0
        : (record.fundedCents / record.targetCents).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label:
          '${record.title}, ${pesos(record.fundedCents)} de ${pesos(record.targetCents)}',
      child: ReferenceFocusOutline(
        radius: 0,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: () => context.push('/rescue-cases/${record.id}'),
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: math.max(84, MediaQuery.textScalerOf(context).scale(84)),
            child: Column(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _CaseProgress(ratio)),
                      Padding(
                        padding: const EdgeInsets.all(7),
                        child: ClipOval(
                          child: photos.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xffefe8dc),
                                  child: Icon(Icons.pets_outlined),
                                )
                              : FutureBuilder<String>(
                                  future: ref
                                      .read(rescueRepositoryProvider)
                                      .fileUrl(photos.first as String),
                                  builder: (_, snapshot) => snapshot.hasData
                                      ? Image.network(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const ColoredBox(
                                                color: Color(0xffefe8dc),
                                                child: Icon(
                                                  Icons.pets_outlined,
                                                ),
                                              ),
                                        )
                                      : const ColoredBox(
                                          color: Color(0xffefe8dc),
                                          child: Icon(Icons.pets_outlined),
                                        ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _compactPesos(record.fundedCents),
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' / ${_compactPesos(record.targetCents)}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    color: muted,
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

class _CaseProgress extends CustomPainter {
  _CaseProgress(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 4) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xffe7e2da)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..color = yellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CaseProgress old) => old.value != value;
}

class GuardianSupportCard extends StatelessWidget {
  const GuardianSupportCard({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => ReferenceFocusOutline(
    radius: 28,
    outlineBorderRadius: const BorderRadius.vertical(top: Radius.circular(33)),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3815110d),
            offset: Offset(0, 16),
            blurRadius: 40,
          ),
        ],
      ),
      child: Semantics(
        key: const ValueKey('guardian-support-card-action'),
        container: true,
        button: true,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: () => context.push('/guardian?enroll=1'),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    child: Image.asset(
                      'assets/guardian/guardian-urgent.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x8c15110d),
                          Color(0x3815110d),
                          Color(0x7315110d),
                          Color(0xe015110d),
                        ],
                        stops: [0, .34, .58, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Apoya a casos urgentes',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -.48,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0x59000000),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _benefit(
                          'Rescatistas y casos verificados',
                          SvgPicture.asset(
                            'assets/profile/icon-shield.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              yellow,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _benefit(
                          'Sigue tu huella',
                          SvgPicture.string(
                            _impact,
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              yellow,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _benefit(
                          'Cancela cuando quieras',
                          SvgPicture.string(
                            _check,
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              yellow,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (MediaQuery.textScalerOf(context).scale(14) > 20)
                    const Positioned(
                      left: 18,
                      right: 18,
                      bottom: 110,
                      child: GuardianSupportDock(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _benefit(String label, Widget icon) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: icon),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            height: 1.3,
            color: Color(0xebffffff),
            shadows: [
              Shadow(
                color: Color(0x4d000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class GuardianSupportDock extends StatelessWidget {
  const GuardianSupportDock({super.key});
  @override
  Widget build(BuildContext context) => ReferenceFocusOutline(
    radius: 0,
    child: Semantics(
      button: true,
      label: 'Suscríbete a Guardián, desde 50 pesos al mes',
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        onTap: () => context.push('/guardian?enroll=1'),
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, box) {
            const price = Text(
              'Desde \$50 / mes',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: 0,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Color(0x59000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            );
            final button = Container(
              key: const ValueKey('guardian-support-cta'),
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59f7cb2d),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Text(
                'Suscríbete ahora',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0,
                  color: ink,
                ),
              ),
            );
            final scaler = MediaQuery.textScalerOf(context);
            double measure(String text, FontWeight weight) {
              final painter = TextPainter(
                text: TextSpan(
                  text: text,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: weight,
                    letterSpacing: 0,
                  ),
                ),
                textScaler: scaler,
                textDirection: Directionality.of(context),
              )..layout();
              final width = painter.width;
              painter.dispose();
              return width;
            }

            if (scaler.scale(14) > 20 ||
                measure('Desde \$50 / mes', FontWeight.w600) +
                        measure('Suscríbete ahora', FontWeight.w700) +
                        48 >
                    box.maxWidth) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [price, const SizedBox(height: 8), button],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [price, const SizedBox(width: 12), button],
            );
          },
        ),
      ),
    ),
  );
}

String _compactPesos(int cents) => cents % 100 == 0
    ? '\$${cents ~/ 100}'
    : '\$${(cents / 100).toStringAsFixed(2)}';

const _impact = r'''<svg preserveAspectRatio="none" overflow="visible" style="display: block;" width="19.9986" height="19.9986" viewBox="0 0 19.9986 19.9986" fill="none" xmlns="http://www.w3.org/2000/svg">
<g id="Icon" clip-path="url(#clip0_0_7)">
<path id="Vector" d="M8.27991 12.9154C8.20552 12.6271 8.05521 12.3639 7.84463 12.1533C7.63404 11.9427 7.37087 11.7924 7.0825 11.718L1.97036 10.3998C1.88314 10.375 1.80637 10.3225 1.75171 10.2502C1.69705 10.1778 1.66748 10.0896 1.66748 9.99897C1.66748 9.90831 1.69705 9.82012 1.75171 9.74779C1.80637 9.67545 1.88314 9.62292 1.97036 9.59817L7.0825 8.27909C7.37077 8.20477 7.63387 8.05459 7.84445 7.84416C8.05502 7.63373 8.20539 7.37073 8.27991 7.08251L9.59815 1.97037C9.62266 1.88281 9.67514 1.80566 9.74758 1.75071C9.82002 1.69576 9.90845 1.66602 9.99938 1.66602C10.0903 1.66602 10.1787 1.69576 10.2512 1.75071C10.3236 1.80566 10.3761 1.88281 10.4006 1.97037L11.718 7.08251C11.7924 7.37088 11.9427 7.63405 12.1533 7.84464C12.3639 8.05523 12.6271 8.20553 12.9154 8.27993L18.0276 9.59733C18.1155 9.62158 18.193 9.674 18.2482 9.74655C18.3035 9.81911 18.3334 9.90778 18.3334 9.99897C18.3334 10.0902 18.3035 10.1788 18.2482 10.2514C18.193 10.3239 18.1155 10.3764 18.0276 10.4006L12.9154 11.718C12.6271 11.7924 12.3639 11.9427 12.1533 12.1533C11.9427 12.3639 11.7924 12.6271 11.718 12.9154L10.3998 18.0276C10.3753 18.1151 10.3228 18.1923 10.2503 18.2472C10.1779 18.3022 10.0895 18.3319 9.99854 18.3319C9.90762 18.3319 9.81919 18.3022 9.74675 18.2472C9.6743 18.1923 9.62183 18.1151 9.59732 18.0276L8.27991 12.9154Z" stroke="#6A615B" stroke-width="1.66655" stroke-linecap="round" stroke-linejoin="round"/>
<path id="Vector_2" d="M16.6655 2.49982V5.83292" stroke="#6A615B" stroke-width="1.66655" stroke-linecap="round" stroke-linejoin="round"/>
<path id="Vector_3" d="M18.3321 4.16602H14.999" stroke="#6A615B" stroke-width="1.66655" stroke-linecap="round" stroke-linejoin="round"/>
<path id="Vector_4" d="M3.33301 14.166V15.8326" stroke="#6A615B" stroke-width="1.66655" stroke-linecap="round" stroke-linejoin="round"/>
<path id="Vector_5" d="M4.16643 14.998H2.49988" stroke="#6A615B" stroke-width="1.66655" stroke-linecap="round" stroke-linejoin="round"/>
</g>
<defs>
<clipPath id="clip0_0_7">
<rect width="19.9986" height="19.9986" fill="white"/>
</clipPath>
</defs>
</svg>
''';
const _check = r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#15110d" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m8.5 12 2.5 2.5 4.5-5"/></svg>
''';
