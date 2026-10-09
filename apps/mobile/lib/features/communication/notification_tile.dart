import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/reference_focus_outline.dart';
import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart' show localDate, AdoptionPhoto;
import '../rescue/rescue_public_photo.dart';

String notificationTime(String value, {DateTime? now}) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '';
  final current = (now ?? DateTime.now()).toLocal();
  final elapsed = current.difference(date);
  if (elapsed.isNegative) return localDate(value);
  final days = DateTime.utc(
    current.year,
    current.month,
    current.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
  if (days == 0) {
    if (elapsed.inMinutes == 0) return 'Ahora';
    if (elapsed.inHours == 0) return 'Hace ${elapsed.inMinutes} min';
    return 'Hace ${elapsed.inHours} h';
  }
  if (days == 1) return 'Ayer';
  if (days < 7) return 'Hace $days días';
  return '${date.day}/${date.month}/${date.year}';
}

class NotificationTile extends StatelessWidget {
  const NotificationTile(
    this.item, {
    super.key,
    required this.onTap,
    this.rescuer = false,
  });
  final Json item;
  final VoidCallback? onTap;
  final bool rescuer;

  @override
  Widget build(BuildContext context) {
    final unread = item['read_at'] == null;
    final kind = item['kind'] == 'guardian'
        ? 'pet'
        : item['kind'] == 'contribution'
        ? 'donation'
        : item['kind'] == 'message'
        ? 'message'
        : item['rescue_id'] != null || item['kind'] == 'rescue'
        ? 'case'
        : 'pet';
    final large = MediaQuery.textScalerOf(context).scale(14) > 20;
    final tone = item['tone'];
    final photo = item['photo_path'] as String?;
    final toneBackground = switch (tone) {
      'positive' => const Color(0xffecfdf5),
      'negative' => const Color(0xfffef2f2),
      'pending' => const Color(0xfffffbeb),
      _ =>
        kind == 'message'
            ? const Color(0xffeff6ff)
            : kind == 'case'
            ? const Color(0xfffaf5ff)
            : const Color(0xfffefce8),
    };
    final title = Text(
      item['title'] as String,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 17 / 14,
        letterSpacing: 0,
        color: rescuer ? const Color(0xff151423) : ink,
      ),
    );
    final time = Tooltip(
      message: localDate(item['created_at'] as String),
      child: Text(
        notificationTime(item['created_at'] as String),
        style: TextStyle(
          fontSize: 12,
          height: 15 / 12,
          letterSpacing: 0,
          color: rescuer ? const Color(0xff4f4e5c) : muted,
        ),
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
                    : rescuer
                    ? const Color(0xffe3e4ed)
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
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: toneBackground,
                        ),
                        alignment: Alignment.center,
                        child: item['thumb_style'] == 'brand'
                            ? SvgPicture.asset(
                                'assets/profile/logo-paw.svg',
                                width: 40,
                                height: 40,
                              )
                            : photo != null && photo.isNotEmpty
                            ? item['photo_purpose'] == 'rescue'
                                  ? RescuePublicPhoto(
                                      photo,
                                      height: 40,
                                      radius: 20,
                                      compact: true,
                                    )
                                  : AdoptionPhoto(photo, height: 40, radius: 20)
                            : SvgPicture.asset(
                                kind == 'donation'
                                    ? 'assets/navigation/tab-donate.svg'
                                    : 'assets/profile/notif-$kind.svg',
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
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  letterSpacing: 0,
                                  color: rescuer
                                      ? const Color(0xff4f4e5c)
                                      : muted,
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
