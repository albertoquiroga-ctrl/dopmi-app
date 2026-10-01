import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';

class MatchThreadRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = (thread['unread_count'] as num? ?? 0).toInt();
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: open,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Color(0xffe8e2d9))),
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
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: thread['pet_name'] as String? ?? 'Mascota',
                          ),
                          TextSpan(
                            text: ' · ${thread['participant_name'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      thread['status'] == 'closed'
                          ? 'Conversación cerrada'
                          : thread['last_message'] as String? ??
                                'Inicia la conversación',
                      maxLines: MediaQuery.textScalerOf(context).scale(14) > 20
                          ? 3
                          : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activity(DateTime.now()),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(height: 6),
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
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
