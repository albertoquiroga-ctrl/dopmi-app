import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/donor_notification_button.dart';
import '../../core/config/adoption_only_build.dart';
import '../../core/ui.dart';
import '../../core/media/media_store.dart';
import '../../core/media/photo_runtime.dart';
import '../../core/media/remote_photo.dart';
import '../../core/reference_focus_outline.dart';
import '../../core/design_tokens.dart';
import '../../core/donor_canvas.dart';
import 'match_favorites.dart';
import 'match_thread_row.dart';
import 'notification_tile.dart';
import 'notification_frame.dart';
import 'chat_message_bubble.dart';
import 'chat_photo_repository.dart';
import 'rescuer_threads_screen.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/experience_controller.dart';

class ThreadsScreen extends ConsumerStatefulWidget {
  const ThreadsScreen({super.key, this.personal = false});
  final bool personal;
  @override
  ConsumerState<ThreadsScreen> createState() => _ThreadsState();
}

class _ThreadsState extends ConsumerState<ThreadsScreen> {
  int page = 1;
  int favoritesRevision = 0;
  bool allFavorites = false;
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
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final experience = ref.watch(experienceProvider);
    return ListenableBuilder(
      listenable: experience,
      builder: (context, _) =>
          !widget.personal && experience.value == AccountExperience.rescuer
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
      bottomNavigationBar: CommunityNav(
        3,
        selectedPath: widget.personal ? '/messages' : null,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 188),
          children: [
            SizedBox(
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SvgPicture.asset(
                    'assets/profile/logo-paw-naranja.svg',
                    width: 40,
                    height: 40,
                    semanticsLabel: 'Dopmi',
                  ),
                  const DonorNotificationButton(),
                ],
              ),
            ),
            SizedBox(height: allFavorites ? 12 : 20),
            if (!allFavorites)
              Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Mis match',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    height: 1.1,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            if (!allFavorites) const SizedBox(height: 12),
            MatchFavorites(
              key: ValueKey(('match-favorites', favoritesRevision)),
              all: allFavorites,
              showAll: showFavorites,
            ),
            const SizedBox(height: 12),
            if (!allFavorites) ...[
              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Chats',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
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
                              Container(
                                key: const ValueKey('match-chats-empty'),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: DopmiTokens.line),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Aún no tienes chats. Ponte en contacto con el rescatista de tu compañero favorito.',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        height: 1.45,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 44),
                                      ),
                                      onPressed: () => context.go('/adoptions'),
                                      child: const Text('Descubrir'),
                                    ),
                                  ],
                                ),
                              ),
                            if (result.items.isNotEmpty)
                              Container(
                                key: const ValueKey('match-thread-list'),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: DopmiTokens.line),
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
                                    for (
                                      var i = 0;
                                      i < result.items.length;
                                      i++
                                    )
                                      MatchThreadRow(
                                        result.items[i],
                                        last: i == result.items.length - 1,
                                        open: () async {
                                          await context.push(
                                            '/messages/${result.items[i]['id']}',
                                          );
                                          if (!mounted) return;
                                          // The first send may remove a favorite even
                                          // when Realtime has not reached this device.
                                          setState(() => favoritesRevision++);
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
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

final chatPhotoPickerProvider = Provider<Future<XFile?> Function()>(
  (ref) =>
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      ),
);

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
  Uint8List? photoBytes;
  String? photoMessageId, attachmentPath;
  int compositionGeneration = 0;
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
  void didUpdateWidget(ThreadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      compositionGeneration++;
      composer.clear();
      photoBytes = null;
      photoMessageId = attachmentPath = pendingId = pendingBody = null;
      messages = [];
      thread = null;
      loading = true;
      busy = false;
      refresh();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    cancel = repo.watch(['dopmi_messages', 'dopmi_threads'], refresh);
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (foreground) {
        refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      refresh();
    }
  }

  @override
  void dispose() {
    generation++;
    compositionGeneration++;
    timer?.cancel();
    cancel?.call();
    composer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refresh() async {
    final current = ++generation;
    final actor = repo.userId;
    try {
      final info = await repo.thread(widget.id);
      final recent = await repo.messages(widget.id);
      if (!mounted || current != generation || repo.userId != actor) {
        return;
      }
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
        if (loading || messages.length <= 40) {
          hasOlder = recent.length == 40;
        }
        loading = false;
        error = null;
      });
    } catch (cause) {
      if (mounted && current == generation) {
        setState(() {
          messages = [];
          thread = null;
          loading = false;
          error = communityError(cause);
        });
      }
      return;
    }
    // A receipt failure must not discard a successfully authorized history.
    try {
      await repo.readThread(widget.id);
    } catch (_) {
      if (mounted && current == generation) {
        setState(
          () => error = 'No pudimos marcar la conversación como leída. Volveremos a intentarlo.',
        );
      }
    }
  }

  Future<void> older() async {
    if (messages.isEmpty || olderBusy) {
      return;
    }
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
      if (mounted && current == generation) {
        setState(() => error = communityError(cause));
      }
    } finally {
      if (mounted) {
        setState(() => olderBusy = false);
      }
    }
  }

  Future<void> send() async {
    if (busy ||
        thread == null ||
        thread!['status'] == 'closed' ||
        (composer.text.trim().isEmpty && photoBytes == null)) {
      return;
    }
    final currentRepo = repo;
    final actor = currentRepo.userId;
    final threadId = widget.id;
    final current = compositionGeneration;
    pendingId ??= photoMessageId ?? const Uuid().v4();
    pendingBody ??= composer.text.trim();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (photoBytes != null) {
        final photos = ref.read(chatPhotoRepositoryProvider);
        if (photos.userId != actor) {
          throw StateError('La sesión cambió. Vuelve a adjuntar la foto.');
        }
        if (attachmentPath == null) {
          final path = await photos.upload(threadId, pendingId!, photoBytes!);
          if (!mounted ||
              current != compositionGeneration ||
              currentRepo.userId != actor) {
            if (currentRepo.userId == actor && photos.userId == actor) {
              try {
                await photos.discard(path);
              } catch (_) {
                /* Pending cleanup is best effort. */
              }
            }
            return;
          }
          attachmentPath = path;
        }
        if (!mounted ||
            current != compositionGeneration ||
            currentRepo.userId != actor ||
            photos.userId != actor) {
          return;
        }
        await photos.send(threadId, pendingId!, pendingBody!, attachmentPath!);
      } else {
        await currentRepo.sendMessage(threadId, pendingId!, pendingBody!);
      }
      if (!mounted ||
          current != compositionGeneration ||
          currentRepo.userId != actor) {
        return;
      }
      setState(() {
        pendingId = null;
        pendingBody = null;
        photoMessageId = attachmentPath = null;
        photoBytes = null;
        composer.clear();
      });
      await refresh();
    } catch (cause) {
      if (mounted &&
          current == compositionGeneration &&
          currentRepo.userId == actor) {
        setState(
          () => error =
              '${communityError(cause)} Tu mensaje está listo para reintentarse.',
        );
      }
    } finally {
      if (mounted &&
          current == compositionGeneration &&
          currentRepo.userId == actor) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> pickPhoto() async {
    if (busy || pendingId != null || thread?['status'] == 'closed') {
      return;
    }
    final actor = repo.userId;
    final current = ++compositionGeneration;
    final id = const Uuid().v4();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected = await ref.read(chatPhotoPickerProvider)();
      if (selected == null) {
        return;
      }
      final bytes = await selected.readAsBytes();
      if (!mounted ||
          current != compositionGeneration ||
          repo.userId != actor) {
        return;
      }
      if (bytes.isEmpty || bytes.length > MediaPurpose.chatPhoto.inputLimit) {
        throw const FormatException('Elige una foto de hasta 5 MB.');
      }
      setState(() {
        photoBytes = bytes;
        photoMessageId = id;
        attachmentPath = null;
      });
    } catch (cause) {
      if (mounted && current == compositionGeneration && repo.userId == actor) {
        setState(() => error = communityError(cause));
      }
    } finally {
      if (mounted && current == compositionGeneration && repo.userId == actor) {
        setState(() => busy = false);
      }
    }
  }

  void clearComposition() {
    if (busy) {
      return;
    }
    final path = attachmentPath;
    if (path != null) {
      ref.read(chatPhotoRepositoryProvider).discard(path).ignore();
    }
    setState(() {
      compositionGeneration++;
      photoBytes = null;
      photoMessageId = attachmentPath = pendingId = pendingBody = null;
    });
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
      final accent = rescuer ? ink : yellow;
      final foreground = rescuer ? Colors.white : ink;
      final textInk = rescuer ? const Color(0xff151423) : ink;
      final textMuted = rescuer ? const Color(0xff4f4e5c) : muted;
      final line = rescuer ? const Color(0xffe3e4ed) : const Color(0xffe6e2dd);
      final adopterId = thread?['adopter_id'];
      final showPetCover =
          !rescuer && adopterId is String && adopterId == repo.userId;
      final coverPath = thread?['photo'];
      final participant = thread?['participant_name'] as String? ?? '';
      final textScaler = MediaQuery.textScalerOf(context);
      final compactDetail =
          showPetCover &&
          MediaQuery.sizeOf(context).width < 360 &&
          textScaler.scale(12) >= 18;
      final headerHeight =
          textScaler.scale(18) * 1.25 +
          (participant.isEmpty ? 0 : textScaler.scale(12) * 1.2 + 2) +
          16;
      final title = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: showPetCover
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            thread?['pet_name'] as String? ?? 'Conversación',
            maxLines: showPetCover ? 1 : null,
            overflow: showPetCover ? TextOverflow.ellipsis : null,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -.36,
              color: textInk,
            ),
          ),
          if (participant.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              participant,
              maxLines: showPetCover ? 1 : null,
              overflow: showPetCover ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.2,
                letterSpacing: 0,
                color: textMuted,
              ),
            ),
          ],
        ],
      );

      void openDetail() {
        final info = thread!;
        final owned = rescuer && info['owner_id'] == repo.userId;
        final path = owned
            ? info['case_id'] != null
                  ? '/rescue/${info['case_id']}'
                  : '/my-adoptions/${info['post_id']}'
            : '/adoptions/${info['post_id']}';
        context.push(path);
      }

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: showPetCover
              ? headerHeight.clamp(70.0, double.infinity).toDouble()
              : 70,
          centerTitle: !showPetCover,
          leadingWidth: showPetCover ? 52 : 60,
          titleSpacing: 0,
          surfaceTintColor: Colors.transparent,
          shape: Border(bottom: BorderSide(color: line)),
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Volver',
            style: IconButton.styleFrom(overlayColor: Colors.transparent),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/messages'),
            icon: SvgPicture.asset(
              'assets/profile/back.svg',
              width: 20,
              height: 20,
            ),
          ),
          title: showPetCover
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ThreadPetCover(
                      source: coverPath is String && coverPath.isNotEmpty
                          ? adoptionPhotoSource(repo, coverPath)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Flexible(child: title),
                  ],
                )
              : title,
          actions: [
            if (thread?['post_id'] != null &&
                (!adoptionOnlyBuild || thread?['case_id'] == null))
              ReferenceFocusOutline(
                key: const ValueKey('chat-detail-link'),
                radius: 0,
                outlineInset: compactDetail
                    ? const EdgeInsets.all(4)
                    : EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical:
                            (48 - textScaler.scale(12) * 1.2).clamp(0, 48) / 2,
                      ),
                child: compactDetail
                    ? IconButton(
                        tooltip: 'Ver detalle',
                        onPressed: openDetail,
                        color: textInk,
                        icon: const Icon(Icons.info_outline),
                      )
                    : TextButton(
                        onPressed: openDetail,
                        style: TextButton.styleFrom(
                          foregroundColor: textInk,
                          overlayColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        child: const Text('Ver detalle'),
                      ),
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
        body: DonorCanvas(
          enabled: !rescuer,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (loading)
                      const Center(child: CircularProgressIndicator()),
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
                          if (photoBytes != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      photoBytes!,
                                      key: const ValueKey('chat-photo-preview'),
                                      width: 96,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const SizedBox(
                                        width: 96,
                                        height: 80,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Quitar foto',
                                    onPressed: busy ? null : clearComposition,
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
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
                                    height: 1.25,
                                    letterSpacing: 0,
                                    color: textInk,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Escribe un mensaje...',
                                    hintMaxLines: 1,
                                    constraints: BoxConstraints(
                                      minHeight:
                                          MediaQuery.textScalerOf(context)
                                                  .scale(16) *
                                              1.25 +
                                          26,
                                    ),
                                    hintStyle: TextStyle(
                                      color: textMuted,
                                      fontSize: 16,
                                      height: 1.25,
                                      letterSpacing: 0,
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
                              IconButton(
                                key: const ValueKey('chat-attach-photo'),
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(40, 40),
                                  maximumSize: const Size(40, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                tooltip: 'Adjuntar foto',
                                onPressed: busy || pendingId != null
                                    ? null
                                    : pickPhoto,
                                icon: SvgPicture.asset(
                                  'assets/profile/paperclip.svg',
                                  width: 22,
                                  height: 22,
                                  colorFilter: ColorFilter.mode(
                                    const Color(0xff5c574f),
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: composer,
                                builder: (context, value, _) => SizedBox(
                                  width: 40,
                                  height:
                                      MediaQuery.textScalerOf(context)
                                              .scale(16) *
                                          1.25 +
                                      26,
                                  child: IconButton(
                                    tooltip: pendingId == null
                                        ? 'Enviar mensaje'
                                        : 'Reintentar envío',
                                    onPressed:
                                        busy ||
                                            (value.text.trim().isEmpty &&
                                                photoBytes == null)
                                        ? null
                                        : send,
                                    style: IconButton.styleFrom(
                                      overlayColor: Colors.transparent,
                                      backgroundColor: accent,
                                      disabledBackgroundColor: accent
                                          .withValues(alpha: .5),
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
                                onPressed: clearComposition,
                                child: const Text(
                                  'Cancelar reintento y editar',
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ThreadPetCover extends StatelessWidget {
  const _ThreadPetCover({required this.source});

  final PhotoRef? source;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    const placeholder = ColoredBox(
      color: Color(0xffefeae3),
      child: Icon(Icons.pets, color: muted, size: 20),
    );
    final photo = source;
    return SizedBox.square(
      key: const ValueKey('chat-pet-cover'),
      dimension: size,
      child: ClipOval(
        child: photo == null
            ? placeholder
            : RemotePhoto(
                source: photo,
                width: size,
                height: size,
                loading: placeholder,
                unavailable: (_) => placeholder,
                excludeFromSemantics: true,
              ),
      ),
    );
  }
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
  Widget build(BuildContext context) => NotificationFrame(
    rescuer: ref.watch(experienceProvider).value == AccountExperience.rescuer,
    children: [
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
              NotificationTile(
                item,
                rescuer:
                    ref.watch(experienceProvider).value ==
                    AccountExperience.rescuer,
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
            if (result.total > 20)
              NotificationPagination(
                page: page,
                total: result.total,
                change: (value) => setState(() => page = value),
              ),
          ],
        ),
      ),
    ],
  );
}
