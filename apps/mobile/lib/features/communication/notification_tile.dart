import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart' show localDate;

class NotificationTile extends StatelessWidget {
  const NotificationTile(this.item, {super.key, required this.onTap});
  final Json item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = item['read_at'] == null;
    final kind = item['kind'] == 'message'
        ? 'message'
        : item['rescue_id'] != null || item['kind'] == 'rescue'
        ? 'case'
        : 'pet';
    final large = MediaQuery.textScalerOf(context).scale(14) > 20;
    final title = Text(
      item['title'] as String,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0,
        color: ink,
      ),
    );
    final time = Text(
      localDate(item['created_at'] as String),
      style: const TextStyle(
        fontSize: 12,
        height: 1.2,
        letterSpacing: 0,
        color: muted,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ReferenceFocusOutline(
        radius: 24,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: unread ? 'Sin leer' : 'Leída',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: unread
                    ? const Color(0xfff3d45d)
                    : const Color(0xffe6e2dd),
              ),
              boxShadow: unread
                  ? const [
                      BoxShadow(
                        color: Color(0x38f7cb2d),
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                splashFactory: NoSplash.splashFactory,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kind == 'message'
                              ? const Color(0xffeff6ff)
                              : kind == 'case'
                              ? const Color(0xfffaf5ff)
                              : const Color(0xfffefce8),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/profile/notif-$kind.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (large) ...[
                              title,
                              const SizedBox(height: 2),
                              time,
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: title),
                                  const SizedBox(width: 10),
                                  time,
                                ],
                              ),
                            if ((item['body'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item['body'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  letterSpacing: 0,
                                  color: muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
