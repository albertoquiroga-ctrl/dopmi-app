import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../../core/reference_focus_outline.dart';
import 'match_favorites.dart';
import 'match_thread_row.dart';
import 'chat_message_bubble.dart';
import 'rescuer_threads_screen.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/experience_controller.dart';

class ThreadsScreen extends ConsumerStatefulWidget {
  const ThreadsScreen({super.key});
  @override
  ConsumerState<ThreadsScreen> createState() => _ThreadsState();
}

class _ThreadsState extends ConsumerState<ThreadsScreen> {
  int page = 1;
  bool allFavorites = false;
  bool showSearch = false;
  String query = '';
  final search = TextEditingController();
  final searchFocus = FocusNode();
  final scroll = ScrollController();
  double homeOffset = 0;
  void showFavorites(bool value) {
    if (value && scroll.hasClients) homeOffset = scroll.offset;
    setState(() => allFavorites = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.jumpTo(
        (value ? 0.0 : homeOffset).clamp(0.0, scroll.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final experience = ref.watch(experienceProvider);
    return ListenableBuilder(
      listenable: experience,
      builder: (context, _) => experience.value == AccountExperience.rescuer
          ? const RescuerThreadsScreen()
          : donor(context),
    );
  }

  Widget donor(BuildContext context) => PopScope(
    canPop: !allFavorites,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && allFavorites) showFavorites(false);
    },
    child: Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      bottomNavigationBar: const CommunityNav(3),
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
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
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: IconButton(
                      tooltip: 'Notificaciones',
                      onPressed: () => context.push('/notifications'),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xffd9d3ca),
                          width: 1.5,
                        ),
                        shape: const CircleBorder(),
                      ),
                      icon: SvgPicture.asset(
                        'assets/profile/icon-bell.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          ink,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: allFavorites ? 12 : 22),
            if (!allFavorites)
              const Text(
                'Mis match',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            if (!allFavorites) const SizedBox(height: 24),
            MatchFavorites(
              key: const ValueKey('match-favorites'),
              all: allFavorites,
              showAll: showFavorites,
            ),
            const SizedBox(height: 24),
            if (!allFavorites) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chats',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  ReferenceFocusOutline(
                    radius: 99,
                    child: IconButton(
                      tooltip: showSearch
                          ? 'Cerrar búsqueda'
                          : 'Buscar conversaciones',
                      onPressed: () {
                        if (showSearch) FocusScope.of(context).unfocus();
                        setState(() {
                          showSearch = !showSearch;
                          if (!showSearch) {
                            search.clear();
                            query = '';
                            page = 1;
                          }
                        });
                        if (showSearch) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && showSearch) {
                              searchFocus.requestFocus();
                            }
                          });
                        }
                      },
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        overlayColor: Colors.transparent,
                      ),
                      icon: Icon(
                        showSearch ? Icons.close : Icons.search,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
              if (showSearch) ...[
                const SizedBox(height: 12),
                TextField(
                  focusNode: searchFocus,
                  controller: search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Buscar por mascota o persona',
                    labelStyle: const TextStyle(color: muted),
                    floatingLabelStyle: const TextStyle(color: ink),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () => setState(() {
                              search.clear();
                              query = '';
                              page = 1;
                            }),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onSubmitted: (value) => setState(() {
                    query = value.trim();
                    page = 1;
                  }),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 18),
              LiveSection<DataPage<Json>>(
                key: ValueKey('$page:$query'),
                tables: const [
                  'dopmi_threads',
                  'dopmi_messages',
                  'dopmi_notifications',
                ],
                load: () => ref
                    .read(communityRepositoryProvider)
                    .threads(page, search: query),
                builder: (result, refresh) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (result.items.isEmpty)
                      Text(
                        query.isEmpty
                            ? 'Aún no tienes chats. Ponte en contacto con el rescatista de tu compañero favorito.'
                            : 'No encontramos conversaciones con “$query”.',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.45,
                          color: muted,
                        ),
                      ),
                    if (result.items.isNotEmpty)
                      Container(
                        key: const ValueKey('match-thread-list'),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xffe6e2dd)),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1415110d),
                              offset: Offset(0, 2),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < result.items.length; i++)
                              MatchThreadRow(
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
          ],
        ),
      ),
    ),
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ref.watch(experienceProvider),
    builder: (context, _) {
      final rescuer =
          ref.read(experienceProvider).value == AccountExperience.rescuer;
      final accent = rescuer ? const Color(0xffb995ff) : yellow;
      final foreground = rescuer ? Colors.white : ink;
      final textInk = rescuer ? const Color(0xff151423) : ink;
      final textMuted = rescuer ? const Color(0xff4f4e5c) : muted;
      final line = rescuer ? const Color(0xffe3e4ed) : const Color(0xffe6e2dd);
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 70,
          centerTitle: true,
          leadingWidth: 60,
          titleSpacing: 0,
          surfaceTintColor: Colors.transparent,
          shape: Border(bottom: BorderSide(color: line)),
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/messages'),
            icon: SvgPicture.asset(
              'assets/profile/back.svg',
              width: 20,
              height: 20,
            ),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                thread?['pet_name'] as String? ?? 'Conversación',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textInk,
                ),
              ),
              if ((thread?['participant_name'] as String? ?? '').isNotEmpty)
                Text(
                  thread!['participant_name'] as String,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: textMuted,
                  ),
                ),
            ],
          ),
          actions: [
            if (thread?['post_id'] != null)
              TextButton(
                onPressed: () =>
                    context.push('/adoptions/${thread!['post_id']}'),
                style: TextButton.styleFrom(
                  foregroundColor: textInk,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                child: const Text('Ver detalle'),
              ),
            if (thread != null && thread!['status'] != 'closed')
              PopupMenuButton<String>(
                tooltip: 'Opciones de conversación',
                enabled: !busy,
                onSelected: (_) => close(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'close',
                    child: Text('Cerrar conversación'),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (loading) const Center(child: CircularProgressIndicator()),
                  if (error != null) Notice(error!, isError: true),
                  if (!loading && thread == null)
                    ActionButton('Volver a cargar', onPressed: refresh),
                  if (thread != null) ...[
                    if (hasOlder && messages.isNotEmpty)
                      TextButton(
                        onPressed: olderBusy ? null : older,
                        child: Text(
                          olderBusy ? 'Cargando…' : 'Ver mensajes anteriores',
                        ),
                      ),
                    if (messages.isEmpty)
                      const Text(
                        'Saluda y cuéntale por qué te interesa esta adopción.',
                        style: TextStyle(color: muted),
                      ),
                    for (final message in messages)
                      ChatMessageBubble(
                        message,
                        mine: message['sender_id'] == repo.userId,
                      ),
                    if (thread!['status'] == 'closed')
                      const Notice(
                        'Esta conversación está cerrada. Puedes consultar su historial.',
                      ),
                  ],
                ],
              ),
            ),
            if (thread != null && thread!['status'] != 'closed')
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: composer,
                                minLines: 1,
                                maxLines: 5,
                                maxLength: 2000,
                                readOnly: busy || pendingId != null,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  height: 1.2,
                                  color: textInk,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Escribe un mensaje...',
                                  hintStyle: TextStyle(
                                    color: textMuted,
                                    fontSize: 16,
                                    height: 1.2,
                                  ),
                                  counterText: '',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: line),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: rescuer ? purple : ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: composer,
                              builder: (context, value, _) => SizedBox(
                                width: 40,
                                height:
                                    MediaQuery.textScalerOf(context).scale(16) *
                                        1.2 +
                                    26,
                                child: IconButton(
                                  tooltip: pendingId == null
                                      ? 'Enviar mensaje'
                                      : 'Reintentar envío',
                                  onPressed: busy || value.text.trim().isEmpty
                                      ? null
                                      : send,
                                  style: IconButton.styleFrom(
                                    backgroundColor: accent,
                                    disabledBackgroundColor: accent.withValues(
                                      alpha: .45,
                                    ),
                                    foregroundColor: foreground,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : SvgPicture.string(
                                          "<svg preserveAspectRatio=\"none\" overflow=\"visible\" style=\"display: block;\" width=\"15.9857\" height=\"15.9857\" viewBox=\"0 0 15.9857 15.9857\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><g id=\"Icon\" clip-path=\"url(#clip0_0_19)\"><path id=\"Vector\" d=\"M9.68201 14.4444C9.70731 14.5075 9.7513 14.5613 9.80808 14.5986C9.86485 14.636 9.93169 14.6551 9.99962 14.6533C10.0675 14.6516 10.1333 14.6291 10.1881 14.5889C10.2429 14.5487 10.2841 14.4927 10.3061 14.4284L14.6356 1.77308C14.6569 1.71406 14.661 1.65019 14.6473 1.58895C14.6336 1.5277 14.6028 1.47161 14.5585 1.42724C14.5141 1.38287 14.458 1.35205 14.3968 1.3384C14.3355 1.32474 14.2716 1.32881 14.2126 1.35013L1.55727 5.67959C1.493 5.70163 1.437 5.74281 1.3968 5.79759C1.3566 5.85238 1.33412 5.91815 1.33238 5.98608C1.33064 6.05402 1.34972 6.12085 1.38706 6.17763C1.42441 6.2344 1.47822 6.27839 1.54129 6.30369L6.82323 8.4218C6.99021 8.48865 7.14191 8.58862 7.26921 8.71569C7.3965 8.84276 7.49675 8.99428 7.5639 9.16114L9.68201 14.4444Z\" stroke=\"#FCFBFF\" stroke-width=\"1.33214\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/><path id=\"Vector_2\" d=\"M14.5563 1.43005L7.2695 8.7162\" stroke=\"#FCFBFF\" stroke-width=\"1.33214\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></g><defs><clipPath id=\"clip0_0_19\"><rect width=\"15.9857\" height=\"15.9857\" fill=\"white\"/></clipPath></defs></svg>",
                                          width: 16,
                                          height: 16,
                                          colorFilter: ColorFilter.mode(
                                            foreground,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (pendingId != null) ...[
                          ActionButton(
                            'Reintentar envío',
                            busy: busy,
                            onPressed: send,
                          ),
                          if (!busy)
                            TextButton(
                              onPressed: () => setState(() {
                                pendingId = null;
                                pendingBody = null;
                              }),
                              child: const Text('Cancelar reintento y editar'),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
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
                              item['rescue_id'] != null
                                  ? '/rescue/${item['rescue_id']}'
                                  : item['thread_id'] == null
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
