import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/css_linear_gradient.dart';
import '../../core/adoption_view_day.dart';
import '../../core/donor_notification_button.dart';
import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import 'rescue_public_photo.dart';
import 'rescue_repository.dart';
import 'rescuer_funnel.dart';

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
                    const SizedBox(height: 4),
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

/// Home summaries preserve the real records and never simulate funnel data.
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
  String pendingProgram = 'support', activityView = 'none';
  String period = 'month';
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
    setState(() => activityView = selection);
    _presentPayments();
  }

  bool get empty =>
      _homeCountsEmpty(counts('adoption')) &&
      _homeCountsEmpty(counts('support')) &&
      !counts('adoption').values.whereType<num>().any((value) => value > 0) &&
      !counts('support').values.whereType<num>().any((value) => value > 0) &&
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
        _HomeVerificationStatus(status: verification),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: _programTab('adoption', 'En adopción'),
                      ),
                      const SizedBox(width: 20),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: _programTab('support', 'Recibiendo apoyo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('home-period-filter'),
              tooltip: 'Filtrar pendientes',
              color: period == 'month' ? ink : purple,
              onPressed: _filterPeriod,
              icon: const Icon(Icons.tune_rounded, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LiveSection<RescuerFunnelMetrics>(
          key: ValueKey('home-funnel-${widget.actor}-$period'),
          tables: const [
            'dopmi_rescue_records',
            'dopmi_adoptions',
            'dopmi_favorites',
            'dopmi_messages',
            'dopmi_donations',
          ],
          load: () async {
            final result = await ref
                .read(rescueRepositoryProvider)
                .funnel(period);
            if (ref.read(identityControllerProvider).identity?.id !=
                widget.actor) {
              throw StateError('identity_changed');
            }
            return result;
          },
          builder: (metrics, _) {
            final hasResults = [
              metrics.views,
              metrics.favorites,
              metrics.messages,
              metrics.adoptions,
              metrics.donors,
              metrics.activeCases,
              metrics.completedCases,
              metrics.raisedCents,
            ].any((value) => value > 0);
            return empty && !hasResults
                ? const _HomeEmpty()
                : _HomeFunnelGrid(
                    metrics: metrics,
                    adoption: pendingProgram == 'adoption',
                  );
          },
        ),
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
              'messages' => 'Mensajes recientes',
              _ => 'Actividad reciente',
            },
            onSeeAll: () => context.go('/profile'),
            children: activityView == 'messages'
                ? [_HomeRecentMessages(actor: widget.actor)]
                : activityView == 'payments'
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

  Future<void> _filterPeriod() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _HomePeriodDialog(
        period: period,
        onChanged: (value) {
          if (mounted) setState(() => period = value);
        },
      ),
    );
    if (mounted && selected != null && selected != period) {
      setState(() => period = selected);
    }
  }
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

class _HomeVerificationStatus extends StatelessWidget {
  const _HomeVerificationStatus({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'approved';
    final label = approved ? 'Rescatista verificado' : 'Completar mi perfil';
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (approved)
          SvgPicture.asset(
            'assets/profile/icon-verified-purple.svg',
            width: 16,
            height: 16,
            excludeFromSemantics: true,
          )
        else
          const Icon(Icons.shield_outlined, color: purple, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: purple,
            ),
          ),
        ),
      ],
    );
    return approved
        ? Semantics(liveRegion: true, child: content)
        : Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('home-complete-profile'),
              onPressed: () => context.go('/profile'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 32),
              ),
              child: content,
            ),
          );
  }
}

const _homeDialogHeading = TextStyle(
  fontFamily: 'Inter',
  fontSize: 22,
  height: 1.3,
  fontWeight: FontWeight.w700,
  color: Color(0xff151423),
);

class _HomePeriodDialog extends StatefulWidget {
  const _HomePeriodDialog({required this.period, required this.onChanged});
  final String period;
  final ValueChanged<String> onChanged;
  @override
  State<_HomePeriodDialog> createState() => _HomePeriodDialogState();
}

class _HomePeriodDialogState extends State<_HomePeriodDialog> {
  late String selected = widget.period;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filtrar',
                  textAlign: TextAlign.center,
                  style: _homeDialogHeading,
                ),
                const SizedBox(height: 8),
                const Text('Período', style: _homeHeading),
                const SizedBox(height: 8),
                for (final option in const [
                  ('yesterday', 'Ayer'),
                  ('week', 'Esta semana'),
                  ('month', 'Este mes'),
                ])
                  Semantics(
                    checked: selected == option.$1,
                    inMutuallyExclusiveGroup: true,
                    child: InkWell(
                      key: ValueKey('home-period-${option.$1}'),
                      onTap: () {
                        setState(() => selected = option.$1);
                        widget.onChanged(option.$1);
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: selected == option.$1
                                    ? purple
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: selected == option.$1
                                      ? purple
                                      : const Color(0xffe3e4ed),
                                ),
                              ),
                              child: selected == option.$1
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                option.$2,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Listo'),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomeFunnelGrid extends StatelessWidget {
  const _HomeFunnelGrid({required this.metrics, required this.adoption});
  final RescuerFunnelMetrics metrics;
  final bool adoption;

  @override
  Widget build(BuildContext context) {
    final trackingDay = DateTime.parse(
      adoptionViewDay(metrics.viewTrackingStartedAt),
    );
    final entries = adoption
        ? [
            (
              'views',
              '${metrics.views}',
              'Vistas',
              'Personas vieron tus mascotas',
            ),
            (
              'favorites',
              '${metrics.favorites}',
              'Favoritos',
              'Guardaron tus mascotas',
            ),
            (
              'messages',
              '${metrics.messages}',
              'Mensajes',
              'Escribieron por adopción',
            ),
            (
              'adoptions',
              '${metrics.adoptions}',
              'Adopciones',
              'Mascotas adoptadas',
            ),
          ]
        : [
            (
              'donors',
              '${metrics.donors}',
              'Donantes',
              'Personas donaron a tus mascotas',
            ),
            (
              'active',
              '${metrics.activeCases}',
              'Activos',
              'Casos recibiendo apoyo',
            ),
            (
              'completed',
              '${metrics.completedCases}',
              'Completados',
              'Casos que lograron la meta',
            ),
            (
              'raised',
              pesos(metrics.raisedCents).replaceAll(' MXN', ''),
              'Recaudado',
              'Total en tus casos de apoyo',
            ),
          ];
    const surfaces = [
      Color(0xfff5f0ff),
      Color(0xfffff4eb),
      Color(0xffeef5ff),
      Color(0xffecfdf3),
    ];
    const tones = [
      Color(0xff6d28d9),
      Color(0xffea580c),
      Color(0xff2563eb),
      Color(0xff16a34a),
    ];
    return Column(
      key: ValueKey('home-funnel-${adoption ? 'adoption' : 'support'}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _HomeFunnelCard(
                      entry: entries[row * 2 + column],
                      surface: surfaces[row * 2 + column],
                      tone: tones[row * 2 + column],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          adoption
              ? 'Favoritos vigentes del período. Vistas desde ${trackingDay.day}/${trackingDay.month}/${trackingDay.year}.'
              : 'Activos y completados al momento. Recaudado es apoyo neto asignado.',
          style: const TextStyle(fontSize: 10, color: Color(0xff5c5650)),
        ),
      ],
    );
  }
}

class _HomeFunnelCard extends StatelessWidget {
  const _HomeFunnelCard({
    required this.entry,
    required this.surface,
    required this.tone,
  });
  final (String, String, String, String) entry;
  final Color surface, tone;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${entry.$3}: ${entry.$2}. ${entry.$4}',
    excludeSemantics: true,
    child: Container(
      key: ValueKey('home-metric-${entry.$1}'),
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0d15110d),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.$2,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.66,
                    color: Color(0xff151423),
                  ),
                ),
              ),
              if (MediaQuery.textScalerOf(context).scale(22) <= 28)
                ExcludeSemantics(
                  child: CustomPaint(
                    size: const Size(48, 32),
                    painter: _FunnelDecoration(tone),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(22) <= 28 ? 9 : 4,
          ),
          Text(
            entry.$3,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Color(0xff5c5650),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.$4,
            maxLines: MediaQuery.textScalerOf(context).scale(22) <= 28
                ? 1
                : null,
            overflow: MediaQuery.textScalerOf(context).scale(22) <= 28
                ? TextOverflow.ellipsis
                : TextOverflow.visible,
            style: const TextStyle(
              fontSize: 10,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: Color(0xff554e48),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A fixed brand ornament, with no data or claim of a measured trend.
class _FunnelDecoration extends CustomPainter {
  const _FunnelDecoration(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()
      ..moveTo(0, 18)
      ..quadraticBezierTo(9, 10, 18, 14)
      ..quadraticBezierTo(27, 18, 36, 10);
    final area = Path.from(line)
      ..lineTo(36, 26)
      ..lineTo(0, 26)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: .18));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FunnelDecoration oldDelegate) =>
      oldDelegate.color != color;
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
    ('adoption', 'Adopción', 'rtab-home.svg'),
    ('support', 'Apoyo', 'tab-donate.svg'),
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

class _HomeRecentMessages extends ConsumerWidget {
  const _HomeRecentMessages({required this.actor});
  final String? actor;
  @override
  Widget build(BuildContext context, WidgetRef ref) => LiveSection<List<Json>>(
    key: ValueKey('home-messages-$actor'),
    tables: const ['dopmi_messages', 'dopmi_conversations'],
    load: () async {
      final result = await ref
          .read(communityRepositoryProvider)
          .rescuerThreads(1);
      if (ref.read(identityControllerProvider).identity?.id != actor) {
        throw StateError('identity_changed');
      }
      final threads = result.items
          .where((item) => item['status'] != 'closed')
          .toList();
      threads.sort((a, b) {
        final aUnread = (_homeCount(a['unread_count']) ?? 0) > 0;
        final bUnread = (_homeCount(b['unread_count']) ?? 0) > 0;
        if (aUnread != bUnread) return aUnread ? -1 : 1;
        final recent = '${b['updated_at'] ?? ''}'.compareTo(
          '${a['updated_at'] ?? ''}',
        );
        return recent != 0 ? recent : '${a['id']}'.compareTo('${b['id']}');
      });
      return threads;
    },
    builder: (threads, _) => Column(
      children: [
        if (threads.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Aún no tienes mensajes recientes.'),
          ),
        for (var index = 0; index < threads.length; index++)
          _HomeMessageRow(
            item: threads[index],
            last: index == threads.length - 1,
          ),
      ],
    ),
  );
}

class _HomeMessageRow extends StatelessWidget {
  const _HomeMessageRow({required this.item, required this.last});
  final Json item;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final threadId = item['id'] as String?;
    final unread = _homeCount(item['unread_count']) ?? 0;
    final occurred = DateTime.tryParse('${item['updated_at'] ?? ''}');
    final photo = item['photo'] as String? ?? '';
    return ReferenceFocusOutline(
      radius: 12,
      child: InkWell(
        key: ValueKey('home-message-$threadId'),
        onTap: threadId == null || threadId.isEmpty
            ? null
            : () => context.push('/messages/${Uri.encodeComponent(threadId)}'),
        borderRadius: BorderRadius.circular(12),
        child: _HomeActivityRow(
          last: last,
          icon: SizedBox(
            width: 44,
            height: 44,
            child: photo.isNotEmpty
                ? AdoptionPhoto(photo, height: 44, radius: 99)
                : Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: purple,
                      size: 20,
                    ),
                  ),
          ),
          title:
              '${item['pet_name'] ?? 'Mascota'} · ${item['participant_name'] ?? 'Adoptante'}',
          subtitle: item['last_message'] as String? ?? 'Inicia la conversación',
          trailing: unread > 0
              ? '$unread'
              : occurred == null
              ? ''
              : _homeRelativeDate(occurred),
        ),
      ),
    );
  }
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
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const _HomePhotoTipsDialog(),
          ),
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

const _homePhotoTips = [
  (
    'Luz natural',
    'Fotografía cerca de una ventana o al aire libre. Evita contraluz y flash directo que tapen los ojos.',
  ),
  (
    'Rostro y cuerpo visibles',
    'Incluye al menos una foto donde se vea bien la cara y otra con el cuerpo completo.',
  ),
  (
    'Fondo simple',
    'Busca un lugar ordenado. Un fondo limpio ayuda a que la mascota sea el foco.',
  ),
  (
    'Varios ángulos',
    'Sube 2 o 3 fotos distintas: de frente, de perfil y una mostrando su personalidad.',
  ),
  (
    'Sin filtros fuertes',
    'Usa colores reales y buena nitidez. Así los adoptantes saben qué esperar al conocerla.',
  ),
];

class _HomePhotoTipsDialog extends StatelessWidget {
  const _HomePhotoTipsDialog();
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.all(20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tips para mejores fotos',
                  style: _homeDialogHeading,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sigue estas recomendaciones para que tus casos destaquen en Adoptar y reciban más vistas.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xff554e48),
                  ),
                ),
                const SizedBox(height: 32),
                for (final tip in _homePhotoTips) ...[
                  Container(
                    padding: const EdgeInsets.only(left: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xffc4b5fd), width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.$1,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xff554e48),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
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
          '¿Empezamos?',
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
          'Aún no tienes casos de adopción o de apoyo publicados.',
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
