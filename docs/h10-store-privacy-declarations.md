# H10.4 — Declaraciones de privacidad de tiendas

Fecha de auditoría: 29 de septiembre de 2026.

Esta matriz describe el comportamiento del candidato interno Dopmi
`com.mycompany.dopmi`. No autoriza publicidad, personalización comercial ni
pagos reales. Analytics y Crashlytics requieren consentimientos separados y
permanecen apagados por defecto.

## Google Play — borrador para importar

El CSV preparado para Data Safety declara los siguientes tipos: nombre, correo,
ID de usuario, dirección, teléfono, historial de compras, ubicación aproximada,
otros mensajes dentro de la app,
fotos, informes de fallos, diagnóstico, archivos/documentos, interacciones con
la app, otro contenido generado por usuarios e identificadores de dispositivo.

- Se elimina `Vídeos` como tipo separado y `Historial de búsqueda dentro de la
  app`, porque el candidato no conserva esas búsquedas.
- No se declara publicidad ni personalización.
- No se declara información de tarjeta ni otros datos patrimoniales: Stripe
  Checkout recibe los datos de pago directamente y Dopmi conserva referencias
  técnicas y evidencia de la transacción, declaradas como historial de compras.
- No se declara compartición. Los proveedores procesan datos por cuenta de
  Dopmi y las publicaciones o mensajes visibles para otra persona resultan de
  acciones concretas iniciadas por el usuario; ambos son supuestos excluidos por
  la definición de compartición de Google Play.
- Analítica se limita a informes de fallos, diagnóstico, interacciones e
  identificadores técnicos y sólo después del consentimiento correspondiente.
- El correo y el ID de usuario son obligatorios; los campos de perfil y el
  contenido aportado por el usuario son opcionales o controlados por él.
- El transporte está cifrado.
- Creación de cuenta: correo/contraseña y OAuth.
- Eliminación completa: `https://dopmi.org/delete-account`.
- Eliminación parcial/derechos sobre datos: `https://dopmi.org/privacy-policy`.

El borrador corrige la declaración publicada en 2023, que atribuía publicidad,
personalización y compartición a datos que Dopmi usa para operar la cuenta y el
servicio. La importación y el envío final siguen pendientes de confirmación del
titular en Play Console.

## App Store — declaración objetivo

Datos vinculados con la identidad y usados para funcionalidad de la app o
gestión de la cuenta:

- nombre, correo, teléfono y dirección;
- ID de usuario;
- ubicación aproximada cuando el usuario aporta ciudad o zona;
- mensajes dentro de la app;
- fotos o vídeos, archivos/documentos y otro contenido generado por el usuario;
- información de pago e historial de compras tratados mediante Stripe para
  aportaciones de prueba y Guardián en test; Dopmi no recibe números de tarjeta.

Datos técnicos no vinculados, recopilados sólo con el consentimiento aplicable:

- interacción con el producto e identificador técnico para Analytics;
- datos de errores, rendimiento y diagnóstico para Crashlytics.

No se declaran publicidad de terceros, marketing del desarrollador, seguimiento
ni personalización comercial. Firebase no recibe correo, UUID de Supabase,
mensajes, documentos, ubicación, importes o referencias financieras.

La declaración publicada aún conserva siete tipos y usos antiguos: correo para
publicidad/marketing, ubicación para personalización, y una URL vieja de
privacidad. App Store Connect permite cambiar los tipos de datos inmediatamente,
pero la URL de privacidad y las URLs de soporte/marketing requieren una nueva
versión de App Store. Deben quedar así en el siguiente registro:

- privacidad: `https://dopmi.org/privacy-policy`;
- opciones de privacidad: `https://dopmi.org/delete-account`;
- soporte: `https://dopmi.org/support`;
- marketing: `https://dopmi.org/`.

## Evidencia pública y operativa

- `https://dopmi.org/privacy-policy`, `/terms`, `/delete-account` y `/support`
  responden públicamente sin autenticación.
- La página de eliminación indica la ruta vigente: Perfil → Configuración →
  Privacidad y eliminación.
- El buzón `soporte@dopmi.org`, Resend SMTP/Auth y Apple Private Relay tienen
  entrega real comprobada. Las claves y el alias privado permanecen fuera del
  repositorio.
