import 'dart:async';
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

class _RescuerThreadsState extends ConsumerState<RescuerThreadsScreen>
    with WidgetsBindingObserver {
  int page = 1, petPages = 1, petTotal = 0, petGeneration = 0;
  bool history = false,
      unreadOnly = false,
      petsLoading = true,
      petsBusy = false;
  String? petFilter, petError;
  List<Json> pets = [];
  final scroll = ScrollController();
  final rail = ScrollController();
  VoidCallback? cancel;
  Timer? timer;
  int activePage = 1;
  String? activePet;
  bool activeUnread = false;
  double activeOffset = 0;
  double? pendingOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadPets();
    cancel = ref.read(communityRepositoryProvider).watch(const [
      'dopmi_threads',
      'dopmi_messages',
      'dopmi_notifications',
      'dopmi_adoptions',
      'dopmi_rescue_records',
    ], () => loadPets());
    timer = Timer.periodic(const Duration(seconds: 30), (_) => loadPets());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) loadPets();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 30), (_) => loadPets());
    }
  }

  @override
  void dispose() {
    petGeneration++;
    timer?.cancel();
    cancel?.call();
    scroll.dispose();
    rail.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> loadPets({bool more = false}) async {
    if (more && petsBusy) return;
    final current = ++petGeneration;
    final requestedHistory = history;
    final selected = petFilter;
    final targetPages = more ? petPages + 1 : petPages;
    setState(() {
      petsBusy = true;
      petError = null;
    });
    try {
      final repo = ref.read(communityRepositoryProvider);
      final entries = <Json>[];
      var total = 0, loadedPages = 0;
      // Reload the previously visible selector pages. If its selected case moved
      // to a later page, locate it before deciding that it became unavailable.
      for (
        var n = 1;
        n <= targetPages ||
            (selected != null &&
                entries.every((e) => e['id'] != selected) &&
                entries.length < total);
        n++
      ) {
        final result = await repo.rescuerInbox(n, history: requestedHistory);
        if (!mounted || current != petGeneration) return;
        total = result.total;
        final ids = entries.map((e) => e['id']).toSet();
        entries.addAll(result.items.where((e) => ids.add(e['id'])));
        loadedPages = n;
        if (n * 20 >= total || result.items.isEmpty) break;
      }
      if (!mounted || current != petGeneration) return;
      setState(() {
        pets = entries;
        petTotal = total;
        petPages = loadedPages;
        petsLoading = false;
        petsBusy = false;
        petError = null;
        if (petFilter != null &&
            pets.every((e) => e['id'] != petFilter || !selectorVisible(e))) {
          petFilter = null;
          page = 1;
        }
      });
    } catch (cause) {
      if (mounted && current == petGeneration) {
        setState(() {
          pets = [];
          petsLoading = false;
          petsBusy = false;
          petError = communityError(cause);
        });
      }
    }
  }

  void filterPet(String? value) => setState(() {
    petFilter = value;
    page = 1;
  });

  void showHistory(bool value) {
    if (value == history) return;
    setState(() {
      if (value) {
        activePage = page;
        activePet = petFilter;
        activeUnread = unreadOnly;
        activeOffset = scroll.hasClients ? scroll.offset : 0;
        page = 1;
        petFilter = null;
        unreadOnly = false;
        pendingOffset = 0;
      } else {
        page = activePage;
        petFilter = activePet;
        unreadOnly = activeUnread;
        pendingOffset = activeOffset;
      }
      history = value;
      pets = [];
      petPages = 1;
      petsLoading = true;
    });
    loadPets();
  }

  void restoreOffset() {
    if (pendingOffset == null || petsLoading || petError != null) return;
    final target = pendingOffset!;
    pendingOffset = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(target.clamp(0.0, scroll.position.maxScrollExtent));
      }
    });
  }

  // Historical groups remain available; active chats are always accessible via Todos.
  bool selectorVisible(Json pet) => history || pet['selector_active'] != false;

  Widget petSelector(BuildContext context) {
    if (petsLoading) return const Center(child: CircularProgressIndicator());
    if (petError != null) {
      return Column(
        children: [
          Notice(petError!, isError: true),
          TextButton(
            onPressed: () => loadPets(),
            child: const Text('Volver a intentar'),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('rescuer-pet-rail'),
      controller: rail,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RescuerPetFilter(
            name: 'Todos',
            selected: petFilter == null,
            onTap: () => filterPet(null),
          ),
          for (final pet in pets.where(selectorVisible)) ...[
            const SizedBox(width: 10),
            RescuerPetFilter(
              key: ValueKey('rescuer-pet-${pet['id']}'),
              name: pet['pet_name'] as String? ?? 'Mascota',
              photo: pet['photo'] as String? ?? '',
              unread: (pet['unread_count'] as num? ?? 0).toInt(),
              selected: petFilter == pet['id'],
              onTap: () => filterPet(pet['id'] as String),
            ),
          ],
          if (pets.length < petTotal) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              child: TextButton(
                key: const ValueKey('rescuer-pets-more'),
                onPressed: petsBusy ? null : () => loadPets(more: true),
                child: Text(
                  petsBusy ? 'Cargando…' : 'Ver más mascotas',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
          controller: scroll,
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
            petSelector(context),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      'Chats',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.44,
                        color: _ink,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    selected: unreadOnly,
                    child: ReferenceFocusOutline(
                      radius: 4,
                      child: InkWell(
                        key: const ValueKey('rescuer-unread-filter'),
                        onTap: () => setState(() {
                          unreadOnly = !unreadOnly;
                          page = 1;
                        }),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            unreadOnly ? 'Mostrar todos' : 'Sin leer',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: unreadOnly
                                  ? const Color(0xff7841f2)
                                  : _muted,
                              decoration: unreadOnly
                                  ? TextDecoration.underline
                                  : null,
                              decorationColor: const Color(0xff7841f2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            LiveSection<DataPage<Json>>(
              key: ValueKey('threads:$history:$page:$petFilter:$unreadOnly'),
              tables: const [
                'dopmi_threads',
                'dopmi_messages',
                'dopmi_notifications',
                'dopmi_adoptions',
                'dopmi_rescue_records',
              ],
              load: () => ref
                  .read(communityRepositoryProvider)
                  .rescuerThreads(
                    page,
                    groupId: petFilter,
                    unreadOnly: unreadOnly,
                    history: history,
                  ),
              builder: (result, refresh) {
                restoreOffset();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      key: const ValueKey('rescuer-chats-panel'),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xffebe8f3)),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0f7841f2),
                            offset: Offset(0, 2),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: result.items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
                              child: Text(
                                unreadOnly
                                    ? 'No tienes mensajes sin leer.'
                                    : history
                                    ? 'Aún no tienes conversaciones en tu historial.'
                                    : 'Aún no tienes mensajes',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  height: 1.45,
                                  color: _muted,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < result.items.length; i++)
                                  RescuerThreadRow(
                                    result.items[i],
                                    flat: true,
                                    key: ValueKey(
                                      'rescuer-thread-${result.items[i]['id']}',
                                    ),
                                    last: i == result.items.length - 1,
                                    open: () async {
                                      await context.push(
                                        '/messages/${result.items[i]['id']}',
                                      );
                                      if (mounted) {
                                        refresh();
                                        loadPets();
                                      }
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
                );
              },
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

class RescuerPetFilter extends StatelessWidget {
  const RescuerPetFilter({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
    this.photo = '',
    this.unread = 0,
  });
  final String name, photo;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(13) > 18;
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = large ? (painter.width + 18).clamp(78.0, 180.0) : 78.0;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name${unread > 0 ? ', $unread mensajes sin leer' : ''}',
      child: ReferenceFocusOutline(
        radius: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: selected
                      ? const Color(0x597841f2)
                      : const Color(0xffe6e2dd),
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0x247841f2)
                        : const Color(0x0f15110d),
                    offset: Offset(0, selected ? 8 : 2),
                    blurRadius: selected ? 22 : 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (photo.isNotEmpty)
                            AdoptionPhoto(photo, height: 52, radius: 99)
                          else
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xffefe8ff),
                                    Color(0xfff7f4ff),
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                'assets/profile/icon-messages.svg',
                                width: 22,
                                height: 22,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xff7841f2),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          if (unread > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xff7841f2),
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.white,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    height: 18 / 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: large ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: _ink,
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
    this.flat = false,
  });
  final Json thread;
  final VoidCallback open;
  final bool last, flat;
  @override
  State<RescuerThreadRow> createState() => _RescuerThreadRowState();
}

class _RescuerThreadRowState extends State<RescuerThreadRow> {
  bool hovered = false;
  Widget flatRow(BuildContext context) {
    final thread = widget.thread;
    final pet = (thread['pet_name'] as String? ?? 'Mascota').trim();
    final person = (thread['participant_name'] as String? ?? 'Participante')
        .trim();
    final photo = thread['photo'] as String? ?? '';
    final unread = (thread['unread_count'] as num? ?? 0).toInt();
    final large = MediaQuery.textScalerOf(context).scale(15) > 21;
    final avatar = ExcludeSemantics(
      child: SizedBox(
        width: 52,
        height: 52,
        child: photo.isEmpty
            ? Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xffefe8ff),
                ),
                child: Text(
                  person.isEmpty ? '?' : person.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff7841f2),
                  ),
                ),
              )
            : AdoptionPhoto(photo, height: 52, radius: 99),
      ),
    );
    final time = Text(
      MatchThreadRow(thread, open: widget.open).activity(DateTime.now()),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: Color(0xff9a9289),
      ),
    );
    final badge = unread == 0
        ? const SizedBox.shrink()
        : Semantics(
            label: '$unread mensajes sin leer',
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xff7841f2),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$unread',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 22 / 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          );
    final title = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: pet,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const TextSpan(
            text: ' · ',
            style: TextStyle(color: Color(0xff9a9289)),
          ),
          TextSpan(
            text: person,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xff4a4560),
            ),
          ),
        ],
      ),
      maxLines: large ? null : 1,
      overflow: large ? TextOverflow.visible : TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, height: 1.3),
    );
    final preview = Text(
      thread['status'] == 'closed'
          ? 'Conversación cerrada'
          : thread['last_message'] as String? ?? 'Inicia la conversación',
      maxLines: large ? 3 : 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 1.35,
        color: _muted,
      ),
    );
    return Semantics(
      button: true,
      label: '$pet, $person',
      child: ReferenceFocusOutline(
        radius: 0,
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: widget.open,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                  child: large
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                avatar,
                                const SizedBox(width: 12),
                                Expanded(child: time),
                                if (unread > 0) ...[
                                  const SizedBox(width: 8),
                                  badge,
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            title,
                            const SizedBox(height: 4),
                            preview,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            avatar,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: title),
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: time,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  preview,
                                ],
                              ),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: badge,
                              ),
                            ],
                          ],
                        ),
                ),
                if (!widget.last)
                  const Positioned(
                    left: 72,
                    right: 14,
                    bottom: 0,
                    child: SizedBox(
                      height: 1,
                      child: ColoredBox(color: Color(0xffebe8f3)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flat) return flatRow(context);
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
