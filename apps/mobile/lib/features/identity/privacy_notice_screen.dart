import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_document_frame.dart';

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) => LegalDocumentFrame(
    title: 'Aviso de Privacidad',
    lead: 'Lee cómo Dopmi trata tu información antes de crear tu cuenta.',
    children: [
      const LegalDocumentSection(
        'Qué cubre este aviso',
        'Dopmi facilita adopciones responsables, comunicación entre personas interesadas y rescatistas, publicación y moderación de casos de rescate, y aportaciones en favor de casos elegibles. Esta política explica qué datos personales puede tratar la nueva app, para qué los utiliza, con quién puede compartirlos y cómo puedes ejercer tus derechos.',
      ),
      const LegalDocumentSection(
        'Datos personales',
        'No se publican automáticamente tu domicilio, teléfono, correo privado, documentos de identidad, comprobantes privados, datos bancarios ni datos completos de tarjeta. Los borradores y correcciones permanecen privados mientras no sean aprobados. Las conversaciones se limitan a sus participantes; el acceso administrativo no concede lectura general de mensajes privados.',
      ),
      const LegalDocumentSection(
        'Tus derechos',
        'Puedes solicitar acceso, rectificación, cancelación u oposición al tratamiento de tus datos; revocar el consentimiento cuando proceda; y pedir que limitemos su uso o divulgación. También puedes solicitar la eliminación de tu cuenta y los datos asociados escribiendo a soporte@dopmi.org.',
      ),
      LegalDocumentSection(
        'Aviso integral',
        'Estos son extractos del aviso publicado. Consulta el documento integral para conocer al responsable, las categorías de datos, finalidades, proveedores, conservación, permisos y el procedimiento para ejercer tus derechos.',
        footer: TextButton(
          onPressed: () async {
            try {
              if (!await launchUrl(
                Uri.parse('https://dopmi.org/privacy-policy'),
                mode: LaunchMode.externalApplication,
              )) {
                throw const FormatException();
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No pudimos abrir el aviso. Intenta de nuevo.',
                    ),
                  ),
                );
              }
            }
          },
          child: const Text('Leer Aviso integral'),
        ),
      ),
    ],
  );
}
