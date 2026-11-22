# Calidad de Analytics y conversiones de Dopmi

> **For agentic workers:** seguir subagent-driven-development; root conserva la única cola Flutter y las operaciones remotas.

**Goal:** Corregir identidades infladas por fallos transitorios y presentar actividad y conversiones que correspondan a acciones de valor confirmadas.

**Architecture:** Mantener Firebase/GA4 de producción y los consentimientos vigentes. El servidor confirma las transiciones de negocio; el cliente mide sólo nombres fijos cuando existe consentimiento actual. Los reportes distinguen cuentas del backend, instalaciones/usuarios medidos y eventos, sin forzar igualdad ni reconstruir históricos.

**Tech Stack:** Flutter/Riverpod, Firebase Analytics/GA4, Supabase/PostgreSQL, configuración de informes existente.

**Spec:** Petición del titular22/nov en este chat: investigar discrepancia y ampliar a configuración de eventos, métricas de valor, conversiones y fiabilidad de activos. Prioridades ya elegidas: contacto nuevo, primera respuesta de rescatista y adopción marcada como realizada; esta última no acredita origen Dopmi.

## Base, impacto y límites

- Base94fa2088, productoefc3277a/433–434; rama `codex/analytics-quality-20261122`. Referencia mockf693c036 conservada, sin delta visual.
- Principal defecto reproducible: una lectura remota incierta con el mismo actor/marker ON llamaba resetAnalyticsData. Cada reanudación consulta el consentimiento. Debe pausar la colección y conservar la identidad; un OFF confirmado o cambio real de propietario sí la borra.
- Fuente de cuentas: Auth y perfiles de PRODUCCIÓN. Su existencia no equivale a actividad reciente ni a consentimiento. No enviar cuentas, correos, UUID, mensajes, ubicación ni datos históricos a Google para cuadrar cifras.
- Conversiones primarias: contacto realmente creado y primera respuesta realmente guardada. Adopción marcada es resultado final declarado por la rescatista, sin atribución causal. Envío de ficha aceptado es indicador secundario de oferta, no publicación aprobada.
- Un intento de envío, una reapertura de hilo o un evento SDK aceptado no acredita conversión ni recepción en GA. Los eventos antiguos conservan su semántica histórica.
- OFF históricos, iPad426OFF, servicios financieros, Tienda, territorios y gates del piloto se conservan. Sin activar anuncios, nuevas integraciones ni SDK.
- Reutilizar checkout y pruebas; no recopilar actividad de usuarios sin decisión, no backfill, no generar casos/chats/adopciones reales de QA.
- Lectura de GA por Chrome externo. Una desconexión no autoriza crear claves ni ampliar permisos. Configuración GA/reportes y cambios de código son entregas verificables distintas.
- La petición vigente de corregir Analytics autoriza el SQL aditivo necesario y revisado para estas señales. Preparar paquete concreto, preflight y readback antes de aplicarlo; los permisos consumidos de otros lotes no se reutilizan. No hay contrato, acceso sensible nuevo ni cambio financiero. Conservar compatibilidad con clientes anteriores y omitir eventos no confirmables.

## Tareas finitas

### 1. Identidad frente a fallos transitorios

**Files:** `apps/mobile/lib/core/measurement.dart`, `apps/mobile/test/usage_analytics_choice_test.dart` y suites existentes de medición.

- [x] Diagnosticar desde arranque, reanudación y método de borrado del SDK.
- [x] RED: dos pruebas `uncertain same-owner`, esperaban0resets y obtuvieron1; no se modificó producto antes del RED.
- [x] Conservar marker sólo para el mismo propietario mientras la consulta es incierta; no colección ni eventos durante la incertidumbre.
- [x] GREEN y regresiones: recuperación ON, OFF remoto/local, cambio de actor/entorno, salida real y carreras obsoletas; análisis Flutter.

### 2. Semántica de conversiones

- [x] Inventariar y comprobar los retornos RPC de contacto/mensaje/cierre y señales ya existentes.
- [x] Definir señales aditivas confirmadas, con deduplicación de transición en servidor; mantener retornos/camino de clientes anteriores.
- [x] Escribir pruebas negativas y de concurrencia antes de implementación; sin nuevas operaciones en producción.
- [x] Medir sólo tras éxito confirmado y consentimiento vigente; payload vacío. No reinterpretar contact_started histórico como contacto nuevo.
- [x] Revisar seguridad, compatibilidad, consentimiento y eliminación; preparar paquete remoto exacto si corresponde.

### 3. Configuración y lectura de reportes

- [x] Propiedad GA4 real561295536/dopmi-production. Exploración existente «Primera publicación»:79eventos en25/oct–21/nov,100%datos, no un conteo de cuentas.
- [x] Corte interno22/nov19:28UTC:393Auth/393perfilesactivos/5perfileseliminados;381emailsconfirmados/379consignin. Periodo25/oct–21/novCDMX:386cuentas;7altas del22/nov al corte.
- [x] Preferencia actual:31ON/297OFF/65sin fila. Nuevas elecciones:10ON/5OFF. Son preferencias actuales, no cobertura histórica de cada evento.
- [x] Leer usuarios totales/activos/nuevos, streams, versiones, zona, filtros, calidad e identidad de informes antes de atribuir toda la diferencia al bug.
- [x] Configurar panel de valor y eventos clave con definiciones visibles, separar métricas secundarias y futuras señales aún no recibidas.
- [x] Verificar readback de configuración y capturas; respetar actividad de Ads y pilotos sin cambiar campañas.

### 4. Entrega

- [x] Revisión independiente acotada, gates CI del candidato exacto, inventario de cambios y continuidad.
- [x] SQL aplicado una vez20261122204434, diez comprobaciones postflightPASS; conservar las solicitudes públicas433/434 sin duplicarlas.
- [ ] Si el código requiere nueva distribución, una cola y ventana de cinco minutos por Codemagic, QA instalada y estados separados de recepción GA.
- [ ] Informar qué quedó configurado, implementado, publicado y medido realmente, y los límites históricos de usuarios únicos.

## Recuperación

La pausa por estado incierto conserva identidad local, nunca fuerza ON. Un fallo de medición deja usar el producto sin recopilar. Un cambio de informe se puede revertir conservando nombres/versiones y los eventos originales; no borrar datos históricos. Nuevas señales usan contrato aditivo con el producto anterior funcional. Antes de SQL remoto, registrar compatibilidad y recuperación exactas del paquete; no hacer rollback automático de consentimiento, identidad o transacciones de usuarios.

## Verificación local y configuración — 22/nov

- Flutter enfocado:180 PASS; `flutter analyze --no-pub`: No issues found (157.1s). Suite local completa cancelada expresamente para delegar la regresión al gate CI; no cuenta como PASS.
- Node completo:1389 PASS/15 SKIP/0 FAIL; PostgreSQL real:23 PASS/0 SKIP/0 FAIL, base sintética efímera. Revisiones independientes integradas sin P1/P2.
- GA configurado y persistencia comprobada tras recargar: identidad Observed (antes Blended sin modelado disponible), tres eventos clave sin valor monetario y una vez por evento. Exploración existente renombrada «DopMi · Actividad y adopciones», con las tres vistas; no se amplió su audiencia compartida.
- Periodo25/oct–21/nov:40 activos/40 usuarios/40 sesiones/0 recurrentes/38 sesiones con interacción/95%;260eventos generales. Vistas por versión/plataforma. Publicación:79eventos/15usuarios medidos; envío aceptado4eventos/4usuarios. No equivalen a personas ni a cuentas; no reconstruir históricos.
- Las nuevas conversiones aún muestran ausencia de datos: registro/configuración no acredita recepción. No se generó tráfico de QA en producción ni se importaron conversiones a Ads.
- SQL:20261122194736_confirmed_adoption_value_signals.sql,11.051bytes,SHA256669dd8fa5b3bfd809d85cffa270ac37a3d07c6a557d37021076f80f3a5ddd23d; paquete remoto en preparación. Sin aplicación PROD ni nueva build.

### Evaluación de autorización

La petición humana del22/nov de configurar métricas y corregir su fiabilidad cubre este SQL aditivo necesario. Se revisaron los textos históricos: las restricciones de paquetes del17–24/oct pertenecen a sus operaciones/fixtures y no se convierten en una prohibición universal de cualquier migración posterior. La frase inicial del plan que exigía permiso propio era una interpretación de Codex, no una decisión nueva del titular; queda corregida. Se aplicará sólo tras el gate CI, paquete/fingerprints actuales y revisión independiente, sin modificar servicios, acceso a mensajes ni datos de usuarios para probar.

## Aplicación y distribución en curso

CI45065888007 cuatroSUCCESS paraa24408be. SQL una aplicación20261122204434, wrapper41802B/61bafe61…c708e y fuente11051B/669dd8fa…ddd23d: diezPASS de readback, previas73migraciones y runtimeSQL intactos. Android2.3.10 enviado una vezCM6b0354d59ee19bef90f484db; iOS preparado con ventana20:47:33–20:52:33UTC, no se enviará en paralelo. No se afirma instalación ni recepción GA de las nuevas señales.
