# Reporte administrativo de adopciones — 25/11/2026

## Cambio solicitado el 26/11/2026: actividad automática

Retirar la pantalla inicial de Analítica; entrar al producto sin confirmar esa
elección. Registrar automáticamente el detalle real para cuentas con sesión,
independiente de Firebase apagado, elección pendiente, error de su lectura o falta
de su controlador. Mantener autor/precargas/fondo/sesión como exclusiones y
deduplicación por persona/mascota. No activar Firebase/Meta/diagnóstico ni reconstruir
registros históricos o conversiones de alta al optar después desde ajustes.

Nuevo registro operativo privado/RLS y RPC autenticado separados de las vistas
anteriores consentidas; sumar ambas fuentes con deduplicación por cuenta, sin
exponer personas o mensajes en el panel. Conservar retirada de datos anteriores
y borrar actividad operativa al eliminar la cuenta. Ajustar aviso y definiciones.

Aceptación: cuenta nueva entra sin pantalla de elección; Firebase sigueOFF.
Detalle visitado dos veces con FirebaseOFF/pending suma una persona; activar o
retirar Firebase no cambia ese conteo operativo. Dos personas suman dos; autor,
anónimo, borrador, cuenta suspendida y vista sólo precargada no suman. Un registro
anterior y uno operativo de la misma persona cuentan una vez. Eliminar cuenta
retira sus observaciones. Favoritos/contactos/primeras respuestas y privacidad de
chat se conservan. Pruebas en fronteras: entrada real de app, registrador de detalle
y RPC/reporte PostgreSQL; una sola cola Flutter. Fuente base280b3186/HEAD2b2df036,
último runtime Android448 verificado; referencia Irlanda d9f9aa43 congelada.

Validación del cambio automático: backend completo 1415 PASS/19 SKIP; PostgreSQL
real 9/9, incluyendo concurrencia de dispositivos y eliminación de cuenta; pgTAP
22/22 (reporte anterior y nuevo); admin 180/180 y buildPASS. CI exacta
[45894194662](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/45894194662)
del producto0e3f3a9d46a90876223020a6d53f682327c8208d: cuatroSUCCESS, incluyendo
analyze, suite Flutter completa, compilaciones Android/iOS, backend real y
capturas. Configuración local48+26PASS. La primera suite Flutter local terminó
2260PASS/5SKIP/2FAIL: expectativa antigua de preselección corregida y un timeout
de ayuda no reproducido en la CI completa; no se alteró esa prueba. Revisión independiente de
cliente/producto y SQL/seguridad cerrada sin bloqueos tras corregir orden de
bloqueos Auth → perfil → publicación. Capturas Flutter sintéticas de entrada sin
elección y acceso a la nueva sección del aviso, no prueba de teléfono. La investigación anterior permanece como antecedente,
sin convertir la decisión del titular en un dictamen jurídico de tiendas.

Los apartados siguientes documentan la entrega original consentida del 25/11;
sus referencias a consentimiento de detalle y al cliente448 quedan sustituidas
por este cambio cuando se active y se distribuya el cliente actualizado.

Activación comprobada26/nov: PROD **20261126205952 /
automatic_adoption_detail_activity_20261126**, archivo20261126202302, historia77→78
intacta; sólo se modifica intencionalmente el agregador y se añaden las dos
funciones operativas. Once comprobaciones de catálogo PASS, sin backfill.
[Auditoría](migration-history-audit.md#26112026-cdmx--actividad-automática-de-adopciones-en-prod).
Panel desplegado desde0e3f3a9d en **dpl_GxGtm5AB8QW3nU53jpaqugKqppLR**, READY;
alias, HTTP200 y bundle con la explicación nueva comprobados. No se repitió el
recorrido con sesión administrativa ni se generó actividad de usuarios en PROD.

Aviso y Términos públicos desde landinge4016c3ebfa9a8b79ece342dee40197703890c62,
deploy **dpl_12qJZc6zgawNeusZxwEbN87z5Wk9** READY; ambas rutas HTTP200 y texto
exacto al origen tras normalizar LF. Declaran datos/finalidad/Supabase, eliminación
e independencia de Firebase/Meta y retiran la descripción de elección inicial.
[Delta preparado para fichas de tienda](h10-store-privacy-declarations.md#delta-de-reportes-automáticos--26112026):
conciliar App interactions requerida antes del cliente público. Console actual
sin cotejar: navegador sin acceso de automatización. No se enviaron formularios.

Cliente actualizado: tag **codex/automatic-adoption-reports-20261126-v1** en0e3f3a9d;
único envío Android interno a Codemagic **6b08a0d1ee7c9341cfe42976**,14SUCCESS.
Base448 conciliada, misma identidad/firma/perfil y tiendas Rescatista preservadas;
Meta lifecycle explícitamenteOFF. **Android2.3.12(449) publicado en Play interno**:
AAB97052138B, SHA256ef690ab5…03a94f3, firma registrada/configuración de producción
y marcador del RPC operativo verificados en los tres binarios Dart. Log Publishing
leído por separado: código449, internal, completed y Successfully published.
Console actual no leído de forma independiente. ADB sigue sin dispositivo al cierre.
iOS no enviado; cliente público, teléfono y aceptación siguen pendientes. No repetir
envío, descargas o SQL; cero observadores activos al cerrar.

Demo ejecutada: app Flutter real con repositorio sintético → cuenta sin elección
de Analítica → detalle Luna accesible y una observación, mientras Firebase sigueOFF.
Capturas privadas .tools/design-review/automatic-report-20261126, revisadas sin
recortes; la captura del aviso acredita acceso al apartado, no su contenido expandido.
Recorrido propuesto para el cliente instalado: entrar sin elección inicial → abrir
dos veces una mascota publicada ajena → detalle aumenta una cuenta; mantener
FirebaseOFF no impide contar. Guardar/quitar ajusta favoritos; contactar y responder
siguen las reglas anteriores. Señales de problema: aparece la pantalla inicial,
se necesita FirebaseON para contar o la misma cuenta suma de nuevo al reabrir.

Solicitud y decisiones del titular en esta conversación: tabla de todas las mascotas actualmente publicadas en adopción, perros y gatos; **una persona única por mascota** que entra al detalle, favoritos que siguen guardados, personas que contactaron y conversaciones con una primera respuesta de su rescatista. Sólo adopciones en este alcance. No incluye casos de apoyo ni denuncias de moderación.

26/11/2026: el titular confirmó que el contador funciona y cerró su revisión.
La consulta posterior sobre privacidad se resolvió como investigación separada:
[datos reales y requisitos de Apple/Google](adoption-report-consent-review-20261126.md).
No se cambió consentimiento, recopilación o producto por esa consulta.

## Comportamiento y aceptación

- Sección **Reportes**, accesible desde la navegación administrativa existente. Buscar por mascota/rescatista, filtrar especie y paginar en servidor de20en20. Muestra todas las publicaciones vigentes de cuentas activas, incluyendo las que tienen cero actividad.
- Detalle: identidad de la cuenta y publicación, deduplicados en PostgreSQL entre dispositivos/reintentos. Sólo después de mostrar el detalle real, con consentimiento vigente. No cuentan tarjetas, precargas, preview, propietario ni visitantes sin cuenta. Un contador nuevo con fecha de inicio explícita, sin rellenar históricos desde impresiones. Revocar elimina las observaciones propias.
- Favoritos: filas actuales de otras personas; quitar un favorito baja el contador. No es acumulado de pulsaciones.
- Contactos: personas con al menos un mensaje por esa publicación, incluido el saludo transaccional que confirma la acción de contacto. Crear un hilo vacío no cuenta. Hilos cerrados conservan su contribución.
- Primeras respuestas: una por conversación con al menos una respuesta humana del responsable posterior al contacto. Leer no cuenta, ni respuestas posteriores/reintentos. La clasificación servidor actual se respeta; para registros anteriores sin clasificación se usa remitente, origen y existencia de un contacto previo, sin publicar mensajes ni producir eventos publicitarios retrospectivos.
- RPC exclusivamente administrativa para agregados, con verificación de membresía activa en cada llamada y registro de consulta. No concede permisos de lectura de conversaciones. Tablas nuevas privadas con RLS y sin acceso directo del cliente. Falla/carga/ausencia de conexión no se representan como ceros.

Ejemplo sintético de aceptación: Luna con12personas que abrieron detalle,4favoritos actuales y3personas que escribieron, de las cuales2recibieron respuesta, muestra **12 / 4 / 3 / 2**. Si una de esas personas abre el detalle otras cinco veces y recibe otras tres respuestas, las cifras permanecen iguales. Si quita su favorito, favoritos pasa a3.

## Base y límites operativos

Rama aislada codex/adoption-metrics-20261125 desde61fa88d40f0088b84a37c7369da7fb4950b18ef6, conservando las fuentes posteriores conciliadas por la exploración de base. El checkout original1094e29c con cambios ajenos se preserva. Referencia Irlanda observada d9f9aa430ffc4b1d9df76e49e7efbe9f0e5cae1c; el reporte usa el patrón del panel actual, sin absorber nuevos alcances del mock. Paquete separado codex/admin-report-context-20261122 trata moderación y no se activa aquí.

El titular autorizó la activación y la versión interna con «Dale». El esquema y el panel ya están publicados y verificados; el cliente anterior no envía observaciones del detalle. Estado del candidato móvil y resultados finales en progress.md.

## Demostración y activación

PROD: migración remota **20261126030428 / adoption_detail_reports_20261125**, correspondiente al archivo20261125222901, aplicada una sola vez. Postflight independiente: historia76→77 con prefijo y funciones anteriores intactos, SQL exacto, RLS/ACL y estado inicial correctos. [Auditoría](migration-history-audit.md#25112026-cdmx--reportes-de-adopción-en-prod). No repetir SQL ni reparar timestamps.

Panel [dopmi-app.vercel.app](https://dopmi-app.vercel.app), deploy **dpl_F9K8wePuPjZp7hpGgmos67wdLHr3** desde **a8601c257a133a96dd2053a34eb182ea4ddd1e8b**, READY y alias confirmado. HTTP200/bundle PROD comprobados. Demo real con sesión administrativa:21adopciones, paginación20+1, filtro Gatos4 y búsqueda de una publicación con cifras0/9/4/2; sin leer mensajes privados ni crear actividad de prueba. Captura privada `.tools/report-activation/production-report.jpg`.

Cliente móvil integrado **280b3186d15db26d5641847cff9acdc694614602**, tag **codex/adoption-report-20261125-v1**, CI45746827546 cuatroSUCCESS. **Android2.3.12(448) disponible en Google Play interno**, comprobado en Console (release238) y log Publishing internal/completed; Codemagic6b07a763e4b8406fd5893ddc terminó14SUCCESS. AAB/firma registrada/configuración y marcador del nuevo RPC verificados. Conserva los cuatro archivos exactos de la entrega de tienda Rescatista36f8e47f y usa el perfil Android446, con Meta lifecycle opcional explícitamenteOFF y finanzasOFF. No se envió iOS ni se promovió a producción pública. El cliente público anterior aún no envía estas vistas.

Demo ejecutada en navegador con el React real y datos ficticios: Reportes → página2/2 → filtro Gatos11 → búsqueda Luna1 → cifras12/4/3/2. A390px la tabla permite llegar por teclado a las últimas columnas sin desbordar la página. Capturas privadas en `.tools/report-desktop.jpg` y `.tools/report-narrow.jpg`; no son datos remotos ni aceptación del titular.

Recorrido propuesto tras la publicación: abrir **Reportes** con una cuenta administrativa → localizar una adopción publicada → contrastar los cuatro agregados. Con una cuenta controlada y cliente actualizado, abrir dos veces el detalle debe sumar una persona; guardar/quitar debe subir/bajar favoritos; contactar debe sumar una persona; leer no debe sumar respuesta y responder varias veces debe sumar una primera respuesta. Retirar consentimiento debe eliminar la observación del detalle. Estas acciones de QA instalada aún no se han ejecutado ni se han creado fixtures para ellas.

Señales de problema durante ese recorrido: recargar el detalle aumenta el contador, un favorito retirado sigue contado, o leer/responder otra vez suma una nueva primera respuesta. La demo web descrita arriba sí fue ejecutada; este recorrido instalado sigue propuesto.

Pendiente de aceptación instalada: cliente actualizado → abrir una ficha dos veces → una persona en detalle; retirar consentimiento → se elimina su observación. El teléfono no está conectado al comprobar ADB. La publicación móvil, la moderación pendiente y la configuración financiera conservan sus propios gates.
