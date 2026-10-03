import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/content_links.dart';

import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/ui.dart';
import '../../core/measurement.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../adoption/publication_frame.dart';
import '../adoption/photo_recovery.dart';
import '../community/content_actions.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import '../payments/payment_repository.dart';
import '../payments/contribution_layout.dart';
import 'rescue_fields.dart';
import 'expense_field.dart';
import 'expense_evidence_card.dart';
import 'expense_frame.dart';
import 'expense_review.dart';
import 'case_information.dart';
import 'case_review.dart';
import 'case_needs.dart';
import 'case_need_row.dart';
import 'case_update_screens.dart';
import 'rescue_repository.dart';
import 'support_home.dart';
import 'case_detail_layout.dart';
import 'public_expense_card.dart';
import 'rescue_public_photo.dart';
import 'owned_case_detail.dart';
import 'owned_expense_card.dart';
import 'owned_case_history.dart';
import 'verification_intro.dart';
import 'verification_form.dart';
import 'verification_state.dart';

class RescueHomeScreen extends ConsumerWidget {
  const RescueHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => CommunityFrame(
    index: 2,
    back: false,
    showAppBar: false,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: RescuerGreeting()),
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      const SizedBox(height: 24),
      LiveSection<Json>(
        tables: const [
          'dopmi_rescue_records',
          'dopmi_donations',
          'dopmi_notifications',
        ],
        load: () => ref.read(rescueRepositoryProvider).dashboard(),
        builder: (data, refresh) => _RescuerDashboard(data, refresh),
      ),
    ],
  );
}

class RescuerGreeting extends ConsumerWidget {
  const RescuerGreeting({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget greeting(String? name) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null || name.trim().isEmpty
              ? 'Hola'
              : 'Hola, ${name.trim().split(RegExp(r"\s+")).first}',
          style: const TextStyle(
            fontSize: 24,
            height: 1.25,
            letterSpacing: .07,
            fontWeight: FontWeight.w700,
            color: Color(0xff151423),
          ),
        ),
        const Text(
          'Tu panel de rescate',
          style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xff4f4e5c)),
        ),
      ],
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

class _RescuerDashboard extends StatelessWidget {
  const _RescuerDashboard(this.data, this.refresh);
  final Json data;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    final verification =
        data['verification_status'] as String? ?? 'not_started';
    final counts = Json.from(data['case_counts'] as Map? ?? {});
    final financial = Json.from(data['financial'] as Map? ?? {});
    final pending = (data['pending'] as List? ?? [])
        .map((item) => Json.from(item))
        .toList();
    final activity = (data['recent_activity'] as List? ?? [])
        .map((item) => Json.from(item))
        .toList();
    final unread = data['unread_messages'] as int? ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (verification != 'approved')
          RescuerVerificationCard(
            status: verification,
            onPressed: () async {
              await context.push('/rescue/new?kind=verification');
              refresh();
            },
          ),
        if (verification == 'approved')
          RescuerFundingSummary(
            financial: financial,
            activeCases: counts['active'] as int? ?? 0,
          ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (pending.isNotEmpty || unread > 0)
              const Icon(
                Icons.error_outline,
                size: 20,
                color: Color(0xff151423),
              ),
            const Text(
              'Acciones pendientes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xff151423),
              ),
            ),
            if (pending.isNotEmpty || unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xfff0eff8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${pending.length + (unread > 0 ? 1 : 0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff2c2b41),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (unread > 0) ...[
          RescuerPendingCard(
            title: 'Responde mensajes pendientes',
            subtitle: '$unread sin leer',
            cta: 'Ir a mensajes',
            icon: Icons.chat_bubble_outline,
            message: true,
            onPressed: () => context.go('/messages'),
          ),
          const SizedBox(height: 8),
        ],
        for (final item in pending) ...[
          RescuerPendingCard(
            title: item['kind'] == 'expense' && item['status'] == 'draft'
                ? 'Termina una evidencia pendiente'
                : item['title'] as String,
            subtitle: item['kind'] == 'expense' && item['status'] == 'draft'
                ? 'Ya empezaste este formulario. Complétalo para enviarlo.'
                : '${rescueStatuses[item['status']] ?? item['status']}${(item['feedback'] as String? ?? '').isEmpty ? '' : ' · ${item['feedback']}'}',
            contextText: item['kind'] == 'expense' && item['status'] == 'draft'
                ? 'Necesidad: ${item['title']} · Progreso: incompleto'
                : null,
            cta: item['status'] == 'draft'
                ? item['kind'] == 'expense'
                      ? 'Continuar evidencia'
                      : 'Continuar borrador'
                : 'Ver expediente',
            icon: item['status'] == 'draft'
                ? Icons.edit_note
                : Icons.error_outline,
            iconAsset: item['kind'] == 'expense' && item['status'] == 'draft'
                ? 'icon-camera-red.svg'
                : null,
            correction:
                (item['kind'] == 'expense' && item['status'] == 'draft') ||
                ['changes_requested', 'rejected'].contains(item['status']),
            onPressed: () => context.push('/rescue/${item['id']}'),
          ),
          const SizedBox(height: 8),
        ],
        if (pending.isEmpty && unread == 0) const RescuerPendingEmpty(),
        if (activity.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Actividad reciente',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xff151423),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in activity)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x1a2dc08e),
                    ),
                    child: const Icon(
                      Icons.south_west,
                      size: 20,
                      color: Color(0xff0b7a5d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pesos(item['allocated_cents'] as int)} asignados',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff151423),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['expense_title'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xff4f4e5c),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
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
    this.message = false,
    this.correction = false,
  });
  final String title, subtitle, cta;
  final String? contextText;
  final String? iconAsset;
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
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
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xff4f4e5c),
              ),
            ],
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
              ? 'Tus borradores y casos aparecerán aquí para que puedas darles seguimiento.'
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
              const Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: Colors.white,
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
                  '$activeCases casos activos',
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

class RescueList extends ConsumerStatefulWidget {
  const RescueList({
    super.key,
    required this.kind,
    this.parent,
    this.showCaseHeader = false,
    this.ownedExpenseCards = false,
  });
  final bool showCaseHeader, ownedExpenseCards;
  final String kind;
  final String? parent;
  @override
  ConsumerState<RescueList> createState() => _RescueListState();
}

class _RescueListState extends ConsumerState<RescueList> {
  int page = 1;
  @override
  Widget build(BuildContext context) => LiveSection<DataPage<RescueRecord>>(
    key: ValueKey('${widget.kind}:${widget.parent}:$page'),
    tables: const ['dopmi_rescue_records'],
    statusFrame: widget.showCaseHeader
        ? (content) => Column(
            children: [
              const OwnedCasesHeading(),
              const SizedBox(height: 18),
              content,
            ],
          )
        : null,
    load: () => ref
        .read(rescueRepositoryProvider)
        .mine(widget.kind, page, parent: widget.parent),
    builder: (data, refresh) => Column(
      children: [
        if (widget.showCaseHeader) ...[
          OwnedCasesHeading(total: data.total),
          const SizedBox(height: 18),
        ],
        if (data.items.isEmpty)
          widget.showCaseHeader && data.total == 0
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: RescuerPendingEmpty(cases: true),
                )
              : const Notice(
                  'Aquí aparecerán tus borradores y las respuestas del equipo.',
                ),
        for (final r in data.items)
          widget.ownedExpenseCards && r.kind == 'expense'
              ? OwnedExpenseCard(r, key: ValueKey(r.id), refresh: refresh)
              : _OwnedRescueCard(record: r, refresh: refresh),
        if (data.total > 20)
          PageControls(
            page: page,
            total: data.total,
            size: 20,
            change: (p) => setState(() => page = p),
          ),
      ],
    ),
  );
}

class _OwnedRescueCard extends ConsumerWidget {
  const _OwnedRescueCard({required this.record, required this.refresh});
  final RescueRecord record;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsAction = [
      'draft',
      'changes_requested',
      'rejected',
    ].contains(record.status);
    final action = switch (record.status) {
      'draft' => 'Continuar publicación',
      'changes_requested' || 'rejected' => 'Corregir publicación',
      'submitted' => 'Ver envío',
      'approved' => 'Administrar',
      'closed' => 'Ver caso cerrado',
      _ => 'Ver caso',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffe3e4ed)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (record.kind == 'case')
                      SizedBox(
                        width: 76,
                        height: 76,
                        child:
                            (record.publicData['photos'] as List? ?? [])
                                .whereType<String>()
                                .isNotEmpty
                            ? RescuePublicPhoto(
                                (record.publicData['photos'] as List)
                                    .whereType<String>()
                                    .first,
                                height: 76,
                                radius: 14,
                                compact: true,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xfff0eff8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.pets_outlined,
                                  color: purple,
                                  size: 28,
                                ),
                              ),
                      )
                    else
                      CircleAvatar(
                        backgroundColor: const Color(0xffeee7fc),
                        child: Icon(
                          needsAction ? Icons.edit_note : Icons.pets_outlined,
                          color: purple,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OwnedCaseHeading(record: record),
                          if (record.data['urgent'] == true) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Urgente',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xffb51224),
                              ),
                            ),
                          ],
                          if (record.kind == 'case' &&
                              (record.publicData['age'] as String? ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              record.publicData['age'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xff4f4e5c),
                              ),
                            ),
                          ],
                          if (record.kind == 'case' &&
                              record.status == 'approved' &&
                              record.targetCents > 0) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'Asignación a gastos',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Color(0xff4f4e5c),
                                  ),
                                ),
                                Text(
                                  '${((record.fundedCents / record.targetCents).clamp(0, 1) * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff151423),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: (record.fundedCents / record.targetCents)
                                  .clamp(0, 1),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(99),
                              color: purple,
                              backgroundColor: const Color(0xffece9f2),
                              semanticsLabel: 'Progreso de gastos aprobados',
                              semanticsValue:
                                  '${((record.fundedCents / record.targetCents).clamp(0, 1) * 100).round()}%',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Asignado: ${pesos(record.fundedCents)}',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Color(0xff4f4e5c),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if ((record.data['feedback'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Notice(
                    record.data['feedback'] as String,
                    isError: needsAction,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xffe3e4ed))),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (needsAction)
                  FilledButton.tonal(
                    onPressed: () async {
                      await context.push('/rescue/${record.id}');
                      refresh();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xffede9fe),
                      foregroundColor: purple,
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(action),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/rescue/${record.id}');
                      refresh();
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(action),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff151423),
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: Color(0xffe3e4ed)),
                    ),
                  ),
                if (record.kind == 'case' && record.status == 'approved')
                  Tooltip(
                    message: 'Preparar publicación para adopción',
                    child: TextButton.icon(
                      onPressed: () async {
                        final linked = await ref
                            .read(communityRepositoryProvider)
                            .ownForCase(record.id);
                        if (!context.mounted) return;
                        await context.push(
                          linked == null
                              ? '/my-adoptions/new?case=${record.id}'
                              : '/my-adoptions/${linked.id}',
                        );
                        refresh();
                      },
                      icon: const Icon(Icons.home_outlined, size: 16),
                      label: const Text('Adopción'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedCaseHeading extends StatelessWidget {
  const _OwnedCaseHeading({required this.record});
  final RescueRecord record;
  @override
  Widget build(BuildContext context) {
    final name = Text(
      record.title.isEmpty ? 'Borrador sin título' : record.title,
      style: const TextStyle(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: Color(0xff151423),
      ),
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: switch (record.status) {
          'approved' => const Color(0xffdef6ee),
          'submitted' => const Color(0xffeef5ff),
          'changes_requested' || 'rejected' => const Color(0xfff7eeee),
          _ => const Color(0xfff0eff8),
        },
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        rescueStatuses[record.status] ?? record.status,
        style: TextStyle(
          fontSize: 10,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: record.status == 'approved'
              ? const Color(0xff176c55)
              : const Color(0xff4f4e5c),
        ),
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(17) > 22 ||
        ['changes_requested', 'rejected'].contains(record.status)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [name, const SizedBox(height: 6), badge],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: name),
        const SizedBox(width: 8),
        badge,
      ],
    );
  }
}

class RescueEditorScreen extends ConsumerStatefulWidget {
  const RescueEditorScreen(
    this.id, {
    super.key,
    this.kind = 'case',
    this.parent,
    this.showRecord = false,
  });
  final String id, kind;
  final String? parent;
  final bool showRecord;
  @override
  ConsumerState<RescueEditorScreen> createState() => _RescueEditorState();
}

class _RescueEditorState extends ConsumerState<RescueEditorScreen>
    with WidgetsBindingObserver {
  final controllers = <String, TextEditingController>{};
  RescueRecord? record;
  List<Json> files = [], history = [];
  int step = 0;
  bool verificationIntroDismissed = false;
  bool loading = true, busy = false, dirty = false, loadFailed = false;
  bool expenseSubmitted = false;
  final caseInformationKey = GlobalKey(debugLabel: 'case-information');
  final caseNeedsKey = GlobalKey(debugLabel: 'case-needs');
  List<Json> needItems = [];
  String? error, message;
  String get kind => record?.kind ?? widget.kind;
  bool get editable => record?.editable ?? true;
  RescueRepository get repository => ref.read(rescueRepositoryProvider);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void fields(RescueRecord? r) {
    if (kind == 'case') {
      needItems = ((r?.publicData['need_items'] as List?) ?? [])
          .map((item) => Json.from(item as Map))
          .toList();
    }
    for (final f in rescueFields[kind]!) {
      final raw = (f.private ? r?.privateData : r?.publicData)?[f.key];
      var value = f.key == 'amount_cents' && raw is int
          ? raw.toString()
          : raw as String? ?? f.initial;
      if (f.key == 'amount_cents' && int.tryParse(value) != null) {
        final cents = int.parse(value);
        value = '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
      }
      (controllers[f.key] ??= TextEditingController()).text = value;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ['verification', 'expense'].contains(kind) &&
        record != null &&
        !editable &&
        !loading &&
        !busy &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      load();
    }
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      if (widget.id != 'new' || record != null) {
        final data = await repository.detail(record?.id ?? widget.id);
        if (!mounted) return;
        record = RescueRecord(Json.from(data['record']));
        history = (data['history'] as List).map((e) => Json.from(e)).toList();
        files = record!.files;
        if (!record!.editable) step = 2;
      }
      fields(record);
      dirty = false;
      error = null;
      loadFailed = false;
    } catch (cause) {
      if (mounted) {
        error = rescueError(cause);
        loadFailed = true;
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await action();
    } catch (cause) {
      if (mounted) {
        setState(() {
          error = rescueError(cause);
          if (cause is PostgrestException && cause.code == '42501') {
            loadFailed = true;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    final pub = <String, dynamic>{}, priv = <String, dynamic>{};
    for (final f in rescueFields[kind]!) {
      var value = controllers[f.key]!.text.trim();
      if (f.key == 'amount_cents' && value.isNotEmpty) {
        final cents = parsePesos(value);
        if (cents == null) {
          throw const FormatException(
            'Escribe el importe en pesos con hasta dos decimales, por ejemplo 250.50.',
          );
        }
        value = cents.toString();
      }
      (f.private ? priv : pub)[f.key] = value;
    }
    if (kind == 'case' &&
        (needItems.isNotEmpty ||
            record?.publicData.containsKey('need_items') == true)) {
      pub['need_items'] = needItems;
    }
    final saved = await repository.save(
      kind,
      pub,
      priv,
      files,
      record: record,
      parent: widget.parent,
    );
    if (!mounted) return;
    setState(() {
      record = saved;
      dirty = false;
      message = 'Borrador guardado.';
    });
  }

  Future<void> pickCasePhoto(ImageSource source) async {
    final actor = ref.read(communityRepositoryProvider).userId;
    if (actor == null) throw const FormatException('Vuelve a iniciar sesión.');
    await save();
    if (!mounted) return;
    final preferences = await SharedPreferences.getInstance();
    final key = pendingPhotoKey(actor);
    final token = 'rescue:${record!.id}';
    await preferences.setString(key, token);
    await preferences.setString(pendingPhotoActorKey, actor);
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      requestFullMetadata: false,
    );
    if (preferences.getString(key) == token) {
      await preferences.remove(key);
      if (preferences.getString(pendingPhotoActorKey) == actor) {
        await preferences.remove(pendingPhotoActorKey);
      }
    }
    if (file == null || !mounted) return;
    if (ref.read(communityRepositoryProvider).userId != actor) {
      throw const FormatException(
        'La sesión cambió. Retoma el borrador con su cuenta.',
      );
    }
    if (await file.length() > 5242880) {
      throw const FormatException('El archivo debe pesar hasta 5 MB.');
    }
    final path = await repository.upload(
      record!.id,
      await file.readAsBytes(),
      pdf: false,
    );
    if (!mounted) return;
    setState(() {
      files = [
        ...files,
        {'role': 'public', 'path': path},
      ];
      dirty = true;
    });
    await save();
  }

  Widget casePhotos() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Sube fotos de la mascota',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w600,
          color: Color(0xff151423),
        ),
      ),
      const SizedBox(height: 16),
      PublicationPhotoPicker(
        onCamera: editable && !busy && files.length < 12
            ? () => run(() => pickCasePhoto(ImageSource.camera))
            : null,
        onGallery: editable && !busy && files.length < 12
            ? () => run(() => pickCasePhoto(ImageSource.gallery))
            : null,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < files.length; i++)
            if (files[i]['role'] == 'public')
              PublicationPhotoThumbnail(
                photo: Semantics(
                  button: true,
                  label: 'Ver foto ${i + 1}',
                  child: InkWell(
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    onTap: () =>
                        context.push('/rescue-file', extra: files[i]['path']),
                    child: RescuePublicPhoto(
                      files[i]['path'] as String,
                      height: 167,
                      radius: 0,
                      compact: true,
                    ),
                  ),
                ),
                principal:
                    i == files.indexWhere((file) => file['role'] == 'public'),
                onRemove: editable && !busy
                    ? () => setState(() {
                        files.removeAt(i);
                        dirty = true;
                      })
                    : null,
              ),
        ],
      ),
    ],
  );

  Future<void> attach(String role) async {
    await save();
    if (!mounted) return;
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: role == 'public' ? 'Fotos' : 'Fotos y PDF',
          extensions: role == 'public'
              ? ['jpg', 'jpeg', 'png', 'webp']
              : ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          uniformTypeIdentifiers: role == 'public'
              ? ['public.image']
              : ['public.image', 'com.adobe.pdf'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    if (await file.length() > 5242880) {
      throw const FormatException('El archivo debe pesar hasta 5 MB.');
    }
    final pdf = file.name.toLowerCase().endsWith('.pdf');
    if (role == 'public' && pdf) {
      throw const FormatException('Para publicación elige una foto.');
    }
    final path = await repository.upload(
      record!.id,
      await file.readAsBytes(),
      pdf: pdf,
    );
    if (!mounted) return;
    setState(() {
      files = [
        ...files,
        {'role': role, 'path': path},
      ];
      dirty = true;
    });
    await save();
  }

  Future<void> transition(String action) async {
    if (action == 'submit') {
      await save();
      if (!mounted) return;
    }
    final result = await repository.transition(record!, action);
    if (action == 'submit') {
      await ref
          .read(measurementControllerProvider)
          ?.event('publication_submitted');
    }
    if (!mounted) return;
    setState(() {
      record = result;
      expenseSubmitted =
          action == 'submit' &&
          result.kind == 'expense' &&
          result.status == 'submitted';
      message = action == 'submit'
          ? 'Solicitud enviada. Te avisaremos cuando el equipo responda.'
          : action == 'close'
          ? 'Caso cerrado.'
          : 'Retiramos la solicitud a borrador.';
    });
    if (action == 'submit' &&
        result.kind == 'case' &&
        result.status == 'submitted') {
      dirty = false;
      context.go('/my-cases');
      return;
    }
    await load();
  }

  Future<bool> confirmLeave() async {
    if (!dirty || !editable) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hay cambios sin guardar'),
            content: const Text(
              'Guarda el borrador antes de salir para conservarlos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir sin guardar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget verificationField(String key) {
    final field = rescueFields['verification']!.firstWhere(
      (item) => item.key == key,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffe3e4ed)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            field.label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: Color(0xff4f4e5c),
            ),
          ),
          const SizedBox(height: 7),
          if (field.options == null)
            Semantics(
              label: field.label,
              child: TextField(
                key: ValueKey('verification-field-$key'),
                controller: controllers[key],
                enabled: editable && !busy,
                maxLength: field.max,
                maxLines: field.lines,
                keyboardType: key == 'phone'
                    ? TextInputType.phone
                    : key == 'social_url'
                    ? TextInputType.url
                    : field.lines > 1
                    ? TextInputType.multiline
                    : TextInputType.text,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: Color(0xff151423),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xff7841f2)),
                  ),
                ),
                onChanged: (_) => setState(() => dirty = true),
              ),
            ),
          if (field.options != null)
            DropdownButtonFormField<String>(
              key: ValueKey(
                'verification-$key:${record?.id ?? 'new'}:${record?.version ?? 0}',
              ),
              initialValue: field.options!.containsKey(controllers[key]!.text)
                  ? controllers[key]!.text
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                border: border,
                enabledBorder: border,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: field.options!.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: editable && !busy
                  ? (value) => setState(() {
                      controllers[key]!.text = value!;
                      dirty = true;
                    })
                  : null,
            ),
        ],
      ),
    );
  }

  Widget verificationDocument(String role) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe3e4ed)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              evidenceRoles[role]!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: Color(0xff151423),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Privado · Solo para revisión del equipo',
              style: TextStyle(
                fontSize: 12,
                height: 1.55,
                color: Color(0xff4f4e5c),
              ),
            ),
            for (final file in files.where((file) => file['role'] == role))
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.description_outlined),
                      label: Text('Ver archivo ${files.indexOf(file) + 1}'),
                      onPressed: () =>
                          context.push('/rescue-file', extra: file['path']),
                    ),
                  ),
                  if (editable)
                    IconButton(
                      tooltip: 'Quitar archivo ${files.indexOf(file) + 1}',
                      icon: const Icon(Icons.close),
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              files.remove(file);
                              dirty = true;
                            }),
                    ),
                ],
              ),
            if (editable)
              OutlinedButton.icon(
                onPressed: busy || files.length >= 12
                    ? null
                    : () => run(() => attach(role)),
                icon: const Icon(Icons.upload_file_outlined),
                label: Text('Adjuntar ${evidenceRoles[role]!.toLowerCase()}'),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> closeExpenseEditor() async {
    if (!await confirmLeave() || !mounted) return;
    setState(() => dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(
          record?.parent != null ? '/rescue/${record!.parent}' : '/my-cases',
        );
      }
    });
  }

  Widget editorFrame({required List<Widget> children}) {
    if (kind == 'case' && editable) {
      return PublicationFrame(
        title: step == 3 ? 'Revisa tu caso' : 'Publicar caso',
        step: step,
        totalSteps: 4,
        onBack: busy
            ? null
            : () {
                if (step > 0) {
                  setState(() => step--);
                } else {
                  closeExpenseEditor();
                }
              },
        footer: PublicationFooter(
          label: step == 3
              ? 'Enviar a revisión'
              : step == 2
              ? 'Continuar a revisión'
              : 'Continuar',
          busy: busy || loading,
          compact: MediaQuery.viewInsetsOf(context).bottom > 0,
          onSave: loadFailed ? null : () => run(save),
          onContinue:
              loadFailed ||
                  (step == 0 &&
                      !files.any(
                        (f) =>
                            f['role'] == 'public' &&
                            (f['path'] as String? ?? '').isNotEmpty,
                      ))
              ? null
              : () => run(() async {
                  if (step < 3) {
                    await save();
                    if (mounted) {
                      setState(() {
                        step++;
                        message = null;
                      });
                    }
                  } else {
                    await transition('submit');
                  }
                }),
        ),
        children: [const PhotoRecoveryNotice(), ...children],
      );
    }
    if (kind != 'expense') return CommunityFrame(children: children);
    return ExpenseFrame(
      step: step,
      readOnly: !editable,
      onBack: busy
          ? null
          : () {
              if (step > 0 && editable) {
                setState(() => step--);
              } else {
                closeExpenseEditor();
              }
            },
      onClose: busy ? null : closeExpenseEditor,
      children: children,
    );
  }

  Widget verificationForm() {
    final total = rescueFields['verification']!.length + 2;
    final captured =
        rescueFields['verification']!
            .where(
              (field) =>
                  controllers[field.key]?.text.trim().isNotEmpty == true &&
                  (field.key != 'social_url' ||
                      RegExp(r'^https://[^ /]+/.+')
                          .hasMatch(controllers[field.key]!.text.trim())),
            )
            .length +
        ['identity', 'address']
            .where(
              (role) => files.any(
                (file) =>
                    file['role'] == role &&
                    (file['path'] as String? ?? '').isNotEmpty,
              ),
            )
            .length;
    return VerificationFormFrame(
      onBack: busy
          ? null
          : () async {
              if (!await confirmLeave() || !mounted) return;
              setState(() => dirty = false);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/rescuer');
                  }
                }
              });
            },
      children: [
        const Text(
          'Completa tu información para verificar tu cuenta de rescatista',
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: Color(0xff4f4e5c),
          ),
        ),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (loadFailed || (record == null && widget.id != 'new')) ...[
          Notice(error ?? 'Solicitud no disponible', isError: true),
          TextButton(onPressed: load, child: const Text('Volver a intentar')),
        ] else ...[
          if (record != null)
            Notice(
              '${rescueStatuses[record!.status]} · Versión ${record!.version}',
            ),
          if ((record?.data['feedback'] as String? ?? '').isNotEmpty)
            Notice('Respuesta del equipo: ${record!.data['feedback']}'),
          if (!editable)
            const Notice(
              'Los datos enviados están protegidos. Puedes consultar el estado actualizado al recargar.',
            ),
          if (busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Guardando o subiendo archivos',
            ),
          const VerificationSectionTitle('Información básica'),
          const Text(
            'Estos datos son privados y se usarán para revisar tu solicitud.',
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: Color(0xff4f4e5c),
            ),
          ),
          const SizedBox(height: 16),
          verificationField('legal_name'),
          verificationField('phone'),
          const VerificationSectionTitle('Experiencia de rescate'),
          verificationField('experience'),
          const VerificationSectionTitle('Redes sociales'),
          const Text(
            'El equipo revisará el perfil que compartas.',
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: Color(0xff4f4e5c),
            ),
          ),
          const SizedBox(height: 16),
          verificationField('social_url'),
          const VerificationSectionTitle('Perfil público'),
          const Text(
            'Estos datos aparecerán después de la aprobación. No incluyas domicilios particulares, teléfonos ni datos de tus comprobantes.',
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: Color(0xff4f4e5c),
            ),
          ),
          const SizedBox(height: 16),
          verificationField('public_name'),
          verificationField('bio'),
          verificationField('city'),
          verificationField('state'),
          const VerificationSectionTitle('Documentos'),
          verificationField('identity_type'),
          const Text(
            'Hasta 12 archivos de 5 MB. JPG, PNG, WebP o PDF.',
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: Color(0xff4f4e5c),
            ),
          ),
          const SizedBox(height: 16),
          verificationDocument('identity'),
          verificationDocument('address'),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffe3e4ed)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Progreso del formulario',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xff4f4e5c),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$captured de $total requisitos capturados'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: captured / total,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(99),
                    color: const Color(0xff7841f2),
                    backgroundColor: const Color(0xffefede8),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El equipo verificará la información y los documentos antes de aprobar.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: Color(0xff4f4e5c),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (error != null) Notice(error!, isError: true),
          if (message != null) Notice(message!),
          if (editable) ...[
            ActionButton(
              'Enviar a revisión',
              busy: busy,
              onPressed: () => run(() => transition('submit')),
            ),
            TextButton(
              onPressed: busy ? null : () => run(save),
              child: const Text('Guardar borrador'),
            ),
          ],
          if (record?.status == 'submitted')
            OutlinedButton(
              onPressed: busy ? null : () => run(() => transition('withdraw')),
              child: const Text('Retirar a borrador'),
            ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (await confirmLeave()) await load();
                  },
            child: const Text('Recargar estado'),
          ),
          if (history.isNotEmpty) ...[
            const VerificationSectionTitle('Historial'),
            for (final item in history)
              ListTile(
                title: Text(
                  rescueStatuses[item['action']] ??
                      const {
                        'submit': 'Enviado',
                        'withdraw': 'Retirado a borrador',
                        'close': 'Caso cerrado',
                      }[item['action']] ??
                      'Actualización',
                ),
                subtitle: Text(
                  '${localDate(item['created_at'] as String)} · Versión ${item['version']}\n${item['feedback']}',
                ),
              ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (expenseSubmitted) {
      return ExpenseSubmitted(onClose: closeExpenseEditor);
    }
    if (widget.id == 'new' &&
        kind == 'verification' &&
        !verificationIntroDismissed) {
      return VerificationIntroScreen(
        onContinue: () => setState(() => verificationIntroDismissed = true),
        onLater: () =>
            context.canPop() ? context.pop() : context.go('/rescuer'),
      );
    }

    if (kind == 'verification' &&
        record != null &&
        ['submitted', 'approved'].contains(record!.status) &&
        !loadFailed &&
        !widget.showRecord) {
      return VerificationStateScreen(
        approved: record!.status == 'approved',
        loading: loading || busy,
        onBack: () => context.canPop() ? context.pop() : context.go('/rescuer'),
        onHome: () => context.go('/rescuer'),
        onPublish: () => context.go('/publish'),
        onRecord: () async {
          await context.push('/rescue/${record!.id}?record=1');
          if (mounted) await load();
        },
        onRefresh: load,
        onWithdraw: record!.status == 'submitted'
            ? () => run(() => transition('withdraw'))
            : null,
      );
    }

    final ownCase =
        record != null &&
        record!.kind == 'case' &&
        ['approved', 'closed'].contains(record!.status) &&
        record!.data['owner_id'] ==
            ref.read(identityControllerProvider).identity?.id;
    if (ownCase && !loadFailed && !widget.showRecord) {
      return OwnedCaseDetail(
        record: record!,
        needs: RescueList(
          kind: 'expense',
          parent: record!.id,
          ownedExpenseCards: true,
        ),
        updates: OwnedCaseHistory(record!.id),
        busy: busy || loading,
        error: error,
        onBack: () =>
            context.canPop() ? context.pop() : context.go('/my-cases'),
        onRecord: () async {
          await context.push('/rescue/${record!.id}?record=1');
          if (mounted) await load();
        },
        onRefresh: load,
        onExpense: () =>
            context.push('/rescue/new?kind=expense&case=${record!.id}'),
        onUpdates: () => context.push('/rescue-cases/${record!.id}/updates'),
        onClose: () => run(() async {
          final close = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('¿Cerrar este caso?'),
              content: const Text(
                'Ya no podrás agregar gastos. El seguimiento aprobado seguirá disponible.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Continuar caso'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Cerrar caso'),
                ),
              ],
            ),
          );
          if (close == true) await transition('close');
        }),
      );
    }
    return PopScope(
      canPop: !dirty || !editable,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await confirmLeave() && context.mounted) {
          setState(() => dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
        }
      },
      child: kind == 'verification'
          ? verificationForm()
          : editorFrame(
              children: [
                if (widget.showRecord && ownCase)
                  TextButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/rescue/${record!.id}'),
                    child: const Text('Volver al caso'),
                  ),
                if (kind != 'expense' && !(kind == 'case' && editable))
                  Heading(
                    kind == 'verification'
                        ? 'Tu labor merece\nconfianza.'
                        : kind == 'case'
                        ? 'Cuéntanos su historia.'
                        : 'Documenta el gasto.',
                    kind == 'verification'
                        ? 'El equipo revisará tus documentos y el enlace social.'
                        : kind == 'case'
                        ? 'Describe el rescate y la necesidad. El equipo revisa todo antes de publicarlo.'
                        : 'Presenta un gasto ya pagado. Cada ronda de comida necesita su propia solicitud y revisión.',
                    eyebrow: rescueKinds[kind]!.toUpperCase(),
                  ),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (loadFailed ||
                    (record == null && widget.id != 'new')) ...[
                  Notice(error ?? 'Solicitud no disponible', isError: true),
                  TextButton(
                    onPressed: load,
                    child: const Text('Volver a intentar'),
                  ),
                ] else ...[
                  if (record != null && !(kind == 'case' && editable))
                    if (kind == 'expense')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x80f0eff8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          rescueStatuses[record!.status] ?? record!.status,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff15110d),
                          ),
                        ),
                      )
                    else
                      Notice(
                        '${rescueStatuses[record!.status]} · Versión ${record!.version}',
                      ),
                  if ((record?.data['feedback'] as String? ?? '').isNotEmpty)
                    Notice('Respuesta del equipo: ${record!.data['feedback']}'),
                  if (!editable)
                    if (kind == 'expense')
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Los datos enviados están protegidos. Recarga para consultar la respuesta del equipo.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 1.55,
                            color: Color(0xff554e48),
                          ),
                        ),
                      )
                    else
                      const Notice(
                        'Los datos enviados están protegidos. Puedes consultar el estado actualizado al recargar.',
                      ),
                  if (kind != 'expense' && !(kind == 'case' && editable))
                    _RescueSteps(step: step),
                  if (busy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Guardando o subiendo archivos',
                    ),
                  if (step == 1 && kind == 'case')
                    CaseInformation(
                      key: caseInformationKey,
                      controllers: controllers,
                      enabled: editable && !busy,
                      onChanged: () => setState(() => dirty = true),
                    ),
                  for (final private in [false, true]) ...[
                    if (step == 1 &&
                        kind != 'case' &&
                        rescueFields[kind]!.any(
                          (f) => f.private == private,
                        )) ...[
                      const SizedBox(height: 20),
                      Text(
                        private
                            ? 'Solo para revisión privada'
                            : 'Información para publicación',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (!private)
                        const Text(
                          'No incluyas domicilios particulares, teléfonos ni datos de tus comprobantes.',
                        ),
                      const SizedBox(height: 16),
                      for (final f in rescueFields[kind]!.where(
                        (f) => f.private == private,
                      ))
                        if (kind == 'expense')
                          ExpenseField(
                            field: f,
                            controller: controllers[f.key]!,
                            enabled: editable && !busy,
                            onChanged: () => setState(() => dirty = true),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: f.options == null
                                ? TextField(
                                    controller: controllers[f.key],
                                    enabled: editable && !busy,
                                    maxLength: f.max,
                                    maxLines: f.lines,
                                    keyboardType: f.key == 'amount_cents'
                                        ? const TextInputType.numberWithOptions(
                                            decimal: true,
                                          )
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: f.label,
                                      alignLabelWithHint: f.lines > 1,
                                    ),
                                    onChanged: (_) =>
                                        setState(() => dirty = true),
                                  )
                                : DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      '${f.key}:${controllers[f.key]!.text}',
                                    ),
                                    initialValue:
                                        f.options!.containsKey(
                                          controllers[f.key]!.text,
                                        )
                                        ? controllers[f.key]!.text
                                        : null,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: f.label,
                                    ),
                                    items: f.options!.entries
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(e.value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: !editable || busy
                                        ? null
                                        : (v) => setState(() {
                                            controllers[f.key]!.text = v!;
                                            dirty = true;
                                          }),
                                  ),
                          ),
                    ],
                  ],
                  if (step == 0 && kind == 'case') casePhotos(),
                  if (step == 0 && kind != 'case') ...[
                    Text(
                      'Documentos y evidencia',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Hasta 12 archivos de 5 MB. JPG, PNG, WebP o PDF; para publicar, solo fotos.',
                    ),
                    for (final role
                        in kind == 'verification'
                            ? ['identity', 'address']
                            : kind == 'case'
                            ? ['public']
                            : ['receipt', 'proof', 'public'])
                      if (kind == 'expense')
                        ExpenseEvidenceCard(
                          title: evidenceRoles[role]!,
                          public: role == 'public',
                          fileIndexes: [
                            for (var i = 0; i < files.length; i++)
                              if (files[i]['role'] == role) i,
                          ],
                          onOpen: (i) => context.push(
                            '/rescue-file',
                            extra: files[i]['path'],
                          ),
                          onRemove: editable && !busy
                              ? (i) => setState(() {
                                  files.removeAt(i);
                                  dirty = true;
                                })
                              : null,
                          onAttach: editable && !busy && files.length < 12
                              ? () => run(() => attach(role))
                              : null,
                        )
                      else
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${evidenceRoles[role]} · ${role == 'public' ? 'Pública después de aprobación' : 'Privada'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                for (final file in files.where(
                                  (f) => f['role'] == role,
                                ))
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          icon: const Icon(
                                            Icons.description_outlined,
                                          ),
                                          label: Text(
                                            'Ver archivo ${files.indexOf(file) + 1}',
                                          ),
                                          onPressed: () => context.push(
                                            '/rescue-file',
                                            extra: file['path'],
                                          ),
                                        ),
                                      ),
                                      if (editable)
                                        IconButton(
                                          tooltip:
                                              'Quitar archivo ${files.indexOf(file) + 1}',
                                          icon: const Icon(Icons.close),
                                          onPressed: busy
                                              ? null
                                              : () => setState(() {
                                                  files.remove(file);
                                                  dirty = true;
                                                }),
                                        ),
                                    ],
                                  ),
                                if (editable)
                                  OutlinedButton.icon(
                                    onPressed: busy || files.length >= 12
                                        ? null
                                        : () => run(() => attach(role)),
                                    icon: const Icon(Icons.upload_file),
                                    label: Text(
                                      'Adjuntar ${evidenceRoles[role]!.toLowerCase()}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                  ],
                  if (step == 2 && kind == 'expense')
                    ExpenseReview(
                      readOnly: !editable,
                      values: {
                        for (final entry in controllers.entries)
                          entry.key: entry.value.text.trim(),
                      },
                      files: files,
                      onOpen: (i) =>
                          context.push('/rescue-file', extra: files[i]['path']),
                      onEditInformation: editable && !busy
                          ? () => setState(() => step = 1)
                          : null,
                      onEditFiles: editable && !busy
                          ? () => setState(() => step = 0)
                          : null,
                    ),
                  if (step == 2 && kind == 'case' && editable)
                    CaseNeeds(
                      key: caseNeedsKey,
                      items: needItems,
                      onItemsChanged: (items) => setState(() {
                        needItems = items;
                        dirty = true;
                      }),
                      controller: controllers['need']!,
                      enabled: !busy,
                      onChanged: () => setState(() => dirty = true),
                    ),
                  if (step == 3 && kind == 'case' && editable)
                    CaseReview(
                      items: needItems,
                      values: {
                        for (final entry in controllers.entries)
                          entry.key: entry.value.text.trim(),
                      },
                      files: files,
                      onOpen: (path) =>
                          context.push('/rescue-file', extra: path),
                      onEditPhotos: busy
                          ? null
                          : () => setState(() => step = 0),
                      onEditInformation: busy
                          ? null
                          : () => setState(() => step = 1),
                      onEditNeeds: busy ? null : () => setState(() => step = 2),
                    ),
                  if (step == 2 &&
                      kind != 'expense' &&
                      !(kind == 'case' && editable)) ...[
                    Text(
                      'Revisa antes de enviar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _RescueReviewRow('Tipo', rescueKinds[kind] ?? kind),
                    _RescueReviewRow(
                      'Nombre',
                      controllers[rescueFields[kind]!.first.key]?.text.trim() ??
                          '',
                    ),
                    _RescueReviewRow('Archivos', '${files.length} adjuntos'),
                    const Notice(
                      'El equipo revisará por separado la información pública, los documentos privados y la evidencia antes de aprobar.',
                    ),
                  ],
                  if (record?.kind == 'expense' && record!.status == 'approved')
                    LiveSection<Json>(
                      key: ValueKey('funding:${record!.id}'),
                      tables: const ['dopmi_donations'],
                      errorMessage: paymentError,
                      load: () => ref
                          .read(paymentRepositoryProvider)
                          .funding(record!.id),
                      builder: (funding, refresh) => Column(
                        children: [
                          Notice(
                            'Monto reembolsable: ${pesos(funding['reimbursable_cents'] as int)}${record!.data['urgent'] == true ? ' · Urgencia aprobada' : ''}. Neto asignado: ${pesos(funding['funded_cents'] as int)}. Transferido a Stripe: ${pesos(funding['transferred_cents'] as int? ?? 0)}. Disponible: ${pesos(funding['available_cents'] as int)}.',
                          ),
                          TextButton(
                            onPressed: refresh,
                            child: const Text('Actualizar aportaciones'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (editable) ...[
                    if (error != null) Notice(error!, isError: true),
                    if (message != null) Notice(message!),
                    if (kind == 'expense')
                      ExpenseActions(
                        primaryLabel: step < 2
                            ? 'Siguiente'
                            : 'Enviar a revisión',
                        onSave: busy
                            ? null
                            : () => run(() async {
                                await save();
                                if (mounted) await closeExpenseEditor();
                              }),
                        onNext: busy
                            ? null
                            : () => run(() async {
                                if (step < 2) {
                                  await save();
                                  if (mounted) setState(() => step++);
                                } else {
                                  await transition('submit');
                                }
                              }),
                      )
                    else if (kind != 'case') ...[
                      if (step < 2)
                        ActionButton(
                          'Guardar y continuar',
                          busy: busy,
                          onPressed: () => run(() async {
                            await save();
                            if (mounted) setState(() => step++);
                          }),
                        )
                      else ...[
                        ActionButton(
                          'Enviar a revisión',
                          busy: busy,
                          onPressed: () => run(() => transition('submit')),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => run(save),
                          child: const Text('Guardar borrador'),
                        ),
                      ],
                    ],
                    if (step > 0 && kind != 'case')
                      TextButton(
                        onPressed: busy ? null : () => setState(() => step--),
                        child: const Text('Regresar al paso anterior'),
                      ),
                  ],
                  if (!editable && error != null) Notice(error!, isError: true),
                  if (!editable && message != null) Notice(message!),
                  if (record?.status == 'submitted')
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => run(() => transition('withdraw')),
                      child: const Text('Retirar a borrador'),
                    ),
                  if (!(kind == 'case' && editable))
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (await confirmLeave()) {
                                await load();
                              }
                            },
                      child: const Text('Recargar estado'),
                    ),
                  if (record?.kind == 'case' && !editable) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Gastos de este caso',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (record!.status != 'closed')
                      ActionButton(
                        'Registrar gasto realizado',
                        sunny: true,
                        onPressed: busy
                            ? null
                            : () => context.push(
                                '/rescue/new?kind=expense&case=${record!.id}',
                              ),
                      ),
                    RescueList(kind: 'expense', parent: record!.id),
                    if (record!.status == 'approved')
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                final close = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('¿Cerrar este caso?'),
                                    content: const Text(
                                      'Ya no podrás agregar gastos. El seguimiento aprobado seguirá disponible.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Continuar caso'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Cerrar caso'),
                                      ),
                                    ],
                                  ),
                                );
                                if (close == true) await transition('close');
                              }),
                        child: const Text('Cerrar caso'),
                      ),
                  ],
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Historial',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final item in history)
                      ListTile(
                        title: Text(
                          rescueStatuses[item['action']] ??
                              {
                                'submit': 'Enviado',
                                'withdraw': 'Retirado a borrador',
                                'close': 'Caso cerrado',
                              }[item['action']] ??
                              'Actualización',
                        ),
                        subtitle: Text(
                          '${localDate(item['created_at'] as String)} · Versión ${item['version']}\n${item['feedback']}',
                        ),
                      ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _RescueSteps extends StatelessWidget {
  const _RescueSteps({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Paso ${step + 1} de 3',
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          for (final entry in [
            'Archivos',
            'Información',
            'Revisión',
          ].indexed) ...[
            Expanded(
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: entry.$1 <= step ? 1 : 0,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(5),
                    backgroundColor: const Color(0xffe7e2da),
                    color: purple,
                  ),
                  const SizedBox(height: 5),
                  Text(entry.$2, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (entry.$1 < 2) const SizedBox(width: 8),
          ],
        ],
      ),
    ),
  );
}

class _RescueReviewRow extends StatelessWidget {
  const _RescueReviewRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value.isEmpty ? 'Falta completar' : value),
  );
}

class RescueFileScreen extends ConsumerStatefulWidget {
  const RescueFileScreen(this.path, {super.key});
  final String path;
  @override
  ConsumerState<RescueFileScreen> createState() => _RescueFileState();
}

class _RescueFileState extends ConsumerState<RescueFileScreen> {
  late Future<String> url = fileUrl();
  String? error;
  Future<String> fileUrl() {
    final request = Future<String>.sync(
      () => ref.read(rescueRepositoryProvider).fileUrl(widget.path),
    );
    request.ignore();
    return request;
  }

  void reload() {
    final request = fileUrl();
    setState(() {
      url = request;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => ContributionFrame(
    title: 'Archivo adjunto',
    rescuer: true,
    back: () => context.canPop() ? context.pop() : context.go('/profile'),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          'El acceso se comprueba al abrir cada archivo.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xff4f4e5c),
          ),
        ),
        const SizedBox(height: 20),
        if (error != null) Notice(error!, isError: true),
        FutureBuilder<String>(
          key: ValueKey(url),
          future: url,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Notice(rescueError(snapshot.error!), isError: true);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (widget.path.endsWith('.pdf')) {
              return ActionButton(
                'Abrir PDF',
                onPressed: () async {
                  try {
                    final fresh = await ref
                        .read(rescueRepositoryProvider)
                        .fileUrl(widget.path);
                    if (!mounted) return;
                    if (!await launchUrl(
                      Uri.parse(fresh),
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw const FormatException('No pudimos abrir el PDF.');
                    }
                  } catch (cause) {
                    if (mounted) setState(() => error = rescueError(cause));
                  }
                },
              );
            }
            return Image.network(
              snapshot.data!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Notice(
                'No pudimos cargar la imagen. Recarga el archivo.',
                isError: true,
              ),
            );
          },
        ),
        TextButton(onPressed: reload, child: const Text('Recargar archivo')),
      ],
    ),
  );
}

class RescueCatalogScreen extends ConsumerStatefulWidget {
  const RescueCatalogScreen({super.key, this.caseId});
  final String? caseId;
  @override
  ConsumerState<RescueCatalogScreen> createState() => _RescueCatalogState();
}

class _RescueCatalogState extends ConsumerState<RescueCatalogScreen> {
  int page = 1;
  bool busy = false;
  bool? savedOverride;
  String? error;

  Future<void> toggleCase(RescueRecord record, VoidCallback refresh) async {
    final repo = ref.read(communityRepositoryProvider);
    if (repo.userId == null) {
      context.push('/login');
      return;
    }
    final previous = savedOverride ?? record.saved;
    setState(() {
      busy = true;
      error = null;
      savedOverride = !previous;
    });
    try {
      await repo.favoriteCase(record.id, !previous);
      refresh();
    } catch (cause) {
      if (mounted) {
        setState(() {
          savedOverride = previous;
          error = communityError(cause);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reportCase(RescueRecord record) async {
    if (busy) return;
    final repo = ref.read(communityRepositoryProvider);
    if (repo.userId == null) {
      context.push('/login');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final sent = await reportPublicContent(
        context,
        repo,
        type: 'case',
        id: record.id,
        title: 'Reportar caso',
      );
      if (sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recibimos tu reporte para revisión.')),
        );
      }
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = LiveSection<DataPage<RescueRecord>>(
      key: ValueKey('${widget.caseId}:$page'),
      statusFrame: widget.caseId == null
          ? (child) => SupportHomePage(
              data: const DataPage([], 0),
              page: page,
              error: null,
              changePage: (value) => setState(() => page = value),
              status: child,
            )
          : (child) => CaseStatusFrame(child),
      load: () {
        final repo = ref.read(rescueRepositoryProvider);
        final caseId = widget.caseId;
        return caseId == null
            ? repo.catalog(page)
            : repo.completeCaseCatalog(caseId);
      },
      builder: (data, refresh) => widget.caseId == null
          ? SupportHomePage(
              data: data,
              page: page,
              error: error,
              changePage: (value) => setState(() => page = value),
            )
          : _PublicCaseDetail(
              records: data.items,
              busy: busy,
              error: error,
              savedOverride: savedOverride,
              toggle: (record) => toggleCase(record, refresh),
              report: reportCase,
            ),
    );
    if (widget.caseId == null) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        bottomNavigationBar: const CommunityNav(1),
        body: content,
      );
    }
    return Scaffold(backgroundColor: Colors.white, body: content);
  }
}

class _PublicCaseDetail extends StatelessWidget {
  const _PublicCaseDetail({
    required this.records,
    required this.busy,
    required this.error,
    required this.savedOverride,
    required this.toggle,
    required this.report,
  });
  final List<RescueRecord> records;
  final bool busy;
  final String? error;
  final bool? savedOverride;
  final ValueChanged<RescueRecord> toggle, report;
  @override
  Widget build(BuildContext context) {
    final cases = records.where((item) => item.kind == 'case').toList();
    if (cases.isEmpty) {
      return const CaseStatusFrame(Notice('Este caso ya no está disponible.'));
    }
    final record = cases.first;
    final expenses = records.where((item) => item.kind == 'expense').toList();
    final planned = ((record.publicData['need_items'] as List?) ?? const [])
        .map((item) => Json.from(item as Map))
        .toList();
    return CaseDetailLayout(
      record: record,
      expenses: expenses,
      busy: busy,
      error: error,
      saved: savedOverride ?? record.saved,
      favorite: () => toggle(record),
      report: () => report(record),
      share: () => shareContent(
        context,
        'Conoce el caso ${record.title} en Dopmi. ${publicContentLink(PublicContent.rescueCase, record.id)}',
      ),
      needs: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (planned.isNotEmpty) ...[
            const Text(
              'Costos estimados',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xff151423),
              ),
            ),
            const SizedBox(height: 8),
            for (final item in planned) ...[
              CaseNeedRow(
                item: item,
                key: ValueKey('public-need-${item['id']}'),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            const Text(
              'Los apoyos disponibles se muestran en cada gasto aprobado.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xff616174),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (expenses.isEmpty)
            const Notice('Este caso no tiene gastos disponibles para aportar.'),
          for (var i = 0; i < expenses.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            PublicExpenseCard(
              expenses[i],
              key: ValueKey(expenses[i].id),
              initiallyOpen:
                  i ==
                  expenses.indexWhere(
                    (e) =>
                        record.status == 'approved' &&
                        e.status == 'approved' &&
                        e.targetCents > e.fundedCents,
                  ),
              canContribute:
                  record.status == 'approved' &&
                  expenses[i].status == 'approved',
            ),
          ],
        ],
      ),
      updates: record.data['owner_id'] != null
          ? PublicCaseUpdates(record.id)
          : null,
    );
  }
}

class OwnedCasesHeading extends StatelessWidget {
  const OwnedCasesHeading({super.key, this.total});
  final int? total;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis casos',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                height: 1.25,
                letterSpacing: -.48,
                fontWeight: FontWeight.w700,
                color: Color(0xff151423),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              total == null
                  ? 'Da seguimiento a tus casos'
                  : total == 0
                  ? 'Aún no tienes casos'
                  : '$total ${total == 1 ? 'caso' : 'casos'} a tu cuidado',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xff4f4e5c),
              ),
            ),
          ],
        ),
      ),
      if (total != 0) ...[
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => context.go('/publish'),
          icon: const Icon(Icons.add_circle_outline, size: 16),
          label: const Text('Nuevo'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ],
    ],
  );
}

class MyRescueCasesScreen extends StatelessWidget {
  const MyRescueCasesScreen({super.key});
  @override
  Widget build(BuildContext context) => const CommunityFrame(
    index: 2,
    back: false,
    showAppBar: false,
    children: [RescueList(kind: 'case', showCaseHeader: true)],
  );
}
