# Atribución de campañas y acciones

## Prueba CPP personal-a — corte20nov2026

El piloto individual iOS se implementa por separado sobre el corte reciente
e48a653b, conservando también compartir perfiles por HTTPS. Captura el destino
estático `io.dopmi.app://acquire/personal-a` al abrir desde la CPP; después del
login normal y del consentimiento inscribe la cuenta con revisión CAS exacta.
No añade códigos, login previo a descarga, portapapeles ni SDK de matching.
Primer contexto/propietario inmutables, pendiente local24h y observación iOS14d
desde inscripción servidor. La fuente se identifica como `ios_cpp_open`, no
como prueba de instalación o clic de Facebook. Los cinco hitos siguen separados.

CPP `f72ab3bc-1cd0-49b7-9220-cff726c86ffd` guardada en borrador desde2.3.8(419).
No se ha enviado ni activado su `ppid` en la landing. Las rutas públicas actuales
siguen midiendo agregados Apple. No hay iPhone físico disponible: ni las pruebas
automatizadas ni una carga TestFlight acreditan instalación desde CPP y eventos
reales. Gates, límites y aceptación en el [runbook](ios-cpp-personal-a-runbook.md);
estado de CI, despliegue y candidato en [candidate-release-current](candidate-release-current.md).

## Integración de producción20nov2026

Alcance aprobado: recuperar mejoras recientes y llevar atribución a producción,
incluyendo por separado ficha enviada, aprobación de esa ficha, saludo automático,
primer mensaje humano como adoptante y primera respuesta del rescatista.
Plan e inventario: [production-attribution](superpowers/plans/2026-11-20-production-attribution.md).
La base es c9d9d03d, descendiente del release público4092.3.7; la rama395 de
atribución no es la base de publicación.

## Contrato del piloto orgánico

Los enlaces `https://www.dopmi.org/descargar/personal-a`, `personal-b`,
`pagina-a` y `pagina-b` distinguen identidad de Facebook y variante del texto.
Android usa Play Install Referrer; no se solicita código al usuario. La medición
iOS se limita a las métricas agregadas de Apple descritas abajo, sin login Dopmi
previo a la descarga ni atribución individual equivalente a Play Install Referrer.
Se conservan sólo variante y fechas necesarias, nunca la cadena original,
identificadores de Facebook, contenido de mensajes o datos de otro participante.

La fuente Android requiere cuenta activa, consentimiento de Analítica de uso y clic
vigente dentro de336horas. Es la primera fuente elegible por cuenta y se
retira con opt-out o eliminación. La ausencia de una elección local en otro
equipo mantiene su Analytics local apagado, sin revocar la elección global.
El consentimiento usa una revisión del servidor para rechazar una escritura
antigua que llegue después de una decisión más reciente. OFF tiene prioridad
frente a solicitudes pendientes del mismo cliente; no se usa un ID de dispositivo.
La cohorte excluye envíos/revisiones de fichas anteriores observables; un
borrador previo no la excluye. No se reconstruye historia eliminada.

## iOS: descarga directa y campañas de App Store

El titular solicita publicar esta misma versión en Apple y rechaza iniciar sesión
en Dopmi antes de descargar: «Prefiero descarga directa; investigar otra vía».
Los cuatro enlaces conservan el salto directo a App Store en iPhone/iPad.
Los campaign links se generaron desde una sesión autenticada de App Store Connect:
`pt=124107377` es el token público de la cuenta desarrolladora, no una credencial
ni un identificador de la persona que descarga. Se reutiliza con `mt=8` y estos
tokens de campaña:

| Variante | `ct` |
| --- | --- |
| `personal-a` | `resc_mty_personal_a` |
| `personal-b` | `resc_mty_personal_b` |
| `pagina-a` | `resc_mty_pagina_a` |
| `pagina-b` | `resc_mty_pagina_b` |

Apple mide descargas por campaña y métricas de uso de Apple agregadas. La primera
descarga debe ocurrir dentro de 24 horas del enlace. La campaña necesita primeras
descargas de al menos cinco usuarios de Apple distintos; cada métrica también
está sujeta a su umbral de cinco. Los resultados aparecen después de al menos
24 horas y pueden demorarse. No se atribuyen a una cuenta Dopmi su primera ficha,
saludo, mensaje o respuesta, ni se mezcla esta cohorte con Android/14 días.
Fuente: [campaign links de Apple](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links).
El uso de la app sólo incluye personas que aceptaron compartir diagnósticos y uso
con desarrolladores mediante Apple; no activa Analytics/Crashlytics de Dopmi ni
reemplaza sus consentimientos independientes.
Fuente: [métricas de uso de Apple](https://developer.apple.com/help/app-store-connect-analytics/engagement/app-usage/).

Implementación de landing: dos archivos, commit
`d9e842c3fd9c5a23f20a8d7fdc624ac29df32813` de main; 16 pruebas HTTP aprobadas y
revisión independiente sin P1/P2. Los helpers Android permanecen iguales.
Sólo se configura el token público como `APPLE_CAMPAIGN_PROVIDER_TOKEN` en
producción; ausente/inválido conserva la URL Apple original sin campaña. El
despliegue Vercel `dpl_GpUoMfppLmK1W6iJqQa1ebaj6iBz` terminó READY y sus aliases
www/apex quedaron comprobados. El postflight de red verificó GET y HEAD iOS de
las cuatro variantes con 302 y `pt/ct/mt` exactos, HTML 200 para crawlers con
enlace Apple etiquetado y cuerpos Android con los mismos SHA256 anteriores.
Las queries no sustituyen el destino; la ruta simple ignora la campaña y las
rutas desconocidas conservan el 404 de la allowlist Vercel. Recibo privado:
`landing-production-postflight.private.json`. No se añadieron credenciales ni
datos personales. Aún no hay instalación real de este recorrido en iPhone ni
métricas de campaña recibidas de Apple.

Investigación posterior20nov: Apple sí documenta una vía adicional mediante
Custom Product Pages con deep links en iOS18+, al pulsar Abrir en esa página.
La conclusión anterior no implica imposibilidad de toda atribución individual:
la opción CPP permite proponer transportar la variante hasta la app y ligarla
a la cuenta después de login/consentimiento. Todavía no está implementada ni
probada en iPhone; abrir desde el icono no tiene la misma garantía documentada.
La URL estática tampoco entrega hora del clic original ni prueba de instalación.
Alcance, alternativas y prueba acotada en
[investigación iOS de descarga directa](ios-direct-attribution-research.md).

## Resultados separados

- Primera ficha original enviada a revisión dentro de14d, y aprobación posterior
  de esa misma ficha, incluso después de correcciones.
- Primer saludo automático iniciado por la cuenta atribuida.
- Primer mensaje enviado desde el compositor por esa cuenta como adoptante;
  texto o foto válidos cuentan, apertura y saludo automático no.
- Primera respuesta desde el compositor por esa cuenta como dueño de la ficha,
  con mensaje entrante previo del adoptante; puede responder un saludo.

Los mensajes se distinguen por origen asignado en el servidor desde esta entrega.
Los anteriores quedan desconocidos; no se examina su texto para clasificarlos.
Los hitos son primeros eventos observables posteriores a atribución dentro de14d,
no necesariamente primeros mensajes históricos de la persona. La aprobación
posterior conserva la regla del primer envío ya implementada.
Reintentar el mismo UUID no produce otra conversión. No se atribuye al rescatista
una acción que realizó el adoptante, ni viceversa.

El reporte agregado `tools/verification/android-rescuer-acquisition.sql` mantiene
los denominadores por variante, cohortes maduras y cuentas nuevas; expone cada
resultado separado. Un saludo no es evidencia de conversación escrita ni de
respuesta. Una fuente pendiente se intenta resolver antes de persistir la
acción, con espera limitada y continuidad del producto ante fallo de medición.

## Evidencia previa y salida

Integración vigente: fuenteee3ef773/CI44823640872 cuatroSUCCESS; SQL PROD agrupado
20261120221225 y Admin de esa fuente desplegados/cotejados. Candidato Android
2.3.8(418) compilado/publicado por Codemagic6b00c856, backendPROD y mediciónTESTOFF;
Play cerrado attribution-dev-qa/release6 disponible20nov17:27CDMX. Samsung418/
Vending instalado limpio desde personal-a: consentimiento PROD autorizado en UI,
fuente atribuida18:16:54 y primera ficha enviada18:22:35CDMX. Unión exacta de
fuente/cuenta/ficha comprobada, submitted/una foto/publicadoNULL; sin inserción
o backfill SQL de atribución. La ficha QA permanece privada en revisión.
QA de visor/compartir/Tienda y reinstalación cerrada en Samsung: fuente y primer
envío preservados, sin revocar consentimiento por ausencia de preferencia local.
El mismo418 se promovió a producción/release43 y se envió a revisión20nov18:44CDMX;
Play UI confirmó 2.3.8(418) Active y versión más reciente a las 19:41 CDMX, por lo que
supersede el estado previo de 409 público/disponibilidad pendiente. Los nuevos
hitos de mensajes tienen prueba PostgreSQL real, todavía
no un recorrido de mensajes entre participantes en el candidato instalado.

Apple 2.3.8(419) conserva el producto ee3ef773 y sólo cambia las notas en efcce99f.
Codemagic6b00f498 terminó 15 pasos SUCCESS y cargó el IPA. El posprocesamiento
`6b00f7c1a14b9f22af0120e5` terminó sin error a las 19:50 CDMX: creó la versión
2.3.8 con notas es-MX y publicación AFTER_APPROVAL, y envió ReviewSubmission.
El estado confirmado es WAITING_FOR_REVIEW (Esperando revisión); no acredita
aprobación, disponibilidad pública ni QA instalada de iOS.

El reporte bruto incluye la cuenta QA utilizada para este ensayo. Excluirla de
los denominadores y resultados antes de comparar variantes, mediante la consulta
privada `pilot-with-qa-excluded.private.sql` del recibo de la entrega. Cotejo
posterior al ensayo: cero cuentas/conversiones reales por las cuatro variantes.
No borrar la prueba ni contar su primer envío como adquisición de un rescatista.

La fuente953d3342 pasó en DEV416: instalación limpia del enlace personal-a,
primera ficha privada en Samsung y reinstalación sin revocación implícita.
Recibo histórico: rama `codex/facebook-rescuer-attribution-395`, commit5a4faef2.
Esa prueba no acredita el candidato integrado de producción ni los eventos nuevos.
Sus dos fixtures privados ya consumidos no se reutilizan ni se aprueban/publican.

Antes de retomar A/B: gates por SHA, SQL revisado y cotejado, candidato instalado
del mismo código y recorrido real, más disponibilidad pública del418. Gates,
SQL, recorrido Android y disponibilidad pública del418 ya cerrados. Separar clics,
cuentas atribuidas y resultados Android de las métricas agregadas Apple;
comparar muestras y cohortes maduras, sin anunciar un ganador estadístico antes
de contar con ellas ni por inspecciones repetidas.
Este lote no activa SDK/transferencias publicitarias de Meta/TikTok ni campañas
pagadas. La atribución de esos proveedores requiere su contrato y consentimiento
separados; los cuatro enlaces orgánicos no equivalen a su medición publicitaria.
