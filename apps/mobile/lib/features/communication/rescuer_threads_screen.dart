import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/reference_focus_outline.dart';
import '../../core/donor_notification_button.dart';
import '../../core/ui.dart' show Notice;
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import 'match_thread_row.dart';

const _ink = Color(0xff151423);
const _muted = Color(0xff4f4e5c);
const _line = Color(0xffe3e4ed);

class RescuerThreadsScreen extends ConsumerStatefulWidget {
  const RescuerThreadsScreen({super.key});
  @override
  ConsumerState<RescuerThreadsScreen> createState() => _RescuerThreadsState();
}

class _RescuerThreadsState extends ConsumerState<RescuerThreadsScreen> {
  int page = 1;
  bool history = false;
  final collapsed = <String>{};

  void showHistory(bool value) => setState(() {
    history = value;
    page = 1;
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !history,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && history) showHistory(false);
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CommunityNav(3),
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const PageStorageKey('rescuer-inbox-scroll'),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 88),
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
            Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text(
                  history ? 'Historial de mensajes' : 'Mensajes',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    height: 1.1,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            LiveSection<DataPage<Json>>(
              key: ValueKey('$history:$page'),
              tables: const [
                'dopmi_threads',
                'dopmi_messages',
                'dopmi_notifications',
                'dopmi_adoptions',
                'dopmi_rescue_records',
              ],
              load: () => ref
                  .read(communityRepositoryProvider)
                  .rescuerInbox(page, history: history),
              builder: (result, refresh) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result.items.isEmpty)
                    history
                        ? const Text(
                            'Aún no tienes conversaciones en tu historial.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: _muted,
                            ),
                          )
                        : RescuerMessagesEmpty(
                            onPublish: () => context.go('/my-cases'),
                          )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < result.items.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == result.items.length - 1 ? 0 : 14,
                            ),
                            child: RescuerInboxGroup(
                              result.items[i],
                              key: ValueKey(
                                '$history:${result.items[i]['id']}',
                              ),
                              history: history,
                              expanded: !collapsed.contains(
                                '$history:${result.items[i]['id']}',
                              ),
                              toggle: () => setState(() {
                                final key = '$history:${result.items[i]['id']}';
                                if (!collapsed.add(key)) collapsed.remove(key);
                              }),
                              refresh: refresh,
                            ),
                          ),
                      ],
                    ),
                  if (result.total > 20)
                    PageControls(
                      page: page,
                      total: result.total,
                      size: 20,
                      change: (value) => setState(() => page = value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => showHistory(!history),
                  child: Text(
                    history ? 'Ver casos en adopción' : 'Historial de mensajes',
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/my-conversations'),
                  child: const Text('Mis conversaciones'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// The group header counts are supplied by PostgreSQL, independently of the
/// number of conversation pages the person has loaded.
class RescuerInboxGroup extends ConsumerStatefulWidget {
  const RescuerInboxGroup(
    this.group, {
    super.key,
    required this.history,
    required this.expanded,
    required this.toggle,
    required this.refresh,
  });
  final Json group;
  final bool history, expanded;
  final VoidCallback toggle, refresh;
  @override
  ConsumerState<RescuerInboxGroup> createState() => _RescuerInboxGroupState();
}

class _RescuerInboxGroupState extends ConsumerState<RescuerInboxGroup> {
  List<Json> additional = [];
  int nextPage = 2, generation = 0;
  int? loadedTotal;
  bool busy = false;
  String? error;

  @override
  void didUpdateWidget(RescuerInboxGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history ||
        jsonEncode(oldWidget.group) != jsonEncode(widget.group)) {
      generation++;
      additional = [];
      loadedTotal = null;
      nextPage = 2;
      busy = false;
      error = null;
    }
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> more() async {
    if (busy) return;
    final current = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(communityRepositoryProvider)
          .rescuerGroupThreads(
            widget.group['id'] as String,
            nextPage,
            history: widget.history,
          );
      if (!mounted || generation != current) return;
      setState(() {
        final seen = {
          ...initial.map((thread) => thread['id']),
          ...additional.map((thread) => thread['id']),
        };
        additional.addAll(
          result.items.where((thread) => seen.add(thread['id'])),
        );
        loadedTotal = result.total;
        nextPage++;
      });
      if (result.total != widget.group['threads_total']) widget.refresh();
    } catch (cause) {
      if (mounted && generation == current) {
        setState(() => error = communityError(cause));
      }
    } finally {
      if (mounted && generation == current) setState(() => busy = false);
    }
  }

  List<Json> get initial => (widget.group['threads'] as List? ?? [])
      .map((value) => Json.from(value as Map))
      .toList();

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final unread = (group['unread_count'] as num? ?? 0).toInt();
    final count = (group['thread_count'] as num? ?? 0).toInt();
    final total = loadedTotal ?? (group['threads_total'] as num? ?? 0).toInt();
    final threads = [...initial, ...additional];
    final photo = group['photo'] as String? ?? '';
    final name = group['pet_name'] as String? ?? 'Mascota';
    final countLabel = widget.history
        ? '$count ${count == 1 ? 'conversación' : 'conversaciones'}'
        : count == 0
        ? 'Sin chats abiertos'
        : count == 1
        ? '1 chat abierto'
        : '$count chats abiertos';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1a14122b),
            offset: Offset(0, 2),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: widget.expanded,
            label:
                '$name, $countLabel${unread > 0 ? ', $unread mensajes sin leer' : ''}',
            child: ReferenceFocusOutline(
              radius: 0,
              child: Material(
                color: const Color(0xfffaf8ff),
                child: InkWell(
                  key: ValueKey('rescuer-group-${group['id']}'),
                  onTap: widget.toggle,
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: photo.isEmpty
                                      ? const DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Color(0xffefe8ff),
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(12),
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.pets,
                                            color: Color(0xff7841f2),
                                            size: 24,
                                          ),
                                        )
                                      : AdoptionPhoto(
                                          photo,
                                          height: 44,
                                          radius: 12,
                                        ),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xff7841f2),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xfffaf8ff),
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        unread > 9 ? '9+' : '$unread',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          height: 18 / 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                countLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ExcludeSemantics(
                          child: AnimatedRotation(
                            key: ValueKey(
                              'rescuer-group-chevron-${group['id']}',
                            ),
                            turns: widget.expanded ? .25 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.ease,
                            child: SvgPicture.asset(
                              'assets/profile/icon-chevron-right.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(
                                _muted,
                                BlendMode.srcIn,
                              ),
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
          if (widget.expanded) ...[
            if (threads.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Text(
                  widget.history
                      ? 'No hay conversaciones para este caso.'
                      : 'Aún no hay mensajes para este caso.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: _muted,
                  ),
                ),
              ),
            for (var i = 0; i < threads.length; i++)
              RescuerThreadRow(
                threads[i],
                last: i == threads.length - 1,
                open: () async {
                  await context.push('/messages/${threads[i]['id']}');
                  if (mounted) widget.refresh();
                },
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Notice(error!, isError: true),
              ),
            if (threads.length < total)
              TextButton(
                key: ValueKey('rescuer-group-more-${group['id']}'),
                onPressed: busy ? null : more,
                child: Text(
                  busy
                      ? 'Cargando…'
                      : error != null
                      ? 'Volver a intentar'
                      : 'Ver más conversaciones',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class RescuerMessagesEmpty extends StatelessWidget {
  const RescuerMessagesEmpty({super.key, required this.onPublish});
  final VoidCallback onPublish;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'No tienes casos en adopción abiertos. Activa la adopción en un caso activo para recibir mensajes de interesados.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          height: 1.45,
          color: _muted,
        ),
      ),
      const SizedBox(height: 12),
      ReferenceFocusOutline(
        radius: 14,
        child: FilledButton(
          onPressed: onPublish,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: const Color(0xff7841f2),
            foregroundColor: const Color(0xfffbfbff),
            overlayColor: Colors.transparent,
            animationDuration: Duration.zero,
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          child: const Text('Ver mis casos'),
        ),
      ),
    ],
  );
}

class RescuerThreadRow extends StatefulWidget {
  const RescuerThreadRow(
    this.thread, {
    super.key,
    required this.open,
    required this.last,
  });
  final Json thread;
  final VoidCallback open;
  final bool last;
  @override
  State<RescuerThreadRow> createState() => _RescuerThreadRowState();
}

class _RescuerThreadRowState extends State<RescuerThreadRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final name = (thread['participant_name'] as String? ?? '').trim();
    final unread = (thread['unread_count'] as num? ?? 0).toInt();
    final avatar = ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xffefe8ff),
        ),
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            height: 1.2,
            letterSpacing: 0,
            fontWeight: FontWeight.w700,
            color: Color(0xff7841f2),
          ),
        ),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (MediaQuery.textScalerOf(context).scale(16) > 20)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Participante' : name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  height: 1.2,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(
                MatchThreadRow(
                  thread,
                  open: widget.open,
                ).activity(DateTime.now()),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 15.2 / 12,
                  letterSpacing: 0,
                  color: _muted,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Participante' : name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    height: 1.2,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                MatchThreadRow(
                  thread,
                  open: widget.open,
                ).activity(DateTime.now()),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 15.2 / 12,
                  letterSpacing: 0,
                  color: _muted,
                ),
              ),
            ],
          ),
        const SizedBox(height: 1),
        Text(
          thread['status'] == 'closed'
              ? 'Conversación cerrada'
              : thread['last_message'] as String? ?? 'Inicia la conversación',
          maxLines: MediaQuery.textScalerOf(context).scale(14) > 20 ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.55,
            letterSpacing: 0,
            color: _muted,
          ),
        ),
      ],
    );
    final trailing = <Widget>[
      if (unread > 0) ...[
        const SizedBox(width: 12),
        Semantics(
          label: '$unread mensajes sin leer',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xff7841f2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$unread',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 15.2 / 12,
                letterSpacing: 0,
                fontWeight: FontWeight.w500,
                color: Color(0xfffbfbff),
              ),
            ),
          ),
        ),
      ],
    ];
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: ReferenceFocusOutline(
        radius: 0,
        child: Material(
          color: hovered ? const Color(0xfffbfaff) : Colors.transparent,
          child: InkWell(
            onTap: widget.open,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: widget.last
                    ? null
                    : const Border(bottom: BorderSide(color: _line)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final enlarged =
                      MediaQuery.textScalerOf(context).scale(16) > 25 &&
                      constraints.maxWidth < 360;
                  if (enlarged) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [avatar, const Spacer(), ...trailing]),
                        const SizedBox(height: 12),
                        copy,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      avatar,
                      const SizedBox(width: 12),
                      Expanded(child: copy),
                      ...trailing,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
