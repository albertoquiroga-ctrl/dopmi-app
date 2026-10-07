# Checkpoint de sincronización — 6 de octubre de 2026

## Entrega activa 9ced070 — MVP_CONTINUO autorizado

Plan completo aprobado en [parity-current-review.md](parity-current-review.md),
único tablero. Ocho grupos incluidos UX01–07 y UX09; UX08 Croquetas excluido
por tienda. Objetivo UX congelado `9ced07094635c076d35589647fff26371d8bc791`
en `irlanda/apoyar-detalle-perfil`, delta desde bccd040 (1 commit / 6 archivos).
No absorber pushes nuevos ni reabrir bccd cerrado 22/22.

Base app `0484f8075c893497c10f6291553071eab7b4e5bf`; rama
`codex/design-foundation`, PR #6 abierto/borrador. Producto en GitHub:
`4f0275552647f322f3a2dfb9382e3d79c8929949`. Sin merge ni force-push.
Tres archivos propios de corrección se consolidan en esta continuación:
rescue_test, rescuer_logout_test y rescuer_pending_evidence_test.
Cambios ajenos excluidos; documentación de cierre se versiona por separado.

Inicio `2026-10-07T03:33:46Z` (6/10 21:33:46 México). Presupuesto 90 minutos
globales; cierre 04:53:46Z, parada 05:03:46Z. Consumo ~38 minutos al corte
04:12Z; no renovar. Goal activo del titular, pausa autorizada al cierre seguro.
No heartbeat, loop ni autorrelanzamiento. Comandos largos: PID propio, timeout
real y terminación del árbol propio; una sola cola Flutter.

L0 protocolo/plan guardados antes de código. L1 contratos/SQL/compartidos y
L2 ocho grupos implementados. Estado de cierre: **PRESUPUESTO_AGOTADO**, verificación remota pendiente.
Gate obligatorio pendiente; candidato todavía no publicable. Implementación,
comprobación, publicación y aceptación son estados separados.
Inicio: grid/períodos/paneles/consejos; Perfil/redes; chrome/Apoyar/fin Adoptar.
Cobertura de vistas diaria consentida nueva, sin backfill. México define
ventanas; favoritos vigentes, snapshots actuales y recaudo neto asignado.
Propiedad y permisos en PostgreSQL; conservar Guardian/Connect/evidencia.
Dinero exclusivamente test; sin flags/Edge/destructivos/datos existentes.

Tres agentes reutilizados, sin recursión ni Flutter/publicación. L2 segunda
pasada agrupada 2/2 consumida. Primera: siete fallos de fixtures/visibilidad,
corregidos y 37/37 afectados aprobados. Analyze inicial sin incidencias
(170.9s); configuración 16/16. Backend nuevo 6/6 PGlite; fallo inicial Date
del fixture corregido en segundo intento. No repetir causas sin evidencia.
Logs privados `.tools/update9ced/`, fuera de GitHub; no son enlaces públicos.

[CI full 37569196187](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/37569196187)
en 4f02755: web/admin/config/backend 612/612, pgTAP 294/294 (37 nuevos),
concurrencia e integración Auth/Storage/Realtime 4/4 aprobados; iOS aprobado.
DTO/RPC por PostgREST con datos no vacíos y aislamiento comprobado en loopback.
Flutter: analyze aprobado; cinco tests heredados fallaron por rutas retiradas
(logout en Settings, CTA anterior de evidencia y quick Mensajes). Corregir
sólo esos tres archivos conservando controles y aserciones: intento 2 local
29/32 aprobado. Tres fallos restantes de fixture/visibilidad, sin defecto
de producto demostrado. Titular autorizó tercera pasada mediante «Adelante» a las 05:01Z.
Corrección aplicada a fila lazy/logout y centrado de controles al 200%.
Patch automático no aplicó por formato; reemplazo directo, formato aprobado.
Comprobación local anterior inició sin patch y no acredita la corrección.
Push duplicado 37569192608 cancelado por concurrencia normal.

DEV `ohqxranynackjignryep`: preflight 03:48Z, latest 20261006142458; cuerpo
y ACL del registro anterior coincidentes, nuevas tablas/RPC ausentes.
Local `20261007033748_rescuer_funnel_9ced` aplicado una vez como remoto
`20261007034858`. Postflight 03:49Z: ambas tablas privadas con RLS, sin
SELECT cliente; RPC anon=false/auth=true; helper privado execute=false.
Cobertura diaria desde `2026-10-07T03:48:58.342396Z`, inicio histórico intacto.
[auditoría de migraciones](migration-history-audit.md); no repair/replay/db push.
DEV E2E con usuario remoto e instalación no se atribuyen a SQL ni CI.

CM 0/2 builds. Workflow vigente `android-guardian-internal`, paquete
`com.mycompany.dopmi`, firma y flags test existentes, configuración sin cambios.
No iniciar CM mientras falle el gate; verificar SHA, AAB,
Publishing, internal y versionCode por separado. No relanzar build en cola.

QA posterior preparada en tablero: instalación Play/ADB Samsung, comparación
visual exhaustiva/gestos/escala, auditoría del delta/ciberseguridad y medición
de rendimiento. No ejecutada ni aceptada. Flutter 3.47.4 y accesos GitHub/CM/
Supabase comprobados; Docker local detenido, PG/integración se ejecutaron en CI.

Cambios ajenos conservados: baseline e initial-dirty.patch privados en
`.tools/update9ced/`; no publicar admin 42501, historia de docs ni no rastreados.
Tercera pasada autorizada sin renovar presupuesto; queda cierre hasta
05:03:46Z. Verificación de corrección y publicación no completadas en ese plazo.
Diagnóstico: logout comprueba fila lazy antes del scroll (dos casos); evidencia
al 200% toca control fuera del área visible (un caso). Propuesta aplicada
`.tools/update9ced/proposed-extra-pass.patch`: mover assert después del scroll
y centrar controles + hitTestable. No debilitar privacidad, logout ni no-save.
Siguiente exacto con presupuesto renovado: comprobar CI del commit de
corrección; resolver sólo lo fallido; si gate aprobado, CM/Play autorizados.
No reiniciar tiempo/contadores. Objetivo se pausa efectivamente, sin loop.
No procesos propios ni builds remotos activos; agentes terminados.

Leer [protocolo estable](mock-sync-workflow.md) antes de ejecutar.
Este checkpoint supersede pendientes antiguos; historial en progress y tablero.

## Entrega cerrada bccd040 — referencia histórica

bccd040 cerrado 22/22. Candidato histórico `f3808f1`, Android 2.3.3(296),
Play/Samsung y limpieza aceptados. No es el APK del producto nuevo 4f02755.
No reiniciar suites, build, aceptación o limpieza de esa entrega.

`.tools/bccd-native/` contiene evidencia privada y fixtures sintéticos consumidos:
no imprimir tokens, copiar datos a docs ni reejecutarlos. No usar su helper
privado de publicación para 9ced. Evidencia pública y límites en fichas/CI/CM
y [migration-history-audit.md](migration-history-audit.md).

## Trabajo local ajeno que se conserva

Admin api/api.test 42501; archivos móviles con cambios de EOL previos; historia
en backlog/design-parity/product-decisions/progress/parity-current-review.
No rastreados previos: attachments privados, build-locked, deno.lock, docs legales/
operations/payment-ux-flows, pycache/validate_operations_evaluation y tmp-h11-device.
Detalle exacto en baseline e initial-status privados; no borrar ni publicar.
Configuración móvil y token CM privados; sólo conservar sus nombres, sin valores.
Conexiones y dispositivos pueden caducar: verificarlos antes de depender de ellos.
