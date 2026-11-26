import 'package:flutter/material.dart';

import '../../core/config/adoption_only_build.dart';
import '../../core/ui.dart';
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
        if (adoptionOnlyBuild)
          const Notice(
            'Esta versión está dedicada a adopciones. El uso de Stripe que describe este aviso corresponde a las funciones de pago cuando estén habilitadas.',
          ),
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
          'La app utiliza Supabase para cuenta, datos y archivos; Stripe para métodos y operaciones; y servicios de verificación de teléfono cuando solicitas vincularlo. Los datos completos de tarjeta se capturan con Stripe. Las conexiones sociales son opcionales: la comprobación conserva identificadores y evidencia de conexión, no autoriza publicar ni leer mensajes privados de tus redes. Desconectar en Dopmi retira la comprobación local; el permiso del proveedor puede permanecer. Revocar el permiso en el proveedor es una operación distinta.${environment == 'production' ? ' Cuando los videos estén habilitados, Cloudflare Stream se utilizará para la carga, el procesamiento y la reproducción de videos y sus pósters. Los videos y pósters requieren moderación y aprobación antes de publicarse. Los comprobantes y las evidencias privados conservan el acceso autorizado.' : ''}',
        ),
        const LegalDocumentSection(
          'Reportes de actividad de adopciones',
          'Dopmi registra automáticamente las visitas al detalle de una mascota publicada para elaborar sus reportes operativos. Guarda el identificador de tu cuenta, la mascota y la fecha de tu primera visita; cada cuenta cuenta una vez por mascota y las visitas de su autor no se suman. Los favoritos actuales, las personas que contactaron y las primeras respuestas se calculan con los registros de esas funciones. El panel recibe cifras agregadas, sin el contenido de conversaciones privadas. Este registro se guarda en Supabase y no se envía a Firebase ni a Meta por esta función. Es independiente de Analítica de uso y del diagnóstico de errores. Al eliminar tu cuenta se retiran tus observaciones del detalle.',
        ),
        const LegalDocumentSection(
          'Medición y permisos',
          'La Analítica de uso es opcional. Puedes activarla o desactivarla en Cuenta y privacidad. Descargar la app o aceptar este aviso no activa la analítica; respetamos las elecciones que ya guardaste. Firebase (Google) mide eventos de uso e identificadores técnicos para mejorar la app y puede estimar una zona aproximada por tu conexión. Los eventos de Dopmi no adjuntan mensajes, documentos, coordenadas, correo ni datos financieros. Dopmi puede vincular campañas con tu cuenta y primeros hitos para evaluar qué difusión ayuda a que más personas publiquen o contacten; no envía el contenido de mensajes a Firebase. La elección, el aviso y la fecha se registran en el servidor. Crashlytics para errores y la medición de publicaciones se eligen por separado y no se activan con Analítica. Estos servicios no sustituyen a Supabase como autenticación o base del producto. Los permisos de fotos, cámara y ubicación se solicitan para la función que los necesita; puedes negarlos o cambiarlos en los ajustes del dispositivo. Al publicar una mascota puedes colocar su punto manualmente en el mapa. Aceptar este aviso no autoriza un cobro ni activa Guardián.',
        ),
        const LegalDocumentSection(
          'Medición de anuncios con Meta en Android',
          'Adenda meta-ads-2026-11-22 · 22 de noviembre de 2026. '
              'Si activas «Medición de anuncios con Meta», Dopmi comparte con Meta '
              'el identificador de publicidad de Android, las versiones de Dopmi y '
              'de Android, y el tipo y la hora de tu primer mensaje elegible como '
              'adoptante o de tu primera ficha nueva y válida enviada a revisión '
              'desde que activaste esta preferencia. El envío incluye un código '
              'aleatorio del evento y el identificador de la app. Meta utiliza estos '
              'datos para atribuir resultados y optimizar la entrega de anuncios de '
              'Dopmi. La elección comienza apagada y se controla por separado de '
              'Analítica de uso, del diagnóstico de errores y de la medición de '
              'publicaciones. Puedes desactivarla en Cuenta y privacidad y seguir '
              'usando las funciones principales. Dopmi elimina de la cola el '
              'identificador publicitario y las versiones técnicas al completar la '
              'entrega o retirar el permiso. Las señales pendientes con más de '
              '24 horas se descartan y sus contextos se eliminan mediante la '
              'limpieza periódica. Se conserva una marca por cuenta y tipo de '
              'evento para evitar repetir la señal. Una solicitud ya despachada '
              'puede completarse después de desactivar la preferencia. Meta trata '
              'los datos que ya recibió conforme a su propia política.',
        ),
        const LegalDocumentSection(
          'Instalaciones y aperturas: medición opcional con Meta',
          'Adenda meta-lifecycle-2026-11-24 · 24 de noviembre de 2026. '
              'Si permites «Instalaciones y aperturas con Meta» en este dispositivo, '
              'Dopmi comparte directamente con Meta el identificador publicitario '
              'permitido de Android o iOS, el identificador de la app, las versiones '
              'de Dopmi y del sistema y la señal de instalación o apertura con su '
              'hora. Meta utiliza estos datos para atribuir instalaciones y medir '
              'y optimizar los anuncios de Dopmi. En iOS también se necesita el '
              'permiso de rastreo del sistema. Este permiso comienza apagado, se '
              'guarda en este dispositivo y es independiente de Analítica de uso, '
              'del diagnóstico y de los eventos de adopción con Meta. Continuar sin '
              'activarlo permite usar la app. Puedes retirarlo en Cuenta y '
              'privacidad; cerrar sesión no cambia esta elección del dispositivo. '
              'Dopmi no guarda el identificador publicitario para este envío ni '
              'adjunta datos de cuenta, mensajes, fichas o ubicación. Conserva '
              'localmente la elección, la versión de este aviso y marcas mínimas '
              'para evitar repetir instalaciones. Al apagarlo cancela los envíos '
              'pendientes; una solicitud ya despachada puede completarse. Meta '
              'trata los datos recibidos conforme a su propia política de privacidad.',
        ),
        const LegalDocumentSection(
          'Ubicación y mapas',
          'Dopmi solicita ubicación precisa mientras usas la app para mostrar adopciones a 25 km de tu ubicación actual. Esta ubicación se mantiene sólo en memoria y se envía para calcular cercanía, sin guardarse en tu perfil. Si niegas el permiso o apagas la ubicación, el listado de adopciones queda vacío y los demás apartados siguen disponibles. En modo Rescatista también explicamos y solicitamos el permiso al entrar: ayuda a encontrar adoptantes cercanos y propone tu ubicación actual como punto inicial de las mascotas nuevas. Puedes cambiar ese punto en Google Maps; si no das permiso, puedes elegirlo manualmente. El punto preciso de la mascota se guarda de forma privada para calcular distancias; públicamente se muestran ciudad y estado. No hacemos seguimiento en segundo plano. Google Maps puede procesar la vista del mapa, el punto preciso, tu consulta, dirección IP y datos técnicos; la geocodificación nativa de Google o Apple recibe el punto para identificar ciudad y estado. Puedes cambiar los permisos en los ajustes del dispositivo.',
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
          'Seguridad y cambios',
          'Aplicamos controles de acceso, separación de datos públicos y privados y autorización en el servidor. Ningún sistema es infalible. Si consideras que tus datos se trataron indebidamente o necesitas ayuda, escribe a soporte@dopmi.org. Las actualizaciones indican su versión y requieren la aceptación que corresponda; puedes seguir consultando privacidad, cancelación y comprobantes propios mientras decides.',
        ),
        Text('Versión ${versions.privacy} · ${versions.date}'),
      ],
    );
  }
}
