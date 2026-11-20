# Atribución de campañas y acciones

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
Android usa Play Install Referrer; no se solicita código al usuario. iOS no
tiene atribución automática de instalación equivalente implementada en este lote.
Se conservan sólo variante y fechas necesarias, nunca la cadena original,
identificadores de Facebook, contenido de mensajes o datos de otro participante.

La fuente requiere cuenta activa, consentimiento de Analítica de uso y clic
vigente dentro de336horas. Es la primera fuente elegible por cuenta y se
retira con opt-out o eliminación. La ausencia de una elección local en otro
equipo mantiene su Analytics local apagado, sin revocar la elección global.
El consentimiento usa una revisión del servidor para rechazar una escritura
antigua que llegue después de una decisión más reciente. OFF tiene prioridad
frente a solicitudes pendientes del mismo cliente; no se usa un ID de dispositivo.
La cohorte excluye envíos/revisiones de fichas anteriores observables; un
borrador previo no la excluye. No se reconstruye historia eliminada.

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

La fuente953d3342 pasó en DEV416: instalación limpia del enlace personal-a,
primera ficha privada en Samsung y reinstalación sin revocación implícita.
Recibo histórico: rama `codex/facebook-rescuer-attribution-395`, commit5a4faef2.
Esa prueba no acredita el candidato integrado de producción ni los eventos nuevos.
Sus dos fixtures privados ya consumidos no se reutilizan ni se aprueban/publican.

Antes de retomar A/B: gates por SHA, SQL revisado y cotejado, candidato instalado
del mismo código y recorrido real. Separar clics, cuentas atribuidas y resultados;
comparar cohortes maduras y no anunciar ganadores por inspecciones repetidas.
Este lote no activa SDK/transferencias publicitarias de Meta/TikTok ni campañas
pagadas. La atribución de esos proveedores requiere su contrato y consentimiento
separados; los cuatro enlaces orgánicos no equivalen a su medición publicitaria.
