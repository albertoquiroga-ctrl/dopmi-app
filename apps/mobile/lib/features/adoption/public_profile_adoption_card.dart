import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';
import 'community_repository.dart';
import 'community_ui.dart';

class PublicProfileAdoptionCard extends ConsumerStatefulWidget {
  const PublicProfileAdoptionCard(this.post, {super.key, required this.open});
  final Adoption post;
  final VoidCallback open;
  @override
  ConsumerState<PublicProfileAdoptionCard> createState() =>
      _PublicProfileAdoptionCardState();
}

class _PublicProfileAdoptionCardState
    extends ConsumerState<PublicProfileAdoptionCard> {
  bool? saved;
  bool busy = false;
  String? error;
  int generation = 0;
  @override
  void didUpdateWidget(covariant PublicProfileAdoptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      generation++;
      saved = null;
      busy = false;
      error = null;
    } else if (!busy && oldWidget.post.saved != widget.post.saved) {
      saved = null;
    }
  }

  Future<void> toggle() async {
    if (busy) return;
    final request = ++generation;
    final id = widget.post.id;
    final previous = saved ?? widget.post.saved;
    setState(() {
      saved = !previous;
      busy = true;
      error = null;
    });
    try {
      await ref.read(communityRepositoryProvider).favorite(id, !previous);
    } catch (cause) {
      if (mounted && request == generation) {
        setState(() {
          saved = previous;
          error = communityError(cause);
        });
      }
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isSaved = saved ?? post.saved;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffe6e2dd)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141d140d),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 258,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (post.photos.isNotEmpty)
                    AdoptionPhoto(post.photos.first, height: 258, radius: 0)
                  else
                    const ColoredBox(color: Color(0xffeeeeee)),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 142,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0x99000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${post.name}${post.data['age_months'] == null ? '' : ', ${post.age}'}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (post.data['distance_km'] is num &&
                            (post.data['distance_km'] as num).isFinite &&
                            (post.data['distance_km'] as num) >= 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${(post.data['distance_km'] as num).toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ReferenceFocusOutline(
                    radius: 22,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        tooltip: isSaved
                            ? 'Quitar de guardados'
                            : 'Guardar mascota',
                        onPressed: busy ? null : toggle,
                        style: IconButton.styleFrom(
                          backgroundColor: isSaved ? yellow : Colors.white,
                          side: const BorderSide(color: Color(0xffe6e2dd)),
                          shape: const CircleBorder(),
                        ),
                        icon: SvgPicture.asset(
                          'assets/profile/icon-bookmark.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ReferenceFocusOutline(
                      radius: 999,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x59f7cb2d),
                              offset: Offset(0, 4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed: widget.open,
                          style: FilledButton.styleFrom(
                            backgroundColor: yellow,
                            foregroundColor: ink,
                            minimumSize: const Size(0, 44),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(
                            'Conoce la historia de ${post.name}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Notice(error!, isError: true),
              ),
          ],
        ),
      ),
    );
  }
}
