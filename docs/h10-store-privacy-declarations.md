# H10.4 — Declaraciones de privacidad de tiendas

Fecha de auditoría: 29 de septiembre de 2026.

Esta matriz describe el comportamiento del candidato interno Dopmi
`com.mycompany.dopmi`. No autoriza publicidad, personalización comercial ni
pagos reales. Analytics y Crashlytics requieren consentimientos separados y
permanecen apagados por defecto.

## Google Play — borrador importado y validado

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
servicio. El CSV se importó en Play Console el 29/9/2026. La vista previa
resultante confirmó los 15 tipos anteriores, cero datos compartidos, cifrado en
tránsito, eliminación completa en `/delete-account`, gestión parcial en
`/privacy-policy` y la política vigente. El titular autorizó el guardado y Play
Console confirmó `Change saved`. Publishing overview muestra exactamente un
cambio, `Data safety — Complete Data safety questionnaire`. Con autorización
separada se envió a revisión; las comprobaciones automáticas terminaron sin
incidencias y Publishing overview muestra `Your changes are now in review`.

El aviso de política todavía visible cita exclusivamente la ruta histórica
`/pages/privacy-policy`. La declaración de Política de privacidad ya contiene la
ruta vigente `/privacy-policy`; Google solicita guardar los cambios pendientes y
enviarlos a revisión. El aviso se mantiene como pendiente hasta su resolución
por Google.

## App Store — declaración objetivo

Datos vinculados con la identidad, cuenta o instalación y usados para
funcionalidad de la app o gestión de la cuenta:

- nombre, correo, teléfono y dirección;
- ID de usuario;
- ubicación aproximada cuando el usuario aporta ciudad o zona;
- mensajes dentro de la app;
- fotos o vídeos, archivos/documentos y otro contenido generado por el usuario;
- historial de compras tratado mediante Stripe para aportaciones de prueba y
  Guardián en test. Apple indica que la información de pago introducida fuera de
  la app y nunca accesible para el desarrollador no se declara; Dopmi no recibe
  números de tarjeta.

Datos técnicos vinculados a la instalación, recopilados sólo con el
consentimiento aplicable:

- interacción con el producto e identificador técnico para Analytics;
- datos de errores, rendimiento y diagnóstico para Crashlytics.

No se declaran publicidad de terceros, marketing del desarrollador, seguimiento
ni personalización comercial. Firebase no recibe correo, UUID de Supabase,
mensajes, documentos, ubicación, importes o referencias financieras.

La declaración publicada el 29/9/2026 contiene 15 tipos. Se retiraron publicidad
y marketing del correo, así como analítica atribuida a ubicación; todos los
tipos están configurados sin seguimiento. La ubicación aproximada se usa para
funcionalidad y personalización de resultados. App Store Connect recibió una
nueva versión 2.3.3 en preparación, con publicación manual y estas URLs:

- privacidad: `https://dopmi.org/privacy-policy`;
- opciones de privacidad: `https://dopmi.org/delete-account`;
- soporte: `https://dopmi.org/support`;
- marketing: `https://dopmi.org/`.

La ficha 2.3.3 no se añadió a revisión ni tiene compilación seleccionada; estos
cambios no autorizan ni provocan un lanzamiento público.

## Evidencia pública y operativa

- `https://dopmi.org/privacy-policy`, `/terms`, `/delete-account` y `/support`
  responden públicamente sin autenticación.
- La página de eliminación indica la ruta vigente: Perfil → Configuración →
  Privacidad y eliminación.
- El buzón `soporte@dopmi.org`, Resend SMTP/Auth y Apple Private Relay tienen
  entrega real comprobada. Las claves y el alias privado permanecen fuera del
  repositorio.
