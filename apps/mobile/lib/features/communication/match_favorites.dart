import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'match_favorites_empty.dart';
import '../../core/measurement.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../adoption/adopt_start_dialog.dart';

class MatchFavorites extends ConsumerStatefulWidget {
  const MatchFavorites({super.key, this.all = false, this.showAll});
  final bool all;
  final ValueChanged<bool>? showAll;
  @override
  ConsumerState<MatchFavorites> createState() => _MatchFavoritesState();
}

class _MatchFavoritesState extends ConsumerState<MatchFavorites> {
  bool busy = false, oldest = false;
  Future<DataPage<SavedEntry>> load() async {
    final repo = ref.read(communityRepositoryProvider);
    final first = await repo.savedAdoptions(1);
    if (!widget.all) return first;
    final items = <SavedEntry>[...first.items];
    for (var page = 2; (page - 1) * 20 < first.total; page++) {
      final next = await repo.savedAdoptions(page);
      if (next.items.isEmpty) break;
      items.addAll(next.items);
    }
    final unique = {for (final item in items) item.id: item};
    return DataPage(unique.values.toList(), first.total);
  }

  String? error;
  Future<void> contact(SavedEntry item) async {
    if (busy) return;
    final accepted = await confirmAdoptionContact(context);
    if (accepted != true || !mounted || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await ref
          .read(communityRepositoryProvider)
          .startThread(item.id);
      await ref.read(measurementControllerProvider)?.event('contact_started');
      if (mounted) await context.push('/messages/$id');
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LiveSection<DataPage<SavedEntry>>(
    key: ValueKey(widget.all),
    tables: const ['dopmi_favorites', 'dopmi_adoptions'],
    load: load,
    builder: (result, refresh) {
      final items = result.items.where((item) => item.available).toList();
      final side = widget.all
          ? (MediaQuery.sizeOf(context).width - 56) / 3
          : math.max(148.0, MediaQuery.textScalerOf(context).scale(100));
      if (widget.all && oldest) {
        final reversed = items.reversed.toList();
        items
          ..clear()
          ..addAll(reversed);
      }
      Widget card(int index) {
        final item = items[index];
        final photos = List<String>.from(item.data['photos'] as List? ?? []);
        return SizedBox(
          width: side,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.all ? 0 : 4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1a15110d),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Material(
                      color: const Color(0xffdddddd),
                      child: InkWell(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        onTap: () async {
                          await context.push('/adoptions/${item.id}');
                          refresh();
                        },
                        child: photos.isEmpty
                            ? const Icon(Icons.pets)
                            : AdoptionPhoto(photos.first, radius: 0),
                      ),
                    ),
                    Positioned(
                      left: widget.all ? 8 : 12,
                      right: widget.all ? 40 : 48,
                      bottom: widget.all ? 8 : 12,
                      child: IgnorePointer(
                        child: Text(
                          item.text('pet_name'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: widget.all ? 13 : 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0x73000000),
                                offset: Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: widget.all ? 8 : 10,
                      bottom: widget.all ? 8 : 10,
                      child: Material(
                        color: yellow,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Escribir sobre ${item.text('pet_name')}',
                          onPressed: busy ? null : () => contact(item),
                          constraints: BoxConstraints.tightFor(
                            width: widget.all ? 30 : 34,
                            height: widget.all ? 30 : 34,
                          ),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            overlayColor: Colors.transparent,
                            minimumSize: Size(
                              widget.all ? 30 : 34,
                              widget.all ? 30 : 34,
                            ),
                            maximumSize: Size(
                              widget.all ? 30 : 34,
                              widget.all ? 30 : 34,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: SvgPicture.string(
                            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"><path d="M7.9 20c1.91.98 4.1 1.24 6.19.75 2.09-.5 3.93-1.72 5.19-3.45 1.26-1.73 1.86-3.86 1.7-6-.17-2.14-1.09-4.15-2.61-5.66C16.85 4.11 14.84 3.19 12.7 3.02c-2.14-.17-4.27.44-6 1.7C5 6 3.75 7.82 3.25 9.91c-.5 2.09-.23 4.28.75 6.19L2 22l5.9-2z" stroke="#15110d" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                              ink,
                              BlendMode.srcIn,
                            ),
                          ),
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.all) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Volver a Mis match',
                style: IconButton.styleFrom(overlayColor: Colors.transparent),
                onPressed: () => widget.showAll?.call(false),
                icon: Transform.translate(
                  offset: const Offset(-4, -4),
                  child: SvgPicture.asset(
                    'assets/profile/back.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 26),
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final labels = [
                          const Text(
                            'Ordenar',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              height: 1.25,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          Text(
                            oldest ? 'Más antiguos' : 'Más recientes',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              height: 1.25,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w500,
                              color: muted,
                            ),
                          ),
                        ];
                        return MediaQuery.textScalerOf(context).scale(16) > 24
                            ? Wrap(spacing: 8, runSpacing: 4, children: labels)
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  labels.first,
                                  const SizedBox(width: 8),
                                  labels.last,
                                ],
                              );
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: TextButton(
                    key: const ValueKey('match-sort'),
                    onPressed: () => setState(() => oldest = !oldest),
                    style: TextButton.styleFrom(
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: Colors.transparent,
                      animationDuration: Duration.zero,
                      minimumSize: const Size.fromHeight(48),
                      padding: EdgeInsets.zero,
                    ),
                    child: Semantics(
                      label:
                          'Ordenar ${oldest ? 'Más antiguos' : 'Más recientes'}',
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Mis favoritos',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                if (result.total > 0)
                  SizedBox(
                    width: 80,
                    height:
                        MediaQuery.textScalerOf(context).scale(16) * 1.3 + 12,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top:
                              (MediaQuery.textScalerOf(context).scale(16) *
                                      1.3 +
                                  12 -
                                  44) /
                              2,
                          height: 44,
                          child: TextButton(
                            onPressed: () async {
                              widget.showAll?.call(true);
                            },
                            style: TextButton.styleFrom(
                              splashFactory: NoSplash.splashFactory,
                              overlayColor: Colors.transparent,
                              animationDuration: Duration.zero,
                              foregroundColor: ink,
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Ver más'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (error != null) Notice(error!, isError: true),
          if (items.isEmpty)
            const MatchFavoritesEmpty()
          else if (widget.all)
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.textScalerOf(context).scale(13) > 20
                    ? 1
                    : 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: items.length,
              itemBuilder: (_, index) => card(index),
            )
          else
            SizedBox(
              height: side + 4,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(width: 12),
                itemBuilder: (_, index) => card(index),
              ),
            ),
        ],
      );
    },
  );
}
