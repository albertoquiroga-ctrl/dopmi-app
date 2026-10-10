# Loop753 — Descarte del reporte público

2026-10-04. Basedf5b97b, SourceIrlanda a3c969cd9103fd46dc5cd886999912526ce75efb sin cambios inicio/cierre.

Source ejecutado Edge377x852/rescuer-profile/María R., Reportar, motivoBorrador local. Click real mouse down/up en4,4 fuera de tarjeta mantiene título Reportar rescatista y textareaBorrador local. ReportDialog Source no declara onClick de backdrop. Flutter showDialog heredaba barrierDismissibletrue, perdiendo borrador. Se cambia a false; Cancelar/Cerrar y Back siguen disponibles, guardas durante envío intactas.

Tests existentes normal200 conservan caso barrier: escriben borrador, tapafuera mantiene dialog/resultado no retornado/texto; luego Cancelar termina sin resultado. Final53508:13/13 en3s content_actions/content_report_flow; analyzer pendiente al redactar. No tests nuevos contabilizables ni envío remoto.

Captura inicial48959 exit0:1/1 en7s, sietePNG de reporte antes del cambio de barrera (cambio no altera layout). Se inspeccionaron seis normal/grande, error/enviando en hoja nativa sin escalar. Grandes inicial/error/enviando se desplazan: título/campos fuera de viewport pueden ser scroll deliberado. En error grande el texto de acción aparece pegado al borde; requiere medición de bounds y contraste, no se da por aceptado. Keyboardlarge ya revisado748; no Androidnativo.

Sin Codemagic, paridad global/nativa pendiente; dinero test-only. Próximo resolver medición de acción ampliada detectada, sin repetir gate global por mera inspección.

Analyzer53508 terminó exit0 limpio51.1s sobre producción y tests finales. Full748/801 anterior749/751/752/753; APK748 también anterior. Browser propio cerrado.
