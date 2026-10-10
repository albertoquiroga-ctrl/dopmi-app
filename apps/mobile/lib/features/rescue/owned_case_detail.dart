import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/reference_focus_outline.dart';
import '../adoption/community_ui.dart';
import 'rescue_repository.dart';
import 'rescue_public_photo.dart';

class OwnedCaseDetail extends StatelessWidget {
  const OwnedCaseDetail({
    super.key,
    required this.record,
    required this.needs,
    required this.updates,
    required this.busy,
    required this.onBack,
    required this.onRecord,
    required this.onRefresh,
    required this.onExpense,
    required this.onUpdates,
    required this.onClose,
    this.error,
  });
  final RescueRecord record;
  final Widget needs, updates;
  final bool busy;
  final VoidCallback onBack, onRecord, onRefresh, onExpense, onUpdates, onClose;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final actionPadding = MediaQuery.textScalerOf(context).scale(14) > 21
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
        : null;
    final age = (record.publicData['age'] as String? ?? '').trim();
    final location = [
      record.publicData['city'],
      record.publicData['state'],
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(', ');
    final title = Text(
      age.isEmpty ? record.title : '${record.title}, $age',
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        height: 1.25,
        letterSpacing: -.48,
        fontWeight: FontWeight.w700,
        color: Color(0xff151423),
      ),
    );
    final city = record.publicData['city'] is String
        ? (record.publicData['city'] as String).trim()
        : '';
    final locationTag = Tooltip(
      message: location,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xffe3e4ed)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/profile/location.svg',
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                Color(0xff4f4e5c),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                city.isEmpty ? location : city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 15 / 12,
                  color: Color(0xff4f4e5c),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CommunityNav(2, selectedPath: '/my-cases'),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Stack(
            children: [
              OwnedCaseHero(record: record, onBack: onBack),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 276, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xffe3e4ed)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (location.isEmpty)
                            title
                          else if (MediaQuery.textScalerOf(context).scale(24) >
                              30) ...[
                            title,
                            const SizedBox(height: 8),
                            locationTag,
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: title),
                                const SizedBox(width: 12),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 120,
                                  ),
                                  child: locationTag,
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Text(
                            record.publicData['story'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: Color(0xff151423),
                            ),
                          ),
                          if (record.status == 'closed')
                            const SizedBox(height: 8),
                          if (record.status == 'closed')
                            const Text(
                              'Caso cerrado',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xff4f4e5c),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        semanticsLabel: 'Actualizando el caso',
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        style: const TextStyle(color: Color(0xffb51224)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Gastos del caso',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 19,
                        height: 1.3,
                        color: Color(0xff151423),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 31.77),
                    needs,
                    if (record.status != 'closed') ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy ? null : onExpense,
                        style: FilledButton.styleFrom(padding: actionPadding),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Registrar gasto realizado',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    updates,
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: busy ? null : onUpdates,
                      style: OutlinedButton.styleFrom(padding: actionPadding),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text(
                        'Administrar avances',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: busy ? null : onRecord,
                      style: OutlinedButton.styleFrom(padding: actionPadding),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text(
                        'Consultar expediente',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : onRefresh,
                      child: const Text('Recargar estado'),
                    ),
                    if (record.status == 'approved') ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: busy ? null : onClose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffb51224),
                          padding: actionPadding,
                        ),
                        child: const Text('Cerrar caso'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OwnedCaseHero extends StatefulWidget {
  const OwnedCaseHero({super.key, required this.record, required this.onBack});
  final RescueRecord record;
  final VoidCallback onBack;
  @override
  State<OwnedCaseHero> createState() => _OwnedCaseHeroState();
}

class _OwnedCaseHeroState extends State<OwnedCaseHero> {
  final controller = PageController();
  int index = 0;
  List<String> get photos => (widget.record.publicData['photos'] as List? ?? [])
      .whereType<String>()
      .toList();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(OwnedCaseHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id ||
        (oldWidget.record.publicData['photos'] as List? ?? []).join('|') !=
            photos.join('|')) {
      index = 0;
      if (controller.hasClients) controller.jumpToPage(0);
    }
  }

  void select(int next) {
    if (!controller.hasClients) return;
    controller.jumpToPage(next);
    setState(() => index = next);
  }

  @override
  Widget build(BuildContext context) {
    final paths = photos;
    final dotsWidth = math.max(48.0, paths.length * 16.0 - 8);
    return SizedBox(
      height: 286,
      child: Stack(
        children: [
          Positioned.fill(
            child: paths.isEmpty
                ? const ColoredBox(
                    color: Color(0xfff0eff8),
                    child: Center(
                      child: Icon(
                        Icons.pets_outlined,
                        size: 56,
                        color: Color(0xff7c3aed),
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: controller,
                    itemCount: paths.length,
                    onPageChanged: (next) => setState(() => index = next),
                    itemBuilder: (_, n) =>
                        RescuePublicPhoto(paths[n], height: 286, radius: 0),
                  ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Semantics(
              button: true,
              label: 'Volver',
              onTap: widget.onBack,
              child: ExcludeSemantics(
                child: ReferenceFocusOutline(
                  radius: 20,
                  outlineInset: const EdgeInsets.all(4),
                  child: InkWell(
                    key: const ValueKey('owned-case-back'),
                    excludeFromSemantics: true,
                    splashFactory: NoSplash.splashFactory,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    onTap: widget.onBack,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x73000000),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/profile/back.svg',
                              width: 20,
                              height: 20,
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
              ),
            ),
          ),
          if (paths.isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${index + 1} / ${paths.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (paths.length > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  label: 'Seleccionar foto',
                  value: '${index + 1} de ${paths.length}',
                  increasedValue: index < paths.length - 1
                      ? '${index + 2} de ${paths.length}'
                      : null,
                  decreasedValue: index > 0
                      ? '$index de ${paths.length}'
                      : null,
                  onIncrease: index < paths.length - 1
                      ? () => select(index + 1)
                      : null,
                  onDecrease: index > 0 ? () => select(index - 1) : null,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      key: const ValueKey('owned-case-photo-selector'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final offset =
                            (dotsWidth - (paths.length * 16 - 8)) / 2;
                        select(
                          ((details.localPosition.dx - offset - 4) / 16)
                              .round()
                              .clamp(0, paths.length - 1),
                        );
                      },
                      child: SizedBox(
                        width: dotsWidth,
                        height: 48,
                        child: Align(
                          alignment: const Alignment(0, .4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var n = 0; n < paths.length; n++) ...[
                                if (n > 0) const SizedBox(width: 8),
                                ReferenceFocusOutline(
                                  radius: 4,
                                  child: InkWell(
                                    key: ValueKey('owned-case-photo-$n'),
                                    onTap: () => select(n),
                                    excludeFromSemantics: true,
                                    splashFactory: NoSplash.splashFactory,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: n == index
                                            ? Colors.white
                                            : const Color(0x73ffffff),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
  }
}
