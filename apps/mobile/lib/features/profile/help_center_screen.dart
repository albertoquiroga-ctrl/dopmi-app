import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'help_support_dialog.dart';

import '../../core/ui.dart';
import '../../core/design_tokens.dart';
import '../../core/donor_canvas.dart';
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
        'Al registrarte autorizas evaluaciones mensuales. Sólo se cobra cuando el neto puede asignarse completo a gastos aprobados. Si no hay capacidad, el registro continúa sin cargo ni deuda para ese mes.',
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
        'Sólo se cobra cuando la evaluación puede asignar todo el neto a gastos aprobados. Un registro sin capacidad no genera cargo, deuda ni recobro; se evalúa el siguiente ciclo.',
      ),
      (
        '¿Cómo cambio mi monto o cancelo?',
        'En Perfil abre Suscripción y pagos. Cancelar detiene ciclos futuros y conserva el historial del ciclo actual.',
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
        'Abre Mis match en la barra inferior y consulta Mis favoritos para volver a las mascotas que guardaste en Adoptar.',
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
        'En tu perfil de Rescatista abre Verificación, revisa las observaciones y envía tus correcciones para una nueva revisión.',
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
        'Desde Perfil usa la tarjeta para cambiar a modo Rescatista o Adoptante. El cambio conserva tus datos y no concede permisos de verificación.',
      ),
      (
        '¿Cómo edito mis datos?',
        'Para cambiar los datos de tu cuenta, entra a Información básica desde las opciones de Cuenta y privacidad en Perfil.',
      ),
      (
        '¿Cómo elimino mi cuenta?',
        'Toca “Eliminar mi cuenta” en esta sección para revisar qué se borra, qué se conserva y las condiciones antes de confirmar.',
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
    splashFactory: NoSplash.splashFactory,
    overlayColor: Colors.transparent,
    animationDuration: Duration.zero,
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
  bool? selectedRescuer;
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
    initialTopic: topic ?? 7,
  );

  @override
  Widget build(BuildContext context) {
    final rescuer = experience.value == AccountExperience.rescuer;
    final large = MediaQuery.textScalerOf(context).scale(18) > 25;
    final audienceRescuer = selectedRescuer ?? rescuer;
    final visibleTopics = audienceRescuer
        ? const [7, 4, 5, 6, 0, 8]
        : const [7, 3, 2, 1, 0, 8];
    final audienceTabs = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffefede8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const audiences = [(false, 'Adoptante'), (true, 'Rescatista')];
            var requiredWidth = 4.0;
            for (final audience in audiences) {
              final painter = TextPainter(
                text: TextSpan(
                  text: audience.$2,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                textScaler: MediaQuery.textScalerOf(context),
                textDirection: Directionality.of(context),
              )..layout();
              requiredWidth += painter.width + 16;
              painter.dispose();
            }
            final sideBySide = requiredWidth <= constraints.maxWidth;
            final buttonWidth = sideBySide
                ? (constraints.maxWidth - 4) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final audience in audiences)
                  SizedBox(
                    width: buttonWidth,
                    child: Semantics(
                      selected: audienceRescuer == audience.$1,
                      button: true,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: Colors.transparent,
                          animationDuration: Duration.zero,
                          backgroundColor: audienceRescuer == audience.$1
                              ? DopmiTokens.orangeButton
                              : Colors.transparent,
                          foregroundColor: audienceRescuer == audience.$1
                              ? Colors.white
                              : muted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          minimumSize: const Size(0, 44),
                          textStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: audienceRescuer == audience.$1
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          if (audienceRescuer == audience.$1) return;
                          setState(() {
                            selectedRescuer = audience.$1;
                            topic = null;
                            openFaq = null;
                          });
                        },
                        child: Text(audience.$2, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
    final topicChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final i in visibleTopics)
          Semantics(
            selected: topic == i,
            button: true,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
                animationDuration: Duration.zero,
                backgroundColor: topic == i
                    ? rescuer
                          ? DopmiTokens.saffronSoft
                          : const Color(0xfffff8e0)
                    : Colors.white,
                foregroundColor: ink,
                side: BorderSide(
                  color: topic == i
                      ? rescuer
                            ? const Color(0x66fab919)
                            : yellow
                      : DopmiTokens.line,
                ),
                shape: const StadiumBorder(),
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
          ),
      ],
    );
    return PopScope(
      canPop: GoRouter.maybeOf(context)?.canPop() ?? true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          GoRouter.maybeOf(context)?.go(rescuer ? '/settings' : '/profile');
        }
      },
      child: Scaffold(
        backgroundColor: rescuer ? Colors.white : cream,
        appBar: AppBar(
          backgroundColor: rescuer ? const Color(0xf5ffffff) : null,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          toolbarHeight: large ? 100 : 67,
          title: const Text(
            'Centro de ayuda',
            style: TextStyle(
              fontSize: 18,
              height: 1.25,
              letterSpacing: -0.36,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          leadingWidth: 60,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: IconButton(
              tooltip: 'Volver',
              style: IconButton.styleFrom(overlayColor: Colors.transparent),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(rescuer ? '/settings' : '/profile'),
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
        body: DonorCanvas(
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              children: [
                const Text(
                  '¿En qué te ayudamos?',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    letterSpacing: -0.48,
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
                audienceTabs,
                const SizedBox(height: 18),
                topicChips,
                const SizedBox(height: 22),
                if (topic == null)
                  const Text(
                    'Elige un tema para ver las respuestas.',
                    style: TextStyle(fontSize: 14, color: muted),
                  )
                else ...[
                  Text(
                    _topics[topic!].$1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: rescuer ? DopmiTokens.orange : ink,
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
                          color: openFaq == i
                              ? const Color(0xfffffdf8)
                              : Colors.white,
                          border: Border.all(
                            color: openFaq == i
                                ? const Color(0x66f7cb2d)
                                : DopmiTokens.line,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                splashFactory: NoSplash.splashFactory,
                                overlayColor: Colors.transparent,
                                animationDuration: Duration.zero,
                                padding: const EdgeInsets.all(16),
                                foregroundColor: ink,
                              ),
                              onPressed: () => setState(
                                () => openFaq = openFaq == i ? null : i,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _topics[topic!].$3[i].$1,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.25,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ExcludeSemantics(
                                    child: RotatedBox(
                                      quarterTurns: openFaq == i ? 1 : 0,
                                      child: SvgPicture.asset(
                                        'assets/profile/icon-chevron-right.svg',
                                        width: 20,
                                        height: 20,
                                        colorFilter: const ColorFilter.mode(
                                          muted,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (openFaq == i)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
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
                      style: OutlinedButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: Colors.transparent,
                        animationDuration: Duration.zero,
                      ),
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
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: Colors.transparent,
                          animationDuration: Duration.zero,
                          backgroundColor: ink,
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: contact,
                        child: const Text(
                          'Contactar a soporte',
                          textAlign: TextAlign.center,
                        ),
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
        ),
      ),
    );
  }
}
