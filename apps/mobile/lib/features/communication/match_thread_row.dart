import '../../core/reference_focus_outline.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';

class MatchThreadRow extends ConsumerStatefulWidget {
  const MatchThreadRow(
    this.thread, {
    super.key,
    required this.open,
    this.last = false,
  });
  final Json thread;
  final VoidCallback open;
  final bool last;
  String activity(DateTime now) {
    final date = DateTime.tryParse(thread['updated_at'] as String? ?? '')
        ?.toLocal();
    if (date == null) return '';
    final today = DateTime(now.year, now.month, now.day);
    final days = today
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (days == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (days == 1) return 'Ayer';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  ConsumerState<MatchThreadRow> createState() => _MatchThreadRowState();
}

class _MatchThreadRowState extends ConsumerState<MatchThreadRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final open = widget.open;
    final last = widget.last;

    final unread = (thread['unread_count'] as num? ?? 0).toInt();
    final heading = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: thread['pet_name'] as String? ?? 'Mascota'),
          TextSpan(
            text: ' · ${thread['participant_name'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w500, color: muted),
          ),
        ],
      ),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        height: 1.2,
        letterSpacing: 0,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    );
    final timestamp = Text(
      widget.activity(DateTime.now()),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 15.2 / 12,
        letterSpacing: 0,
        color: muted,
      ),
    );
    return ReferenceFocusOutline(
      radius: 0,
      child: Material(
        color: hovered ? const Color(0xfffffbed) : Colors.transparent,
        child: InkWell(
          onTap: open,
          onHover: (value) => setState(() => hovered = value),
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(bottom: BorderSide(color: Color(0xffe6e2dd))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipOval(
                    child: LiveSection<Adoption?>(
                      key: ValueKey(thread['post_id']),
                      tables: const ['dopmi_adoptions'],
                      load: () async {
                        final id = thread['post_id'] as String?;
                        if (id == null) return null;
                        try {
                          return await ref
                              .read(communityRepositoryProvider)
                              .detail(id);
                        } catch (_) {
                          return null;
                        }
                      },
                      builder: (pet, _) => pet != null && pet.photos.isNotEmpty
                          ? AdoptionPhoto(pet.photos.first, radius: 0)
                          : const ColoredBox(
                              color: Color(0xffefeae3),
                              child: Icon(Icons.pets, color: muted),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (MediaQuery.textScalerOf(context).scale(16) > 20)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [heading, timestamp],
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: heading),
                            const SizedBox(width: 10),
                            timestamp,
                          ],
                        ),
                      const SizedBox(height: 1),
                      Text(
                        thread['status'] == 'closed'
                            ? 'Conversación cerrada'
                            : thread['last_message'] as String? ??
                                  'Inicia la conversación',
                        maxLines:
                            MediaQuery.textScalerOf(context).scale(14) > 20
                            ? 3
                            : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.55,
                          letterSpacing: 0,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 12),
                  Semantics(
                    label: '$unread mensajes sin leer',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: yellow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 15.2 / 12,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
