import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/css_linear_gradient.dart';
import '../../core/donor_notification_button.dart';
import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import 'rescue_public_photo.dart';
import 'rescue_repository.dart';

class RescueHomeScreen extends ConsumerWidget {
  const RescueHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityControllerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CommunityNav(2),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListenableBuilder(
              listenable: identity,
              builder: (context, _) {
                final actor = identity.identity?.id;
                final repository = ref.watch(rescueRepositoryProvider);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Brand(),
                        DonorNotificationButton(rescuer: true),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
                      child: RescuerGreeting(key: ValueKey('greeting-$actor')),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: LiveSection<Json>(
                        key: ValueKey('home-$actor'),
                        tables: const [
                          'dopmi_rescue_records',
                          'dopmi_adoptions',
                          'dopmi_donations',
                          'dopmi_notifications',
                          'dopmi_favorites',
                        ],
                        load: () async {
                          final data = await repository.dashboardV2();
                          if (identity.identity?.id != actor) {
                            throw StateError('identity_changed');
                          }
                          return data;
                        },
                        builder: (data, refresh) => RescuerHomeDashboard(
                          key: ValueKey(actor),
                          data: data,
                          refresh: refresh,
                          actor: actor,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class RescuerGreeting extends ConsumerWidget {
  const RescuerGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget greeting(String? name) => Semantics(
      header: true,
      child: Text(
        name == null || name.trim().isEmpty
            ? 'Hola'
            : 'Hola, ${name.trim().split(RegExp(r'\s+')).first}',
        style: const TextStyle(
          fontSize: 28,
          height: 40 / 28,
          fontWeight: FontWeight.w700,
          color: Color(0xff151423),
        ),
      ),
    );
    return LiveSection<Profile>(
      load: () => ref.read(identityRepositoryProvider).loadProfile(),
      statusFrame: (_) => greeting(null),
      builder: (profile, _) => greeting(
        profile.id == ref.read(identityControllerProvider).identity?.id
            ? profile.name
            : null,
      ),
    );
  }
}

class RescuerVerificationCard extends StatelessWidget {
  const RescuerVerificationCard({
    super.key,
    required this.status,
    required this.onPressed,
  });
  final String status;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0x4d7c3aed)),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x1a7c3aed), Color(0x0d7c3aed)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.textScalerOf(context).scale(16) > 24)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x337c3aed),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 24,
                  color: purple,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _verificationTitle(status),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: purple,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x337c3aed),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 24,
                  color: purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _verificationTitle(status),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: purple,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        const Text(
          'La verificación protege a donantes y mascotas. Tus documentos no son públicos.',
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xff4f4e5c)),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          child: Text(status == 'not_started' ? 'Verificarme' : 'Ver estado'),
        ),
      ],
    ),
  );
}

/// The home selectors reveal summaries; the carousel itself is informational.
class RescuerHomeDashboard extends ConsumerStatefulWidget {
  const RescuerHomeDashboard({
    super.key,
    required this.data,
    required this.refresh,
    required this.actor,
  });
  final Json data;
  final VoidCallback refresh;
  final String? actor;

  @override
  ConsumerState<RescuerHomeDashboard> createState() =>
      _RescuerHomeDashboardState();
}

class _RescuerHomeDashboardState extends ConsumerState<RescuerHomeDashboard> {
  String pendingProgram = 'adoption', activityView = 'none';
  String? queuedCursor, failedCursor;
  final acknowledged = <String>{};
  bool acknowledging = false;

  Json counts(String program) =>
      Json.from(widget.data['${program}_counts'] as Map? ?? {});
  List<Json> get activity => _homeRows(widget.data['recent_activity']);
  List<Json> get evidence => _homeRows(widget.data['pending_evidence']);

  @override
  void didUpdateWidget(RescuerHomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _presentPayments();
  }

  void _presentPayments() {
    final cursor = widget.data['payments_cursor'] as String?;
    if (activityView != 'payments' ||
        activity.isEmpty ||
        cursor == null ||
        cursor.isEmpty ||
        acknowledging ||
        queuedCursor == cursor ||
        failedCursor == cursor ||
        acknowledged.contains(cursor)) {
      return;
    }
    queuedCursor = cursor;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          activityView != 'payments' ||
          ref.read(identityControllerProvider).identity?.id != widget.actor) {
        queuedCursor = null;
        return;
      }
      setState(() => acknowledging = true);
      try {
        await ref.read(rescueRepositoryProvider).acknowledgePayments(cursor);
        if (!mounted ||
            ref.read(identityControllerProvider).identity?.id != widget.actor) {
          return;
        }
        acknowledged.add(cursor);
        failedCursor = null;
        // Refresh the server count: a payment arriving meanwhile stays unseen.
        widget.refresh();
      } catch (_) {
        if (mounted) failedCursor = cursor;
      } finally {
        if (mounted) {
          setState(() {
            acknowledging = false;
            queuedCursor = null;
          });
          _presentPayments();
        }
      }
    });
  }

  void _select(String selection) {
    if (selection == 'messages') {
      context.go('/messages');
      return;
    }
    setState(() => activityView = selection);
    _presentPayments();
  }

  bool get empty =>
      _homeCountsEmpty(counts('adoption')) &&
      _homeCountsEmpty(counts('support')) &&
      evidence.isEmpty &&
      widget.data['unanswered_conversations'] == 0 &&
      widget.data['payments_unseen_count'] == 0 &&
      activity.isEmpty;

  @override
  Widget build(BuildContext context) {
    final verification =
        widget.data['verification_status'] as String? ?? 'not_started';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (verification != 'approved') ...[
          RescuerVerificationCard(
            status: verification,
            onPressed: () async {
              await context.push('/rescue/new?kind=verification');
              if (mounted) widget.refresh();
            },
          ),
          const SizedBox(height: 20),
        ],
        if (empty)
          const _HomeEmpty()
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _programTab('adoption', 'En adopción'),
                const SizedBox(width: 20),
                _programTab('support', 'Recibiendo apoyo'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _HomeCarousel(
            key: ValueKey(pendingProgram),
            cards: pendingProgram == 'adoption'
                ? _adoptionCards()
                : _supportCards(),
          ),
        ],
        const SizedBox(height: 20),
        _HomeQuickAccess(
          selected: activityView,
          counts: {
            'adoption': _homePendingCount(counts('adoption')),
            'support': _homePendingCount(counts('support')),
            'messages': _homeCount(widget.data['unanswered_conversations']),
            'payments': _homeCount(widget.data['payments_unseen_count']),
          },
          onSelected: _select,
        ),
        if (activityView != 'none') ...[
          const SizedBox(height: 20),
          _HomeActivityPanel(
            title: switch (activityView) {
              'adoption' => 'Resumen de adopción',
              'support' => 'Resumen de apoyo',
              _ => 'Actividad reciente',
            },
            onSeeAll: activityView == 'payments'
                ? () async {
                    await context.push('/rescuer/received-payments');
                    if (mounted) widget.refresh();
                  }
                : null,
            children: activityView == 'payments'
                ? [
                    if (activity.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('Aún no tienes apoyos recibidos.'),
                      ),
                    for (var index = 0; index < activity.length; index++)
                      _HomePaymentRow(
                        item: activity[index],
                        last: index == activity.length - 1,
                      ),
                    if (failedCursor != null)
                      _AcknowledgementRetry(
                        onPressed: () {
                          setState(() => failedCursor = null);
                          _presentPayments();
                        },
                      ),
                  ]
                : [
                    for (final status in _homeStatuses)
                      _HomeSummaryRow(
                        program: activityView,
                        status: status,
                        count: _homeCount(counts(activityView)[status]),
                        last: status == _homeStatuses.last,
                      ),
                  ],
          ),
        ],
        const SizedBox(height: 20),
        const _HomePhotoTips(),
      ],
    );
  }

  Widget _programTab(String program, String label) => ReferenceFocusOutline(
    radius: 6,
    child: Semantics(
      selected: pendingProgram == program,
      button: true,
      child: InkWell(
        onTap: () => setState(() => pendingProgram = program),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: pendingProgram == program
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: pendingProgram == program
                  ? const Color(0xff151423)
                  : const Color(0xffa8a29a),
            ),
          ),
        ),
      ),
    ),
  );

  List<_HomeCardData> _adoptionCards() {
    final metrics = Json.from(widget.data['adoption_metrics'] as Map? ?? {});
    final viewers = _homeCount(metrics['unique_viewers']);
    final saved = _homeCount(metrics['pets_saved']);
    final unanswered = _homeCount(widget.data['unanswered_conversations']);
    final started = DateTime.tryParse(
      '${metrics['tracking_started_at'] ?? ''}',
    );
    return [
      _HomeCardData(
        kind: 'Adoptar',
        count: viewers,
        copy: viewers == 1
            ? 'persona vio tus mascotas en Adoptar'
            : 'personas vieron tus mascotas en Adoptar',
        note: started == null
            ? null
            : 'Seguimiento desde ${started.day}/${started.month}/${started.year}',
        color: Colors.white,
      ),
      _HomeCardData(
        kind: 'Mis match',
        count: saved,
        copy: saved == 1
            ? 'mascota pasó a Mis match desde Adoptar'
            : 'mascotas pasaron a Mis match desde Adoptar',
        color: const Color(0xffe8f2ff),
      ),
      _HomeCardData(
        kind: 'Mensajes',
        count: unanswered,
        copy: unanswered == 1
            ? 'conversación sin responder'
            : 'conversaciones sin responder',
        color: const Color(0xffefe8ff),
      ),
    ];
  }

  List<_HomeCardData> _supportCards() => [
    for (var index = 0; index < evidence.length; index++)
      if (evidence[index]['status'] != 'approved')
        _HomeCardData(
          kind: 'Evidencia',
          copy: [
            evidence[index]['pet_name'],
            evidence[index]['expense_title'],
            evidence[index]['status'] == 'draft'
                ? evidence[index]['urgent'] == true
                      ? 'Incompleta'
                      : 'Evidencia pendiente'
                : 'Requiere correcciones',
          ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
          badge: evidence[index]['urgent'] == true ? 'Urgente' : 'Pendiente',
          urgent: evidence[index]['urgent'] == true,
          progress: _homeCount(evidence[index]['progress_percent']),
          color: index.isEven
              ? const Color(0xffefe8ff)
              : const Color(0xffe8f2ff),
        ),
  ];
}

const _homeStatuses = ['active', 'review', 'draft', 'corrections'];
int? _homeCount(dynamic value) => value is num ? value.toInt() : null;
List<Json> _homeRows(dynamic value) =>
    value is List ? value.whereType<Map>().map(Json.from).toList() : [];
bool _homeCountsEmpty(Json counts) =>
    _homeStatuses.every((status) => counts[status] == 0);
int? _homePendingCount(Json counts) {
  final values = _homeStatuses
      .skip(1)
      .map((status) => _homeCount(counts[status]));
  if (values.any((value) => value == null)) return null;
  return values.fold<int>(0, (sum, value) => sum + value!);
}

class _HomeCardData {
  const _HomeCardData({
    required this.kind,
    required this.copy,
    required this.color,
    this.count,
    this.note,
    this.badge,
    this.urgent = false,
    this.progress,
  });
  final String kind, copy;
  final Color color;
  final int? count, progress;
  final String? note, badge;
  final bool urgent;
  bool get metric => badge == null;
}

class _HomeCarousel extends StatelessWidget {
  const _HomeCarousel({super.key, required this.cards});
  final List<_HomeCardData> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 168),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xffefe8ff),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text('No tienes evidencias pendientes.'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context);
        final large = scale.scale(12) > 18;
        final widths = cards.map((card) {
          final longest = card.kind
              .split(' ')
              .map((word) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: word,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  textScaler: scale,
                  textDirection: Directionality.of(context),
                )..layout();
                return painter.width;
              })
              .reduce(math.max);
          return math
              .max(
                large
                    ? math.max(224, constraints.maxWidth * .8)
                    : (constraints.maxWidth - 28) / 2.28,
                longest + 104,
              )
              .toDouble();
        }).toList();
        final offsets = <double>[0];
        for (var index = 0; index < widths.length - 1; index++) {
          offsets.add(offsets.last + widths[index] + 14);
        }
        return SingleChildScrollView(
          key: const ValueKey('home-carousel'),
          scrollDirection: Axis.horizontal,
          physics: _HomeSnapPhysics(offsets),
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index > 0) const SizedBox(width: 14),
                  SizedBox(
                    width: widths[index],
                    child: _HomeCard(data: cards[index], large: large),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeSnapPhysics extends ClampingScrollPhysics {
  const _HomeSnapPhysics(this.offsets, {super.parent});
  final List<double> offsets;

  @override
  _HomeSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _HomeSnapPhysics(offsets, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((position.pixels <= position.minScrollExtent && velocity <= 0) ||
        (position.pixels >= position.maxScrollExtent && velocity >= 0)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final stops =
        offsets
            .map(
              (offset) => offset
                  .clamp(position.minScrollExtent, position.maxScrollExtent)
                  .toDouble(),
            )
            .toSet()
            .toList()
          ..sort();
    final projected = position.pixels + velocity * .12;
    var target = stops.reduce(
      (a, b) => (a - projected).abs() <= (b - projected).abs() ? a : b,
    );
    if (velocity.abs() > toleranceFor(position).velocity &&
        (target - position.pixels).abs() < .5) {
      final next = stops
          .where((stop) => velocity > 0 ? stop > target : stop < target)
          .toList();
      if (next.isNotEmpty) target = velocity > 0 ? next.first : next.last;
    }
    if ((target - position.pixels).abs() < .5) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.data, required this.large});
  final _HomeCardData data;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
    label: data.note,
    child: Container(
      constraints: const BoxConstraints(minHeight: 168),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0f15110d),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(right: large ? 0 : 72),
                child: Text(
                  data.kind,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff8a837c),
                  ),
                ),
              ),
              if (large && data.badge != null) ...[
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: _badge()),
              ],
              if (data.metric) ...[
                const SizedBox(height: 10),
                Text(
                  '${data.count ?? '—'}',
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.6,
                    color: Color(0xff151423),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.copy,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff5c574f),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.textScalerOf(context).scale(17) * 3.75,
                  ),
                  child: Text(
                    data.copy,
                    maxLines: large ? null : 3,
                    overflow: large ? null : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.34,
                      color: Color(0xff151423),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Avance',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff8a837c),
                        ),
                      ),
                    ),
                    Text(
                      data.progress == null ? '—' : '${data.progress}%',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff8a837c),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Semantics(
                  label: data.progress == null
                      ? 'Avance no disponible'
                      : 'Formulario completado al ${data.progress} por ciento',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: data.progress == null
                          ? 0
                          : data.progress!.clamp(0, 100) / 100,
                      minHeight: 5,
                      backgroundColor: const Color(0x14151423),
                      color: const Color(0xff151423),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!large && data.badge != null)
            Positioned(top: -2, right: -2, child: _badge()),
        ],
      ),
    ),
  );

  Widget _badge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0x8cffffff),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: data.urgent ? const Color(0xfff5b5ad) : const Color(0xffd9d3ca),
      ),
    ),
    child: Text(
      data.badge!,
      style: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: data.urgent ? const Color(0xffc41c2e) : const Color(0xff5c574f),
      ),
    ),
  );
}

class _HomeQuickAccess extends StatelessWidget {
  const _HomeQuickAccess({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });
  final String selected;
  final Map<String, int?> counts;
  final ValueChanged<String> onSelected;
  static const actions = [
    ('adoption', 'Adopción', 'rtab-cases.svg'),
    ('support', 'Apoyo', 'rtab-cases.svg'),
    ('messages', 'Mensajes', 'icon-messages.svg'),
    ('payments', 'Pagos', 'icon-billing.svg'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1415110d),
          blurRadius: 28,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Mis pendientes', style: _homeHeading),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context);
            var columns = 4;
            final longestLabel = actions
                .map((action) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: action.$2,
                      style: _homeQuickLabelStyle,
                    ),
                    textScaler: scale,
                    textDirection: Directionality.of(context),
                  )..layout();
                  final width = painter.width;
                  painter.dispose();
                  return width;
                })
                .reduce(math.max);
            while (columns > 1 &&
                longestLabel + 4 >
                    (constraints.maxWidth - (columns - 1) * 8) / columns) {
              columns = columns == 4 ? 2 : 1;
            }
            if (columns == 4) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < actions.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(child: _action(actions[index])),
                  ],
                ],
              );
            }
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 16,
              children: [
                for (final action in actions)
                  SizedBox(width: width, child: _action(action)),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _action((String, String, String) action) {
    final (id, label, asset) = action;
    final count = counts[id];
    return ReferenceFocusOutline(
      radius: 12,
      child: Semantics(
        label:
            '$label${count == null
                ? ', pendientes no disponibles'
                : count > 0
                ? ', $count pendientes'
                : ''}',
        selected: selected == id,
        button: true,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('home-quick-$id'),
          onTap: () => onSelected(id),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected == id
                              ? const Color(0xfff3eeff)
                              : const Color(0xfff0eeea),
                          shape: BoxShape.circle,
                          border: selected == id
                              ? Border.all(color: purple)
                              : null,
                        ),
                        child: SvgPicture.asset(
                          'assets/profile/$asset',
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            selected == id ? purple : ink,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      if (count != null && count > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: purple,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  style: _homeQuickLabelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _homeQuickLabelStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w500,
  color: Color(0xff5c5650),
);

const _homeHeading = TextStyle(
  fontSize: 16,
  height: 1.4,
  fontWeight: FontWeight.w600,
  color: Color(0xff151423),
);

class _HomeActivityPanel extends StatelessWidget {
  const _HomeActivityPanel({
    required this.title,
    required this.children,
    this.onSeeAll,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
    decoration: BoxDecoration(
      color: const Color(0xfff0eeea),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: _homeHeading)),
            if (onSeeAll != null) ...[
              const SizedBox(width: 12),
              ReferenceFocusOutline(
                radius: 6,
                child: InkWell(
                  onTap: onSeeAll,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Ver todo',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff5c574f),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class _HomeSummaryRow extends StatelessWidget {
  const _HomeSummaryRow({
    required this.program,
    required this.status,
    required this.count,
    required this.last,
  });
  final String program, status;
  final int? count;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, color) = switch (status) {
      'active' => (
        'Casos activos',
        program == 'adoption' ? 'Buscando hogar' : 'Recibiendo apoyo',
        const Color(0xfff7cb2d),
      ),
      'review' => (
        'Casos en revisión',
        'Pendiente de aprobación',
        const Color(0xff5c2fd4),
      ),
      'draft' => (
        'Casos en borrador',
        'Publicación incompleta',
        const Color(0xff5c574f),
      ),
      _ => (
        'Casos por corregir',
        'Requieren corrección',
        const Color(0xffc41c2e),
      ),
    };
    return ReferenceFocusOutline(
      radius: 12,
      child: InkWell(
        key: ValueKey('home-summary-$program-$status'),
        onTap: () => context.push('/my-cases?program=$program&status=$status'),
        borderRadius: BorderRadius.circular(12),
        child: _HomeActivityRow(
          last: last,
          icon: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/navigation/rtab-cases.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
          title: title,
          subtitle: subtitle,
          trailing: '${count ?? '—'}',
        ),
      ),
    );
  }
}

class _HomePaymentRow extends StatelessWidget {
  const _HomePaymentRow({required this.item, required this.last});
  final Json item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cents = _homeCount(item['net_cents']);
    final photo = item['photo'] as String?;
    final expense = item['expense_title'] as String? ?? '';
    final guardian = item['source'] == 'guardian';
    final occurred = DateTime.tryParse('${item['occurred_at'] ?? ''}');
    final state = switch (item['transfer_status']) {
      'transferred' || 'paid' || 'succeeded' => 'Transferido al saldo',
      'failed' => 'Transferencia pendiente',
      'attention' => 'Transferencia por revisar',
      'reversed' => 'Transferencia revertida',
      'pending' || 'processing' => 'Transferencia en proceso',
      _ => 'Asignado al gasto',
    };
    return Semantics(
      child: _HomeActivityRow(
        last: last,
        icon: SizedBox(
          width: 44,
          height: 44,
          child: photo == null || photo.isEmpty
              ? Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pets_outlined,
                    size: 20,
                    color: purple,
                  ),
                )
              : RescuePublicPhoto(photo, height: 44, radius: 22, compact: true),
        ),
        title:
            '${guardian ? 'Guardián' : 'Apoyo asignado'}${expense.isEmpty ? '' : ' — $expense'}',
        subtitle:
            'Para ${item['pet_name'] ?? 'tu caso'}${occurred == null ? '' : ' · ${_homeRelativeDate(occurred)}'} · $state',
        trailing: cents == null
            ? '—'
            : '+\$${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}',
      ),
    );
  }
}

String _homeRelativeDate(DateTime date) {
  final elapsed = DateTime.now().difference(date);
  if (elapsed.isNegative || elapsed.inHours < 24) return 'Hoy';
  if (elapsed.inDays == 1) return 'Ayer';
  if (elapsed.inDays < 7) return 'Hace ${elapsed.inDays} días';
  return '${date.day}/${date.month}/${date.year}';
}

class _HomeActivityRow extends StatelessWidget {
  const _HomeActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.last,
  });
  final Widget icon;
  final String title, subtitle, trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(15) > 22.5;
    final amount = Text(
      trailing,
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: Color(0xff151423),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xffe7e3dc))),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff151423),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xff5c574f),
                  ),
                ),
                if (large) ...[const SizedBox(height: 6), amount],
              ],
            ),
          ),
          if (!large) ...[const SizedBox(width: 12), amount],
        ],
      ),
    );
  }
}

class _AcknowledgementRetry extends StatelessWidget {
  const _AcknowledgementRetry({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text(
        'No se pudo actualizar el contador de pagos.',
        style: TextStyle(fontSize: 12, color: Color(0xff5c574f)),
      ),
      TextButton(
        onPressed: onPressed,
        child: const Text('Reintentar contador'),
      ),
    ],
  );
}

class _HomePhotoTips extends StatefulWidget {
  const _HomePhotoTips();
  @override
  State<_HomePhotoTips> createState() => _HomePhotoTipsState();
}

class _HomePhotoTipsState extends State<_HomePhotoTips> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => ReferenceFocusOutline(
    radius: 24,
    child: AnimatedScale(
      scale: pressed ? .99 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.ease,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/rescuer/photo-tips'),
          onHighlightChanged: (value) => setState(() => pressed = value),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xff15110d),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4715110d),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tips para mejores fotos',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Te damos recomendaciones para que tus casos tengan más visualizaciones',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xb8ffffff),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xffefe8ff),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SvgPicture.asset(
                    'assets/profile/icon-star.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
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

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffe3e4ed)),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x1a7c3aed),
            shape: BoxShape.circle,
          ),
          child: SvgPicture.asset(
            'assets/profile/empty-pending-heart.svg',
            width: 32,
            height: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No tienes pendientes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -.36,
            color: Color(0xff151423),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cuando publiques casos, recibas mensajes o tengas evidencias por subir, aparecerán aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: Color(0xff5c574f),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.go('/publish'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Publicar caso'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        ),
      ],
    ),
  );
}

/// Received allocations are separate from a donor's subscription billing.
class RescuerReceivedPaymentsScreen extends ConsumerStatefulWidget {
  const RescuerReceivedPaymentsScreen({super.key});

  @override
  ConsumerState<RescuerReceivedPaymentsScreen> createState() =>
      _RescuerReceivedPaymentsScreenState();
}

class _RescuerReceivedPaymentsScreenState
    extends ConsumerState<RescuerReceivedPaymentsScreen>
    with WidgetsBindingObserver {
  final items = <Json>[];
  final acknowledged = <String>{};
  late final String? actor;
  late final IdentityController identity;
  late final RescueRepository repository;
  int page = 1, total = 0, generation = 0;
  bool loading = true, loadingMore = false, exhausted = false;
  bool acknowledging = false;
  Object? error;
  String? presentedCursor, queuedCursor, failedCursor;

  bool get sameActor =>
      ref.read(identityControllerProvider).identity?.id == actor;

  @override
  void initState() {
    super.initState();
    identity = ref.read(identityControllerProvider);
    actor = identity.identity?.id;
    repository = ref.read(rescueRepositoryProvider);
    identity.addListener(_identityChanged);
    WidgetsBinding.instance.addObserver(this);
    _load(reset: true);
  }

  void _identityChanged() {
    if (!mounted || sameActor) return;
    generation++;
    setState(() {
      items.clear();
      error = null;
      loading = loadingMore = false;
      presentedCursor = null;
      failedCursor = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && sameActor) _load(reset: true);
  }

  @override
  void dispose() {
    generation++;
    identity.removeListener(_identityChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (!sameActor || (!reset && loadingMore)) return;
    final revision = ++generation;
    final nextPage = reset ? 1 : page + 1;
    setState(() {
      loading = reset;
      loadingMore = !reset;
      error = null;
      if (reset) {
        items.clear();
        presentedCursor = null;
        failedCursor = null;
      }
    });
    try {
      final result = await repository.receivedActivity(nextPage);
      if (!mounted || revision != generation || !sameActor) return;
      setState(() {
        final existing = items.map((item) => item['id']).toSet();
        for (final item in result.items) {
          if (existing.add(item['id'])) items.add(item);
        }
        page = nextPage;
        total = result.total;
        exhausted = result.items.isEmpty;
        presentedCursor = result.cursor;
        loading = loadingMore = false;
      });
      _acknowledgePresented();
    } catch (cause) {
      if (!mounted || revision != generation || !sameActor) return;
      setState(() {
        // A permission failure must not leave a previous private response.
        items.clear();
        total = 0;
        error = cause;
        presentedCursor = null;
        loading = loadingMore = false;
      });
    }
  }

  void _acknowledgePresented() {
    final cursor = presentedCursor;
    if (items.isEmpty ||
        cursor == null ||
        cursor.isEmpty ||
        acknowledging ||
        cursor == queuedCursor ||
        cursor == failedCursor ||
        acknowledged.contains(cursor)) {
      return;
    }
    queuedCursor = cursor;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !sameActor || loading || error != null) {
        queuedCursor = null;
        return;
      }
      setState(() => acknowledging = true);
      try {
        await repository.acknowledgePayments(cursor);
        if (!mounted || !sameActor) return;
        acknowledged.add(cursor);
        failedCursor = null;
      } catch (_) {
        if (mounted && sameActor) failedCursor = cursor;
      } finally {
        if (mounted && sameActor) {
          setState(() {
            acknowledging = false;
            queuedCursor = null;
          });
          _acknowledgePresented();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Pagos recibidos'),
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/rescuer');
          }
        },
      ),
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (loading)
                  const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando pagos recibidos',
                    ),
                  )
                else if (error != null) ...[
                  Notice(communityError(error!), isError: true),
                  TextButton(
                    onPressed: () => _load(reset: true),
                    child: const Text('Volver a intentar'),
                  ),
                ] else if (!sameActor)
                  const Notice('Tu sesión cambió. Vuelve a Inicio.')
                else ...[
                  _HomeActivityPanel(
                    title: 'Actividad reciente',
                    children: [
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('Aún no tienes apoyos recibidos.'),
                        ),
                      for (var index = 0; index < items.length; index++)
                        _HomePaymentRow(
                          item: items[index],
                          last: index == items.length - 1,
                        ),
                    ],
                  ),
                  if (failedCursor != null) ...[
                    const SizedBox(height: 12),
                    _AcknowledgementRetry(
                      onPressed: () {
                        setState(() => failedCursor = null);
                        _acknowledgePresented();
                      },
                    ),
                  ],
                  if (loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Cargando más pagos',
                        ),
                      ),
                    )
                  else if (!exhausted && items.length < total)
                    TextButton(
                      onPressed: () => _load(reset: false),
                      child: const Text('Cargar más pagos'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RescuerPhotoTipsScreen extends StatelessWidget {
  const RescuerPhotoTipsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Tips para mejores fotos'),
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/rescuer');
          }
        },
      ),
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const Text(
                'Ayuda a que conozcan mejor a tu mascota.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              for (final (title, copy) in const [
                (
                  'Usa luz natural',
                  'Busca un lugar iluminado, de preferencia cerca de una ventana o en sombra al aire libre.',
                ),
                (
                  'Evita el flash y los filtros',
                  'Conserva los colores y rasgos reales de la mascota. Evita una luz intensa directamente en sus ojos.',
                ),
                (
                  'Ponte a su altura',
                  'Acércate al nivel de la mascota y permite que se sienta tranquila. No la fuerces a posar.',
                ),
                (
                  'Cuida el enfoque y el fondo',
                  'Enfoca sus ojos, limpia la lente y elige un fondo claro y sencillo. Incluye una foto de cuerpo completo.',
                ),
              ]) ...[
                Text(title, style: _homeHeading),
                const SizedBox(height: 6),
                Text(
                  copy,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xff5c574f),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class RescuerPendingCard extends StatelessWidget {
  const RescuerPendingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.onPressed,
    this.contextText,
    this.iconAsset,
    this.badge,
    this.message = false,
    this.correction = false,
  });
  final String title, subtitle, cta;
  final String? contextText;
  final String? iconAsset;
  final int? badge;
  final IconData icon;
  final VoidCallback onPressed;
  final bool message, correction;
  @override
  Widget build(BuildContext context) {
    final tone = correction
        ? const Color(0xffb51224)
        : message
        ? const Color(0xff6b5000)
        : purple;
    return Material(
      color: message
          ? Colors.white
          : correction
          ? const Color(0xfffef4f4)
          : const Color(0xfff8f5fe),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: message ? const Color(0xffe3e4ed) : tone.withValues(alpha: .2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Align(
                    alignment: Alignment.topCenter,
                    widthFactor: 1,
                    child: iconAsset == null
                        ? Icon(icon, size: 20, color: tone)
                        : ExcludeSemantics(
                            child: SvgPicture.asset(
                              'assets/profile/$iconAsset',
                              width: 20,
                              height: 20,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff151423),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Color(0xff4f4e5c),
                        ),
                      ),
                      if (contextText != null) ...[
                        Text(
                          contextText!,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Color(0xff4f4e5c),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        cta,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: tone,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (badge != null)
                  Center(
                    widthFactor: 1,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 26),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfff7cb2d),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff0d0d0d),
                        ),
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xff4f4e5c),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RescuerPendingEmpty extends StatelessWidget {
  const RescuerPendingEmpty({super.key, this.cases = false});
  final bool cases;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffe3e4ed)),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x1a7c3aed),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            cases
                ? 'assets/navigation/rtab-cases.svg'
                : 'assets/profile/empty-pending-heart.svg',
            width: 32,
            height: 32,
            colorFilter: cases
                ? const ColorFilter.mode(Color(0xff7c3aed), BlendMode.srcIn)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          cases ? 'No tienes casos todavía' : 'No tienes acciones pendientes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -.36,
            color: Color(0xff151423),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cases
              ? 'Cuando publiques una mascota para adopción o donaciones, tus casos aparecerán aquí para que puedas darles seguimiento.'
              : 'Los borradores, correcciones, mensajes y evidencias aparecerán aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: Color(0xff4f4e5c),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.go('/publish'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Publicar caso'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ],
    ),
  );
}

String _verificationTitle(String status) => switch (status) {
  'submitted' => 'Verificación en proceso',
  'changes_requested' || 'rejected' => 'Corrige tu información',
  'draft' => 'Continúa tu verificación',
  _ => 'Verifícate para recibir aportaciones',
};

class RescuerFundingSummary extends StatelessWidget {
  const RescuerFundingSummary({
    super.key,
    required this.financial,
    required this.activeCases,
  });
  final Json financial;
  final int activeCases;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(18) > 27;
    final assigned = pesos(financial['assigned_cents'] as int? ?? 0);
    Widget statistic(String label, String field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xfff0e7ff),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          pesos(financial[field] as int? ?? 0),
          style: const TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const CssLinearGradient(
          degrees: 146,
          colors: [Color(0xff7c3aed), Color(0xff6d28d9)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x477841f2),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/profile/icon-wallet.svg',
                    width: 20,
                    height: 20,
                    excludeFromSemantics: true,
                  ),
                  Text(
                    'Resumen comprobado',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x38ffffff),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$activeCases ${activeCases == 1 ? 'caso activo' : 'casos activos'}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (large) ...[
            Text(
              assigned.replaceAll(' MXN', ''),
              style: const TextStyle(
                fontSize: 32,
                height: 1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Text(
              'MXN',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ] else
            Text(
              assigned.replaceAll(' MXN', ''),
              semanticsLabel: assigned,
              style: const TextStyle(
                fontSize: 48,
                height: 1,
                letterSpacing: .35,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Asignado a gastos aprobados',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xfff0e7ff),
            ),
          ),
          const SizedBox(height: 16),
          if (large) ...[
            statistic('Transferido', 'transferred_cents'),
            const SizedBox(height: 12),
            statistic('En revisión', 'in_review_cents'),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: statistic('Transferido', 'transferred_cents')),
                const SizedBox(width: 12),
                Expanded(child: statistic('En revisión', 'in_review_cents')),
              ],
            ),
        ],
      ),
    );
  }
}
