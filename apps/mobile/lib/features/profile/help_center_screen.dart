import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'help_support_dialog.dart';

import '../../core/ui.dart';
import '../identity/experience_controller.dart';

// Audience controls presentation only. Financial answers describe implemented rules.
const _topics = <(String, String, List<(String, String)>)>[
  (
    'Cómo funcionan los apoyos',
    'both',
    [
      (
        'Cuando apoyas a un caso',
        'Puedes apoyar gastos ya pagados, documentados y aprobados. Se descuentan la comisión de Dopmi del 2 % y los costos de Stripe.',
      ),
      (
        'Cuando eres Guardián',
        'El primer cobro ocurre al activar. Después se cobra mensualmente sólo cuando el neto puede asignarse completo. Un mes omitido no genera deuda.',
      ),
    ],
  ),
  (
    'Apoyar',
    'donor',
    [
      (
        '¿Dónde veo todos mis apoyos?',
        'Abre el historial de apoyos desde tu perfil. El historial muestra los pagos y asignaciones confirmados por el servidor.',
      ),
      (
        'Mi pago no se completó, ¿se me cobró?',
        'Consulta el estado del pago en tu historial. Si tienes dudas sobre un cargo, contacta a soporte con la fecha y el monto; no compartas datos completos de tu tarjeta.',
      ),
    ],
  ),
  (
    'Guardián',
    'donor',
    [
      (
        '¿Cuándo cobra Guardián?',
        'El primer cobro ocurre al activar. Los siguientes son mensuales sólo cuando el neto puede asignarse completo. Un mes omitido no genera deuda.',
      ),
      (
        '¿Cómo cambio mi monto o cancelo?',
        'En Configuración abre Suscripción y pagos. Cancelar detiene ciclos futuros y conserva el historial del ciclo actual.',
      ),
    ],
  ),
  (
    'Adoptar',
    'donor',
    [
      (
        '¿Cómo contacto a una rescatista?',
        'Abre la mascota y confirma que deseas contactar. La conversación sólo es visible para sus participantes.',
      ),
      (
        '¿Dónde encuentro mis mascotas favoritas?',
        'En tu perfil abre Guardados para volver a los perfiles que guardaste en Adoptar.',
      ),
    ],
  ),
  (
    'Verificación',
    'rescuer',
    [
      (
        '¿Cambiar de modo me verifica como rescatista?',
        'No. Cambiar de modo sólo cambia la experiencia. La verificación requiere enviar información y recibir la revisión del equipo.',
      ),
      (
        '¿Cómo corrijo mi información?',
        'Abre el estado de verificación en Configuración, revisa las observaciones y envía tus correcciones para una nueva revisión.',
      ),
    ],
  ),
  (
    'Publicar casos',
    'rescuer',
    [
      (
        '¿Cómo publico un caso?',
        'Desde Publicar puedes crear un borrador y continuar después. El caso debe aprobarse antes de aparecer públicamente.',
      ),
      (
        '¿Por qué no se aprobó mi caso?',
        'Revisa las observaciones en Mis casos. Corrige el borrador y vuelve a enviarlo; los cambios requieren nueva revisión.',
      ),
    ],
  ),
  (
    'Fondos y evidencia',
    'rescuer',
    [
      (
        '¿Qué gastos puedo recibir apoyo para cubrir?',
        'Gastos ya pagados, documentados y aprobados. Conserva el comprobante y la evidencia para su revisión.',
      ),
      (
        '¿Dónde reviso mis transferencias?',
        'En tu perfil consulta los importes asignados y las transferencias. La cuenta bancaria se administra mediante Stripe Connect.',
      ),
    ],
  ),
  (
    'Mi cuenta',
    'both',
    [
      (
        '¿Cómo cambio entre Donante y Rescatista?',
        'En Configuración abre Cambiar tipo de cuenta. El cambio conserva tus datos y no concede permisos de verificación.',
      ),
      (
        '¿Cómo edito mis datos?',
        'En Configuración abre Información básica para editar tu nombre completo, teléfono y ciudad.',
      ),
      (
        '¿Cómo elimino mi cuenta?',
        'Abre Eliminar mi cuenta para revisar qué se borra, qué se conserva y las condiciones antes de confirmar.',
      ),
    ],
  ),
  (
    'Confianza y seguridad',
    'both',
    [
      (
        '¿Cómo reporto un caso o un perfil?',
        'En el caso o perfil público toca Reportar y confirma el motivo. El equipo revisa los reportes.',
      ),
      (
        '¿Cómo protegen mis datos de pago?',
        'Los pagos se procesan mediante Stripe. No compartas contraseñas, códigos de acceso ni datos completos de tarjeta con soporte.',
      ),
    ],
  ),
];

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});
  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  static final _footerStyle = TextButton.styleFrom(
    foregroundColor: muted,
    textStyle: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    ),
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  int? topic, openFaq;
  late final ExperienceController experience;

  @override
  void initState() {
    super.initState();
    experience = ref.read(experienceProvider);
    experience.addListener(refreshExperience);
  }

  void refreshExperience() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    experience.removeListener(refreshExperience);
    super.dispose();
  }

  Future<void> contact() => showHelpSupportDialog(
    context,
    topics: _topics.map((item) => item.$1).toList(),
    initialTopic: topic ?? 0,
  );

  @override
  Widget build(BuildContext context) {
    final rescuer = experience.value == AccountExperience.rescuer;
    final large = MediaQuery.textScalerOf(context).scale(18) > 25;
    bool primary(int i) =>
        _topics[i].$2 == 'both' ||
        _topics[i].$2 == (rescuer ? 'rescuer' : 'donor');
    Widget group(String title, bool main) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _topics.length; i++)
              if (primary(i) == main)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: topic == i
                        ? const Color(0xfffff8e0)
                        : Colors.white,
                    foregroundColor: topic == i ? const Color(0xff6b5000) : ink,
                    side: BorderSide(
                      color: topic == i ? yellow : const Color(0xffe6e2dd),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => setState(() {
                    topic = topic == i ? null : i;
                    openFaq = null;
                  }),
                  child: Text(_topics[i].$1),
                ),
          ],
        ),
      ],
    );
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: large ? 100 : 67,
        title: const Text(
          'Centro de ayuda',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            tooltip: 'Volver',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(rescuer ? '/rescuer/settings' : '/profile'),
            icon: SvgPicture.asset(
              'assets/profile/back.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xffe6e2dd)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            const Text(
              '¿En qué te ayudamos?',
              style: TextStyle(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Encuentra respuestas rápidas o escríbenos.',
              style: TextStyle(fontSize: 14, height: 1.45, color: muted),
            ),
            const SizedBox(height: 22),
            group(rescuer ? 'Para rescatistas' : 'Para adoptantes', true),
            const SizedBox(height: 16),
            group(
              rescuer ? 'También para adoptantes' : 'También para rescatistas',
              false,
            ),
            const SizedBox(height: 22),
            if (topic == null)
              const Text(
                'Elige un tema para ver las respuestas.',
                style: TextStyle(fontSize: 14, color: muted),
              )
            else ...[
              Text(
                _topics[topic!].$1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _topics[topic!].$3.length; i++) ...[
                if (topic == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    _topics[topic!].$3[i].$1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _topics[topic!].$3[i].$2,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: muted,
                    ),
                  ),
                ] else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xffe6e2dd)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            foregroundColor: openFaq == i
                                ? const Color(0xff6b5000)
                                : ink,
                          ),
                          onPressed: () =>
                              setState(() => openFaq = openFaq == i ? null : i),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _topics[topic!].$3[i].$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        ),
                        if (openFaq == i)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              _topics[topic!].$3[i].$2,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
              ],
              if (topic == 7)
                OutlinedButton(
                  onPressed: () => context.push('/account-privacy'),
                  child: const Text('Eliminar mi cuenta'),
                ),
            ],
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xffe6e2dd)),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0d15110d),
                    offset: Offset(0, 8),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '¿No encontraste lo que buscabas?',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escríbenos y te respondemos lo antes posible.',
                    style: TextStyle(fontSize: 14, height: 1.45, color: muted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xff0d0d0d),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: contact,
                    child: const Text('Contactar a soporte'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  TextButton(
                    style: _footerStyle,
                    onPressed: () => context.push('/about'),
                    child: const Text('Sobre nosotros'),
                  ),
                  const ExcludeSemantics(
                    child: Text(
                      '·',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  TextButton(
                    style: _footerStyle,
                    onPressed: () => context.push('/terms'),
                    child: const Text('Términos y Condiciones'),
                  ),
                  const ExcludeSemantics(
                    child: Text(
                      '·',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  TextButton(
                    style: _footerStyle,
                    onPressed: () => context.push('/privacy-notice'),
                    child: const Text('Aviso de privacidad'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
