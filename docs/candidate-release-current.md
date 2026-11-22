## Candidato vigente — Android público433 y piloto60, 22/11/2026

Google Play Console confirma Submission166 Published y Production2.3.9(433),
con «Start full rollout». La etiqueta mostrada es21nov22:54; su zona horaria
no está acreditada. Fuente efc3277a7c11f8633235584a4cf2c95c7d471181,
tag codex/discovery-zoom-efc3277a; CM6b0264a98a656efc66c206b5 terminó14SUCCESS.
La metadata AAB coincide con433 y el perfilPROD/adopciones/Amazon esperado.

433 contiene1544a85236ee96a89eda576bda35fb2a5b9b140c: comparación de fuentes
ahead5/behind0, sin cambios en parser, enrollment ni hook de adquisición.
Conserva p60, la elección explícita de Analítica y los arreglos recientes de
navegación, adjuntos del chat y controles de descubrimiento con pantalla ampliada.
La verificación criptográfica del AAB429 es evidencia anterior separada;
no se atribuye al binario433 una inspección de firma ni QA física nuevas.

Landing2179f1c6 pública/HTTP18PASS y SQLPROD20261122004520/31PASS conservados.
El22nov se activaron atómicamente las60 colocaciones noQA del manifiesto exacto
enPROD. **Fase de contacto cerrada22nov:**60 envíos,59 visibles y1 pendiente
de moderación;30 desde perfil personal/30 desde DopMi,15porR1–R4 y32gatos/28perros.
Auditoría de lectura del ledger:60 claves de autora/post/token distintas,
asignaciones y textos conformes al manifiesto. Son contactos, no60 rescatistas
independientes verificadas ni60 comentarios publicados. Seguimiento y análisis
siguen abiertos. LecturaPROD22nov21:40:10UTC:0 fuentes Android consentidas p60,
0 primeras fichas etiquetadas y0 cohortes maduras; no son conteos de descargas
ni evidencia de ausencia de resultados en iOS o con AnalíticaOFF.
**QA manual p60 de instalación limpia → primera ficha atribuida sigue pendiente.**
Disponibilidad pública y activación no equivalen a esa aceptación.
[Estado operativo](campaign-placement-pilot.md).
Preservar elOFF elegido en iPad426; iOS no tiene atribución individual p60 verificada.

## Analítica opcional — corte anterior21/11/2026

Elección inicial de Analítica, corte21/nov: fuente inmutable
`af0e2274f13a51c10a13e8579fd932f35f1ebf58`, tag
`codex/usage-analytics-choice-af0e2274`, CI44878177593 cuatro trabajos SUCCESS.
ON sólo visual hasta guardar; elección opcional, OFF históricos y diagnóstico/
publicaciones separados. Código, transporte, recibos y textos nativos verificados;
no equivalen a instalación ni aceptación física. Regresiones finales95PASS,
configuración42PASS y análisis0incidencias; full local1965PASS/4SKIP anterior al
último copy/gate, incluido después en la CI final completa. Revisión independiente
final de código/seguridad/UI sin P1/P2. [Plan](superpowers/plans/2026-11-21-usage-analytics-choice.md).

El titular autorizó el paquete exacto. SQLPROD aplicado una vez como
`20261121223246 / usage_analytics_explicit_choice_20261121`: historia71→72,
prefijo71 MD5 `7c11e252392ec5fd42f47a3ed8f4e871` intacto, cuatro conjuntos de
postflight/16condicionesPASS. Mapeo local20261121062012 en migration-history-audit.
Recibos privados `.tools/analytics-choice-20261121/server`. Los objetos nuevos
producen avisos deliberados de RLS privado sin políticas y RPC authenticated
SECURITY DEFINER; ACL/actor revisados. No atribuir todos los avisos a historia previa.

Términos/privacidad públicos desde landing
`c95be7f56b877f84a9e52e5fac628b61c4ceb11b`, Vercel
`dpl_6w6vWZdwDGecMSBEnqaGRPonMzGb` READY: HTTP200 y hashes exactos,
privacidad28811B5df1686a…9a741cb/términos3955Bad358012…cdb0054c.
Versiones generales conservadas; aviso propio usage-analytics-2026-11-21.
App Privacy Apple publicado:16tipos, trackingNO; User ID añade Analytics y
marketing del desarrollador, Coarse Location añade Analytics, Product Interaction
añade marketing propio. Play Data Safety **publicado**: Submission165 del21/nov,
envío16:49/publicación16:59 según la consola, detalle de un solo cambio Data Safety.
Incluye Analytics/captación y ubicación precisa funcional; recibo
stores/play-published.private.json. No se promovió ningún binario público.

Android: único Codemagic `6b021e276328dae170dd4245`, fuenteaf0e2274, terminó
**14SUCCESS** el21nov22:56:22UTC. Metadata **2.3.9 (425)**; publishing confirma
Version code425, Updated release internal, readbackStatuscompleted y Successfully
published. **Play interno publicado y AAB/runtime/firma verificados**,
SHA256 `b5fd334daf6c7227d60ef610fbcf1705f738bd6edcb0be92439f96910789a919`.
Identidad/Firebase/backendPROD, configuración, minSDK24/targetSDK≥36, aviso/RPC y
arranque nativoOFF cotejados. Firma JAR válida con pin existente; strict_exit4
corresponde al certificado upload autofirmado esperado, sin afirmar cadena CA
pública. Recibos android/{verification,shipping.verified}.private.json.
Instalación y aceptación siguen pendientes.
Después de Android terminal y de la ventana22:50:46.648–22:55:46.648UTC, un solo
POST22:56UTC envió iOS `6b02219da77af65f4a2437b1`, workflowios-testflight,
misma fuente/CI. **2.3.9 (426)** terminó15SUCCESS; IPA55006025B verificado,
SHA256 `a408e42aec6a35b64a3b058457d3734ffaeec83be69b751bb25b4aa9b814247c`.
Runtime adopciones/TiendaON, finanzas/mediciónTEST/walletsTESTOFF; bootstrap
Analytics/CrashlyticsOFF, identidad/FirebasePROD y ubicación sólo foreground
cotejados. Perfil/firma iOS válidos estructuralmente, sin validación CMS criptográfica.
Recibo ios/verification.private.json. El posprocesamiento Apple terminó sin error
el21nov23:16:17UTC. Chrome23:17:40UTC confirmó426 **Lista para enviar**, Caduca90d,
DopMi Inner Team/5invitaciones: **disponible en TestFlight interno**. Recibo
ios/testflight-readback.private.json y captura privada. El titular confirma426
actualizada/instalada, sesión conservada y navegación correcta. Veía Analítica
ON sin recordar su preferencia previa; después la apagó, esperó el guardado y
cerró/reabrió. Confirmó «Sigue apagada y conserva el inicio de sesión».
**iOS426: sesión/navegación y retirada con OFF persistente confirmados**; conservar
esa elección finalOFF. No acredita primera elección, un OFF anterior desconocido,
onboarding de una cuenta nueva ni eventos del SDK en red. Cola única, sin reenvío.
Los flags citados son del cliente; esta entrega no apagó servicios remotos ni
cambió sus flags financieros. No hubo promoción pública de estos binarios.
Samsung elegido por el titular, paquete Dopmi ausente. Un intento real desde
la ficha «Eres verificador interno» → Instalar terminó en «No se puede descargar
DopMi». No hay logs actuales que acrediten1010 ni qué número solicitó el teléfono;
la publicación425 sí está cotejada. No se repitió descarga, limpieza, acceso ni
sideload. Evidencia privada android/phone-attempt.private.json. Android sigue sin
instalación; esa descarga bloqueada no invalida el reporte humano de iOS426.

Corrección de Favoritos sobre esta continuación: al volver a
Mis match, la rama retenida refresca su lista; al confirmarse un like tardío,
el repositorio avisa localmente a sus observadores de favoritos de esa misma
cuenta. Tres archivos Dart productivos, sin SQL ni cambios de servicios.
Fuente inmutable `1441e2955e8d069ed9508083adb7bbbfa657ab0c`, tag
`codex/match-favorites-refresh-1441e295`. Regresión de navegación/swipe y escritura
retrasada11PASS, análisis0incidencias y suite completa1940PASS/4SKIP/0FAIL.
CI [44869286815](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/44869286815)
cuatro trabajos SUCCESS; revisión independiente de código/seguridad/UX sin
hallazgos materiales finales. Codemagic Android único `6b012afc52531896647e44fe`
terminó14SUCCESS: **2.3.9 (423)**, runtime PROD/adopciones/AmazonON cotejado y
readback `internal/completed/423`. Después, en la misma cola, Codemagic
`6b012e863e7818a35b07a3f1` terminó15SUCCESS: **iOS2.3.9 (424)**, IPA/runtime
verificados. Tarea Apple6b01326fa14b9f22af0129c3 finished/sinerror; Chrome
21nov00:03CDMX muestra424/Lista para enviar/DopMi Inner Team/cinco invitaciones
existentes. Sin promoción pública ni cambios de servicios.
Samsung pidió423 a23:48CDMX y volvió a fallar1010 antes de descargar; paquete
ausente. El caso Google3-8197000042220 recibió la versión actual por el mismo
hilo/SENT. ZFlip aún no conectado; instalación y aceptación física del favorito
pendientes. Preserva la exclusión después del mensaje y el piloto iOS inferior.

Preparación autorizada del piloto individual iOS `personal-a`: base e48a653b,
incluyendo el arreglo reciente de compartir perfiles HTTPS de b278540d/420.
Cliente temprano/persistente y RPC SQL aditiva implementados; primer contexto y
propietario inmutables, revisión consentida exacta, cinco hitos independientes.
No códigos, login previo a descarga ni matching de dispositivo. Revisión
independiente sin P1/P2 después de corregir fallos de persistencia/reinicio.
Fuente inmutable `55061f99f48c0b0b8e54ee628bc8faab553d0763`, tag
`codex/ios-cpp-personal-a-2.3.9-55061f99`. CI
[44860327579](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/44860327579)
cuatro trabajos SUCCESS: Flutter1929PASS/4SKIP, análisis, compilaciones Android/
iOS simulator y capturas aprobados; backend1339PASS/12SKIP, PostgreSQL real
adquisición/CAS/iOS42PASS/0SKIP y Auth/Storage/Realtime5PASS. Pruebas locales de
transporte conjunto12PASS, módulo30PASS, PostgreSQL iOS17PASS y configuración42PASS.

SQL PROD aplicado una vez: `20261121034107 /
ios_cpp_personal_a_acquisition_20261120`. Historia70→71 con prefijo intacto;
333funciones previas/OID/ACL/configuración exactos, cinco funciones nuevas
cotejadas, dos tablas RLS sin CRUD cliente y cuatro triggers. Fuentes/eventos0;
sin backfill ni cambios a datos QA. Mapeo en migration-history-audit.md.
Codemagic único `6b0112f68d36bd30d38e3998`, `ios-testflight`, terminó15/15SUCCESS;
suite real1929PASS/4SKIP. IPA **2.3.9 (421)**, fuente55061f99, PROD/adopciones/
AmazonON y submissionfalse cotejados. Bundle/scheme/App Links, Firebase plist
exacto contra419, perfil App Store y marcadores PROD verificados en el IPA.
SHA256 `f3fd0fe90b59c6e898a308e0112f66336b6eaa109bc6fc47367d2b8921af90d7`.
OFF de mediciónTEST/nativewalletsTEST se deriva de los guards del perfil;
no se afirma decodificar todas las constantes Dart ni verificar Stripe servidor.
Publishing y tarea Apple `6b01161fa14b9f22af0125ac` finalizaron sin error.
Chrome22:03CDMX confirmó2.3.9/421 procesado, **Lista para enviar**, grupo interno
DopMi Inner Team/cinco invitaciones existentes. No nuevas invitaciones manuales,
envío a revisión pública2.3.9, instalación o aceptación de iPhone atribuidos.
Recibos saneados de artefactos/publishing/posprocesamiento y screenshot
apple-build421-ready.jpg fuera de Git. HTTP PROD sin sesión401/42501, sin fuente.

CPP `personal-a · Publicar en adopción`, id público
`f72ab3bc-1cd0-49b7-9220-cff726c86ffd`, creada desde2.3.8(419); destino
`io.dopmi.app://acquire/personal-a` guardado y cotejado tras recargar Chrome.
Borrador sin enviar a revisión, sin nuevo `ppid` en landing. El419 continúa
Pendiente de revisión/publicación, confirmado otra vez22:02CDMX; no se retiró.
Público sigue2.3.7. La carga2.3.9(421) no envió revisión pública ni la CPP.
Captura del titular confirma iPad Pro12.9″/5.ªgeneración con iPadOS26.6.1.
El mismo IPA421 admite iPad arm64 (familias1,2 y mínimo15.0); CPP requiere18+.
El titular confirma instalación421 desde TestFlight y apertura de URI desde Safari.
Registro automático personal-a/ios_cpp_open cotejado en PROD22:53:37CDMX:
mismo actor del preflight22:44, consentimientoTRUE/revisión1→2 y una fuente.
En ese corte, primera ficha/aprobaciónNULL y eventos0. Revisión independiente de recibo limpia
para captura/inscripción; no prueba de muerte del proceso ni de instalación CPP.
QA excluida en consulta operativa privada: bruto1/técnico1/noQA0; no borrar el recibo.
Actualización21nov16:37CDMX: el titular envió una mascota real desde el iPad y
vio «Enviado a revisión». Lectura PROD16:37:58: misma cuenta y fuente original,
primera ficha propia submitted16:37:27.809 y `first_submitted_at`16:37:27.856;
la referencia fuente→ficha coincide exactamente. Dos fotos almacenadas en bucket
privado, rutas correctas y archivos válidos no vacíos. AnalíticaTRUE/revisión3,
una sola fuente/ficha; sin aprobación/publicación ni eventos de mensajes. No
escrituras administrativas, backfill o ajuste de campaña. Recibo privado
ipad421-first-listing.verified.private.json y revisión independiente favorables.
Agregado16:41:48CDMX: fuentes1/QA1/noQA0 y primeros envíos1/QA1/noQA0, mediante
filtro privado sin borrar datos. Prueba real421/55061f99, TestFlight+Safari;
no acredita el424 posterior ni instalación CPP, aprobación o mensajes.
Actualización21nov17:00CDMX en421: saludo automático y primer mensaje humano
verificados como eventos separados para la fuente original personal-a.
Contacto real de adopción elegido por el titular: hilo nuevo, saludo1/compositor0
→saludo1/compositor1; eventos `automatic_greeting`16:58:58.577 y
`first_user_message`16:59:59.971CDMX. Mismo actor/hilo/consentimientoON/revisión3,
dentro336h y primera ficha intacta. Lecturas sólo de metadatos, recibos privados
independientes favorables; sin cuerpos ni escrituras administrativas. Ambos
eventos QA excluidos por filtro privado17:01CDMX, noQA0 por tipo.
Ficha propia ahora archivada/sin aprobación; titular deja expresamente pendiente
`first_rescuer_reply`. La respuesta del dueño externo no se atribuye al adoptante.
Primera ficha y mensajes desde CPP/App Store siguen pendientes; TestFlight o
CI no equivalen a esa aceptación. Operación en [runbook](ios-cpp-personal-a-runbook.md).

Corrección de compartir perfil preparada sobre este mismo release en
`b278540d`, CI `44853201553` con cuatro trabajos aprobados. El botón usa
`https://www.dopmi.org/people/<uuid>` en una línea propia. La página y portada
están publicadas desde landing `17fafda`, Vercel
`dpl_9QdrSqU7NuNGjH2nGSRUUsoJtU6Q` READY. Sus respuestas públicas verificadas
son HTML 200 y JPEG 200 de 1200×630 sin EXIF. Codemagic
`6b01003f9e3cad7e76b08946` completó 14 pasos y el readback de Play confirmó
2.3.8 (420), canal interno, estado completed. El reporte del artefacto
confirmó el mismo runtime de producción con Tienda habilitada.
Instalación y prueba física del nuevo botón pendientes.

Seguimiento de descarga del 20/nov: Play Console
confirma release 224 disponible para testers y APK para SM-S938B/Android 17.
El paquete 420 no está instalado. Dos cuentas elegibles, incluida una solicitud
remota reautenticada por el titular, reciben 1010 antes de descargar. Firmas del
APK base y ARM64 descargados de Console válidas. Cuenta original de Play
restaurada; ese diagnóstico no utilizó sideload, otra build ni cambios de rollout. Informe autorizado
y enviado una vez a Google; caso visible Pending, con Case ID pending.
La autorización incluye seguimiento de ese mismo expediente. Evidencia en
[progreso](progress.md); no atribuir resolución del problema a la publicación.

Reenvío adicional solicitado expresamente por el titular: misma fuente/tag
`b278540d`, configuración resuelta de420, firma y cuatro grupos existentes;
sin incorporar el piloto iOS55061f99. Ventana20nov21:54:04–21:59:04CDMX y cola
libre tras terminar iOS421. Un único POST produjo Codemagic
`6b01170eecb05f7db4ae068f`: **2.3.8 (422)**,14SUCCESS. AAB/reporte runtime
PROD/adopciones/AmazonON, Guardian/mediciónTEST/billeterasTESTOFF y readback `internal/completed/422`
verificados. Primer intento del teléfono aún pidió420; tras reiniciar sólo
el proceso Play,22:16:44CDMX pidió422 y repitió respuesta no-OK2/estado1010
antes de descargar. Paquete ausente; reenvío publicado, descarga aún sin resolver.
Producción pública y configuración de servicios conservadas; sin sideload.
Confirmación por correo localizada: caso Google **3-8197000042220**.
El titular informa descarga correcta en un Samsung Z Flip; modelo exacto,
Android y build instalado allí aún sin cotejar. Se respondió una sola vez en
el mismo hilo con esa comparación y el fallo422 del S25 Ultra, sin adjuntos
ni nuevo caso. Gmail confirmó SENT y el hilo original. Pendiente respuesta
técnica; el contraste acota la investigación, no acredita la causa.
Recibos/capturas fuera de Git en `.tools/play420-resend` y `.tools/play420-install`.

La apertura de Chrome en el Samsung quedó pendiente. La revisión automática
rechazó la apertura por ADB y Computer Use detuvo el control de Windows
porque no pudo verificar la URL abierta del navegador. Se conservó esa
limitación al solicitar el titular que el integrador hiciera la prueba.

Correctivo de perfil público aplicado el 20 de noviembre a las 19:33 CDMX
desde `5fa23089`.
La respuesta de `dopmi_public_profile` incluye las adopciones publicadas del
propietario también cuando usa el perfil sin sello. Migración remota
`20261121013358`, historia 70. Samsung 2.3.8 (418)/Vending comprobado con
detalle→perfil→Adopción→foto→mismo detalle y regreso. La fuente del binario
continúa en `ee3ef773`. La corrección está en el servidor que usa ese cliente.

Este corte sustituye las instrucciones operativas históricas inferiores para
la entrega actual. Rama `codex/production-attribution-restored-20261120`;
base reciente congelada `c9d9d03dc34ac99f743c15be8862788136b189be`.
Fuente del binario `ee3ef773798ff876430bc800c705e2a8ab7b0331`, tag inmutable
`codex/production-attribution-2.3.8-ee3ef773`. No usar la rama395 ni el PR7 antiguo
como base. Conservar Amazon, navegación centrada y detalles opcionales; compartir
HTTPS y visor ampliado/carrusel restaurados, sello manual por perfil recuperado.

- CI [44823640872](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/44823640872):
  cuatro jobs SUCCESS, Flutter1858PASS/4SKIP, PostgreSQL concurrente y servicios
  reales Auth/Storage/Realtime aprobados. Compilación iOS simulator, sin firma ni
  aceptación de iPhone atribuida.
- Supabase PROD `ysaoeuidcvgtlmphmeyb`: operación agrupada única
  `20261120221225 / production_restored_campaign_attribution_20261120` aplicada y
  cotejada; historia68→69 con prefijo intacto,28funciones/ACL/RLS verificadas.
  Mapeo de las cuatro fuentes en `migration-history-audit.md`; no reaplicar.
- Admin PROD `dpl_8MLN3k2TThpEZA6DtH8eGLJh7kiz`, READY, fuenteee3ef773 y
  root `apps/admin`; alias `https://dopmi-app.vercel.app`. Conserva WebPush y
  Primera Publicación. No se realizó aprobación manual de sello ni login staff.
- Codemagic `6b00c8569aa5efcb10765a77`, `android-guardian-internal`, terminó
  con14accionesSUCCESS. AAB/metadatos del mismo handle: **2.3.8 (418)**,
  SHAee3ef773, Supabase/Firebase PROD, adopciones/AmazonON, Guardian/mediciónTEST/
  billeterasTESTOFF. Suite del candidato1858PASS/4SKIP. No cambiar sus gates.
- Publishing y readback Codemagic confirman `attribution-dev-qa`; Play Console
  confirmó release6/2.3.8 **disponible para los testers seleccionados**, publicado
  el20nov17:27CDMX y consultado18:10CDMX. El Samsung instaló418 desde ese canal.
  El rótulo genérico «Google Play internal» del build-info no acredita el canal.
  Público Android seguía4092.3.7 al enviar la promoción. Consulta posterior
  20nov19:41CDMX de Production confirma Active, Latest release2.3.8 y enlaces
  de métricas versionCode418: el418 ya está activo en producción pública.

Samsung: instalación limpia en el perfil principal desde `personal-a`, versión
2.3.8(418) e instalador/iniciador Vending comprobados por ADB y versión visible
en la app. El titular autorizó expresamente Analítica para esta cuenta QA en PROD;
activada desde UI, diagnósticoOFF. Fuente personal-a registrada automáticamente
18:16:54CDMX, antes del primer envío18:22:35CDMX: misma cuenta, referencia exacta,
estado submitted, una foto y published_at NULL. No se insertó ni corrigió esa
atribución por SQL. El borrador anterior y los fixtures DEV quedaron intactos.

QA física cerrada: acceso Google, foto propia, búsqueda de zona Monterrey, paso
opcional/Ir a vista previa y envío privado. Visor público con4fotos: flechas,
swipe, contador, cerrar y Back comprobados; foto completa cargada y controles
presentes en los PNG originales. Hoja de compartir contiene el enlace HTTPS
correcto; se canceló sin destinatario. Tienda/producto/aviso de Amazon/regreso
probados sin compra. La interrupción temporal por Roku se resolvió con el titular.

Segunda instalación limpia de418/Vending18:38:43CDMX: login de la misma cuenta,
Analítica/diagnóstico localesOFF sin pulsar switches. Fuente y primer envío
conservaron15campos exactos. Consentimiento servidortrue/revisión2, cuya última
escritura18:23:50 antecede a la reinstalación; no hubo revocación implícita.
Recibo privado `samsung418-native-acceptance.private.json`. La ficha QA sigue
en revisión, sin aprobación/publicación ni mensajes a personas reales.

La cuenta QA debe excluirse del análisis del experimento; el reporte bruto la
incluye. Consulta privada con exclusión comprobada: cero cuentas/conversiones
reales por las cuatro variantes al corte. No confundir ese ensayo con adquisición.

Promoción realizada en Play del **mismo código418**, sin otra compilación:
producción/release43, nombre2.3.8 y notas es-419, alcance100% en los países ya
seleccionados. Se envió únicamente ese cambio; Publishing overview confirma
Changes in review. Consulta20nov18:52CDMX: ya no aparecen comprobaciones previas
en curso y el mensaje confirma «Your changes are now in review». Managed
publishing ya estabaOFF y se conservó. Consulta posterior20nov19:41CDMX confirma
el418 activo en Production; supersede el pendiente público409 de los cortes
anteriores. No disparar un workflow nuevo como forma de promoción.

Apple: solicitud expresa del titular de enviar esta versión. Fuente inmutable
`efcce99f7673e6ae74fa6613722cd6acaeaa42c8`, tag
`codex/ios-2.3.8-production-efcce99f`; lib/android/ios/configuración/SQL idénticos
a ee3ef773. Sólo `apps/mobile/release_notes.json` deja de prometer medición de
campaña de instalación que iOS aún no implementa. Codemagic
`6b00f498ff04049620c7e6d0`, `ios-app-store`,15accionesSUCCESS e IPA **2.3.8(419)**
cargado; runtimePROD/adopciones/AmazonON y finanzasOFF cotejados. Configuración
efectiva tomada del último iOS410 aprobado, con overrides explícitos de esta
entrega; identidad/firma existentes conservadas. Tarea de distribución Apple
`6b00f7c1a14b9f22af0120e5` terminó sin error20nov19:50CDMX. El log real confirma
versión2.3.8 creada, notas es-MX actualizadas, AFTER_APPROVAL y ReviewSubmission
enviado con estado **WAITING_FOR_REVIEW**. La publicación quedó programada tras
aprobación, sin aprobación/disponibilidad pública ni instalación/QA de iPhone
atribuidas.15accionesSUCCESS, analyze limpio y1858PASS/4SKIP; recibo saneado
privado `release-receipt.sanitized.json` y hash IPA conservados fuera de Git.

El titular prefiere descarga directa y rechaza login web previo a App Store.
Chrome local, mediante su extensión, permitió generar los cuatro enlaces
oficiales de campaña de Apple. Landing `d9e842c3fd9c5a23f20a8d7fdc624ac29df32813`,
Vercel PROD `dpl_GpUoMfppLmK1W6iJqQa1ebaj6iBz` READY: cuatro rutas iOS GET/HEAD302
con proveedor/campaña oficiales; fallback de crawlers conserva campaña. Las
cuatro páginas Android mantienen SHA256 idénticos antes/después.16pruebas HTTP
locales y revisión independiente sin bloqueantes. No login adicional ni SDK.
Apple sólo mide descargas/uso agregado de campaña; no enlaza una cuenta Dopmi
con su primera ficha/mensajes. No hay atribución automática de instalación
iOS equivalente a Android en este lote. Plan/contrato y evidencia: `progress.md`,
`facebook-rescuer-experiment.md` y
`superpowers/plans/2026-11-20-production-attribution.md`.

Precisión P3 para un próximo delta: el aviso de Analítica dice «primer mensaje
escrito», pero el hito de compositor cuenta texto o foto, como documenta el
reporte. No confundir esta etiqueta con un contador exclusivo de texto. La
revisión de privacidad no encontró una discrepancia P1/P2 nueva.

## Continuidad histórica d304535 — 17/10/2026

Titular aprobó el plan de paridad d304535 y sus decisiones, registradas en product-decisions.md. Base c53b6686 / Play314; seguir codex/finish-release-20261015. Matriz única parity-current-review.md, checkpoint mock-sync-current.md.

B0 cerrado17oct tras disponibilidad del Samsung y revisión independiente. Play314/Vending y sesión conservada; no repetir alta/Setup/Guardián. Puntual10 único, confirmado y transferido5.84; Guardián20 existente transferido15.17. Cotejo proveedor6GET/0writes, total30TEST, postflight sin objetos inesperados y cancelación normal SQL/UI. Diario histórico intacto; recibos posteriores privados enlazados en mock-sync-current.md. B1/B2 liberados; producto nuevo aún sin gates, CI, publicación ni aceptación. No confundir los pendientes históricos inferiores de313/CI/build con la evidencia posterior314.

# Candidato Guardián y pagos — 15/10/2026 México

El titular encarga a Codex terminar directamente este release sin depender de
Paperclip. CEO, Desarrollo, Calidad y Mejora IA quedaron pausados estando libres;
se conserva su evidencia. Se reutiliza un solo seguimiento operacional.

Base `23f64786d96586e04feb53652d209d33ebb5f1b7`, continuación
`codex/finish-release-20261015`. El checkout original tiene cambios ajenos y no
se limpia ni superpone. Referencia congelada
`0962ebec70bacf9ff8707960bb0908e5b979acfe`, conservada privadamente en
`development/dopa39/reference0962ebe/App.tsx`.

## Alcance humano vigente

Decisión14oct: registrar Guardián aun sin capacidad, sin cargo/deuda/recobro;
evaluar el siguiente aniversario mensual. Conciliar el mismo intento; éxito y
error confirmados, acción bancaria cuando sea necesaria y fallos mensuales en
Perfil/Tu impacto. Implementar primero y auditar después diseño residual.
No pedir otra vez variantes como bloqueo previo a la implementación.
Mínimo Guardián20MXN, puntual10MXN; este lote conserva la fórmula financiera
existente y no autoriza dinero real.

## Delta implementado

- Tarjeta Guardián mediante SetupIntent y PaymentSheet dentro de Dopmi:
  consentimiento previo, propietario, lease, clave estable y confirmación servidor.
  Apple/Google mantienen controles separados; Checkout histórico conserva canal.
- Puntual mediante PaymentIntent ligado antes de abrir SDK, reserva completa y
  settlement existente. Expiración1h conserva el límite Checkout anterior;
  sólo cancelación confirmada libera, sin nuevo cargo ante incertidumbre.
- Intento Guardián marcado/no enviado/rechazado se cancela y consulta sobre el
  mismo recurso. Método nulo sólo en canceled/requires_payment_method ya ligado;
  éxito/acción/método extranjero o identidad incompleta siguen rechazados.
  requires_confirmation conserva120s de gracia para no cancelar un envío concurrente.
- pk_test independiente de billeteras; disponibilidad y avisos seguros, clave
  conservada, navegación bloqueada durante SDK y consulta sin segundo envío.
  Perfil/Tu impacto muestran el intento terminado sin cobro.
- El SDK comprueba propietario/ruta antes y después de inicializar: cerrar sesión
  o salir no abre una hoja de pago del actor anterior. Recibos terminales e
  históricos se leen con filtro de propietario aunque la admisión nativa esté
  cerrada. Accesos de pagos refluyen al ampliar texto, sin partir palabras.
- Webhook del PI Guardián concilia únicamente su intento marcado/vinculado y
  ciclo de SQL; una entrega duplicada termina sólo jobs pendientes de ese ciclo.
  Relee evidenciaTEST y no autoriza cobros ni busca candidatos globales. La
  ausencia de binding se distingue de un fallo de permisos/RLS, que conserva503.

## Evidencia actual y límites

Paquete privado: `C:/Users/betoq/Paperclip-Dopmi/development/dopa39/integration-test-package-23f64786`.

PostgreSQL17.6 real59/59, `codex-registration-postgres-v3.log`: fuentes actuales
en base nueva temporal, carreras con dos conexiones para registro y puntual.
Contenedor dedicado/tmpfs, puerto127.0.0.1:55432, sin datos de negocio ni
AuthHTTP/Stripe. Red interna+bridge para Windows; no afirmar salida aislada.
No se parcheó el stack antiguo ni se tocaron sus volúmenes.

Backend completo782/782, `codex-full-backend-v2.log`, antes del último caso de
gracia concurrente; consumer final32/32 y puntual38 dirigidas. Configuración
móvil17/17. Primer fallo backend era proyección ampliada
stripe_payment_intent_id:null; corrección y regresión561/561.

Flutter analyze sin incidencias (`codex-mobile-analyze-v2.log`, antes del último
ajuste de perfil/guardas SDK). La suite completa local obtuvo1085 aprobadas y8
fallos, conservados en `codex-mobile-full.log`: fixtures de disponibilidad,
desplazamiento y etiquetas anteriores, lectura de recibos y navegación pendiente.
Se corrigieron agrupadamente; después118/121 dirigidas identificaron tres
restantes. El corte final19/19 (`codex-mobile-async-final.log`) comprueba esas
correcciones y sesión cambiada durante respuesta503;53/53
(`codex-mobile-profile-final.log`) comprueba registro y accesos al100/200%.
Formato de19 archivos Dart sin cambios. CI completa nueva aún debe acreditar
todas las comprobaciones juntas en el commit final; no extrapolar del subconjunto.

Revisión independiente de capturas actuales cerró el defecto de palabras
partidas al200%. Capturas en `codex-native-captures-release`; demuestran widgets,
no PaymentSheet bancario, lector de pantalla ni teléfono real. Diseño residual
se audita después de esta implementación: registro sin cobro, conciliación y
método pendiente/expirado no vuelven a bloquear código por un diseño previo.

Siete definiciones/ACL remotas y cuatro bundles Edge actuales respaldados mediante
conector propio. La operación agrupada16SQL pasó ensayo PostgreSQL real sobre83
fuentes base y los siete originales remotos exactos: STOP por drift inducido,
COMMIT único y postflight19 funciones/6 tablas/ACL/RLS; base UUID eliminada.
Recibo `codex-operation/operation-local-rehearsal-receipt.json`.
Tres GET de metadatos de cuentas Connect TEST existentes verificaron tipo/país/
capacidad, sin propietarios/PII, cambios ni transferencias; destino nominal sólo
para fixture local. No migraciones remotas, flags, pagos, KYC o producción
modificados en este corte.

## Cierre pendiente

1. CI completa por SHA/evento/workflow.5b3c15e1/run38835112715 final4/4verde:
   web/base, Flutter (analyze0,1113tests, capturas y APK debug), iOS simulator,
   integración identidad/adopción. No es publicación firmada ni Play.
   El primer379d8baf/run38833853805 tuvo3jobsverdes y Flutter detenido por tres
   infos de análisis ya corregidas, sin quitar reglas. La auditoría remota después
   encontró un webhookPI Guardián que caía al procesador puntual; corrección
   acotada y revisión independiente favorables,46/46 dirigidas y4entrypoints
   Deno comprobados (`codex-registration-scoped-webhook-final.log`). Ese delta
   backend requiere su commit/CI nueva; no atribuirle la CI anterior por inferencia.
2. Una operación revisada:16 fuentes SQL agrupadas con guardas, postflight,
   cuatro bundles Edge, flags TEST nominados y ensayo finito. Sólo DEV
   ohqxranynackjignryep; PRODysaoeuidcvgtlmphmeyb excluido. Sin replay/repair/purga.
   Conservar expansión/reconciliadores después de jobs nativos; no restaurar
   ciegamente tres RPC anteriores ni prometer reversión de efectos Stripe por SQL.
   Ensayo proveedor preparado, NO ejecutado:1Customer/1SetupIntent/máximo4
   PaymentIntents,30MXN TEST esperados y50MXN TEST intentados,96 peticiones máximo;
   sin transferencias. No prueba webhooks reales ni entrega al rescatista por sí solo.
   Los flags actuales no delimitan una cohorte; no prometer aislamiento por actor
   sin control efectivo. Cambios remotos/recorrido TEST necesitan la decisión
   concreta agrupada, no heredan los permisos de lectura anteriores.
3. Autenticación Stripe ya disponible: clave publicable TEST recuperada del
   sandbox correcto y ligada al tenant obtenido con GET /v1/account. Petición
   Codemagic preparada con override público por build; no necesita persistir
   una variable nueva ni copiar claves privadas. Build aún no disparado.
   Dashboard Supabase DEV autenticado permite configurar el flag puntual nuevo,
   actualmente ausente, sin ampliar accesos. Los seis flags Guardián ya estaban
   habilitados. Lectura real del webhook TEST detectó cuatro eventos faltantes:
   setup_intent.succeeded/canceled/setup_failed y payment_intent.canceled.
   Incluir unión exacta conservando los21 eventos anteriores, URL, versión y
   secreto en la autorización agrupada; todavía no se modificó configuración.
   Cron existente activo cada minuto, colas financieras agregadas sin elegibles
   al corte01:27Z; no crear otro timer ni invocar reconcile global como probe.
   Capacidad actual de dos gastos DEV aprobados suficiente para Guardián20;
   lectura predictiva no es barrera de concurrencia ni prueba de caso sintético.
   Preparar un único recorrido financiero remoto revisable que sustituya el
   ensayo financiero local aún PENDING; no ejecutar ambos ni crear otras cuentas
   por inferencia. AuthAdmin de dos identidades técnicas requiere alcance y
   acceso específico en la misma decisión agrupada; sin INSERTauth/PII/grants.
4. Integración TEST real y android-guardian-internal/com.mycompany.dopmi.
   Publicación Play se comprueba separada del build; teléfono/aceptación humanos
   siguen pendientes. El campo teléfono vacío fue observado EN APP por titular;
   no inferir estado Auth ni enviar SMS/cambiar cuentas.

Ruta local/DEV existente sin Pro ni proyecto/rama nuevos: incremento de planUSD0.
No se contrató plan; cuotas/saldo Codemagic se comprueban aparte. Una compra nueva
requiere costo/alcance concreto, no se infiere del permiso condicional Supabase.

## Traslado y retro

Captura20261015T234131Z-014202 conserva9536 archivos comprobados, pero no es
respaldo final completo: automatización y tareas cambiaron durante captura.
Se conserva compañía/originales y trabajo comercial independiente; no borrar.

La cadena anterior acumuló preparación/lecturas y esperas sin integración.
Esta continuación usa checkout conservado, ejecución directa, revisión acotada y
una cola Flutter. Juzgar resultados/gates/candidato, no roles/acuses, autonomía
general o ahorro de tokens/costo inferido de una muestra pequeña.
