# Checkpoint de sincronización — 6 de octubre de 2026

Leer [protocolo estable](mock-sync-workflow.md) antes de ejecutar.
Este checkpoint supersede pendientes antiguos de bccd en backlog/tablero/handoff.
El historial completo permanece en progress y fichas; no reiniciar esos loops.

## Estado y siguiente acción

**Sin lote de paridad activo. bccd cerrado22/22**, cero defectos perceptibles
conocidos, entrega Android y cleanup completos. Próximo paso: esperar encargo
del titular; si autoriza nuevo corte, inventariar una sola vez el delta desde
bccd hacia el SHA que se congele. No implementar automáticamente el branch vivo.

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
