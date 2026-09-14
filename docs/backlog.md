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

## Después del hito 2

3. Verificación de rescatistas, gastos, evidencia previa, revisión y correcciones.
4. Aportaciones y Stripe Connect, conciliación y transferencias.
5. Guardián sin reserva, distribución por prioridad y facturación condicionada.
6. Beta, dispositivos, contenidos definitivos y preparación de tiendas.

No abrir el siguiente hito como efecto secundario de corregir el actual.
