import 'package:flutter/material.dart';

import 'legal_document_frame.dart';
import 'identity_repository.dart';

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key, this.environment = 'test'});
  final String environment;
  @override
  Widget build(BuildContext context) {
    final versions = legalVersionsForEnvironment(environment);
    if (versions == null) {
      return const LegalDocumentFrame(
        title: 'Aviso de Privacidad',
        lead: 'Documento no disponible',
        children: [
          Text(
            'No pudimos confirmar el entorno de la cuenta. Intenta más tarde.',
          ),
        ],
      );
    }
    return LegalDocumentFrame(
      title: 'Aviso de Privacidad',
      lead: '${versions.privacy} · ${versions.date}',
      children: [
        const LegalDocumentSection(
          'Qué cubre este aviso',
          'Dopmi facilita adopciones responsables, comunicación entre personas interesadas y rescatistas, publicación y moderación de casos de rescate y aportaciones a casos elegibles. Trata datos de cuenta, publicaciones, mensajes, moderación y operaciones necesarios para prestar esas funciones.',
        ),
        const LegalDocumentSection(
          'Datos públicos y privados',
          'No se publican automáticamente tu domicilio exacto, teléfono, correo privado, documentos de identidad, comprobantes privados, datos bancarios ni datos completos de tarjeta. Los borradores y correcciones permanecen privados hasta su aprobación. Las conversaciones se limitan a sus participantes; el acceso administrativo no concede lectura general de mensajes privados.',
        ),
        LegalDocumentSection(
          'Proveedores y conexiones sociales',
          'La app utiliza Supabase para cuenta, datos y archivos; Stripe para métodos y operaciones; y servicios de verificación de teléfono cuando solicitas vincularlo. Los datos completos de tarjeta se capturan con Stripe. Las conexiones sociales son opcionales: la comprobación conserva identificadores y evidencia de conexión, no autoriza publicar ni leer mensajes privados de tus redes. Desconectar en Dopmi retira la comprobación local; el permiso del proveedor puede permanecer. Revocar el permiso en el proveedor es una operación distinta.${environment == 'production' ? ' Cloudflare Stream se utiliza para la carga, el procesamiento y la reproducción de videos y sus pósters. Los videos y pósters requieren moderación y aprobación antes de publicarse. Los comprobantes y las evidencias privados conservan el acceso autorizado.' : ''}',
        ),
        const LegalDocumentSection(
          'Medición y permisos',
          'Firebase (Google) incluye Analytics para eventos de uso y Crashlytics para errores y trazas técnicas. Son dos elecciones independientes en Cuenta y privacidad: ambas permanecen apagadas hasta que elijas activarlas. Aceptar este aviso no activa estas opciones. Estos servicios no sustituyen a Supabase como autenticación o base de datos del producto. Los permisos de fotos, cámara y ubicación se solicitan para la función que los necesita; puedes negarlos o cambiarlos en los ajustes del dispositivo. Puedes seleccionar tu ciudad manualmente. Aceptar este aviso no autoriza un cobro ni activa Guardián.',
        ),
        const LegalDocumentSection(
          'Conservación',
          'La eliminación de la cuenta no equivale al borrado inmediato de toda evidencia. Los registros que deban conservarse para pagos, disputas, seguridad u obligaciones aplicables requieren revisión. Los intentos sociales, recibos operativos y marcas temporales de revocación tienen una retención operativa específica. No prometemos un plazo general de eliminación de respaldos o registros que no esté acreditado.',
        ),
        const LegalDocumentSection(
          'Tus derechos y eliminación',
          'Puedes solicitar acceso, rectificación, cancelación u oposición, revocar consentimiento cuando proceda y pedir limitación de uso o divulgación. Usa Cuenta y privacidad o escribe a soporte@dopmi.org. El responsable del buzón coordina la comprobación privada de titularidad antes de consultar o borrar datos. Un correo, nombre o ID escrito por sí solo no basta. Para cuentas antiguas o sin acceso, si no puedes recuperar ningún acceso asociado, la solicitud queda pendiente de revisión por caso; recibirla no confirma un borrado. Los datos de la aplicación antigua se revisan por separado.',
        ),
        const LegalDocumentSection(
          'Seguridad, menores y cambios',
          'Dopmi está dirigido a mayores de 18 años. Aplicamos controles de acceso, separación de datos públicos y privados y autorización en el servidor. Ningún sistema es infalible. Si consideras que se trataron indebidamente datos de una persona menor de edad o necesitas ayuda, escribe a soporte@dopmi.org. Las actualizaciones indican su versión y requieren la aceptación que corresponda; puedes seguir consultando privacidad, cancelación y comprobantes propios mientras decides.',
        ),
        Text('Versión ${versions.privacy} · ${versions.date}'),
      ],
    );
  }
}
