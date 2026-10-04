import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/reference_focus_outline.dart';
import '../payments/contribution_amount_dialog.dart';
import 'rescue_repository.dart';
import 'rescue_public_photo.dart';

class CaseDetailLayout extends StatefulWidget {
  const CaseDetailLayout({
    super.key,
    required this.record,
    required this.expenses,
    required this.needs,
    required this.saved,
    required this.busy,
    required this.favorite,
    required this.share,
    required this.report,
    this.updates,
    this.error,
  });
  final RescueRecord record;
  final List<RescueRecord> expenses;
  final Widget needs;
  final Widget? updates;
  final bool saved, busy;
  final VoidCallback favorite, share, report;
  final String? error;
  @override
  State<CaseDetailLayout> createState() => _CaseDetailLayoutState();
}

class _CaseDetailLayoutState extends State<CaseDetailLayout> {
  final photosController = PageController();
  int photoIndex = 0;
  List<String> get photos =>
      (widget.record.publicData['photos'] as List? ?? const [])
          .whereType<String>()
          .toList();
  @override
  void dispose() {
    photosController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CaseDetailLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id ||
        (oldWidget.record.publicData['photos'] as List? ?? []).join('|') !=
            photos.join('|')) {
      photoIndex = 0;
      if (photosController.hasClients) photosController.jumpToPage(0);
    }
  }

  void back() => context.canPop() ? context.pop() : context.go('/rescue-cases');
  void selectPhoto(int index) {
    if (photosController.hasClients) photosController.jumpToPage(index);
    setState(() => photoIndex = index);
  }

  Widget photoDot(int index, int count) {
    final size = index == photoIndex ? 8.0 : 7.0;
    final left = index == 0 ? 0.0 : 3.0;
    final right = index == count - 1 ? 0.0 : 3.0;
    return Semantics(
      button: true,
      selected: photoIndex == index,
      label: 'Foto ${index + 1} de $count',
      onTap: () => selectPhoto(index),
      child: ReferenceFocusOutline(
        radius: size / 2,
        outlineInset: EdgeInsets.fromLTRB(left, 20, right, 28 - size),
        child: InkWell(
          key: ValueKey('public-case-photo-$index'),
          onTap: () => selectPhoto(index),
          excludeFromSemantics: true,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: SizedBox(
            width: left + size + right,
            height: 48,
            child: Padding(
              padding: EdgeInsets.fromLTRB(left, 20, right, 28 - size),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: index == photoIndex ? 1 : .45,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget svg(String name, double size, {Color? color}) => SvgPicture.asset(
    'assets/profile/$name.svg',
    width: size,
    height: size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color, BlendMode.srcIn),
  );
  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final photoPaths = photos;
    final heroHeight = MediaQuery.sizeOf(context).height * .42;
    final height = heroHeight.clamp(260.0, 340.0);
    final rescuer = record.data['rescuer_name'] as String? ?? '';
    final owner = record.data['owner_id'] as String?;
    final location = [
      record.publicData['city'],
      record.publicData['state'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final categories = widget.expenses
        .map(
          (e) => categoryLabel(
            (e.publicData['category'] ?? e.publicData['type'] ?? '').toString(),
          ),
        )
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final eligible = widget.expenses
        .where(
          (e) =>
              record.status == 'approved' &&
              e.status == 'approved' &&
              e.targetCents > e.fundedCents,
        )
        .toList();
    final ratio = record.targetCents <= 0
        ? 0.0
        : (record.fundedCents / record.targetCents).clamp(0.0, 1.0);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (photoPaths.isEmpty)
                            const ColoredBox(
                              color: yellow,
                              child: Center(
                                child: Icon(Icons.pets, size: 72, color: ink),
                              ),
                            )
                          else
                            PageView.builder(
                              controller: photosController,
                              itemCount: photoPaths.length,
                              onPageChanged: (index) =>
                                  setState(() => photoIndex = index),
                              itemBuilder: (_, index) => RescuePublicPhoto(
                                photoPaths[index],
                                key: ValueKey(photoPaths[index]),
                                height: height,
                                radius: 0,
                              ),
                            ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: IconButton(
                                  tooltip: 'Volver',
                                  onPressed: back,
                                  style: IconButton.styleFrom(
                                    overlayColor: Colors.transparent,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: .72,
                                    ),
                                    minimumSize: const Size(40, 40),
                                    maximumSize: const Size(40, 40),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: svg('back', 20, color: ink),
                                ),
                              ),
                            ),
                          ),
                          if (owner != null && rescuer.isNotEmpty)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: math.min(
                                    MediaQuery.sizeOf(context).width * .58,
                                    220,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    splashFactory: NoSplash.splashFactory,
                                    overlayColor: const WidgetStatePropertyAll(
                                      Colors.transparent,
                                    ),
                                    onTap: () => context.push('/people/$owner'),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        5,
                                        6,
                                        5,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              rescuer,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                letterSpacing: 0,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: yellow,
                                            foregroundColor: ink,
                                            child: Text(
                                              rescuer.characters.first,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                letterSpacing: 0,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (photoPaths.isNotEmpty)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < photoPaths.length; i++)
                                    photoDot(i, photoPaths.length),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: height - 22),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x0f15110d),
                            offset: Offset(0, -8),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.title,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        letterSpacing: -.56,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                        color: ink,
                                      ),
                                    ),
                                    if (location.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          svg(
                                            'location',
                                            14,
                                            color: const Color(0xff6b5000),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              location,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                letterSpacing: 0,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xff6b5000),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    // The public catalog is gated by private.dopmi_rescuer_verified on the server.
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        svg('icon-verified', 16),
                                        const SizedBox(width: 6),
                                        const Expanded(
                                          child: Text(
                                            'Rescatista verificado',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              letterSpacing: 0,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 42,
                                height: 42,
                                child: IconButton(
                                  tooltip: 'Compartir',
                                  onPressed: widget.share,
                                  style: IconButton.styleFrom(
                                    overlayColor: Colors.transparent,
                                    side: const BorderSide(
                                      color: Color(0xffe6e2dd),
                                      width: 1.5,
                                    ),
                                    shape: const CircleBorder(),
                                  ),
                                  icon: svg('icon-share', 18, color: ink),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, box) {
                              final items = [
                                _CaseFundingStat(
                                  'Recibido',
                                  record.fundedCents,
                                  received: true,
                                ),
                                _CaseFundingStat(
                                  'Objetivo',
                                  record.targetCents,
                                  received: false,
                                ),
                              ];
                              if (MediaQuery.textScalerOf(context).scale(18) >
                                  25) {
                                return Column(
                                  children: [
                                    items[0],
                                    const SizedBox(height: 12),
                                    items[1],
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: items[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: items[1]),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: const Color(0xffefe9df),
                            color: yellow,
                          ),
                          if (categories.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final category in categories)
                                  Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 34,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xffe6e2dd),
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        letterSpacing: 0,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                            'Mi historia',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              letterSpacing: 0,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (record.publicData['story'] ??
                                    record.publicData['description'] ??
                                    '')
                                as String,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              letterSpacing: 0,
                              fontSize: 14,
                              height: 1.55,
                              color: muted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Ayúdame a recuperar:',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              letterSpacing: 0,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          widget.needs,
                          if (photoPaths.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, box) {
                                final columns =
                                    MediaQuery.textScalerOf(context).scale(14) >
                                        20
                                    ? 1
                                    : 2;
                                final size =
                                    (box.maxWidth - 12 * (columns - 1)) /
                                    columns;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    for (var i = 0; i < photoPaths.length; i++)
                                      SizedBox(
                                        width: size,
                                        height: size,
                                        child: Semantics(
                                          button: true,
                                          label: 'Ver foto ${i + 1}',
                                          child: InkWell(
                                            splashFactory:
                                                NoSplash.splashFactory,
                                            overlayColor:
                                                const WidgetStatePropertyAll(
                                                  Colors.transparent,
                                                ),
                                            onTap: () => selectPhoto(i),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            child: RescuePublicPhoto(
                                              photoPaths[i],
                                              height: size,
                                              radius: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: widget.busy ? null : widget.report,
                              style: TextButton.styleFrom(
                                splashFactory: NoSplash.splashFactory,
                                overlayColor: Colors.transparent,
                                animationDuration: Duration.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: muted,
                                padding: EdgeInsets.zero,
                                textStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  letterSpacing: 0,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  svg('icon-alert-circle', 16, color: muted),
                                  const SizedBox(width: 6),
                                  const Flexible(child: Text('Reportar')),
                                ],
                              ),
                            ),
                          ),
                          if (widget.error != null)
                            Notice(widget.error!, isError: true),
                          OutlinedButton.icon(
                            onPressed: widget.busy ? null : widget.favorite,
                            icon: Icon(
                              widget.saved
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                            ),
                            label: Text(
                              widget.saved ? 'Caso guardado' : 'Guardar caso',
                            ),
                          ),
                          if (widget.updates != null) widget.updates!,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xffe6e2dd))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0f15110d),
                  offset: Offset(0, -8),
                  blurRadius: 24,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.busy || eligible.isEmpty
                        ? null
                        : () => chooseContribution(
                            context,
                            eligible.first.id,
                            eligible.first.targetCents -
                                eligible.first.fundedCents,
                            caseId: widget.record.id,
                          ),
                    style: FilledButton.styleFrom(
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: Colors.transparent,
                      animationDuration: Duration.zero,
                      backgroundColor: ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        letterSpacing: 0,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      eligible.isEmpty ? 'Sin gastos disponibles' : 'Donar',
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _CaseFundingStat extends StatelessWidget {
  const _CaseFundingStat(this.label, this.cents, {required this.received});
  final String label;
  final int cents;
  final bool received;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: ${pesos(cents)}',
    child: Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: received
                  ? const Color(0xffeee8ff)
                  : const Color(0xfffff1df),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: received
                ? SvgPicture.string(
                    _impact,
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      purple,
                      BlendMode.srcIn,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/profile/icon-star.svg',
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      Color(0xffc45c12),
                      BlendMode.srcIn,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _amount(cents),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    letterSpacing: 0,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: ink,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    letterSpacing: 0,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: muted,
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

String _amount(int cents) {
  final whole = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '\$$whole${cents % 100 == 0 ? '' : '.${(cents % 100).toString().padLeft(2, '0')}'}';
}

String categoryLabel(String value) =>
    const {
      'veterinary': 'Veterinario',
      'medicine': 'Medicinas',
      'food': 'Alimento',
      'other': 'Otro',
      'Comida': 'Alimento',
      'Medicina': 'Medicinas',
    }[value] ??
    value;

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

class CaseStatusFrame extends StatelessWidget {
  const CaseStatusFrame(this.content, {super.key});
  final Widget content;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      toolbarHeight: 70,
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Volver',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/rescue-cases'),
        icon: SvgPicture.asset(
          'assets/profile/back.svg',
          width: 20,
          height: 20,
        ),
      ),
    ),
    body: SafeArea(
      child: Padding(padding: const EdgeInsets.all(20), child: content),
    ),
  );
}
