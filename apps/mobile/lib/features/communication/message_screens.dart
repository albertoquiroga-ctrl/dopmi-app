import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';

class ThreadsScreen extends ConsumerStatefulWidget {
  const ThreadsScreen({super.key});
  @override
  ConsumerState<ThreadsScreen> createState() => _ThreadsState();
}

class _ThreadsState extends ConsumerState<ThreadsScreen> {
  int page = 1;
  @override
  Widget build(BuildContext context) => CommunityFrame(
    index: 3,
    back: false,
    children: [
      const Heading(
        'Una conversación,\nun nuevo comienzo.',
        'Ponte de acuerdo sobre sus necesidades, cuidados y el proceso de adopción.',
        eyebrow: 'MENSAJES',
      ),
      LiveSection<DataPage<Json>>(
        key: ValueKey(page),
        tables: const [
          'dopmi_threads',
          'dopmi_messages',
          'dopmi_notifications',
        ],
        load: () => ref.read(communityRepositoryProvider).threads(page),
        builder: (result, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.items.isEmpty)
              const Notice(
                'Abre una publicación y toca “Quiero conocerle” para iniciar una conversación.',
              ),
            for (final thread in result.items)
              Card(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Badge(
                    isLabelVisible: (thread['unread_count'] as num) > 0,
                    label: Text('${thread['unread_count']}'),
                    child: const CircleAvatar(
                      child: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                  title: Text(
                    '${thread['pet_name']} · ${thread['participant_name']}',
                  ),
                  subtitle: Text(
                    thread['status'] == 'closed'
                        ? 'Conversación cerrada'
                        : thread['last_message'] as String? ??
                              'Inicia la conversación',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    await context.push('/messages/${thread['id']}');
                    refresh();
                  },
                ),
              ),
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
  );
}

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<ThreadScreen> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<ThreadScreen>
    with WidgetsBindingObserver {
  final composer = TextEditingController();
  List<Json> messages = [];
  Json? thread;
  String? error, pendingId, pendingBody;
  bool loading = true,
      busy = false,
      olderBusy = false,
      hasOlder = true,
      foreground = true;
  int generation = 0;
  Timer? timer;
  VoidCallback? cancel;
  CommunityRepository get repo => ref.read(communityRepositoryProvider);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    cancel = repo.watch(['dopmi_messages', 'dopmi_threads'], refresh);
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (foreground) refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) refresh();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    cancel?.call();
    composer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refresh() async {
    final current = ++generation;
    try {
      final info = await repo.thread(widget.id);
      final recent = await repo.messages(widget.id);
      if (!mounted || current != generation) return;
      setState(() {
        thread = info;
        final merged = {
          for (final item in messages) item['id'] as String: item,
          for (final item in recent) item['id'] as String: item,
        };
        messages = merged.values.toList()
          ..sort((a, b) {
            final date = (a['created_at'] as String).compareTo(
              b['created_at'] as String,
            );
            return date == 0
                ? (a['id'] as String).compareTo(b['id'] as String)
                : date;
          });
        if (loading || messages.length <= 40) hasOlder = recent.length == 40;
        loading = false;
        error = null;
      });
      // Reading notifications is separate from receiving a message; a failed read can be retried.
      await repo.readThread(widget.id);
    } catch (cause) {
      if (mounted && current == generation) {
        setState(() {
          messages = [];
          thread = null;
          loading = false;
          error = communityError(cause);
        });
      }
    }
  }

  Future<void> older() async {
    if (messages.isEmpty || olderBusy) return;
    setState(() => olderBusy = true);
    final current = generation;
    try {
      final items = await repo.messages(widget.id, before: messages.first);
      if (mounted && current == generation) {
        setState(() {
          final ids = messages.map((m) => m['id']).toSet();
          messages = [
            ...items.where((m) => !ids.contains(m['id'])),
            ...messages,
          ];
          hasOlder = items.length == 40;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => olderBusy = false);
    }
  }

  Future<void> send() async {
    if (busy || composer.text.trim().isEmpty) return;
    pendingId ??= const Uuid().v4();
    pendingBody ??= composer.text.trim();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.sendMessage(widget.id, pendingId!, pendingBody!);
      if (!mounted) return;
      setState(() {
        pendingId = null;
        pendingBody = null;
        composer.clear();
      });
      await refresh();
    } catch (cause) {
      if (mounted) {
        setState(
          () => error =
              '${communityError(cause)} Tu mensaje está listo para reintentarse.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> close() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar conversación?'),
        content: const Text(
          'Conservarás el historial y ya no se podrán enviar mensajes en esta conversación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir conversando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar conversación'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await repo.closeThread(widget.id);
      await refresh();
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      Heading(
        thread == null ? 'Conversación' : 'Sobre ${thread!['pet_name']}',
        'Solo tú y la otra persona pueden leer estos mensajes.',
        eyebrow: 'ADOPCIÓN',
      ),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null) Notice(error!, isError: true),
      if (!loading && thread == null)
        ActionButton('Volver a cargar', onPressed: refresh),
      if (thread != null) ...[
        if (hasOlder && messages.isNotEmpty)
          TextButton(
            onPressed: olderBusy ? null : older,
            child: Text(olderBusy ? 'Cargando…' : 'Ver mensajes anteriores'),
          ),
        if (messages.isEmpty)
          const Notice('Saluda y cuéntale por qué te interesa esta adopción.'),
        for (final message in messages)
          Align(
            alignment: message['sender_id'] == repo.userId
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 370),
              decoration: BoxDecoration(
                color: message['sender_id'] == repo.userId
                    ? const Color(0xffeee7fc)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['sender_id'] == repo.userId
                        ? 'Tú'
                        : 'La otra persona',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: purple,
                    ),
                  ),
                  SelectableText(
                    message['body'] as String,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localDate(message['created_at'] as String),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        if (thread!['status'] == 'closed')
          const Notice(
            'Esta conversación está cerrada. Puedes consultar su historial.',
          )
        else ...[
          const SizedBox(height: 16),
          TextField(
            controller: composer,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            readOnly: busy || pendingId != null,
            decoration: const InputDecoration(labelText: 'Tu mensaje'),
          ),
          ActionButton(
            pendingId == null ? 'Enviar mensaje' : 'Reintentar envío',
            busy: busy,
            onPressed: send,
          ),
          if (pendingId != null && !busy)
            TextButton(
              onPressed: () => setState(() {
                pendingId = null;
                pendingBody = null;
              }),
              child: const Text('Cancelar reintento y editar'),
            ),
          TextButton(
            onPressed: busy ? null : close,
            child: const Text('Cerrar conversación'),
          ),
        ],
      ],
    ],
  );
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  int page = 1;
  String? error;
  bool busy = false;
  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      const Heading(
        'Lo nuevo en Dopmi.',
        'Respuestas del equipo y mensajes de la comunidad.',
        eyebrow: 'NOTIFICACIONES',
      ),
      if (error != null) Notice(error!, isError: true),
      LiveSection<DataPage<Json>>(
        key: ValueKey(page),
        tables: const ['dopmi_notifications'],
        load: () => ref.read(communityRepositoryProvider).notifications(page),
        builder: (result, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.items.isEmpty)
              const Notice(
                'Cuando haya una respuesta o un mensaje, lo encontrarás aquí.',
              ),
            for (final item in result.items)
              Card(
                color: item['read_at'] == null
                    ? const Color(0xffeee7fc)
                    : Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    item['kind'] == 'message'
                        ? Icons.chat_bubble_outline
                        : Icons.fact_check_outlined,
                    color: purple,
                  ),
                  title: Text(item['title'] as String),
                  subtitle: Text(
                    '${item['read_at'] == null ? 'Sin leer · ' : ''}${localDate(item['created_at'] as String)}',
                  ),
                  onTap: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await ref
                                .read(communityRepositoryProvider)
                                .readNotification(item['id'] as String);
                            if (!context.mounted) return;
                            await context.push(
                              item['thread_id'] == null
                                  ? '/my-adoptions/${item['post_id']}'
                                  : '/messages/${item['thread_id']}',
                            );
                            refresh();
                          } catch (cause) {
                            if (mounted) {
                              setState(() => error = communityError(cause));
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                ),
              ),
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
  );
}
