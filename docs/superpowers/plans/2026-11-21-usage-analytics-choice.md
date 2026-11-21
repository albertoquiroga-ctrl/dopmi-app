# Elección inicial de Analítica de uso

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ofrecer Analítica de uso preseleccionada, activarla sólo tras confirmar la elección y conservar la opción de desactivarla.

**Architecture:** Un aviso opcional autenticado, separado de los términos, cubre correo, Google y Apple. El SDK comienza apagado; el estado servidor distingue ausencia de decisión de un OFF anterior y registra las nuevas acciones con versión y fecha. Se reutilizan el consentimiento de atribución, CAS y los controles existentes.

**Tech Stack:** Flutter/Riverpod, SharedPreferences, Firebase Analytics, Supabase/PostgreSQL.

**Spec:** Petición del titular del21/nov/2026 en este chat; decisiones conservadas en `docs/product-decisions.md`. Base verificada35204afd, producto1441e295, QA423/424. La selección inicial no se declara como consentimiento ya otorgado.

## Global Constraints

- Analítica opcional: ON visual antes de confirmar; cero colección antes de una acción real. Se puede continuar con OFF.
- Conservar todo OFF local/remoto, incluso revisión0, reinstalación, otra cuenta y otro teléfono. Un nuevo gesto explícito sí puede modificar la elección.
- Crashlytics, PostHog/publicaciones, anuncios y seguimiento publicitario permanecen separados. No ampliar payloads ni SDKs.
- Sin backfill ni reinterpretación de aceptación legal, metadata editable o decisiones históricas. SDK nativo inicialmente OFF.
- Preservar PROD, identidad, Tienda, adopciones, finanzas, piloto CPP y una cola Flutter. SQL/publicación remota y fichas se concilian por separado de implementación.

## Review Focus

- Restauración ON local frente a OFF remoto: no resucitarlo ni escribir ON automáticamente.
- Ausencia de fila frente a OFF/revisión0: sólo ausencia ofrece la selección inicial.
- Timeout/conflicto o cambio de cuenta durante la elección: no activar ni repetir una escritura incierta.
- Rechazo de medición o fallo de red: la funcionalidad del producto sigue disponible sin colección.
- Aviso legal, ubicación y analítica: no superponer permisos ni confundir aceptar términos con consentir medición.

### Task1: Estado y evidencia de elección

**Files:** Nueva migración `usage_analytics_choice`; `tools/verification/usage-analytics-choice-sql.test.mjs` y registro del gate.

**Interfaces:** `dopmi_adoption_measurement_state()` añade `has_choice` y `notice_version`; `dopmi_choose_usage_analytics(consent boolean, expected_revision bigint, notice_version text)` exige `usage-analytics-2026-11-21`, usa CAS y devuelve estado/applied. Recibos privados, fecha servidor y borrado con cuenta.

- [x] Probar ausencia, OFF/rev0, CAS/carreras, clientes anteriores, permisos y eliminación primero en rojo.
- [x] Implementar mínimo SQL aditivo sin modificar los RPC anteriores; ejecutar pruebas y PostgreSQL aislado.
- [x] Revisar independientemente contrato/seguridad antes de preparar cualquier aplicación remota.

### Task2: Restauración, elección y aviso

**Files:** `core/adoption_measurement_consent.dart`, `core/measurement.dart`, `core/usage_analytics_choice.dart`, `main.dart`, `app.dart`; nuevo `features/profile/usage_analytics_prompt.dart`; textos nativos `features/identity/auth_screens.dart` y `privacy_notice_screen.dart`; pruebas de transporte/controlador/UI.

**Interfaces:** Lectura autenticada y elección explícita versionada en el transporte. Controller restaura estado confirmado antes de habilitar Firebase y expone si falta elegir. Aviso recibe `Future<void> Function(bool) onConfirm` y `VoidCallback onPrivacy`; selección inicialtrue, botón de guardar y alternativa OFF. Gate después de legal/antes de ubicación; ajustes conservan retirada.

- [x] Escribir regresiones de no colección inicial, ON confirmado, OFF previos, otra cuenta/dispositivo, conflicto/timeout y retirada.
- [x] Implementar lectura/elección y restauración sin escrituras ON; bloquear operaciones obsoletas por generación y pausar al retirar.
- [x] Implementar aviso accesible y prueba a320px/texto200%; integrar gate sin alterar aceptación legal ni rutas exentas.
- [x] Ejecutar pruebas enfocadas, análisis y suite Flutter por la única cola; revisar UI/UX/código/seguridad.

### Task3: Transparencia y distribución

**Files:** Delta exacto de términos/privacidad en el sitio existente; matriz de categorías Apple/Play; continuidad en documentos existentes.

- [x] Contrastar eventos/identificadores reales con los avisos y fichas, sin asumir que declaraciones históricas son actuales.
- [x] Preparar diffs y paquetes revisables; aplicar SQL/textos autorizados y verificar readback.
- [x] Publicar y cotejar las tres categorías de App Privacy Apple.
- [x] Conciliar y enviar un cambio Data Safety Play, incluida ubicación precisa funcional.
- [x] Comprobar publicación de Data Safety Play: Submission165 Published, un único cambio.
- [x] Congelar fuente y CI de cuatro trabajos.
- [x] Ventana de cinco minutos antes del único Android6b021e276328dae170dd4245.
- [x] Consumir ventana iOS22:50:46.648–22:55:46.648UTC y enviar un único POST tras Android terminal (6b02219da77af65f4a2437b1).
- [x] Comprobar AAB/runtime/firma425 y publicación Play interno por separado.
- [x] Comprobar IPA/runtime/identidad426 del único iOS; firma/perfil sólo estructurales.
- [x] Comprobar posprocesamiento Apple426 terminado sin error y disponibilidad TestFlight/DopMi Inner Team/5invitaciones, Lista para enviar.
- [x] Titular confirma426 instalada, sesión/navegación correctas y retirada con OFF persistente tras guardar/cerrar/reabrir; conservar el estado finalOFF.
- Límite de esta aceptación: preferencia previa desconocida; no acredita primera elección/onboarding nuevo ni eventos SDK en red. Android sigue sin instalar por el bloqueo de Play.

## Evidencia del corte local

- SQL4673B4028bc86…a13080:12/12 pruebas nuevas con PostgreSQL real; Node1354PASS/0FAIL/9SKIP. Wrapper PROD18468B7bb6e22e…fd9412,12/12 guardas/rollback local. Revisión independiente sin P1/P2; aplicado una vez en PROD como20261121223246/usage_analytics_explicit_choice_20261121. Postflight4conjuntos/16PASS, historia72 y prefijo71intacto.
- Flutter92 pruebas enfocadas PASS, después suite completa1965PASS/4SKIP. El último delta de copy legal y orden previo a Nearby tiene17 comprobaciones enfocadas/render PASS y regresiones finales95PASS; CI44878177593 verificó toda la fuente final. Configuración42PASS y análisis0incidencias. No equiparar ese primer full local al SHA posterior.
- Cinco capturas de widget real sintético390×844 y320×640/texto200%, cero callbacks al capturar. Revisión UI/UX independiente sin P1/P2; no equivalen a aceptación física ni TalkBack/VoiceOver.
- La revisión halló y corrigió dos P2 antes de publicar: error de lectura no revoca globalmente y OFF incierto no genera segundo POST v2. Regresiones combinadas cubren OFF leído después del primer ON y retirada con disco demorado/cambio de cuenta. No incidente remoto.
- HTML propuesto revisado: privacidad28811B5df1686a…9a741cb; términos3955Bad358012…cdb0054c.18 validaciones locales, baselines públicos conservados. Textos publicadosc95be7f/READY y HTTP200hash exactos. Apple publicó tres categorías/16tipos/trackingNO; Play Submission165 Published con un único cambio Data Safety. Deltas en `docs/h10-store-privacy-declarations.md`.
- CI44878177593 terminó cuatro trabajos SUCCESS paraaf0e2274: fuente final completa, Android/iOSsimulator, privacidad nativa, capturas, PostgreSQL e integración Auth/Storage/Realtime. Sin builds Codemagic ni modificación de producción por esta CI.
- Autorización propia recibida y SQL/textos cotejados; App Privacy Apple publicado. Android6b021e276328dae170dd4245 terminó14SUCCESS/425, Play interno completed/publicado y AAB/runtime/firma cotejados (shipping.verified). iOS6b02219da77af65f4a2437b1 terminó15SUCCESS/426; IPA/runtime cotejados, tarea Apple terminada sin error y TestFlight/DopMi Inner Team disponible. Titular confirma426 instalada, sesión/navegación y retirada/OFF persistente tras guardar/cerrar/reabrir; preferencia previa al ON desconocida, sin primera elección/onboarding nuevo o SDK en red acreditados. Un intento del Samsung falló en Play, sin código ni versión solicitada acreditados; paquete ausente. Pendiente externo: expediente de descarga Samsung, sin otra QA humana solicitada para este alcance iOS. Fichas Apple/Play publicadas, sin promoción pública del binario. No cambiar edades ni activar SDK publicitario.

Fuente congelada `af0e2274f13a51c10a13e8579fd932f35f1ebf58`, tag
`codex/usage-analytics-choice-af0e2274`, CI
[44878177593](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/44878177593).
La publicación de esta rama no aplica SQL ni cambia servicios o fichas.


Cierre de distribución21/nov: SQL, textos y declaraciones Apple/Play publicados;
Android425 interno e iOS426 TestFlight verificados. El perfil cliente mantiene
adopciones/TiendaON; eso no cambia flags ni apaga servicios remotos. No se
promovieron binarios públicos. El titular confirmó el alcance iOS de sesión/
navegación y retirada con OFF persistente; no cubre los límites anteriores ni
la instalación Android bloqueada. No reabrir CI/builds por esperar al proveedor.
