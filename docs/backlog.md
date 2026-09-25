# Dopmi — entregas

Cada tarea se completa con código, prueba de aceptación y evidencia en `progress.md`.

## Hito 1 — completado

- [x] H1.1 Preparar estructura y reglas. Aceptación: prototipo conservado, apps separadas, configuración fuera de Git.
- [x] H1.2 Identidad en PostgreSQL. Depende de H1.1. Aceptación: perfil creado con cada usuario, datos propios editables, permisos administrativos fuera del cliente y cierre del acceso heredado inseguro.
- [x] H1.3 Flutter. Diez pruebas de estado/interfaz y dos recorridos de integración contra Auth/PostgreSQL/SMTP reales. Registro y confirmación del titular comprobados; su sesión web se restauró tras reiniciar Windows. Edición y lectura del perfil comprobadas en remoto; recuperación por código/enlace y persistencia de sesión/PKCE comprobadas con cuentas desechables locales.
- [x] H1.4 Admin. Código, cinco pruebas y build listos. Membresía del titular habilitada en servidor después de comprobar correo confirmado y perfil activo. Su sesión abrió el directorio de diez cuentas al recargar el panel.
- [x] H1.5 Verificación. SQL local/remoto, recuperación con correo local, Android e iOS simulator en macOS comprobados. Los cuatro jobs del [CI ampliado](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34788208103) aprobaron el commit de implementación y pruebas `788a236`.

## Hito 2 — completado

- [x] H2.1 Backend y permisos. Migraciones para publicaciones, fotos, favoritos, conversaciones, mensajes y notificaciones. Aceptación: aislamiento de borradores/conversaciones, moderación en servidor y reintentos sin duplicados. 58 comprobaciones nuevas pgTAP aprobadas en local y remoto.
- [x] H2.2 Publicación y revisión. Depende de H2.1. Flutter permite guardar, adjuntar fotos, enviar, corregir y cerrar; el panel revisa la versión exacta y registra su decisión. Datos conservados al corregir y contenido no aprobado ausente del catálogo, comprobados por integración y recorrido visual.
- [x] H2.3 Descubrimiento. Depende de H2.1–2. Catálogo, filtros, detalle, guardados y perfiles públicos. Solo contenido aprobado, paginación y favoritos por cuenta, sin datos privados publicados; pruebas SQL, integración e interfaz aprobadas.
- [x] H2.4 Comunicación. Depende de H2.3. Inicio de conversación desde una publicación, mensajes privados, cierre y notificaciones. Aceptación de Realtime desde base nueva, lectura persistente y reintentos sin duplicados; recepción visual comprobada con otra cuenta local.
- [x] H2.5 Verificación y entrega. Depende de H2.1–4. Migraciones remotas y revisión visual completas. Análisis y 14 pruebas Flutter, nueve admin, 69 SQL local, diez PGlite y tres recorridos contra servicios reales aprobados. Los cuatro jobs de [CI 34792258918](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34792258918) aprobaron `7039f35`, incluidos Android e iOS simulator.

## Hito 3 — completado

- [x] H3.1 Backend y permisos. Se agregó `public.dopmi_rescue_records`, `private.dopmi_rescue_history`, políticas de Storage privadas y funciones de guardado/revisión con control de estado, deduplicación y validación de montos urgencia en centavos.
- [x] H3.2 Rescatista móvil. Se implementó el flujo completo de verificación/caso/gasto en `apps/mobile/lib/features/rescue/`, incluyendo borradores, evidencia por rol, envíos, correcciones, retiro y estado.
- [x] H3.3 Administración. Se agregó revisión de expedientes de rescate en `apps/admin/src/Rescues.tsx` con detalle, decisión, auditoría y cambios de estado protegidos por RLS/funciones RPC.
- [x] H3.4 Seguimiento y cierre. El backend cierra casos solo cuando no hay gastos pendientes, bloquea nuevos gastos contra expedientes cerrados, publica solo snapshots aprobados y mantiene notificaciones por cambios de estado.
- [x] H3.5 Verificación y entrega. Se ejecutaron análisis/tests locales de Flutter, pruebas admin y suites SQL de hito (`identity`, `adoption`, `rescue`) en base local; migración y pruebas listas para mover a CI de hito siguiente.

## Hito 4 — aportaciones y Connect (completado en modo prueba)

- [x] H4.1 Contribuciones en base de datos: tablas, índices y política/registro de funciones para guardar aportaciones y asignaciones determinísticas.
- [x] H4.2 Consola administrativa: vista de aportaciones, filtro por estado, recarga y manejo de errores.
- [x] H4.3 Pruebas locales: test de unidad/admin y suite SQL inicial para idempotencia/allocación/publicación.
- [x] H4.4 Ejecución completa de `supabase test db` con stack local activo para validar la suite `supabase/tests/contributions.test.sql`. Aprobado en CI con PostgreSQL local y migraciones reales.
- [x] H4.5 Activar en el proyecto las funciones ya implementadas de Stripe Connect, webhooks y trabajador; validar una aportación, transferencia, devolución y conciliación completas en modo prueba bajo idempotencia. La producción queda fuera hasta una revisión independiente. Incluye trabajo periódico verificado con HTTP 200 y devolución/reversión comprobada en Stripe, base de datos y Android.
- [x] H4.6 Cerrar documentación de entrega del hito y propuesta de siguiente alcance (Guardián). Véase `docs/hito4-delivery.md`.

## Hito 5 — Guardián (abierto; continuación en Codex)

Corte: 25 de septiembre de 2026. Rama `codex/stripe-transfer-delivery`; guía principal en [codex-handoff.md](codex-handoff.md). Se separa implementación de aceptación: no reconstruir funciones existentes porque una casilla integral siga abierta.

- [x] H5.1 Planificador del neto: urgencia, antigüedad y desempate estable; sin asignación parcial cuando falta capacidad.
- [x] H5.2 Decisiones del titular: primer cobro al activar, mensualidad condicionada, mes omitido sin deuda, cambio futuro y cancelación. Consentimiento e interfaz implementados. Reglas en `product-decisions.md`.
- [ ] H5.3 Aceptación de reserva y liquidación transaccional. Código, migraciones, CI y concurrencia PostgreSQL implementados/verificados; falta recorrido integrado con Stripe/app que confirme neto completo o devolución total.
- [ ] H5.4 Aceptación del ciclo de vida. Ya están implementados alta/abandono, calendario protegido, cobro mensual y omisión, recuperación, solicitudes de monto/cancelación, cancelación durante alta, cambio de tarjeta/3DS, historial privado, límites de aniversario y devoluciones/reversiones. Último CI revisado: 356 backend, 191 pgTAP, 51 Flutter, cuatro jobs aprobados en `8e6663d`. Falta aceptación integrada; ver matriz.
- [ ] H5.5 Recorridos completos y revisión independiente, con evidencia antes de cerrar el hito. No habilita dinero real automáticamente.

### Cola inmediata

- [ ] H5.A Comparar entorno remoto actual con el código y [historial de migraciones](migration-history-audit.md). Resolver diferencias antes de schema push/repair; no reejecutar migraciones ya aplicadas.
- [ ] H5.B Comprobar/desplegar `guardian_preflight` de `payment-worker` según corresponda. Verificar lecturas y, por separado, escrituras necesarias de la clave Stripe del servidor. El preflight de metadatos ya aprobado solo demostró acceso y nombres de secretos.
- [x] H5.C Preparación de flags de procesamiento con nuevas altas cerradas, acreditada por CI 36071101143 y registro previo. Reconsultar estado antes de abrir la aceptación; no contar como una comprobación remota nueva.
- [x] H5.D Configuración TestFlight que incluye Guardián y conserva bundle/firma; CI 36074983990 aprobado. Configuración no equivale a IPA firmado ni instalación.
- [ ] H5.E El titular compila en Codemagic con `ios-testflight` e instala desde TestFlight. Registrar SHA, versión/build y dispositivo.
- [ ] H5.F Con permisos/capacidad/Connect/dispositivo listos, habilitar altas **test**, comprobar smoke esperado y respuestas reales de Cron. Abrir test afecta a todos los usuarios autenticados elegibles; no hay allowlist individual.
- [ ] H5.G Ejecutar [la matriz de aceptación](guardian-acceptance.md): primera aportación, renovación/omisión, rechazo/3DS/tarjeta, cambio/cancelación, aniversario, privacidad/historial, devolución/reversión y recuperación sin duplicados.
- [ ] H5.H Corregir defectos, revisar independientemente y registrar el cierre verificable.

Android conectado separado también está compilado; es una alternativa de aceptación, no un requisito adicional para que el titular siga su ruta TestFlight.

## Hito 6 y lanzamiento público

Después de la aceptación H5: beta, dispositivos, paridad completa, contenido definitivo, privacidad y tiendas. Mantener el alcance de [mvp-release-contract.md](mvp-release-contract.md); sus etapas R0–R6 no son los hitos H1–H6. Auditar las casillas históricas contra evidencia actual antes de repetir configuración de firma, proveedores o credenciales.
