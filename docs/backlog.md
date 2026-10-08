# Dopmi — entregas

> Corte vigente8/10/2026: [checkpoint](mock-sync-current.md) y
> [tablero único](parity-current-review.md). Delta9ced implementada/gates y
> QA instalada focalizada301 verificadas; aceptación final pendiente. Próximo
> chat: RETOMAR entrega9ced para revisión titular/Irlanda y QA final con evidencia,
> sin repetir verificaciones válidas.4369 posterior no inventariado. Perfil
> ENTREGA_CONTINUA_EFICIENTE_VERIFICADA; no presupuestos/renovaciones.

> Decisión vigente 27/9/2026: el titular admite las pantallas actuales para continuar; la fidelidad visual queda aplazada, sin aceptación atribuida a Irlanda. H9 autorizado: aceptación integrada y correcciones, con revisión final agrupada en Internal Testing. Ver [H9](h9-acceptance.md). Esta decisión supersede los bloqueos visuales históricos inferiores.

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

## Hito 5 — Guardián (completado en modo prueba)

Cierre: 25 de septiembre de 2026. Aceptación del titular con excepción explícita para disputa posterior a transferencia, según recomendación de soporte Stripe. Evidencia y límites en [entrega H5](hito5-delivery.md). No autoriza dinero real.

- [x] H5.1 Planificador del neto: urgencia, antigüedad y desempate estable; sin asignación parcial cuando falta capacidad.
- [x] H5.2 Decisiones del titular: primer cobro al activar, mensualidad condicionada, mes omitido sin deuda, cambio futuro y cancelación. Consentimiento e interfaz implementados. Reglas en `product-decisions.md`.
- [x] H5.3 Aceptación de reserva y liquidación transaccional completada en test: alta/renovación, omisión, concurrencia, devolución y reversiones conciliadas. Excepción de disputa documentada en hito5-delivery.md.
- [x] H5.4 Ciclo de vida aceptado: alta/abandono, calendario, cobro/omisión, recuperación, monto/cancelación, tarjeta/3DS e historial privado. CI36202506285, commit943a7d4: cuatro jobs aprobados. Límites de calendario preparado y dispositivo explícitos en entrega H5.
- [x] H5.5 Revisión independiente de seguridad y correcciones registrada; revisión final documental/test sin otro recorrido pendiente. Excepción de cobertura de disputa aceptada por el titular. No habilita dinero real.

### Cola inmediata

- [x] H5.A Comparar entorno remoto actual con el código y [historial de migraciones](migration-history-audit.md). SQL, catálogos y cinco Edge Functions comparados; diferencias de timestamps/defaults/formato explicadas. Conservar correspondencia explícita y no usar `db push`/repair sin renovar la auditoría; no se reejecutó SQL ni se alineó artificialmente el historial.
- [x] H5.B `payment-worker` v10 desplegado y comparado; preflight 1616 aprobó las 16 lecturas. Escrituras acreditadas separadamente por alta, renovación, cambio de monto/tarjeta, cancelación y reversión automática de la devolución en Stripe test. Evidencia en `progress.md`; no equivale a cerrar todos los escenarios de H5.G.
- [x] H5.C Preparación de flags de procesamiento con nuevas altas cerradas, acreditada por CI 36071101143 y registro previo. Reconsultar estado antes de abrir la aceptación; no contar como una comprobación remota nueva.
- [x] H5.D Configuración TestFlight que incluye Guardián y conserva bundle/firma; CI 36074983990 aprobado. Configuración no equivale a IPA firmado ni instalación.
- [x] H5.E Android 2.3.3 (247), SHA `3fe7a1d`, publicado por Codemagic e instalado desde Google Play interno; recorridos acreditados con capturas del titular. Dispositivo confirmado: Samsung Galaxy S25 Ultra (SM-S938B), Android 16, One UI 8.5. Actualización compilada e instalada según el titular; captura 1000343790 verifica el arreglo visual de cancelación. Codemagic confirma actualización 2.3.3 (248), commit a1e3b76267ff39200a47c720dbf472da044dc007, publicación internal completed; evidencia en la guía de aceptación. TestFlight queda como alternativa.
- [x] H5.F Altas **test** habilitadas con dispositivo/capacidad/Connect listos; 18 smoke checks aprobados con --expect-enabled y respuestas reales de Cron comprobadas. Primera aportación y renovación procesadas en test. Abrir test afecta a todos los usuarios autenticados elegibles; no hay allowlist individual. Los recorridos restantes siguen en H5.G.
- [x] H5.G Matriz aceptada en modo prueba, con disputa automática remota y conciliación posterior a transferencia simulada como cobertura alternativa autorizada. La secuencia remota posterior a transferencia no se ejecutó.
- [x] H5.H Defectos corregidos, revisiones independientes y cierre verificable registrados en hito5-delivery.md.

La APK Android separada queda como alternativa. La ruta elegida ahora es Google Play interno; el workflow estándar `android-internal` no habilita Guardián.

## H6 — Base única y trazable (completado)

Plan autorizado: [H6–H12](release-roadmap.md). Las casillas de aceptación visual/dispositivo nunca se cierran por código solamente.

- [x] H6.1 Comparar refs y reunir continuación/principal sin perder archivos locales.
- [x] H6.2 Registrar alcance MVP/post-MVP, responsables y correspondencia R0–R6.
- [x] H6.3 Registrar referencia viva de Irlanda y matriz por ruta/estado.
- [x] H6.4 Publicar PR, verificar CI e integrar en la rama principal.
- [x] H6.5 Registrar SHA integrado y CI; comprobar referencia de diseño al cierre.

## H7 — Legado y límites de código

- [x] H7.1 Inventariar objetos antiguos, dependencias, permisos, cron, Storage y funciones Edge.
- [x] H7.2 Respaldar legado fuera de Git y demostrar restauración aislada.
- [x] H7.3 Revocar superficies antiguas; retirar Cron/Edge/objetos por lotes; verificar autorización y sistema actual.
- [x] H7.4 Retirar exposiciones antiguas y documentar RPC/tablas privadas intencionales en legacy-retirement.md. Configuración de protección de contraseñas queda explícitamente en H10.6.
- [x] H7.5 Modelos tipados en límites y servicio común de archivos (sin videos).

Evidencia H7: [retiro reversible](legacy-retirement.md). PR #5 integrado en `ba9f897`, CI 36208309068 aprobado en sus cuatro trabajos. La restauración probada es lógica del legado, no recuperación completa de producción.

## H8 — Paridad completa y funcional (alcance corregido 26/9/2026)

Plan vigente: [h8-execution.md](h8-execution.md). Las casillas históricas inferiores documentan implementación parcial, no aceptación de H8. Los recorridos visibles de H9 se ejecutan ahora dentro de H8.

- [x] H8.0 Matriz concreta de pantallas/acciones, dependencias y evidencia separada. Es un registro vivo: cada ciclo actualiza I/T/V sin borrar diferencias abiertas.
- [x] H8.1 Dos experiencias completas; cambio dedicado de modo y conservación de estado. I/T completos; V pendiente del candidato instalado.
- [x] H8.2 Swipe, filtros, personalidad, zona/radio aproximado y paginación. Implementación y comprobación técnica completas; aceptación visual se conserva en H8.7.
- [x] H8.3 Detalles, favoritos de mascotas/casos/rescatistas, Mis match y comunicación. I/T completos; V pendiente.
- [x] H8.4 Perfil, configuración separada, historial real y ayuda. I/T completos; textos legales definitivos permanecen H10.
- [x] H8.5 Apoyar, historias moderadas, perfil público e impacto real. I/T completos; V pendiente.
- [x] H8.6 Panel/Casos/Publicar/Mensajes/Perfil rescatista; verificación/evidencia por pasos. I/T completos; V pendiente.
- [ ] H8.7 Aportaciones/Guardián fieles con resultados reales: I/T completos. Android 2.3.3 (256), SHA `ea5350e`, publicado con CI y Publishing aprobados; falta aceptación visual/dispositivo de Irlanda para cerrar H8.

### Registro anterior: componentes implementados, no cierre de paridad

- [x] H8.1 Base de tokens, fuentes/assets y controles del mockup implementada; revisión visual pendiente H8.3.
- [x] H8.2 Navegación por experiencia y conservación de estado entre pestañas; cuentas separadas y recuperación cubiertas por pruebas.
- [ ] H8.3 Capturas comparables, accesibilidad y revisión de Irlanda.
- [x] H8.4 Implementar onboarding contextual, entrada de cuenta y formularios con componentes de la referencia; conservar confirmación/recuperación reales y gates OAuth. Aceptación de paridad visual pendiente en H8.3.

Detalle y capturas de componentes/acceso: [H8](design-foundation.md). H8 permanece abierto hasta revisión y aceptación visual de Irlanda; no equivale a H9 ni a aceptación en dispositivo.

## H9 — Aceptación integrada y confiabilidad funcional

Plan autorizado 27/9/2026: [matriz, defectos y revisión agrupada](h9-acceptance.md). El titular aplaza la fidelidad visual y admite las pantallas actuales para continuar.

- [x] H9.0 Base, conexiones, matriz y fixtures locales reproducibles.
- [x] H9.1 Integración de adopción/favoritos/contacto/retiro y privacidad entre cuentas.
- [x] H9.2 Integración de rescate, correcciones, fotos, avances, perfil y adopción vinculada; defectos de notificación/visibilidad corregidos.
- [x] H9.3 Regresiones financieras y acceso remoto test; evidencia histórica H5 preservada. Aceptación instalada se agrupa en H9.5.
- [x] H9.4 Correcciones de moderación, permisos, paginación y guía operativa.
- [ ] H9.5 CI 36330974531 aprobado; Android 2.3.3 (259) publicado en Internal Testing desde 73c731f. Falta aceptación funcional agrupada del titular; no cerrar por compilación/publicación.

## H10 — Identidad pública y operación

Plan autorizado y cola detallada: [h10-execution.md](h10-execution.md).
Inicio 28/9: guardas de entorno y cliente Google nativo comprobados localmente;
Apple sólo adaptador preparatorio. Ningún subhito H10 cerrado todavía.

- [x] H10.1 Configurar/verificar Google y Apple, callbacks y no duplicación de identidad. Google aprobado en Android/iOS; Apple nativo aprobado sólo en iOS/iPadOS por decisión de producto; vinculación conserva el mismo perfil.
- [x] H10.2 Eliminación de cuenta y tratamiento de sesiones/contenido/evidencia. Reintento Auth parcial, operaciones pendientes, Guardián, aislamiento y permisos servidor verificados.
- [x] H10.3 Analítica mínima y errores sin datos privados; consentimiento comprobado.
- [x] H10.4 Correo, soporte/moderación, legal y declaraciones de privacidad definitivas. App Privacy quedó publicada; Data Safety fue enviada a revisión. La ficha Apple 2.3.3 y la resolución del aviso histórico de Google se revalidarán con el candidato final, sin bloquear el siguiente bloque.
- [x] H10.5 Separar configuración test/producción, conservando identidad y firma. Producción quedó sin altas, proveedores sociales, secretos personalizados, usuarios ni datos; Android 281 y iOS 282 se publicaron internamente desde el mismo SHA `0a25ba8`.

- [ ] H10.6 Habilitar/verificar protección de contraseñas filtradas en Supabase Auth, sujeto a disponibilidad del plan. MCP actual no permite configurar Auth.

Estado vigente 28/9: proveedores test, eliminación servidor, medición, Resend y
proyecto de producción ya están implementados/configurados. Las tareas H10.1–H10.5
permanecen abiertas únicamente hasta completar aceptación instalada, Firebase,
Private Relay y el candidato conjunto. H10.6 se difiere por decisión del titular
a H12 porque requiere Supabase Pro; debe cerrarse antes del lanzamiento público.

### Corte H10 del 28/9/2026

- [x] Términos/privacidad/18+ versionados y aviso de desarrollo retirado.
- [x] Eliminación dentro de Configuración, solicitud web y proceso servidor
  idempotente desplegado en test; conserva evidencia y contenido ajeno.
- [x] Interfaces Analytics/Crashlytics con consentimientos independientes,
  apagados por defecto; configuración Firebase segura preparada en Codemagic.
- [x] Activar Google/Apple y vinculación manual en Supabase test; flags seguros
  activos en los candidatos H10. Google quedó aceptado en Android/iOS; Apple
  nativo, Private Relay y revocación quedaron aceptados en iOS/iPadOS.
- [x] Vinculación explícita confirmada sobre el mismo perfil. Apple web en
  Android se retiró del alcance por decisión del titular: Android ofrece
  Google/correo y Apple permanece exclusivo de iOS/iPadOS.
- [x] Probar recepción/respuesta y configurar SMTP transaccional. Resend quedó
  verificado en ambos sentidos; la clave `Supabase` se reserva para Auth/SMTP
  y `Codex Dopmi` para envíos controlados de prueba.
- [x] Aprobar costo cero actual y crear Supabase producción limpio y cerrado.
- [x] Publicar el mismo SHA en Internal Testing y TestFlight e instalar ambos:
  Android 277 e iOS/iPadOS 278; Google y persistencia aprobados por el titular.

## H11 — Beta en ambas tiendas

- [x] H11.1 Mismo SHA por Codemagic en Play interno y TestFlight; verificar publicación. Android 283 e iOS 284 provienen de `94cb82e` y están disponibles en los canales internos.
- [x] H11.2 Recorridos disponibles en Android, accesibilidad, instalación/actualización y recuperación. El titular trasladó correo real e iOS final a H12.
- [x] H11.3 Sin defectos críticos/altos en la evidencia ejecutada; recuperación automática queda como fricción media. Revisión visual externa trasladada expresamente al candidato final H12.
- [x] H11.4 Procedimiento de reversión probado sin mutar las tiendas: SHA conocido como bueno recuperable, diferencias acotadas, identidad/firma/canales conservados y rebuild monotónico definido. La reversión real sólo se ejecuta ante un defecto.

## H12 — Lanzamiento

- [ ] H12.0 Integrar los cambios finales de Irlanda y el parche de consentimiento; publicar un mismo SHA nuevo en Play interno y TestFlight. Repetir regresión Android/iOS, correo real y revisión visual externa.
- [ ] H12.1 Landing, fichas, capturas, privacidad y soporte listos.
- [ ] H12.2 Revisar Stripe live/Connect, conciliación, disputas, depósitos y límites.
- [ ] H12.3 Obtener autorización explícita de dinero real antes de activarlo.
- [ ] H12.4 Publicación gradual y monitoreo operativo verificado.

## Controles recurrentes

- [x] Monitor diario de diseño 09:00 configurado; sólo notifica novedades accionables.
- [x] Revisión semanal de dependencias, seguridad, costos, soporte y deuda.
- [x] Revisión mensual de restauración, accesos y firma.
- [ ] Comprobación de artefactos/publicación por build y monitoreo de producción.

Los monitores de Codex requieren equipo/conexiones disponibles; no reemplazan Cron ni observabilidad del servidor.

## 2026-10-04 — Actualización889 autorizada, supersede el aplazamiento anterior

Implementar REF-01–19 del tablero parity-current-review.md hasta889c096,
desde8785f66/Play290. Funciones completas con contratos aditivos mínimos;
saludo sólo al confirmar el primer contacto, transaccional y sin duplicados.
Tres subagentes/frentes exclusivos y un integrador/cola Flutter. Commits nuevos
posteriores al corte quedan para otra entrega. Codemagic únicamente candidato
final; cierre requiere regresión y Android instalado. Dinero exclusivamente test.

Estado5/10 del corte889:19/19 grupos implementados y cerrados en desarrollo,
candidato51cc7c1 con gate integral37278538360 aprobado (846 tests móviles,
backend/SQL/integración y compilaciones). Nativo emulador aprobado después de
corregir el offset entre pasos. Codemagic6ac3570f3a34cf7c3070ed0f entregó
2.3.3(291), Play internal/completed comprobado; Guardián permanece en test.
- [x] Comprobar291 instalada y ocho recorridos modificados en Samsung al115%.
- [x] Limpiar sólo las dos identidades y15 objetos sintéticos del manifest QA889; postflight cero y participante Samsung conservado.
Los commits Source posteriores a889c096 y los pendientes H12 siguen separados.

### 2026-10-05 — Swipe cerrado en Samsung y Play 295

Supera el pendiente del candidato fcc2ce7: único release interno 2.3.3 (295), source 7cf8202; Play completed confirmado y Samsung actualizado desde tienda. Diez avances efectivos sobre catálogo repetido; videos 293/295 comparados por cuadros intermedios, transiciones mixtas centradas y foto/texto unidos. Codemagic 877 tests; gate móvil 37406799890/41c5a37 y checks iOS/web/backend 37405575748 acreditados. Auditoría cerrada sin pendientes; dos correcciones sólo de verificación. Ver docs/swipe-stack-delivery.md. No hay otro loop de swipe abierto.

## 2026-10-06 — Actualización bccd040 autorizada

22/22 grupos cerrados en desarrollo; referencia congelada bccd040 y base
ed4b788/Play295. Tablero vigente parity-current-review y cuatro fichasupdatebccd.
Pendientes de entrega: auditoría delta, gate SHA final, nativo emulador,
CodemagicGuardianInternal/Play/Samsung y limpieza exacta. Conservar fotos/swipe295,
privacidad, revisión y edición de apoyo aprobado bloqueada; dinero test.


## 2026-10-06 — checkpoint de sincronización vigente

Corte bccd040 cerrado22/22, Android296/Samsung y cleanup cero comprobados; supersede los pendientes de entrega bccd anteriores. No hay lote de paridad activo. Referencia viva9ced070 observada por Git, delta aún no inspeccionado ni implementado. Siguiente: esperar encargo y congelar su alcance antes de inventariar. Leer [mock-sync-current.md](mock-sync-current.md) y [mock-sync-workflow.md](mock-sync-workflow.md); no reiniciar gates/fixtures cerradas.
