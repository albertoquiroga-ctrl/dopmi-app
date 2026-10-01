import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/measurement.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../adoption/adopt_start_dialog.dart';

class MatchFavorites extends ConsumerStatefulWidget {
  const MatchFavorites({super.key});
  @override
  ConsumerState<MatchFavorites> createState() => _MatchFavoritesState();
}

class _MatchFavoritesState extends ConsumerState<MatchFavorites> {
  bool busy = false;
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
    tables: const ['dopmi_favorites', 'dopmi_adoptions'],
    load: () => ref.read(communityRepositoryProvider).savedAdoptions(1),
    builder: (result, refresh) {
      final items = result.items.where((item) => item.available).toList();
      final side = math.max(148.0, MediaQuery.textScalerOf(context).scale(100));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mis favoritos',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              if (result.total > 0)
                TextButton(
                  onPressed: () async {
                    await context.push('/saved');
                    refresh();
                  },
                  style: TextButton.styleFrom(foregroundColor: ink),
                  child: const Text('Ver más'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (error != null) Notice(error!, isError: true),
          if (items.isEmpty) ...[
            const Center(
              child: SizedBox(
                width: 220,
                child: Text(
                  'Es tiempo de compartir una nueva aventura',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: FilledButton(
                onPressed: () => context.go('/adoptions'),
                child: const Text('Explorar →'),
              ),
            ),
          ] else
            SizedBox(
              height: side + 8,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final item = items[index];
                  final photos = List<String>.from(
                    item.data['photos'] as List? ?? [],
                  );
                  return SizedBox(
                    width: side,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
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
                                left: 12,
                                right: 48,
                                bottom: 12,
                                child: IgnorePointer(
                                  child: Text(
                                    item.text('pet_name'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
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
                                right: 10,
                                bottom: 10,
                                child: Material(
                                  color: yellow,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip:
                                        'Escribir sobre ${item.text('pet_name')}',
                                    onPressed: busy
                                        ? null
                                        : () => contact(item),
                                    constraints: const BoxConstraints.tightFor(
                                      width: 34,
                                      height: 34,
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                      color: ink,
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
                },
              ),
            ),
        ],
      );
    },
  );
}
