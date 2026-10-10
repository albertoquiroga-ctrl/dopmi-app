import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui.dart';

final informationLinkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class InformationFrame extends StatelessWidget {
  const InformationFrame({
    super.key,
    required this.title,
    required this.fallback,
    required this.children,
  });
  final String title, fallback;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle: true,
      toolbarHeight: math.max(
        68,
        MediaQuery.textScalerOf(context).scale(18) + 24,
      ),
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: IconButton(
          tooltip: 'Regresar',
          icon: const Icon(Icons.arrow_back, size: 22, color: ink),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(fallback),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xffe6e2dd)),
      ),
    ),
    body: SafeArea(
      top: false,
      child: DefaultTextStyle.merge(
        style: const TextStyle(letterSpacing: 0),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: children,
        ),
      ),
    ),
  );
}

class InformationSection extends StatelessWidget {
  const InformationSection(this.title, {super.key, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        for (final child in children) ...[const SizedBox(height: 10), child],
      ],
    ),
  );
}

class InformationParagraph extends StatelessWidget {
  const InformationParagraph(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 15, height: 1.5, color: muted),
  );
}

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});
  Future<void> contact(BuildContext context, WidgetRef ref) async {
    try {
      final opened = await ref.read(informationLinkOpenerProvider)(
        Uri(
          scheme: 'mailto',
          path: 'soporte@dopmi.org',
          queryParameters: {'subject': 'Ayuda con Dopmi'},
        ),
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos abrir tu correo. Escribe a soporte@dopmi.org.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => InformationFrame(
    title: 'Sobre Nosotros',
    fallback: '/profile',
    children: [
      const InformationSection(
        'Ayudar se siente bien.',
        children: [
          InformationParagraph(
            'DopMi nació entre rescatistas, para rescatistas y para todas las personas que quieren sumar.',
          ),
        ],
      ),
      const InformationSection(
        'Nuestra historia',
        children: [
          InformationParagraph(
            'En México, rescatar a un perro o un gato se hace a pura fuerza de voluntad: publicaciones que se pierden en redes, grupos de WhatsApp y la suerte de que alguien vea el post a tiempo.',
          ),
          InformationParagraph(
            'Quienes rescatan no necesitan más ruido. Necesitan que su trabajo llegue a las personas correctas. Por eso hicimos DopMi: un solo lugar para adoptar, apoyar y darle seguimiento a cada rescate.',
          ),
        ],
      ),
      InformationSection(
        'Lo que hacemos',
        children: [
          for (final item in const [
            (
              'Adoptar',
              'Mascotas reales, publicadas por rescatistas reales. Hablas directo con quien la cuida.',
              'tab-adoption.svg',
            ),
            (
              'Apoyar',
              'Ayudas a reembolsar una necesidad pagada y aprobada, como comida, medicina o una consulta, y puedes seguir sus avances.',
              'tab-donate.svg',
            ),
            (
              'Rescatar',
              'Las rescatistas preparan sus casos, los envían a revisión y encuentran personas que quieren apoyar.',
              'intent-rescuer.svg',
            ),
          ])
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffe6e2dd)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0d15110d),
                    offset: Offset(0, 8),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xfffff8e0),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/profile/${item.$3}',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Color(0xff6b5000),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const InformationSection(
        'Por qué puedes confiar',
        children: [
          InformationParagraph(
            'No te pedimos que confíes. Te mostramos por qué puedes hacerlo.',
          ),
          InformationParagraph(
            'Personas verificadas. Los casos que reciben apoyo pertenecen a rescatistas con verificación aprobada.',
          ),
          InformationParagraph(
            'Mascotas reales. Revisamos cada publicación antes de mostrarla, y también cada cambio.',
          ),
          InformationParagraph(
            'Seguimiento con evidencia. Los avances y fotos públicos pasan por revisión. Tus documentos privados no se muestran en el caso.',
          ),
        ],
      ),
      const InformationSection(
        'Guardianes',
        children: [
          InformationParagraph(
            'Algunas personas eligen estar siempre. Con Guardián, tu apoyo mensual se asigna a gastos pagados y aprobados. Sólo se cobra cuando se puede asignar todo el neto. Puedes seguir los avances públicos de los casos que apoyaste.',
          ),
        ],
      ),
      const InformationSection(
        'No estás ayudando solo.',
        children: [
          InformationParagraph(
            'Cada pequeña ayuda suma, y aquí celebramos todas.',
          ),
        ],
      ),
      OutlinedButton(
        onPressed: () => context.push('/transparency'),
        child: const Text('Transparencia'),
      ),
      const SizedBox(height: 28),
      const Divider(color: Color(0xffe6e2dd)),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          TextButton(
            onPressed: () => context.push('/help'),
            child: const Text('Centro de ayuda'),
          ),
          TextButton(
            onPressed: () => context.push('/terms'),
            child: const Text('Términos y Condiciones'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final opened = await ref.read(informationLinkOpenerProvider)(
                  Uri.parse('https://dopmi.org/privacy-policy'),
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No pudimos abrir el aviso de privacidad. Inténtalo de nuevo.',
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No pudimos abrir el aviso de privacidad. Inténtalo de nuevo.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Aviso de privacidad'),
          ),
          TextButton(
            onPressed: () => contact(context, ref),
            child: const Text('Contacto'),
          ),
        ],
      ),
    ],
  );
}

class TransparencyScreen extends StatefulWidget {
  const TransparencyScreen({super.key});
  @override
  State<TransparencyScreen> createState() => _TransparencyScreenState();
}

class _TransparencyScreenState extends State<TransparencyScreen> {
  bool criteria = false;
  @override
  Widget build(BuildContext context) => InformationFrame(
    title: 'Transparencia',
    fallback: '/about',
    children: [
      const InformationSection(
        'Cuando apoyas un caso',
        children: [
          InformationParagraph(
            'Tu apoyo se asigna al gasto pagado y aprobado que elegiste de esa mascota: comida, medicina o atención veterinaria.',
          ),
        ],
      ),
      InformationSection(
        '¿A dónde va cada peso?',
        children: [
          const InformationParagraph('Cada apoyo tiene un desglose propio:'),
          for (final row in const [
            (
              'Neto asignado',
              'Es el importe que se destina al reembolso del gasto aprobado.',
            ),
            (
              'Costos de Stripe',
              'Son los costos del procesador de pago; no son una comisión de Dopmi.',
            ),
            (
              'Comisión Dopmi',
              'Se descuenta del importe aportado para mantener funcionando la plataforma.',
            ),
          ])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xfffff8e0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${row.$1}. ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: row.$2),
                  ],
                ),
                style: const TextStyle(fontSize: 14, height: 1.45, color: ink),
              ),
            ),
          const InformationParagraph(
            'Los costos reales se concilian con el pago. Consulta el detalle de tus movimientos en Mi historial; una estimación no sustituye el importe confirmado.',
          ),
          TextButton(
            onPressed: () => context.push('/payments'),
            child: const Text('Mi historial'),
          ),
        ],
      ),
      const InformationSection(
        'Cómo se usa el dinero',
        children: [
          InformationParagraph(
            'La rescatista documenta un gasto ya pagado antes de que pueda recibir apoyos. Dopmi revisa el caso, los comprobantes y el importe reembolsable. Sólo las fotos y los avances aprobados se muestran públicamente; los comprobantes y documentos privados permanecen protegidos.',
          ),
        ],
      ),
      const InformationSection(
        '¿Y si…?',
        children: [
          InformationParagraph(
            '…el gasto ya está cubierto? No se aceptan nuevos apoyos para exceder el monto aprobado.',
          ),
          InformationParagraph(
            '…un pago confirmado deja de poder asignarse? Se tramita la devolución íntegra; no se crea un fondo ni se reasigna tu apoyo puntual a otra mascota.',
          ),
          InformationParagraph(
            '…falta evidencia o aprobación? El gasto no puede recibir apoyos. La rescatista debe completar su expediente y pasar por revisión.',
          ),
        ],
      ),
      InformationSection(
        'Cuando eres Guardián',
        children: [
          const InformationParagraph(
            'Autorizas un monto mensual. El primer cobro es al activar y los siguientes en el aniversario mensual, sólo cuando se puede asignar todo el neto a gastos aprobados. Si no hay capacidad, ese mes se omite sin deuda ni cargos posteriores por el mes omitido.',
          ),
          const InformationParagraph(
            'Urgencias primero. La asignación comienza por la urgencia aprobada y después por la aprobación más antigua.',
          ),
          TextButton(
            onPressed: () => setState(() => criteria = !criteria),
            child: Text(criteria ? 'Ocultar criterios' : 'Ver criterios'),
          ),
          if (criteria)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xfffff8e0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Se ordena por urgencia aprobada y fecha de aprobación, con desempate estable. Se cubre el faltante antes de pasar al siguiente gasto, sin exceder su monto aprobado. Sólo se cobra cuando el neto completo puede asignarse.',
                style: TextStyle(fontSize: 13, height: 1.45, color: ink),
              ),
            ),
          const InformationParagraph(
            'Puedes seguir los casos que apoyaste desde Mi impacto. Cambiar tu monto aplica al siguiente ciclo; cancelar detiene los ciclos futuros y conserva el historial.',
          ),
        ],
      ),
      const Divider(color: Color(0xffe6e2dd)),
      const Text(
        'Los pagos de esta versión funcionan en modo prueba. No utilizan dinero real.',
        style: TextStyle(fontSize: 12, height: 1.45, color: muted),
      ),
    ],
  );
}
