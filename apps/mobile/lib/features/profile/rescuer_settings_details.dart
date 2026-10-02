import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../identity/identity_controller.dart';
import 'rescuer_profile_repository.dart';

class RescuerSettingsDetails extends ConsumerWidget {
  const RescuerSettingsDetails({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 22),
      const SettingsSectionHeading('Redes sociales'),
      const SizedBox(height: 10),
      LiveSection<Json?>(
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
                    : data![item.$2] as String,
                icon: item.$3,
                path: '/rescuer/profile/edit',
                onReturn: refresh,
                editLabel: 'Editar ${item.$1}',
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Los cambios de tu perfil público pasan por revisión.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.4,
                letterSpacing: 0,
                color: Color(0xff554e48),
              ),
            ),
          ],
        ),
      ),
      const SettingsBankingSection(),
    ],
  );
}

class SettingsSectionHeading extends StatelessWidget {
  const SettingsSectionHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Color(0xff15110d),
      ),
    ),
  );
}

class SettingsDataRow extends StatelessWidget {
  const SettingsDataRow({
    super.key,
    required this.label,
    required this.value,
    required this.path,
    required this.editLabel,
    this.icon,
    this.onReturn,
  });
  final String label, value, path, editLabel;
  final String? icon;
  final VoidCallback? onReturn;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe6e2dd)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xffefede8),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/profile/$icon.svg',
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  Color(0xff554e48),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.4,
                  letterSpacing: 0,
                  color: Color(0xff554e48),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  color: Color(0xff15110d),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: editLabel,
          onPressed: () async {
            await context.push(path);
            if (context.mounted) onReturn?.call();
          },
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            maximumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            splashFactory: NoSplash.splashFactory,
            overlayColor: Colors.transparent,
          ),
          icon: SvgPicture.asset(
            'assets/profile/icon-edit.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Color(0xff15110d),
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    ),
  );
}

class SettingsBankingSection extends StatelessWidget {
  const SettingsBankingSection({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 22),
      const SettingsSectionHeading('Datos bancarios'),
      const SizedBox(height: 10),
      const SettingsDataRow(
        label: 'Cuenta Stripe',
        value: 'Configurar pagos con Stripe',
        path: '/connect',
        editLabel: 'Gestionar datos bancarios en Stripe',
      ),
      const SizedBox(height: 10),
      const Text(
        'Administra tus datos bancarios directamente en Stripe.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          height: 1.4,
          letterSpacing: 0,
          color: Color(0xff554e48),
        ),
      ),
    ],
  );
}
