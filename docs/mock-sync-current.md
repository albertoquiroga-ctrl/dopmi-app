# Checkpoint de sincronización — 6 de octubre de 2026

## Entrega activa 9ced070 — MVP_CONTINUO autorizado

Inicio: **2026-10-07T03:33:46Z** (6/10, 21:33:46 en México).
Presupuesto global: 90 minutos; cierre desde las 04:53:46Z y parada a las
05:03:46Z. No se renueva por lote. El plan aprobado está guardado en
[parity-current-review.md](parity-current-review.md), único tablero.

App base `0484f8075c893497c10f6291553071eab7b4e5bf`, rama
`codex/design-foundation`; PR #6 abierto y borrador, remoto coincidente.
Mockup `irlanda/apoyar-detalle-perfil`, objetivo congelado
**9ced07094635c076d35589647fff26371d8bc791**, desde bccd040: un commit y seis
archivos. Los pushes posteriores quedan fuera de esta entrega.

Inventario de nueve grupos: UX01 chrome; UX02 Inicio y estados; UX03 métricas
y período; UX04 paneles y mensajes; UX05 consejos; UX06 Perfil; UX07 redes y
configuración; UX08 Croquetas, excluido por tienda; UX09 final de Adoptar.
Ocho grupos incluidos. L0: protocolo y plan; L1: contratos, SQL y compartidos;
L2: pantallas; L3: gate, DEV y Play.

L0 y L1 implementados; L2 integrado y en revisión focalizada. Los ocho grupos
están implementados. Flutter analyze inicial aprobado: cero incidencias en
170.9 segundos. Primera pasada dirigida: 81/88; corregidos siete fallos de
fixtures/visibilidad. Segunda pasada: 37/37 en cinco archivos afectados,
incluida nueva prueba de fecha México. Gate, publicación y aceptación pendientes.
QA profundo, visual, nativo e instalado corresponde a la fase posterior.

Decisiones: actividad real por período en `America/Mexico_City`; registro
diario consentido, sin historia inventada. DEV aditivo, CI y Play interno
autorizados. Sin Edge Functions, cambios de flags financieros, dinero live,
fixtures anteriores, limpieza global ni merge.

Tres agentes reutilizados, sin nuevas invocaciones. Sus tres frentes están
implementados; integración focalizada de capturadores y pgTAP en curso.
No ejecutan Flutter, publican ni delegan recursivamente. El integrador posee
router, contratos, repositorios, SQL, compartidos y la única cola Flutter.
Codemagic: 0/2 builds.

Consumo del presupuesto: aproximadamente 22 minutos. La primera pasada Flutter
detectó siete fallos: cinco fixtures de identidad, un reintento fuera del área
visible y una pestaña fuera del área visible con texto al 200%. Los fixtures
y el capturador se corrigieron; el test Home centra la pestaña y comprueba
que recibe el toque antes de tocarla. Segunda pasada limitada a cuatro
archivos afectados, pendiente. Configuración: 16/16 comprobaciones aprobadas.
No se atribuye todavía aprobación al candidato consolidado.

Backend 9ced: 6/6 comprobaciones aprobadas en PGlite local. Comparación Date
del fixture corregida en el segundo intento; no fue un defecto SQL ni se
consumió un fixture remoto. Evidencia privada local:
`.tools/update9ced/backend-2.stdout.log`; no está disponible en GitHub.

Acceso comprobado: GitHub, lectura Codemagic y catálogo Supabase DEV.
Flutter 3.47.4; ADB Samsung y emulador presentes, sin atribuir aceptación.
Docker detenido: PostgreSQL e integración completos mediante el gate de CI.
Goal activo creado por el titular; autorización explícita de pausa al cierre
seguro, sin autorrelanzamiento.

Cambios locales ajenos preservados. Baseline privada:
`.tools/update9ced/baseline` e `initial-dirty.patch`, fuera de GitHub.
Admin 42501, documentos y archivos no rastreados ajenos no son este encargo.
L1 incorpora migración `20261007033748_rescuer_funnel_9ced`, DTO tipado y
deduplicación diaria cliente. L2 cubre Inicio, Perfil/redes, Apoyar y final de
Adoptar.

DEV: preflight el 7/10 a las 03:48Z, último historial anterior
`20261006142458`; registro existente y permisos coincidentes con SQL canónico.
La migración local `20261007033748` se aplicó una vez como
`20261007034858` remota. Postflight a las 03:49Z: tabla diaria privada con
RLS; RPC con `anon=false` y `authenticated=true`; helper privado sin ejecución
directa (`false`). Comienzo diario `2026-10-07T03:48:58Z`, sin cambiar el
inicio histórico. SQL no acredita un recorrido completo remoto con usuario.

Siguiente: terminar análisis y pruebas Flutter, consolidar gate completo en
CI y solicitar el candidato a Codemagic; comprobar compilación, publicación
y versión en Play por separado. La historia inferior no reabre bccd.

Leer [protocolo estable](mock-sync-workflow.md) antes de ejecutar.
Este checkpoint supersede pendientes antiguos de bccd en backlog/tablero/handoff.
El historial completo permanece en progress y fichas; no reiniciar esos loops.

## Estado y siguiente acción

**bccd cerrado22/22**, cero defectos perceptibles conocidos, entrega Android y
cleanup completos. La entrega activa y siguiente acción están en la sección
superior9ced070; no implementar pushes posteriores al SHA congelado.

Referencia aceptada: `irlanda/apoyar-detalle-perfil@bccd040d3a4b1c391bc6ab9eeccc479198868a7f`
del repo `albertoquiroga-ctrl/dopmi-functional-mockup`.
`git ls-remote` en este traspaso observó **9ced07094635c076d35589647fff26371d8bc791**;
sus cambios NO inspeccionados, implementados, probados ni aceptados aquí.

App base `ed4b788bd4117eb8949bb633483e94d8d4b36010` /Play295.
Producto bccd final `f362eb41a18e295e71e7c75eae8ca5506c80965c`;
candidato Android publicado `f3808f1a7ecd3e0cfb773434c840fa56b3251dae` /2.3.3(296).
Rama de trabajo/remota `codex/design-foundation`: HEAD previo al commit de
este traspaso **06696fa133a3dddbf1dc5693f1f2fc3135a029ac**, ambos verificados.
Consultar `git log` para el nuevo commit documental; no confundirlo con APK.
Base PR `codex/Dopmi@ba9f897f3fa418e952b98e4c604cffe468a8aa95`.
[PR6](https://github.com/albertoquiroga-ctrl/dopmi-app/pull/6): abierto/borrador,
no fusionado, head06696fa verificado por API antes de este traspaso.

## Evidencia y límites

| Puerta | Observado técnicamente / fuente verificable |
| --- | --- |
|22grupos|Inicio8, Mis casos8, Mensajes4, compartidos2; [tablero](parity-current-review.md) y [cuatro fichas](design-reviews/parity-updatebccd/shared.md). Normal/115%/320px200%, operaciones reales y auditoría delta cerradas; dos defectos específicos corregidos, sin otra auditoría global|
|Móvil final|[run37485195797](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/37485195797), f380:913tests, analyze/format,127capturas, APK; artefactos11422992948/11423193195|
|Backend/admin/config/integración/iOS|[run37480248797](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/37480248797), f362:606backend, PostgreSQL/permisos/concurrencia, Auth/Storage/Realtime e iOS. Reutilizados por equivalencia exacta de producto/SQL/admin/config con f380, NO afirmar jobs frescos sobre f380|
|Emulador|21checks controlados: >20registros, privacidad/lectura vs respuesta, cierre/reactivación mismoID6fotos, apoyo cerrado sin gastos aprobados, Back/recuperación/picker cancelado, galería/swipe. APK debug hash02e33c895e1af2061ac38fcaf9d7fad2925a3e8b8bdcbc6f5d2dec9f7dfa8954; no es Play296|
|Codemagic/Play|[build6ac512ac762af530b028e23f](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6ac512ac762af530b028e23f), workflowandroid-guardian-internal, f380:13acciones success, AAB firmado296; Publishing y consulta posterior internal/completed296 separadas|
|Samsung|ADB SM-S938B/Android16, paquete296 y escala1.15. Inicio/carrusel, casos/filtros/Archivo, inbox/selector/Sinleer/Historial/Back/refresh, teclado/FAB,6fotos/galería/puntos; swipe85px conservaRocky y740px avanzaToby sin contacto/Like. Modo Adoptante restaurado, sesión y borradores/mensajes propios sin escrituras. Cierres/reactivación reales se probaron en emulador, no en estados ausentes de la cuenta Samsung|
|CleanupDEV|4Auth/4perfiles,22adopciones,5rescues,8objetos retirados. Postflight19conteos QA cero; fecha global measurement_start1/preservedtrue/changed0; sin financiero. Último archivo protegido eliminado administrativamente con sesión Dashboard, más2marcadores vacíos generados; sin cambiar estados/ACL|

**Reportado por usuario:** actualizó y abrió Samsung; autorizó retiro administrativo.
La versión, UI y cleanup anteriores fueron comprobados por herramientas, no
deducidos de esos reportes. No se atribuye aprobación humana de Irlanda al QA
sintético. Dinero live, delta9ced, publicación iOS/aceptación física equivalente
a Android y otros hitos de release NO quedan aceptados por este cierre.

## Distribución iOS paralela: no confundir con este APK

Commits preservados `3a03788` (TestFlight externo) y `428896d` (purpose strings
cámara/ubicación) posteriores a f380. Ledger actual registra iOS299 procesada
y disponible; hubo rechazo298 resuelto. También registra invitaciones y alta
al grupo pendientes de aceptación de testers. No se revalidó Apple en este
encargo documental; leer últimas entradas iOS de progress antes de continuar
ese frente. No nuevos builds ni consultas privadas de testers aquí.

## Dirty tree preservado (local, NO incluido en el cierre)

`git status --short` observado al iniciar el traspaso:

- `apps/admin/src/api.ts`, `api.test.ts`: tratamiento/test del42501 self-review;
  modificación ajena, no se ejecutaron sus pruebas aquí.
- Mobile marcadosM pero `git diff --numstat` sin diff de contenido:
  `lib/features/community/content_actions.dart`,
  `lib/features/profile/help_support_dialog.dart`,
  `lib/features/profile/rescuer_settings_verification.dart`,
  `test/guardian_history_test.dart`, `test/payment_history_screen_test.dart`.
  No reset ni normalización de EOL.
- Docs con cambios previos: backlog77líneas, design-parity5, product-decisions16,
  parity-current-review114+/10-, progress1425+/11- (medición previa al traspaso).
  Ledger/decisiones ajenas permanecen en working tree; stage sólo adición propia.
- No rastreados: `.codex-remote-attachments/`, dos `apps/mobile/build-locked-*`,
  `deno.lock`, `docs/legal-draft-handoff-2026-09-30.md`,
  `docs/legal-irlanda-crosscheck-2026-09-30.md`,
  `docs/legal-payment-review-2026-09-30.md`, `docs/operations/`,
  `docs/payment-ux-flows-irlanda-2026-09-30.md`, `scripts/__pycache__/`,
  `scripts/validate_operations_evaluation.mjs`, `tmp-h11-device/`.
  No borrar/committear por este traspaso.

## Evidencia local privada y configuración no secreta

`.tools/bccd-native/` ignorado: `gate-approved.json`, `gate-equivalence.json`
(flagpending antiguo supersedido), `native-emulator-proof.json`,
`samsung-acceptance-proof.json`, `codemagic-status.json`, `publishing.log`,
`cleanup-final-proof.json`, PNG/XML. No están en GitHub ni son imprescindibles
para leer este checkpoint: CI/CM y fichas públicas documentan resultados/límites.
El directorio también contiene cuentas/tokens sintéticos consumidos: **no imprimir,
copiar a docs ni reejecutar fixtures/cleanup**. Nueva entrega crea inventario nuevo.
`apps/mobile/config.local.json` privado; ejemplo versionado
`apps/mobile/config.example.json`. TokenCM local existe; no registrar valores.
No fue necesaria ni instalada una clave nueva `DOPMI_DEV_STORAGE_SECRET`.

DEV migrations local→remota:
06035705→06041254,06041500→06041524,06044300→06044234,
06142000→06142458 (prefijo202610); [auditoría canónica](migration-history-audit.md).
No replay/repair. Conexiones/dispositivos/sesiones pueden caducar: comprobar
presencia antes de actuar, no inferir acceso desde este registro.

Bloqueos bccd: **ninguno**. No relanzar suites, Codemagic, aceptación ni limpieza
por abrir una sesión nueva. Revisar Git actual y el encargo del titular primero.
