import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/reference_focus_outline.dart';
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
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    bottomNavigationBar: const CommunityNav(3),
    body: SafeArea(
      bottom: false,
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/profile/icon-messages.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Mensajes',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        height: 1.25,
                        letterSpacing: -.4,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Habla con adoptantes',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.55,
                    letterSpacing: 0,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 16),
                LiveSection<DataPage<Json>>(
                  key: ValueKey(page),
                  tables: const [
                    'dopmi_threads',
                    'dopmi_messages',
                    'dopmi_notifications',
                  ],
                  load: () =>
                      ref.read(communityRepositoryProvider).threads(page),
                  builder: (result, refresh) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.items.isEmpty)
                        RescuerMessagesEmpty(
                          onPublish: () => context.push('/publish'),
                        )
                      else
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: _line),
                            borderRadius: BorderRadius.circular(24),
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
                            children: [
                              for (var i = 0; i < result.items.length; i++)
                                RescuerThreadRow(
                                  result.items[i],
                                  last: i == result.items.length - 1,
                                  open: () async {
                                    await context.push(
                                      '/messages/${result.items[i]['id']}',
                                    );
                                    refresh();
                                  },
                                ),
                            ],
                          ),
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
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class RescuerMessagesEmpty extends StatelessWidget {
  const RescuerMessagesEmpty({super.key, required this.onPublish});
  final VoidCallback onPublish;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0x1a7c3aed),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/navigation/rtab-messages.svg',
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
          'No tienes mensajes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            height: 1.2,
            letterSpacing: -.36,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 280),
          child: Text(
            'Cuando adoptantes te escriban sobre tus mascotas, verás las conversaciones aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: 0,
              color: _muted,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ReferenceFocusOutline(
          radius: 14,
          child: FilledButton.icon(
            onPressed: onPublish,
            icon: SvgPicture.asset(
              'assets/profile/empty-publish-plus.svg',
              width: 16,
              height: 16,
            ),
            label: const Text('Publicar caso'),
            style:
                FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.hovered)
                        ? const Color(0xff6d28d9)
                        : const Color(0xff7841f2),
                  ),
                ),
          ),
        ),
      ],
    ),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x337841f2), Color(0x33a478ff)],
          ),
        ),
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
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
                  fontWeight: FontWeight.w600,
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
                    fontWeight: FontWeight.w600,
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
          'Sobre ${thread['pet_name'] ?? 'la mascota'}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 15.2 / 12,
            letterSpacing: 0,
            color: _muted,
          ),
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
