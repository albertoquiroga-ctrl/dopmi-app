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

Por decisión del titular, el envío de esa ficha se aplaza hasta que terminen los
demás pendientes y exista el candidato final que se seleccionará para revisión.
Debe revalidarse junto con el resultado de Google antes del cierre del candidato;
no requiere rehacer la declaración App Privacy ya publicada.

## Evidencia pública y operativa

- `https://dopmi.org/privacy-policy`, `/terms`, `/delete-account` y `/support`
  responden públicamente sin autenticación.
- La página de eliminación indica la ruta vigente: Perfil → Configuración →
  Privacidad y eliminación.
- El buzón `soporte@dopmi.org`, Resend SMTP/Auth y Apple Private Relay tienen
  entrega real comprobada. Las claves y el alias privado permanecen fuera del
  repositorio.
# Conciliación y publicación de Analítica — 21/11/2026

Este corte supersede las declaraciones históricas anteriores para el delta de
medición; no equivale a consentimiento de los usuarios. Fuenteaf0e2274,
CI44878177593 cuatroSUCCESS. La elección opcional puede aparecer preseleccionada,
pero el SDK sólo se habilita después de una acción real. OFF previos respetados;
Crashlytics y publicaciones conservan controles separados.

## Apple: publicado y cotejado

App Store Connect confirmó publicación de tres categorías. Se mantienen16tipos
vinculados y trackingNO:

| Categoría | Finalidades publicadas |
|---|---|
| ID de usuario | Funcionalidad de la app, Publicidad o marketing del desarrollador, Análisis de datos. |
| Ubicación aproximada | Funcionalidad de la app, Personalización del producto, Análisis de datos. |
| Interacción con el producto | Análisis de datos, Publicidad o marketing del desarrollador. |

ID de dispositivo ya conservaba Análisis/Funcionalidad; ubicación exacta funcional
ya estaba declarada. La captación se declara por evaluar difusión/campañas y
primeros hitos, sin activar tracking, anuncios personalizados ni envíos a Meta.
Recibo privado `.tools/analytics-choice-20261121/stores/apple-published.private.json`.
La publicación de App Privacy no publica por sí misma el binario iOS ni acredita
TestFlight instalado.

## Play: publicado y cotejado

Se guardó y envió un único cambio Data Safety. La actividad y el detalle de Play
confirman **Submission165 → Published**,21/nov16:49→16:59 según horas mostradas,
con exactamente un cambio Data Safety. La publicación ya está cotejada; no sigue
en revisión. No se creó ni promovió otra release pública. Recibo y capturas en
`.tools/analytics-choice-20261121/stores/play-published.private.json`; envío y
preview se conservan como evidencia anterior, no como estado vigente.

| Categoría publicada | Tratamiento/finalidades |
|---|---|
| User IDs | Requeridos/no efímeros; conserva Functionality/Security/Account management y añade Analytics/Advertising or marketing. |
| App interactions | Recopiladas/no compartidas/opcionales/no efímeras; Analytics y Advertising or marketing. |
| Approximate location | Opcional/no efímera; Functionality y Analytics por la geografía general del SDK. |
| Precise location | Nueva declaración: recopilada, no compartida, no efímera, opcional; Functionality y Personalization para el punto privado de mascota y cercanía. |

La ubicación precisa sin seleccionar era una discrepancia previa; se corrigió en
el formulario enviado, sin atribuir GPS a los eventos propios. Las coordenadas
no se publican; el mapa es una acción del usuario y los proveedores del servicio
se clasifican según las excepciones aplicables de Data Safety, no como una
exención de declarar su recopilación. Audiencia16–17/18+ conservada.
No marcar todo User ID opcional: sigue sosteniendo la cuenta. La finalidad de
captación en el piloto orgánico es una interpretación conservadora del uso, no
una regla que convierta cualquier referrer en publicidad. Publicar el formulario
no concede consentimiento ni promueve la nueva versión de la app.

## Textos públicos

Landingc95be7f56b877f84a9e52e5fac628b61c4ceb11b, Vercel
dpl_6w6vWZdwDGecMSBEnqaGRPonMzGb READY. `/privacy-policy` HTTP200,
28811B/SHA2565df1686a…9a741cb; `/terms` HTTP200,3955B/SHA256ad358012…cdb0054c,
exactos a los textos autorizados. Versiones generales conservadas y aviso de
elección propio usage-analytics-2026-11-21. Recibo estable privado
`.tools/analytics-choice-20261121/legal/publication.receipt.private.json` y
revisión independiente sin P1/P2. No se promete anonimato del SDK: los eventos
Dopmi no añaden contenido de mensajes/GPS, pero Firebase puede estimar zona
aproximada por conexión y usa identificadores técnicos.

Fuentes de clasificación: [Apple](https://developer.apple.com/app-store/app-privacy-details/),
[Google Play](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).

## Delta de reportes automáticos — 26/11/2026

Producto0e3f3a9d46a90876223020a6d53f682327c8208d retira la pantalla inicial y
registra cuenta + mascota + primera fecha en Supabase, sin depender de Firebase.
El reporte administrativo usa agregados; el registro sigue vinculado a la cuenta.
Firebase, diagnóstico y publicidad conservan sus controles opcionales. Este delta
no reconstruye históricos ni envía las observaciones a Firebase/Meta.

La matriz de tiendas debe reflejar ese tratamiento al preparar el cliente público:

| Categoría | Delta de este reporte |
|---|---|
| Play User IDs | Continúa requerida/no efímera. El uso analítico propio se suma a los usos de cuenta ya declarados; no convertir todo el tipo a opcional por Firebase. |
| Play App interactions | El reporte automático hace requerida la recopilación de esta categoría para quienes usan el detalle con sesión. Conservar Analytics y los demás usos reales existentes; no marcar todo opcional por los controles de SDK. |
| Apple User ID / Product Interaction | Vinculados a la cuenta, usados para Analytics; este flujo propio no añade tracking publicitario ni un tipo nuevo. Conciliar con los usos previos, sin alterar los de otros SDK. |

El corte publicado aquí del21/nov marca App interactions opcional; **la consola
actual no se cotejó** en este cambio. El26/nov la comprobación de navegador devolvió
“Local browser access is unavailable for this chat”. Se preparó este delta, sin
modificar ni enviar formularios de tienda ni atribuirles aprobación. Conciliar la
declaración efectiva antes de promover el cliente público. La versión interna,
la publicación del formulario y la aprobación del binario son estados distintos.

Avisos públicos publicados desde landinge4016c3ebfa9a8b79ece342dee40197703890c62,
Verceldpl_12qJZc6zgawNeusZxwEbN87z5Wk9 READY; `/privacy-policy` y `/terms` HTTP200
y exactos al texto actualizado tras normalizar finales de línea. Recibo privado
.tools/automatic-report-20261126/legal.verified.private.json. Las versiones generales
se conservan; se añadió la actualización de reportes y se eliminó la descripción
de la pantalla inicial. Véase la investigación de requisitos y sus límites en
[adoption-report-consent-review-20261126.md](adoption-report-consent-review-20261126.md).
