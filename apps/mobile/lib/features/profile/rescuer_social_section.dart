import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import 'rescuer_profile_repository.dart';
import 'rescuer_settings_details.dart';
import 'rescuer_social_dialog.dart';

class RescuerSocialSection extends ConsumerWidget {
  const RescuerSocialSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      const SettingsSectionHeading('Redes sociales'),
      const SizedBox(height: 10),
      LiveSection<Json?>(
        key: ValueKey(ref.watch(identityControllerProvider).identity?.id),
        tables: const ['dopmi_rescuer_profiles'],
        load: () async {
          final owner = ref.read(identityControllerProvider).identity?.id;
          final data = await ref.read(rescuerProfileRepositoryProvider).load();
          if (data != null &&
              (owner == null ||
                  data['owner_id'] != owner ||
                  ref.read(identityControllerProvider).identity?.id != owner)) {
            throw const FormatException(
              'El perfil no corresponde a tu cuenta.',
            );
          }
          return data;
        },
        builder: (data, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in const [
              ('Instagram', 'instagram_url', 'icon-instagram'),
              ('Facebook', 'facebook_url', 'icon-facebook'),
            ]) ...[
              if (item.$1 == 'Facebook') const SizedBox(height: 10),
              SettingsDataRow(
                label: item.$1,
                value: (data?[item.$2] as String? ?? '').trim().isEmpty
                    ? 'Sin agregar'
                    : rescuerSocialDisplayValue(
                        item.$2,
                        data![item.$2] as String,
                      ),
                icon: item.$3,
                path: '/rescuer/profile/edit',
                onReturn: refresh,
                onEdit: data == null
                    ? null
                    : () async {
                        final saved = await editRescuerSocial(
                          context,
                          data,
                          item.$2,
                        );
                        if (context.mounted && saved == true) {
                          refresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Guardamos tu borrador. Los cambios pasan por revisión.',
                              ),
                            ),
                          );
                        }
                      },
                editLabel: 'Editar ${item.$1}',
              ),
            ],
            const SizedBox(height: 6),
            const SettingsFieldHint(
              'Los cambios de tu perfil público pasan por revisión.',
            ),
          ],
        ),
      ),
    ],
  );
}
