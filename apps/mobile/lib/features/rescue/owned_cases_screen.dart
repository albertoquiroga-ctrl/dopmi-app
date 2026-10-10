import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/donor_notification_button.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import 'rescue_repository.dart';
import 'rescue_public_photo.dart';
import 'need_order.dart';
import 'public_expense_card.dart';

class OwnedCasesHeading extends StatelessWidget {
  const OwnedCasesHeading({super.key, this.total});
  final int? total;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _OwnedCasesTitle(),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text(
              total == null
                  ? 'Da seguimiento a tus mascotas'
                  : total == 0
                  ? 'Aún no tienes mascotas publicadas'
                  : '$total ${total == 1 ? 'mascota' : 'mascotas'} a tu cuidado',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xff4f4e5c),
              ),
            ),
          ),
          if (total != 0) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => context.go('/publish'),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Nuevo'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

class _OwnedCasesTitle extends StatelessWidget {
  const _OwnedCasesTitle();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 46),
    padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
    alignment: Alignment.centerLeft,
    child: Semantics(
      header: true,
      child: const Text(
        'Mis Casos',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 28,
          height: 1.1,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          color: Color(0xff151423),
        ),
      ),
    ),
  );
}

const _caseFilters = {
  'corrections': 'Rechazado',
  'draft': 'Borrador',
  'review': 'En revisión',
  'active': 'Activo',
};

String _phase(Object? status) => switch (status) {
  'changes_requested' || 'rejected' => 'corrections',
  'submitted' => 'review',
  'published' || 'approved' => 'active',
  'adopted' || 'archived' || 'closed' => 'closed',
  _ => status?.toString() ?? 'draft',
};

class MyRescueCasesScreen extends ConsumerStatefulWidget {
  const MyRescueCasesScreen({
    super.key,
    this.initialProgram = 'adoption',
    this.initialStatus,
  });
  final String initialProgram;
  final String? initialStatus;
  @override
  ConsumerState<MyRescueCasesScreen> createState() =>
      _MyRescueCasesScreenState();
}

class _MyRescueCasesScreenState extends ConsumerState<MyRescueCasesScreen> {
  final scroll = ScrollController(keepScrollOffset: false);
  late String program;
  late Set<String> statuses;
  bool archived = false, busy = false;
  int page = 1, revision = 0;
  String? error;

  Set<String> initialStatuses() =>
      _caseFilters.containsKey(widget.initialStatus)
      ? {widget.initialStatus!}
      : _caseFilters.keys.toSet();

  @override
  void initState() {
    super.initState();
    program = widget.initialProgram == 'support' ? 'support' : 'adoption';
    statuses = initialStatuses();
  }

  @override
  void didUpdateWidget(MyRescueCasesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialProgram != widget.initialProgram ||
        oldWidget.initialStatus != widget.initialStatus) {
      program = widget.initialProgram == 'support' ? 'support' : 'adoption';
      statuses = initialStatuses();
      archived = false;
      page = 1;
      revision++;
      resetScroll();
    }
  }

  void resetScroll() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) scroll.jumpTo(0);
  });

  void scope(VoidCallback change) {
    setState(() {
      change();
      page = 1;
      revision++;
      error = null;
    });
    resetScroll();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> filters() async {
    var selected = Set<String>.from(statuses);
    final result = await showDialog<Set<String>>(
      context: context,
      barrierColor: const Color(0x73151423),
      builder: (context) => StatefulBuilder(
        builder: (context, change) => _CaseModal(
          title: 'Filtrar',
          children: [
            const Text(
              'Estatus',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            for (final filter in _caseFilters.entries)
              _CaseCheckRow(
                key: ValueKey('owned-filter-${filter.key}'),
                label: filter.value,
                value: selected.contains(filter.key),
                fontSize: 15,
                onChanged: (value) => change(() {
                  if (value == true) {
                    selected.add(filter.key);
                  } else {
                    selected.remove(filter.key);
                    if (selected.isEmpty) selected = _caseFilters.keys.toSet();
                  }
                }),
              ),
            const SizedBox(height: 12),
            _CaseButton(
              label: 'Mostrar todos',
              outlined: true,
              onPressed: () =>
                  change(() => selected = _caseFilters.keys.toSet()),
            ),
            const SizedBox(height: 12),
            _CaseButton(
              label: 'Listo',
              onPressed: () => Navigator.pop(context, selected),
            ),
          ],
        ),
      ),
    );
    if (mounted) scope(() => statuses = result ?? selected);
  }

  Future<void> operate(Json item, _CaseOperation operation) async {
    if (busy) return;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x73151423),
      barrierDismissible: false,
      builder: (_) => _CaseOperationDialog(item: item, operation: operation),
    );
    if (!mounted || result != true) return;
    scope(() {
      if (operation == _CaseOperation.reactivate) archived = false;
      if (operation == _CaseOperation.closeAdoption ||
          operation == _CaseOperation.closeSupport) {
        archived = true;
      }
    });
  }

  Future<void> archiveCompleted(Json item) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(rescueRepositoryProvider)
          .archiveSupport(item['id'] as String, item['version'] as int? ?? 0);
      if (!mounted) return;
      scope(() => archived = true);
      await showDialog<void>(
        context: context,
        barrierColor: const Color(0x73151423),
        builder: (_) => const _CaseArchivedNotice(),
      );
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Json item) async {
    await context.push(
      item['program'] == 'support'
          ? '/rescue/${item['id']}'
          : '/my-adoptions/${item['id']}',
    );
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(rescueRepositoryProvider);
    final actor = ref.watch(communityRepositoryProvider).userId;
    final selected = _caseFilters.keys.where(statuses.contains).toList();
    final large = MediaQuery.textScalerOf(context).scale(17) > 24;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CommunityNav(2, selectedPath: '/my-cases'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              key: const ValueKey('owned-cases-scroll'),
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
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
                      const DonorNotificationButton(rescuer: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _OwnedCasesTitle(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xffe2ddf1)),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: large
                      ? Column(
                          children: [
                            for (final entry in const {
                              'adoption': 'Adopción',
                              'support': 'Apoyo',
                            }.entries)
                              SizedBox(
                                width: double.infinity,
                                child: _ProgramTab(
                                  label: entry.value,
                                  selected: program == entry.key,
                                  onPressed: busy
                                      ? null
                                      : () => scope(() {
                                          program = entry.key;
                                          archived = false;
                                        }),
                                ),
                              ),
                          ],
                        )
                      : Row(
                          children: [
                            for (final entry in const {
                              'adoption': 'Adopción',
                              'support': 'Apoyo',
                            }.entries)
                              Expanded(
                                child: _ProgramTab(
                                  label: entry.value,
                                  selected: program == entry.key,
                                  onPressed: busy
                                      ? null
                                      : () => scope(() {
                                          program = entry.key;
                                          archived = false;
                                        }),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : filters,
                      icon: const Icon(Icons.tune, size: 22),
                      label: const Text(
                        'Filtrar',
                        style: TextStyle(fontSize: 15),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: statuses.length == _caseFilters.length
                            ? const Color(0xff999188)
                            : ink,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(80, 48),
                      ),
                    ),
                    const Spacer(),
                    _CaseIcon(
                      label: archived ? 'Volver a casos' : 'Ver archivo',
                      asset: 'icon-inbox-archive',
                      fill: archived ? yellow : Colors.transparent,
                      color: archived ? Colors.white : const Color(0xff8a837c),
                      onPressed: busy
                          ? null
                          : () => scope(() => archived = !archived),
                    ),
                  ],
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null) Notice(error!, isError: true),
                const SizedBox(height: 12),
                LiveSection<Json>(
                  key: ValueKey(
                    '$actor/$program/$archived/$selected/$page/$revision',
                  ),
                  tables: const [
                    'dopmi_adoptions',
                    'dopmi_rescue_records',
                    'dopmi_threads',
                    'dopmi_donations',
                  ],
                  load: () => repository.ownedCases(
                    page,
                    program: program,
                    statuses: archived ? const [] : selected,
                    archived: archived,
                  ),
                  builder: (data, _) {
                    final items = (data['items'] as List? ?? const [])
                        .map((item) => Json.from(item as Map))
                        .toList();
                    final total = data['total'] as int? ?? 0;
                    final totalOwned = data['total_owned'] as int? ?? total;
                    if (totalOwned == 0) {
                      return const _OwnedCasesEmpty();
                    }
                    if (items.isEmpty) {
                      return Text(
                        archived
                            ? 'No tienes casos archivados.'
                            : program == 'adoption'
                            ? 'No tienes casos en adopción en este momento.'
                            : 'No tienes casos recibiendo apoyo en este momento.',
                        style: const TextStyle(fontSize: 14, color: muted),
                      );
                    }
                    final groups = archived
                        ? {'Archivo': items}
                        : {
                            'En proceso': items
                                .where(
                                  (item) => _phase(item['status']) != 'active',
                                )
                                .toList(),
                            program == 'adoption'
                                ? 'Buscando hogar'
                                : 'Recibiendo apoyo': items
                                .where(
                                  (item) => _phase(item['status']) == 'active',
                                )
                                .toList(),
                          };
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final group in groups.entries)
                          if (group.value.isNotEmpty) ...[
                            if (!archived)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  group.key,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                              ),
                            for (final item in group.value)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OwnedCaseCard(
                                  key: ValueKey('$program/${item['id']}'),
                                  item: item,
                                  archived: archived,
                                  busy: busy,
                                  onOpen: () => open(item),
                                  onOperation: (operation) =>
                                      operate(item, operation),
                                  onCompleted: () => archiveCompleted(item),
                                ),
                              ),
                            const SizedBox(height: 10),
                          ],
                        if (total > 20)
                          PageControls(
                            page: page,
                            total: total,
                            size: 20,
                            change: (value) {
                              setState(() => page = value);
                              resetScroll();
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgramTab extends StatelessWidget {
  const _ProgramTab({
    required this.label,
    required this.selected,
    this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xff151423)
            : Colors.transparent,
        foregroundColor: selected ? Colors.white : const Color(0xff4f4e5c),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 17,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _OwnedCasesEmpty extends StatelessWidget {
  const _OwnedCasesEmpty();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe3e4ed)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x1a7c3aed),
          ),
          child: SvgPicture.asset(
            'assets/navigation/rtab-cases.svg',
            width: 32,
            height: 32,
            colorFilter: const ColorFilter.mode(
              Color(0xff7c3aed),
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No tienes casos todavía',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cuando publiques una mascota para adopción o apoyo, tus casos aparecerán aquí para que puedas darles seguimiento.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 20 / 14, color: muted),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.go('/publish'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Publicar caso'),
          style: FilledButton.styleFrom(
            backgroundColor: purple,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
          ),
        ),
      ],
    ),
  );
}

class _CaseIcon extends StatelessWidget {
  const _CaseIcon({
    required this.label,
    this.icon,
    this.asset,
    this.fill = Colors.transparent,
    this.color = ink,
    this.onPressed,
    this.turns = 0,
  });
  final String label;
  final IconData? icon;
  final String? asset;
  final Color fill, color;
  final double turns;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.all(6),
      disabledForegroundColor: const Color(0xffb2afaa),
    ),
    icon: AnimatedRotation(
      turns: turns,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: asset != null
            ? SvgPicture.asset(
                'assets/profile/$asset.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  onPressed == null ? const Color(0xffb2afaa) : color,
                  BlendMode.srcIn,
                ),
              )
            : Icon(
                icon,
                size: 20,
                color: onPressed == null ? const Color(0xffb2afaa) : color,
              ),
      ),
    ),
  );
}

enum _CaseOperation { closeAdoption, closeSupport, archive, reactivate }

class _OwnedCaseCard extends ConsumerStatefulWidget {
  const _OwnedCaseCard({
    super.key,
    required this.item,
    required this.archived,
    required this.busy,
    required this.onOpen,
    required this.onOperation,
    required this.onCompleted,
  });
  final Json item;
  final bool archived, busy;
  final VoidCallback onOpen, onCompleted;
  final ValueChanged<_CaseOperation> onOperation;
  @override
  ConsumerState<_OwnedCaseCard> createState() => _OwnedCaseCardState();
}

class _OwnedCaseCardState extends ConsumerState<_OwnedCaseCard> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final support = item['program'] == 'support';
    final phase = _phase(item['status']);
    final active = phase == 'active';
    final rich = support && (active || widget.archived);
    final target = item['target_cents'] as int? ?? 0;
    final funded = item['funded_cents'] as int? ?? 0;
    final completed = target > 0 && funded >= target;
    final adopted =
        widget.archived && !support && item['close_reason'] == 'adopted';
    final positive = rich && completed;
    final neutral = support && widget.archived && !positive;
    final background = positive
        ? const Color(0xffe8f7ef)
        : neutral
        ? const Color(0xfff0eeea)
        : active
        ? const Color(0xfffff8e0)
        : Colors.white;
    final border = positive
        ? const Color(0xff9fd4b0)
        : neutral
        ? const Color(0xffddd9d2)
        : active
        ? const Color(0xfff3e8c4)
        : const Color(0xffe8e6e1);
    final label = widget.archived
        ? (adopted
              ? 'Adoptado'
              : support && completed
              ? 'Finalizado'
              : 'Cerrado')
        : rich && completed
        ? 'Finalizado'
        : _caseFilters[phase] ?? 'Borrador';
    final tagColor = switch (phase) {
      'corrections' => const Color(0xffc41c2e),
      'review' => const Color(0xff5c2fd4),
      'active' => ink,
      _ => const Color(0xff5c574f),
    };
    final published = DateTime.tryParse(
      (item['published_at'] ?? item['approved_at'] ?? '').toString(),
    );
    final days = published == null
        ? null
        : DateTime.now().difference(published).inDays.clamp(0, 999999);
    final cover = (item['cover_path'] ?? '').toString();
    final summary = InkWell(
      key: ValueKey('owned-case-open-${item['id']}'),
      onTap: widget.busy ? null : widget.onOpen,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: support
                  ? RescuePublicPhoto(
                      cover,
                      height: 52,
                      radius: 26,
                      compact: true,
                    )
                  : AdoptionPhoto(cover, height: 52, radius: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        (item['pet_name'] ?? 'Sin nombre').toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: positive || active
                              ? Colors.white
                              : phase == 'corrections'
                              ? const Color(0xfffdecec)
                              : phase == 'review'
                              ? const Color(0xffede8fc)
                              : adopted || neutral
                              ? Colors.transparent
                              : const Color(0xfff0eeea),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: positive || adopted
                                ? const Color(0xff187342)
                                : tagColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (phase != 'draft') ...[
                    const SizedBox(height: 4),
                    if (rich)
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Recolectado: '),
                            TextSpan(
                              text: _caseAmount(funded),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: ' de ${_caseAmount(target)}'),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: ink,
                        ),
                      )
                    else
                      Text(
                        phase == 'review'
                            ? 'Pendiente de aprobación'
                            : phase == 'corrections'
                            ? 'Requiere corrección'
                            : active || widget.archived
                            ? (days == null
                                  ? 'Publicado'
                                  : days == 0
                                  ? 'Recién publicado en Dopmi'
                                  : '$days ${days == 1 ? 'día' : 'días'} en Dopmi')
                            : 'Continúa tu publicación',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                  if (!support && (active || widget.archived)) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _CaseMetric(
                          icon: Icons.chat_bubble_outline,
                          asset: 'icon-messages',
                          label: 'Conversaciones',
                          value: item['thread_count'] as int? ?? 0,
                        ),
                        _CaseMetric(
                          icon: Icons.visibility_outlined,
                          label: 'Vistas únicas',
                          value: item['unique_view_count'] as int? ?? 0,
                        ),
                      ],
                    ),
                  ],
                  if (rich) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        for (final type
                            in (item['need_types'] as List? ?? const []))
                          _NeedSymbol(type.toString(), size: 18),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.archived) const SizedBox(height: 36),
        if (widget.archived && !support)
          _CaseIcon(
            label: 'Reactivar caso',
            asset: 'icon-edit',
            color: const Color(0xff5c574f),
            onPressed: widget.busy
                ? null
                : () => widget.onOperation(_CaseOperation.reactivate),
          )
        else if (!widget.archived && active)
          _CaseIcon(
            label: rich && completed
                ? 'Archivar caso completado'
                : 'Cerrar caso',
            icon: rich && completed ? Icons.check : Icons.close,
            color: rich && completed
                ? const Color(0xff187342)
                : const Color(0xffb83748),
            onPressed: widget.busy
                ? null
                : rich && completed
                ? widget.onCompleted
                : () => widget.onOperation(
                    support
                        ? _CaseOperation.closeSupport
                        : _CaseOperation.closeAdoption,
                  ),
          )
        else if (!widget.archived && phase != 'review')
          _CaseIcon(
            label: 'Archivar borrador',
            icon: Icons.close,
            color: const Color(0xffc10007),
            onPressed: widget.busy
                ? null
                : () => widget.onOperation(_CaseOperation.archive),
          ),
        if (!widget.archived && phase == 'review') const SizedBox(height: 36),
        if (rich)
          Semantics(
            expanded: open,
            child: _CaseIcon(
              label: open ? 'Ocultar desglose' : 'Ver desglose',
              icon: Icons.keyboard_arrow_down,
              turns: open ? .5 : 0,
              onPressed: widget.busy
                  ? null
                  : () => setState(() => open = !open),
            ),
          )
        else if (!widget.archived)
          _CaseIcon(
            label: phase == 'review'
                ? 'Edición pendiente de revisión'
                : 'Editar caso',
            asset: 'icon-edit',
            color: const Color(0xff5c574f),
            onPressed: widget.busy || phase == 'review' ? null : widget.onOpen,
          ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: active || rich
            ? const [
                BoxShadow(
                  color: Color(0x1415110d),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summary),
                const SizedBox(width: 4),
                actions,
              ],
            ),
          ),
          if (rich)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: target <= 0 ? 0 : (funded / target).clamp(0.0, 1.0),
                  color: positive
                      ? const Color(0xff1a9d55)
                      : neutral
                      ? const Color(0xffb8b4ac)
                      : yellow,
                  backgroundColor: neutral
                      ? const Color(0xffe3e0da)
                      : const Color(0xffefe9df),
                ),
              ),
            ),
          if (rich)
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: LiveSection<DataPage<RescueRecord>>(
                        key: ValueKey('owned-breakdown-${item['id']}'),
                        tables: const ['rescue_records', 'donations'],
                        load: () => ref
                            .read(rescueRepositoryProvider)
                            .completeCaseCatalog(item['id'] as String),
                        builder: (data, _) => Column(
                          children: [
                            for (final need in orderedNeeds(
                              data.items.where(
                                (record) => record.kind == 'expense',
                              ),
                            ))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: PublicExpenseCard(
                                  need,
                                  canContribute: false,
                                  showContributeAction: false,
                                ),
                              ),
                            if (!data.items.any(
                              (record) => record.kind == 'expense',
                            ))
                              const Text(
                                'Aún no hay necesidades aprobadas para mostrar.',
                              ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
        ],
      ),
    );
  }
}

class _CaseMetric extends StatelessWidget {
  const _CaseMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.asset,
  });
  final IconData icon;
  final String? asset;
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: asset != null
              ? SvgPicture.asset(
                  'assets/profile/$asset.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Color(0xff8a837c),
                    BlendMode.srcIn,
                  ),
                )
              : Icon(icon, size: 18, color: const Color(0xff8a837c)),
        ),
        const SizedBox(width: 4),
        ExcludeSemantics(
          child: Text(
            '$value',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xff8a837c),
            ),
          ),
        ),
      ],
    ),
  );
}

String _caseAmount(int cents) =>
    pesos(cents)
        .replaceFirst(RegExp(r'\.00 MXN$'), '')
        .replaceFirst(RegExp(r' MXN$'), '');

class _NeedSymbol extends StatelessWidget {
  const _NeedSymbol(this.type, {this.size = 22});
  final String type;
  final double size;
  @override
  Widget build(BuildContext context) {
    final category = switch (needRank(type)) {
      0 => 'veterinary',
      1 => 'medicine',
      2 => 'food',
      _ => '',
    };
    return category.isEmpty
        ? Icon(Icons.auto_awesome, size: size, color: muted)
        : SvgPicture.asset(
            'assets/profile/need-$category.svg',
            width: size,
            height: size,
          );
  }
}

InputDecoration _caseInput({String? hint}) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xffe2ddf1)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xffe2ddf1)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: purple),
  ),
  counterText: '',
);

class _CaseChoice extends StatelessWidget {
  const _CaseChoice({
    required this.label,
    required this.selected,
    this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected ? const Color(0xfff3eeff) : Colors.white,
        foregroundColor: selected
            ? const Color(0xff5c2fd4)
            : const Color(0xff4f4e5c),
        minimumSize: const Size(0, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        side: selected ? const BorderSide(color: purple) : BorderSide.none,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

class _CaseCheckRow extends StatelessWidget {
  const _CaseCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.fontSize = 15,
  });
  final String label;
  final bool value;
  final double fontSize;
  final ValueChanged<bool?>? onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    enabled: onChanged != null,
    label: label,
    excludeSemantics: true,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: .85,
                      child: Checkbox(
                        value: value,
                        onChanged: onChanged,
                        activeColor: purple,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CaseOperationDialog extends ConsumerStatefulWidget {
  const _CaseOperationDialog({required this.item, required this.operation});
  final Json item;
  final _CaseOperation operation;
  @override
  ConsumerState<_CaseOperationDialog> createState() =>
      _CaseOperationDialogState();
}

class _CaseOperationDialogState extends ConsumerState<_CaseOperationDialog> {
  final description = TextEditingController();
  String reason = 'adopted';
  bool dopmiSupport = true, acceptRemaining = false, busy = false;
  String? error;
  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final item = widget.item;
      final repository = ref.read(rescueRepositoryProvider);
      final id = item['id'] as String;
      final version = item['version'] as int? ?? 0;
      final record = Json.from(item['record'] as Map);
      switch (widget.operation) {
        case _CaseOperation.closeAdoption:
          await repository.closeAdoption(
            id,
            version,
            reason,
            dopmiSupport: reason == 'adopted' ? dopmiSupport : null,
            description: reason == 'other' ? description.text.trim() : '',
          );
        case _CaseOperation.closeSupport:
          await repository.closeSupportCase(RescueRecord(record));
        case _CaseOperation.archive:
          if (item['program'] == 'support') {
            await repository.archiveSupport(id, version);
          } else {
            await ref
                .read(communityRepositoryProvider)
                .transition(Adoption(record), 'archive');
          }
        case _CaseOperation.reactivate:
          await repository.reactivateAdoption(Adoption(record));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    final closeAdoption = operation == _CaseOperation.closeAdoption;
    final closeSupport = operation == _CaseOperation.closeSupport;
    final archive = operation == _CaseOperation.archive;
    final remaining =
        ((widget.item['target_cents'] as int? ?? 0) -
                (widget.item['funded_cents'] as int? ?? 0))
            .clamp(0, 1 << 53)
            .toInt();
    final name = (widget.item['pet_name'] ?? 'esta mascota').toString();
    final title = closeAdoption
        ? 'Cerrar caso'
        : closeSupport
        ? '¿Deseas cerrar el caso?'
        : archive
        ? '¿Archivar este borrador?'
        : '¿Reactivar este caso?';
    return PopScope(
      canPop: !busy,
      child: _CaseModal(
        title: title,
        canDismiss: !busy,
        children: [
          if (!closeSupport)
            Text(
              closeAdoption
                  ? 'Esta acción archiva el caso.'
                  : archive
                  ? 'El borrador de $name se moverá al archivo. Su información y el historial se conservarán.'
                  : 'El caso de $name volverá a tus borradores con sus fotos e información. Necesitará una nueva revisión antes de publicarse.',
              style: const TextStyle(fontSize: 14, height: 1.5, color: muted),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          if (closeAdoption) ...[
            const Text(
              'Motivo',
              style: TextStyle(fontSize: 14, height: 1.5, color: ink),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: const ValueKey('owned-close-reason'),
              initialValue: reason,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'adopted',
                  child: Text('Ya fue adoptado'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Otro motivo')),
              ],
              decoration: _caseInput(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.35,
                color: ink,
              ),
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: ink),
              onChanged: busy
                  ? null
                  : (value) => setState(() => reason = value!),
            ),
            const SizedBox(height: 16),
            if (reason == 'adopted') ...[
              const Text(
                '¿Se adoptó con apoyo de Dopmi?',
                style: TextStyle(fontSize: 14, color: ink),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffe2ddf1)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final choice in const {
                      true: 'Sí',
                      false: 'No',
                    }.entries) ...[
                      Expanded(
                        child: _CaseChoice(
                          label: choice.value,
                          selected: dopmiSupport == choice.key,
                          onPressed: busy
                              ? null
                              : () => setState(() => dopmiSupport = choice.key),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Describe el motivo',
                style: TextStyle(fontSize: 14, height: 1.5, color: ink),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: description,
                maxLength: 1000,
                maxLines: 4,
                minLines: 4,
                style: const TextStyle(fontSize: 14, height: 1.5, color: ink),
                cursorColor: purple,
                enabled: !busy,
                key: const ValueKey('owned-close-description'),
                decoration: _caseInput(
                  hint: 'Opcional',
                ).copyWith(constraints: const BoxConstraints(minHeight: 112)),
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (closeSupport && remaining > 0) ...[
            _CaseCheckRow(
              key: const ValueKey('owned-close-remaining'),
              value: acceptRemaining,
              label:
                  'Entiendo que al cerrar el caso ya no recibirá el apoyo faltante de ${_caseAmount(remaining)}. Las aportaciones registradas se conservarán.',
              fontSize: 14,
              onChanged: busy
                  ? null
                  : (value) => setState(() => acceptRemaining = value == true),
            ),
            const SizedBox(height: 16),
          ],
          if (error != null) ...[
            Notice(error!, isError: true),
            const SizedBox(height: 12),
          ],
          _CaseButton(
            label: busy
                ? 'Guardando…'
                : closeAdoption || closeSupport
                ? 'Confirmar cierre'
                : archive
                ? 'Sí, archivar'
                : 'Sí, reactivar',
            danger: closeAdoption || closeSupport || archive,
            onPressed: busy || closeSupport && remaining > 0 && !acceptRemaining
                ? null
                : submit,
          ),
          const SizedBox(height: 10),
          _CaseButton(
            label: 'Cancelar',
            outlined: true,
            onPressed: busy ? null : () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}

class _CaseModal extends StatelessWidget {
  const _CaseModal({
    required this.title,
    required this.children,
    this.canDismiss = true,
  });
  final String title;
  final List<Widget> children;
  final bool canDismiss;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    48)
                .clamp(80, 2000)
                .toDouble(),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
                Positioned(
                  right: -18,
                  top: -22,
                  child: IconButton(
                    tooltip: 'Cerrar diálogo',
                    onPressed: canDismiss ? () => Navigator.pop(context) : null,
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _CaseButton extends StatelessWidget {
  const _CaseButton({
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool outlined, danger;
  @override
  Widget build(BuildContext context) {
    final shape = outlined || danger
        ? const StadiumBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final padding = EdgeInsets.symmetric(
      horizontal: 14,
      vertical: outlined || danger ? 12 : 8,
    );
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: outlined || danger ? 16 : 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
    return outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: purple,
              side: const BorderSide(color: Color(0xffc9b8ff)),
              minimumSize: const Size(0, 48),
              padding: padding,
              shape: shape,
            ),
            child: text,
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: danger ? const Color(0xfffff1f2) : purple,
              foregroundColor: danger ? const Color(0xffc41c2e) : Colors.white,
              disabledBackgroundColor: danger ? const Color(0xfffff7f8) : null,
              disabledForegroundColor: danger ? const Color(0xffdb7a89) : null,
              side: danger ? const BorderSide(color: Color(0xfffecdd3)) : null,
              minimumSize: const Size(0, 48),
              padding: padding,
              shape: shape,
            ),
            child: text,
          );
  }
}

class _CaseArchivedNotice extends StatefulWidget {
  const _CaseArchivedNotice();
  @override
  State<_CaseArchivedNotice> createState() => _CaseArchivedNoticeState();
}

class _CaseArchivedNoticeState extends State<_CaseArchivedNotice> {
  Timer? timer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (timer == null && !MediaQuery.accessibleNavigationOf(context)) {
      timer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/profile/icon-inbox-archive.svg',
                width: 44,
                height: 44,
                colorFilter: const ColorFilter.mode(purple, BlendMode.srcIn),
              ),
              const SizedBox(height: 16),
              const Text(
                'Caso finalizado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Este caso se envió al archivo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
