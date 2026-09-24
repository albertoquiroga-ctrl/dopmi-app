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

## Después del hito 4

- [x] H5.1 Planificador puro del neto mensual: urgencia aprobada, aprobación más antigua e ID como desempate; no entrega asignaciones parciales cuando falta capacidad. Cuatro pruebas en `tools/verification/guardian.test.mjs`. Aún no inicia cobros ni reserva saldos.
- [x] H5.2 Validada con el titular la experiencia de cobro automático condicionado, primer cobro al activar, ciclos mensuales omitidos sin deuda si falta capacidad, importes $50/$200/$500 MXN o personalizados, cambio desde el ciclo siguiente y cancelación de ciclos futuros. Documentada en `docs/product-decisions.md`. Falta implementar la interfaz y la autorización real en H5.4.
- [ ] H5.3 Reserva y liquidación transaccionales aplicadas a Supabase y aprobadas en CI. Para una factura pagada y previamente vinculada, la liquidación asigna el neto real completo o registra devolución total; conserva capacidad para las asignaciones y libera la diferencia entre reserva y neto. Concurrencia contra Checkout individual comprobada en PostgreSQL. Falta conectar el alta/cobro con estas operaciones y aceptar el recorrido completo en Stripe test antes de cerrar esta tarea.
- [ ] H5.4 Integrar el cobro inicial/mensual solo en modo de prueba con claves estables, reintentos, historial privado y conciliación. Procesador de facturas confirmadas y trabajos de transferencia/devolución implementado y probado; aún sin desplegar ni habilitar. Primer pago de Checkout implementado en servidor: consentimiento, reserva, recuperación, liquidación y devolución; CI y migración remota verificados. No se expone aún el alta en la app. Calendario mensual protegido implementado: registro sólo tras verificar la pausa de Stripe, recuperación por etapas y sincronización de cancelaciones. Sigue sin habilitarse en remoto. Cobro mensual y omisión sin deuda implementados en servidor, pendientes de aceptación integrada: reserva/vínculo atómicos, una autorización de pago, conciliación de resultados inciertos y anulación del ciclo sin capacidad. Recuperación backend implementada: cierre de rechazo/autenticación sin nuevo cargo, espera de procesamiento y conciliación tardía, con prueba aislada de cancelación en Stripe. Solicitudes del titular implementadas en PostgreSQL: consulta privada, consentimiento/revisión, deduplicación y cancelación serializada con la autorización de pago; el importe de un ciclo preparado se conserva y se bloquean ciclos nuevos mientras haya un cambio pendiente. Aplicación backend de monto/cancelación implementada: concesión exclusiva, lecturas de confirmación, claves estables, precio por período y snapshot de facturas. Prueba aislada de Stripe sin cargos, cuatro jobs de CI (244 pruebas backend, 163 pgTAP y concurrencia) y migración remota verificados; permanece deshabilitada. Integración Flutter de alta/consulta/cambio/cancelación implementada detrás de un flag desactivado: 31 pruebas Flutter y los cuatro jobs de CI aprobados; migración de consulta del titular verificada. La aceptación integrada sigue pendiente. Cancelación del alta implementada antes de Checkout y durante la preparación del calendario: conserva pagos en conciliación y detiene futuras activaciones. Actualización y autenticación del medio de pago para futuros ciclos implementadas con Checkout setup: consentimiento, recuperación, confirmación por servidor y exclusión con cobros/cancelaciones; no se vuelven a cobrar ciclos omitidos. Falta aceptación integrada de SetupIntent/3DS en dispositivo, historial de ciclos, revisión de cambios cercanos al aniversario, devoluciones posteriores a transferencias y aceptación integral.
- [ ] H5.5 Aceptación integral del flujo y evaluación independiente antes de habilitar dinero real.
- 5. Guardián sin reserva comunitaria, distribución por prioridad y facturación condicionada.
- 6. Beta, dispositivos, contenidos definitivos y preparación de tiendas.
