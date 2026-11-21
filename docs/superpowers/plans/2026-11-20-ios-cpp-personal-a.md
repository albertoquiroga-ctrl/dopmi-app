# Prueba iOS CPP personal-a — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Root integra y verifica; agentes tienen archivos exclusivos y no ejecutan Flutter ni despliegues. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** conservar descarga directa y recibir personal-a al abrir desde una CPP,
para asociar primera ficha y eventos separados de mensajes después del login
normal y consentimiento.

**Architecture:** captura iOS temprana y persistente, separada de enlaces públicos
y Android; inscripción por RPC con revisión exacta del consentimiento y hora del
servidor. Observadores aditivos privados conservan las reglas de participantes y
moderación. CPP y landing se activan sólo con un cliente compatible.

**Tech Stack:** Flutter/app_links/SharedPreferences, Supabase PostgreSQL y App Store Connect.

**Spec:** [investigación aprobada](../../ios-direct-attribution-research.md),
pedido expreso del titular de implementar sólo personal-a sobre el release reciente.
El titular informa que no dispone de iPhone ahora; prueba física sigue pendiente.

## Restricciones y decisiones de integración

- Base vigente congelada `e48a653bbd0d58bc8d7913ebbb67a048f4eabc34`; rama
  `codex/production-attribution-restored-20261120`. El inventario posterior al
  corte inicial1a9a83e3 encontró únicamente b278540d y dos registros de entrega:
  compartir perfil por HTTPS, sus pruebas y build420 interno. Integrados por
  fast-forward y reaplicación limpia del trabajo local. Conserva móvil419/ee3,
  correctivo servidor5fa23089 y compartir perfil reciente; no ampliar otros lotes.
- No códigos, login web previo, clipboard, SDK de atribución, fingerprint o anuncios.
- URI canónica única `io.dopmi.app://acquire/personal-a`; no aceptar otras variantes,
  query, fragmento, credenciales, puerto, aliases codificados o ruta distinta.
- Captura local pendiente hasta24h desde recepción; primer contexto y primer
  propietario no se reasignan. Guardar sólo variante/fecha local/propietario/estado.
- Consentimiento explícitoOFF invalida intención y fuente; preferencia local
  ausente no revoca consentimiento remoto ni elimina contexto antes del opt-in.
- Cohorte `ios_cpp_open`: ventana de eventos14d desde inscripción servidor,
  distinta de clicAndroid14d. No inventar clicked_at/instalación nueva/origenFacebook.
- Una cola Flutter. FinanzasOFF, firma/com.mycompany.dopmi y funciones existentes intactas.
- No publicar fichas sintéticas ni enviar mensajes a desconocidos para probar.

## Impacto y despliegue

Nuevos módulos/test iOS de persistencia, captura y transporte de inscripción;
integración en main/app, transporte de consentimiento,
barrera de acciones y aviso de privacidad. Migración CLI
`20261121022319_ios_cpp_acquisition.sql`, dos tablas privadas, RPC y observadores
aditivos; Android y funciones send/contact no se reemplazan. Reporte iOS separado.
PROD antes del cambio: historia70/latest20261121013358, objetos iOS ausentes.

Orden: pruebas y CI → SQL aditivo cotejado → cliente compatible cargado → revisión
del cliente/CPP → ruta personal-a con ppid → instalación/App Store física.
Si419 continúa en revisión, no retirarlo por la preparación: usar carga
`ios-testflight` con PROD/AmazonON como candidato; no confundirla con prueba CPP.
Sin teléfono, no declarar QA física ni activar campaña nueva sin cliente público.

Recuperación: detener sólo la nueva ruta CPP y conservar descarga agregada pt/ct.
Mantener tablas/RPC compatibles para binarios ya cargados; no borrar fuentes,
revertir historial o revocar elecciones de usuarios como rollback automático.
El envío de fichas/mensajes reales es irreversible en sus efectos normales;
medición no debe impedirlos ni generarlos por recibir el enlace.

## Lotes y pruebas

### 1. Cliente y contrato de consentimiento

- [x] Tests de URI exacta, iOS-only, primer contexto, expiración y entorno.
- [x] Observar RED, implementar `IosCppAcquisition.capture/observeOwner/revoke/record`.
- [x] Probar persistencia, ownerA→B, escritura fallida, timeout y OFF concurrente.
- [x] Capturar initial/stream antes de Firebase/OAuth; conservar instancia al reintentar.
- [x] Añadir callback opcional `onAcceptedRevision(int)` al CAS sin cambiar API bool.
- [x] Propagar inscripción consentida y barrera antes de ficha/contacto/compositor;
  un enlace nuevo con sesión consentida también dispara intento.
- [x] Aviso iOS honesto, sin cambiar enlaces públicos o comportamiento Android.

### 2. Servidor y reporte

- [x] Test SQL ejecutable RED antes del contenido de la migración.
- [x] RPC `dopmi_record_ios_cpp_acquisition(p_variant text,
  p_expected_consent_revision bigint)` retorna status recorded/already_recorded/
  ineligible/consent_changed. Actor de sesión; hora exclusivamente del servidor.
- [x] Tablas source/eventos RLS sin CRUD cliente; eventos por actor/tipo únicos.
- [x] Observar primer envío, su aprobación posterior y tres hitos de mensajes;
  excluir historia previa observable y no clasificar texto legado.
- [x] Opt-out/eliminación purgan fuentes/eventos; Android y APIs previas intactos.
- [x] PGlite y PostgreSQL real: permisos, límites, deduplicación y carreras
  inscripción↔envío/mensaje, OFF↔evento en ambos órdenes y OFF→ON↔intención vieja.
- [x] Reporte por método/variante, sin contenido, contrapartes ni falso new_account.

### 3. Integración, distribución y aceptación

- [ ] Analyze + suiteFlutter, backend y configuración; CI completa por SHA.
- [x] Revisión independiente de UI/UX/código/seguridad; corregir defectos concretos.
- [ ] Pre/postflight de historia, funciones, permisos y guardas; aplicar una vez.
- [ ] Cargar candidato desde fuente inmutable reciente con entorno PROD verificado.
- [x] Preparar una CPP en borrador con destino real de adopciones y personal-a;
  no publicar landing ppid antes de tener cliente compatible.
- [ ] iPhone18+: enlace Safari/Facebook → CPP → instalación limpia → Abrir;
  login/legal/Analítica → primera ficha privada → eventos de mensajes de QA legítimos.
- [ ] Negativos: icono, ficha genérica, OFF, cuentaB, reintento y reinstalación.
- [ ] Registrar bloqueos externos y evidencia; ningún éxito instalado por simulador.

## Review Focus

Cold start antes de OAuth; nueva URI después de opt-in; OFF no bloqueado por
red; cambio de cuenta tras POST incierto; timestamp de apertura distinto al clic.
Estos casos tienen pruebas en lote1/2 y aceptación de lote3. iPhone ausente y
App Review son gates externos; no se resuelven recreando builds o backfill.

## Ajustes derivados de revisión

La captura necesita una barrera durable de primera recepción para que un reinicio
después de fallar la persistencia del propietario no convierta una entrega
duplicada en una fuente para otra cuenta. Se conserva durante el consumo/OFF.
Si todo almacenamiento falla antes de recibir durablemente el contexto, no se
promete recuperación tras muerte del proceso; se prefiere perder atribución.
La inscripción se extrae en `core/ios_cpp_enrollment.dart` para probar en conjunto
las cinco clases reales y el cliente HTTP, además de los tests de cada componente.
