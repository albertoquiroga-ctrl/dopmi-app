# H7 — retiro reversible del legado

Corte: 25 de septiembre de 2026, México. Proyecto `ohqxranynackjignryep`. El titular autorizó usar Supabase MCP directamente y confirmó que los datos antiguos eran de prueba. No se requiere otra credencial PostgreSQL.

## Alcance y resultado remoto

Migración local `20260926010602_archive_legacy_surface.sql`, aplicada por MCP como `20260926011355`. No se ejecutó `db push`, reparación ni renombrado del historial remoto.

- 29 tablas con 25 filas conservadas en `dopmi_legacy`, junto con sus restricciones, índices y políticas. Ninguna FK ni vista actual depende de ellas.
- Dos vistas antiguas trasladadas al mismo esquema: `v_deprecated_sponsorships` y la materializada `v_fund_pool_balance`. Dejan de estar expuestas en `public`.
- 20 rutinas antiguas trasladadas, con ejecución revocada y `search_path` fijo. El trigger histórico de Auth sigue existiendo porque su tabla pertenece a Supabase; su rutina ahora sólo devuelve `NEW`. El trigger actual `dopmi_create_profile` sigue creando perfiles.
- Revocados acceso al esquema y permisos de tablas, columnas, secuencias y funciones para PUBLIC, anon, authenticated y service_role. El propietario conserva recuperación administrativa. No añadir este esquema a los esquemas de API.
- Desactivados mediante `cron.alter_job`: `cleanup-expired-spei`, `close-expired-sponsor-windows`, `sponsorship-cycle-warnings`. `dopmi-payment-worker-reconcile` sigue activo y ejecutándose correctamente.
- Retiradas exactamente 16 políticas antiguas de Storage. Los cuatro buckets antiguos son privados; sus cinco objetos permanecen almacenados. Los 15 objetos de evidencia actual y sus políticas no se eliminan.
- Las 20 Edge Functions del [manifiesto](legacy-edge-manifest.json) fueron sustituidas por respuesta HTTP 410, versión 13, sin acceso a datos, secretos ni proveedores de pago. Conservan su configuración JWT. No fueron eliminadas del inventario de despliegues. El código original versión 12 está respaldado.
- Las cinco funciones actuales conservan sus versiones: payments 9, stripe-webhook 21, payment-worker 21, payment-return 8, guardian-client 13.

Tablas archivadas: achievements, adoption_applications, community_goals, conversations, device_tokens, donations, error_reports, fund_pool_contributions, fund_pool_disbursements, fund_pool_settings, fund_pool_subscriptions, messages, needs, notifications, partner_products, payment_methods, pets, posts, reimbursement_requests, reports, rescuer_profiles, saved_pets, saved_rescuers, sponsorship_charges, sponsorships, transactions, user_achievements, user_feedback, users.

Los tipos enum y el dominio geográfico antiguos no contienen datos ni conceden acceso; permanecen como dependencias de las tablas archivadas. No se usa CASCADE ni se eliminan cuentas de Auth, evidencia financiera o blobs.

## Respaldo y restauración comprobada

Copias locales ignoradas por Git en `.tools/legacy-backup`: `database.json` (datos, 341 columnas, 142 restricciones y cinco enums), `metadata.json` (funciones, vistas, triggers, índices, políticas, ACL, buckets y Cron), `platform.json` (dos auxiliares de plataforma), `migrations.json` y `edges/*.json` (fuentes originales). Contienen información de prueba privada: no publicarlas ni adjuntarlas a PR.

La herramienta `node tools/verification/legacy-restore.mjs .tools/legacy-backup` crea una base nueva con nombre aleatorio en PostgreSQL **local**, con PostGIS y el dominio `geography_point`. Restaura las tablas/datos/restricciones, funciones, vistas, índices, triggers y políticas, reproduce las migraciones y comprueba conservación de filas, cierre de privilegios, registro actual y traslado inverso de tablas. Elimina únicamente la base desechable que acaba de crear. No admite URL remota ni nombres de bases existentes.

Resultado: 29 tablas, 25 filas, 142 restricciones y 20 rutinas recuperadas; archivo/reversión, creación de perfil, aislamiento y conservación del Cron financiero aprobados. Las ACL de cliente del simulacro son deliberadamente amplias para probar la revocación; no representa una restauración completa de permisos de plataforma. Los blobs no se copiaron ni borraron y siguen conservados en Storage. Este respaldo lógico del legado no sustituye un respaldo completo del proyecto ni una prueba de recuperación de producción.

Para recuperar funcionalidad antigua, revisar primero la necesidad y las interacciones financieras. En una migración nueva: trasladar tablas/vistas/rutinas de vuelta a `public`, restaurar las definiciones originales (incluida la rutina de signup), su configuración y ACL desde el snapshot, después políticas/buckets y, sólo si procede, Cron/Edge. No reactivar todo a ciegas. La recuperación de filas mediante traslado inverso ya fue probada localmente; reactivar proveedores externos está fuera del simulacro.

## Evidencia y seguridad

- Correspondencia SQL renovada: las 21 entradas remotas previas coinciden exactamente con archivos locales normalizando CRLF y espacios extremos. Se mantienen los siete antecedentes sin fila CLI.
- Catálogo de permisos actuales comparado antes/después: triggers actuales, ACL de tablas/columnas y 14 políticas actuales de Storage sin cambios.
- Registro remoto probado dentro de una transacción revertida: perfil actual creado, ninguna fila nueva en el legado.
- Código remoto de los 20 endpoints comparado con el módulo de retiro. HTTP sin JWT: 19 rechazos 401 del gateway y 410 del webhook histórico. No se declara un recorrido autenticado HTTP para esos 19 endpoints.
- Simulacro PostgreSQL real, prueba automatizada de permisos y pruebas de respuestas 410 aprobadas. La suite existente de 388 pruebas también aprobó; pgTAP local pasó 191 comprobaciones después de actualizar las migraciones locales pendientes, sin reset.

El asesor de seguridad ya no reporta la vista SECURITY DEFINER expuesta, la vista materializada expuesta ni funciones sin `search_path`. Permanecen:

1. 22 tablas privadas con RLS sin políticas públicas: aislamiento intencional; acceso mediante RPC autorizadas. [Aviso](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).
2. Nueve RPC ejecutables por anon y 39 por authenticated con SECURITY DEFINER: APIs deliberadas de catálogo/perfiles aprobados, auxiliares de Storage y operaciones con identidad/propiedad/rol validados en servidor. Incluyen los helpers que devuelven false sin identidad en las políticas restrictivas. No sustituirlas por invoker ni revocarlas indiscriminadamente; su autorización está cubierta por suites identity/adoption/rescue/contributions/Guardian. [Anon](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
3. Protección de contraseñas filtradas deshabilitada: pendiente de configuración de Auth y disponibilidad del plan; el MCP conectado no expone actualización de esa configuración. Se conserva como tarea H10 previa al lanzamiento, sin afirmar que está resuelta. [Requisito/configuración](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Límite común de archivos

`MediaStore`, `MediaPurpose` y `PreparedMedia` centralizan buckets, límites, MIME, rutas, URL firmadas y procesamiento. Los repositorios de adopción/rescate delegan allí. Se conserva normalización JPEG, orientación y eliminación de EXIF; los documentos requieren firma PDF y límite de 5 MB. La validación de firma no pretende ser un analizador completo de PDF. Videos continúan deshabilitados. Storage/PostgreSQL conservan la autoridad sobre propiedad, borradores, revisión y exposición pública.
