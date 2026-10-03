import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../identity/experience_controller.dart';

class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble(this.message, {super.key, required this.mine});
  final Json message;
  final bool mine;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: ref.watch(experienceProvider),
    builder: (context, _) {
      final rescuer =
          ref.read(experienceProvider).value == AccountExperience.rescuer;
      final date = DateTime.tryParse(message['created_at'] as String? ?? '')
          ?.toLocal();
      final time = date == null
          ? ''
          : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      return LayoutBuilder(
        builder: (context, box) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            constraints: BoxConstraints(maxWidth: box.maxWidth * .78),
            decoration: BoxDecoration(
              color: mine
                  ? (rescuer ? purple : yellow)
                  : (rescuer
                        ? const Color(0xfff0eff8)
                        : const Color(0xffefede8)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(mine ? 24 : 12),
                bottomRight: Radius.circular(mine ? 12 : 24),
              ),
            ),
            child: Semantics(
              label: mine ? 'Mensaje enviado por ti' : 'Mensaje recibido',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message['body'] as String? ?? '',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.55,
                      color: mine && rescuer ? Colors.white : ink,
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 3),
                    Semantics(
                      label: 'Fecha del mensaje: ${date.toString()}',
                      child: ExcludeSemantics(
                        child: Text(
                          time,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            height: 1.2,
                            color: mine && rescuer
                                ? Colors.white70
                                : (mine ? muted : const Color(0xff777289)),
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
    },
  );
}
