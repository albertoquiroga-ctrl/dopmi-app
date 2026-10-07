# Checkpoint de sincronización — 7 de octubre de 2026

## Entrega activa 9ced070 — MVP_CONTINUO

Plan completo aprobado y único tablero: [parity-current-review.md](parity-current-review.md).
Ocho grupos UX01–07 y UX09 implementados; UX08 Croquetas excluido por tienda.
UX congelado `9ced07094635c076d35589647fff26371d8bc791`, rama
`irlanda/apoyar-detalle-perfil`, delta bccd040→9ced de1 commit/6 archivos.
Ref viva reconsultada 13:36Z: sin cambios. No absorber pushes ni reabrir bccd.

App `codex/design-foundation`, PR6 abierto/borrador, base0484f807.
Producto4f02755; corrección de tests48bac1b; candidato vigente
`3bd67b6f4d0eeedc7dec2721bc8e7495c046c0c7` (sólo captura y docs desde48bac1b).
Cambios ajenos preservados/excluidos; sin merge ni force-push.

## Tiempo, límites y siguiente acción

El tramo inicial90min 03:33:46Z→05:03:46Z terminó sin publicación.
«Adelante» autorizó tercera pasada L2 sin renovar ese tramo: aplicada48bac1b.
«Continúa» renueva90min el7/10 desde13:34:10Z; cierre14:54:10Z,
parada15:04:10Z. Conserva contadores: L2 dos pasadas + tercera autorizada;
causa nueva de captura1/2; CM0/2. Agentes anteriores terminados.
Una cola Flutter, timeout/PID propios. Sin Goal nuevo, heartbeat o loop.

Estado **GATE_APROBADO / LISTO_PARA_CM**. CI37629942682 completed/success
13:52:09Z, capturas y APK cargados. Antes de publicar: checkpoint documental,
HEAD/remoto coincidentes y un solo CM android-guardian-internal; verificar
SHA/AAB/Publishing/internal/versionCode.
API CM y repositorio verificados por lectura13:38Z. No CM iniciado.
Compilación, publicación y aceptación instalada son estados separados.

## Evidencia y diagnóstico acotado

CI full37574438050 en48bac1b: analyze y931 tests móviles aprobados;
web/admin/config/backend/permisos/concurrencia/integración e iOS aprobados.
Capturas de acceso aprobadas; Perfil/Apoyar falló en coordenada heredada136.8.
Marco46px del UX9ced exige top148, card263.75. Corrección sólo herramienta,
tolerancias/altura intactas. Captura focalizada normal/200% aprobada1/1.
[CI móvil37629942682](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/37629942682)
en3bd67b6; reutilizar gates full aprobados porque lib/SQL/admin/config intactos.
Analyze,931 tests,ambas suites de capturas,APK y artifacts aprobados.
Gate consolidado aprobado con reutilización acotada de backend/iOS.
Artifacts11486735135(design) y11486476793(APK), no expirados.

CI previo37569196187/4f02755: backend612/612, pgTAP294/294(37 nuevos),
integración real4/4 e iOS aprobados. PostgREST DTO/RPC con datos/aislamiento
comprobados en loopback. Historial de fixtures y correcciones en tablero/progress.
Logs locales privados .tools/update9ced, no enlaces públicos.

DEV ohqxranynackjignryep: migración local20261007033748 aplicada una vez
como remota20261007034858. Pre/postflight cuerpo/ACL/RLS comprobados.
Tabla diaria privada sin SELECT cliente; RPC anon=false/auth=true;
helper privado execute=false. Cobertura desde2026-10-07T03:48:58.342396Z.
México define ventanas; sin backfill, fechas históricas preservadas.
[migration-history-audit.md](migration-history-audit.md): no repair/replay/db push.
Sin cambios Edge/flags/datos anteriores; dinero exclusivamente test.
No atribuir DEV E2E remoto o dispositivo a SQL/CI.

QA posterior: instalación Play/Samsung, revisión visual exhaustiva/gestos/escala,
auditoría independiente del delta/seguridad y rendimiento. No ejecutada ni aceptada.
Paquete com.mycompany.dopmi, firma dopmi_upload_2026 y Guardian test conservados.
Leer [protocolo estable](mock-sync-workflow.md) antes de continuar.
Este checkpoint supersede pendientes históricos inferiores.

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
