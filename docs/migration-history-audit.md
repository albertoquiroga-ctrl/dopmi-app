# Auditoría del historial de migraciones

## H10 eliminación y producción — 28/9/2026

Test: `20260928205058_h10_terms_account_deletion.sql` → `20260928211754` y
`20260928211922_h10_account_deletion_content_retention.sql` → `20260928212147`.
La corrección local `20260928223000_h10_auth_reference_cleanup.sql` se aplicó por
MCP como test `20260928221654` y producción `20260928221656`. Cambia únicamente
las dos FK privadas de revisión a `ON DELETE SET NULL`, de modo que la evidencia
moderada sobreviva sin impedir retirar la identidad del revisor.

Producción `ysaoeuidcvgtlmphmeyb` se creó limpia y recibió secuencialmente las 47
migraciones existentes mediante MCP; sus versiones remotas `20260928220554`–
`20260928220743` corresponden al contenido local por nombre y orden. No usar esos
timestamps para reparar test ni renombrar archivos. Tras el despliegue: cero
usuarios/perfiles/aportaciones/adopciones/objetos Storage y ningún secreto Stripe.

## H10 credenciales Apple — 28/9/2026

Local `20260928154523_h10_apple_credentials.sql` → remoto `20260928155742`.
Antes se comprobó ausencia de tabla/RPC y presencia de auth.identities.provider_id;
historial remoto conserva las tres migraciones H9. Aplicación aditiva por MCP,
sin replay/repair/push. Después: tabla privada RLS, RPC sólo service_role, cero
credenciales. No altera perfiles, pagos ni firmas existentes.
Local original carecía de las tres correcciones H9; aplicadas sólo localmente
tras confirmar el defecto de notificación anterior. Suite PostgreSQL:254 aprobadas.


## Adición H8.6 — 26 de septiembre de 2026

Migración local `20260927033610_moderated_rescuer_profiles.sql`, aplicada por MCP como versión remota `20260927033251` con nombre `moderated_rescuer_profiles`. Es aditiva: tabla RPC-only para perfil público, auditoría privada, bucket privado y funciones versionadas de dueño/administración. No reutiliza legado ni cambia firmas consumidas por el build 253. La consulta posterior confirmó objetos, bucket privado, ausencia de lectura cruda anónima y denegación anónima de la RPC administrativa. PostgreSQL local fue reconstruido desde todas las migraciones y aprobó 243 pruebas; no se usó `db push`, reparación ni renombrado.

Migración correctiva local `20260927035600_public_case_guardian_progress.sql`, remota `20260927034007`: conserva la firma pública y reemplaza el agregado incompleto de donaciones por `dopmi_expense_funding`, que incluye asignaciones confirmadas de Guardián. La suite financiera detectó el defecto y sus 338 pruebas aprobaron después del arreglo. La definición remota contiene la fuente canónica y no consulta tablas privadas directamente.

## H8 descubrimiento — 26 de septiembre de 2026 (México)

Migración local `20260927020621_community_saved_reports.sql`, remota `20260927021744`: añade favoritos privados UUID de casos/rescatistas, búsqueda privada de conversaciones, marcadores de adopciones retiradas sin contenido y reportes con resolución administrativa auditada. No cambia firmas consumidas por el build 253. La migración siguiente `20260927021820_community_table_boundaries.sql`, remota `20260927021850`, registra políticas restrictivas para las tres tablas RPC-only. Ninguna concede lectura cruda a `authenticated`.

La base local se reconstruyó desde cero y las cuatro suites pgTAP aprobaron 213 pruebas. En remoto se comprobaron tablas, privilegios de RPC y denegación de SELECT. Los avisos de funciones autenticadas `SECURITY DEFINER` corresponden a puntos API deliberados con identidad/visibilidad comprobadas, `search_path` vacío y grants explícitos.

Migración local `20260927022451_public_case_favorite_state.sql`, remota `20260927022716`: conserva la firma de `dopmi_rescue_public` y añade únicamente el booleano `saved`, calculado para la identidad activa. Anónimo obtiene `false`; no se exponen el UUID del usuario ni las filas de favoritos. Las pruebas pgTAP aumentaron a 217 e incluyen guardar/reconsultar/reportar un caso aprobado.

Migración local `20260927022858_moderated_case_updates.sql`, remota `20260927023747`: crea un ciclo aditivo de avances y un bucket privado separado. Borrador, fotos y retroalimentación sólo se consultan por RPC autorizadas; el público recibe cuerpo/fotos/fecha del snapshot aprobado, sin propietario ni moderación. PostgreSQL local completo: 224 pruebas. Remoto: bucket privado, falta de SELECT crudo y ejecución de la RPC propietaria comprobados. `private.dopmi_case_update_reviews` conserva el aviso informativo de RLS sin políticas porque no se expone al API y sus grants están revocados.

Migración local `20260927024050_public_rescuer_and_impact.sql`, remota `20260927024547`: añade dos lecturas aditivas. `dopmi_rescuer_public` agrega exclusivamente perfil, publicaciones, casos y avances aprobados. `dopmi_personal_impact` exige sesión y limita cantidades a aportaciones confirmadas asignadas de la identidad activa; no entrega otro donante, Stripe, mensajes, documentos ni evidencia privada. Remoto: perfil anónimo permitido, impacto anónimo denegado e impacto autenticado permitido. PostgreSQL local completo: 230 pruebas.

Migración local `20260927030310_public_case_progress.sql`, remota `20260927025431`: conserva firma/permisos de `dopmi_rescue_public` y añade `target_cents`, además de restaurar sus agregados públicos `funded_cents` y `transferred_cents`. La meta suma sólo gastos aprobados públicamente; la asignación/transferencia suma cantidades sin identidad de donante ni identificadores del procesador. Remoto comprobado con cinco casos y PostgreSQL local completo: 232 pruebas. Los asesores no añadieron hallazgos; permanecen avisos generales ya documentados de RPC públicas deliberadas y tablas privadas sin grants.

Migración local `20260927031520_rescuer_dashboard.sql`, remota `20260927030616`: añade un resumen exclusivamente autenticado y acotado por `auth.uid()`. Devuelve estados/conteos propios, notificaciones no leídas y agregados financieros etiquetados; la actividad excluye donante, cargos, transferencias y cuenta bancaria. Acceso remoto del propietario comprobado y `anon` carece de `EXECUTE`. PostgreSQL local completo: 234 pruebas.

Migración local `20260927032540_case_adoption_link.sql`, remota `20260927031531`: añade `rescue_case_id` a adopciones con FK y unicidad parcial. `dopmi_save_adoption` conserva firma y sólo acepta un caso aprobado del propietario; no altera estados de revisión de ninguna entidad. La consulta directa sigue protegida por RLS. Remoto: columna/privilegios comprobados; PostgreSQL local completo: 236 pruebas, incluido rechazo de un segundo borrador vinculado.

Antes del cambio se reconsultaron las 22 entradas remotas y la ausencia de columnas/RPC nuevas. Migración local `20260927013712_adoption_discovery.sql`, aplicada por MCP como `20260927014731`: añade personalidad y coordenadas redondeadas a publicaciones, más `dopmi_discovery` sin cambiar `dopmi_catalog` ni otra firma consumida por el build 253. La RPC sólo devuelve distancia calculada cuando el cliente aporta ubicación completa; nunca devuelve coordenadas. No se ejecutó `db push`, renombrado ni reparación del historial.

Reproducción desde cero y `supabase test db`: cuatro archivos, 198 pruebas aprobadas. Verificación remota: dos perros juguetones, dos perros dentro de 10 km del punto de prueba en Monterrey, distancia presente y cero claves de coordenadas. El asesor conserva los avisos documentados de funciones públicas `SECURITY DEFINER`; `dopmi_discovery` es una lectura pública deliberada de publicaciones aprobadas, con filtros validados y `search_path` vacío.

La migración local `20260927015519_adoption_support_cards.sql`, aplicada por MCP como `20260927015643`, añade una lectura pública acotada para intercalar casos. Sólo devuelve casos aprobados de rescatistas verificados con un gasto aprobado, pagable y con capacidad real restante. Se comprobó contra el proyecto de pruebas; no crea ni asigna aportaciones.

## Renovación H7 — 25 de septiembre de 2026 (México)

Consultadas de nuevo las 21 entradas remotas previas: todas sus sentencias coinciden con los archivos locales normalizando CRLF/LF y espacios extremos. Se conservan los siete antecedentes sin fila CLI. Snapshot privado en `.tools/legacy-backup/migrations.json`; no se reejecutó ni reparó historial remoto.

Nueva migración local `20260926010602_archive_legacy_surface.sql`, aplicada por MCP como `20260926011355`. Total posterior: 29 archivos locales y 22 entradas remotas. Traslada legado a esquema privado, retira accesos/políticas antiguas y desactiva tres Cron. Copia lógica restaurada en PostgreSQL local con PostGIS antes del cambio. Permisos actuales comparados antes/después sin diferencias. Ver `legacy-retirement.md`.

Intentos iniciales se revirtieron completamente: Auth no permite alterar su trigger con el rol conectado y Cron no admite UPDATE directo; la versión aplicada retira el cuerpo de la rutina antigua y usa `cron.alter_job`. No se modificaron propietarios de objetos de plataforma. Un error de delimitación al transportar el SQL se corrigió leyendo el archivo probado literalmente; ninguna versión fallida quedó aplicada.

## Adición del 25 de septiembre de 2026: reintento de visibilidad de anulación

Nueva migración local `20260925171348_guardian_void_visibility_retry.sql`, aplicada como versión remota `20260925171711` tras desplegar el colector corregido. Reparación acotada de la cola, sin modificar esquema, reservas ni evidencia financiera. No se reparó ni reejecutó historial previo. El total pasa a 27 archivos locales y 20 entradas remotas; la correspondencia histórica inferior sigue vigente. Suite completa de 366 pruebas aprobada, con reparación idempotente y exclusiones de autorización, lease activo, error ajeno y límites de reintento.

Antes de desplegar, las funciones remotas payment-worker v11, stripe-webhook v11 y guardian-client v3 coincidían con el repositorio salvo guardian-collection.mjs modificado en este arreglo. Después: v12/v12/v4, respectivamente, comparadas archivo por archivo con el paquete esperado; se preservan los demás archivos. La lectura actual de versiones sustituye los números del corte histórico inferior.

## Comprobación directa — 25 de septiembre de 2026

Proyecto `ohqxranynackjignryep`, rama `codex/stripe-transfer-delivery`, migraciones del código `e16e1da` (sin cambios lógicos posteriores). Se consultó `supabase_migrations.schema_migrations` directamente: **19 filas** con una sentencia por fila; las 19 coinciden con el archivo local correspondiente tras normalizar CRLF/LF y espacios al principio/final. Sus timestamps difieren; se añade abajo `payment_delivery`, ausente en la comparación documental inicial. Las siete migraciones `202609130001`–`202609130007` no tienen fila de historial.

Se reprodujeron las 26 migraciones en PGlite y se compararon catálogos con el proyecto real, sin modificarlo:

- 30 tablas con los mismos estados RLS, 372 columnas (tipo, nulabilidad y default), 258 restricciones, 110 índices y nueve políticas sobre las tablas de Dopmi: coinciden.
- 84 funciones presentes. Coinciden `security_definer`, configuración y ACL tras reproducir los permisos predeterminados reales de Supabase (`pg_default_acl`). 79 definiciones coinciden normalizando saltos de línea. Las cinco funciones de identidad restantes coinciden quitando espacios y el comentario explicativo de `admin_list_users`; se inspeccionaron sus cuerpos, no se asumió equivalencia por nombre.
- Comprobación adicional completada: coinciden cuatro triggers (definición y estado), ACL de las 30 tablas, cinco ACL de columnas y las 14 políticas `dopmi_%` de Storage. Esta comparación no audita objetos heredados ajenos a Dopmi ni sustituye los recorridos de autenticación y archivos.
- La ejecución adicional por `service_role`, y por `anon` en `dopmi_can_write_photo`, proviene de esos defaults de plataforma; no es divergencia frente a ejecutar las migraciones sobre Supabase. La función conserva sus comprobaciones de identidad/propiedad y devuelve `false` sin sesión. El aislamiento de las nueve RPC Guardián de servidor y las tres consultas privadas también pasó en el smoke HTTP remoto.

**Decisión por migración:** conservar las 19 versiones remotas y sus archivos locales, con la correspondencia explícita de la tabla. Para las primeras siete, conservar el antecedente de aplicación por SQL Editor y la evidencia del catálogo. No ejecutar `db push`, renombrar archivos ni realizar `migration repair` sobre este proyecto compartido: el historial CLI todavía no está alineado, aunque los objetos examinados concuerden. Una futura alineación debe preservar la exportación del historial y renovar esta comparación antes de marcar versiones como aplicadas. La auditoría del esquema examinada queda acreditada; H5.A incluye además la comparación del código de funciones Edge desplegadas.

Snapshots de trabajo (sin datos de usuarios ni credenciales): `.tools/h5-audit/migrations-remote.json`, `catalog-local.json`, `catalog-remote.json`, `schema-local.json` y `schema-remote.json`; se mantienen fuera de Git. No se alteró esquema ni historial remoto.

## Comparación documental inicial

Las funciones Edge recuperadas también coinciden archivo por archivo con el código local normalizando CRLF/LF: `guardian-client` v2 (14 archivos), `stripe-webhook` v10 (14), `payments` v8 (3), `payment-return` v7 (1), y `payment-worker` v10 (15) comprobado tras su despliegue. H5.A queda resuelto como auditoría/correspondencia; no representa reparación del historial CLI ni aceptación de pagos.

Corte: 25 de septiembre de 2026. Comparación de archivos del repositorio en `8e6663d` con las versiones remotas **registradas en `docs/progress.md`**. No es una consulta nueva de `supabase_migrations.schema_migrations` ni prueba de que el SQL remoto sea diferente.

Hay 26 archivos locales; en 18 nombres, el timestamp del archivo difiere del timestamp registrado para su aplicación remota. Las primeras migraciones también tienen antecedentes de aplicación por SQL Editor sin historial CLI. El próximo agente debe resolver la correspondencia antes de cualquier `db push` o reparación del historial. **No renombrar ni ejecutar de nuevo migraciones para hacer coincidir números.**

| Nombre | Versión del archivo en Git | Versión remota documentada |
| --- | --- | --- |
| `payment_delivery` | `202609230001` | `20260923145807` |
| `refund_reversal` | `20260923190407` | `20260923190919` |
| `fix_payment_reconcile_candidates` | `20260923215745` | `20260923215929` |
| `guardian_atomic_reservations` | `20260923224118` | `20260923225013` |
| `guardian_capacity_preview` | `20260923233000` | `20260923234106` |
| `guardian_subscription_registry` | `20260924021815` | `20260924024539` |
| `guardian_settlement` | `20260924031643` | `20260924034146` |
| `guardian_initial_checkout` | `20260924035436` | `20260924041103` |
| `guardian_monthly_schedule` | `20260924134958` | `20260924141312` |
| `guardian_monthly_collection` | `20260924142301` | `20260924143909` |
| `guardian_payment_recovery` | `20260924151905` | `20260924160254` |
| `guardian_owner_requests` | `20260924160633` | `20260924161814` |
| `guardian_request_processing` | `20260924163547` | `20260924171515` |
| `guardian_mobile_state` | `20260924174516` | `20260924180505` |
| `guardian_activation_cancel` | `20260924182953` | `20260924184639` |
| `guardian_payment_method` | `20260924191102` | `20260924193738` |
| `guardian_cycle_history` | `20260924201240` | `20260924202605` |
| `guardian_anniversary_review` | `20260924204840` | `20260924214410` |
| `guardian_refund_reversals` | `20260924220619` | `20260924222351` |
| `guardian_initial_dispute_review` | `20260925190500` | `20260925190650` |

## Procedimiento de comprobación

1. Confirmar el proyecto `ohqxranynackjignryep`, la rama de continuación y acceso de solo lectura. Consultar la ayuda de la CLI instalada antes de utilizar sus comandos.
2. Leer las versiones/nombres/SQL disponibles del historial remoto. Contrastar con las 26 migraciones locales, `progress.md` y el esquema real: tablas, funciones, definiciones, restricciones, índices, RLS y grants. Que dos nombres se parezcan no acredita que ejecutaron el mismo SQL.
3. Distinguir SQL equivalente con identificador distinto, migración aplicada fuera de CLI y diferencia real de esquema. Para las primeras migraciones, no asumir que sigue faltando historial solo porque así era el 13 de septiembre.
4. Preparar un plan explícito por migración. Si hace falta `migration repair`, usarlo solo después de demostrar qué SQL está aplicado y conservar el registro original; no usarlo para ocultar diferencias. Una reparación de historial no ejecuta el SQL faltante.
5. Si se necesita corregir el esquema, crear una migración nueva y probarla primero localmente/CI. No editar el contenido histórico ya desplegado ni resetear el proyecto compartido.
6. Registrar fecha, proyecto, versión local/remota, resultado de comparación, acción y evidencia sin secretos. Actualizar este documento con la tabla de resultados.

Este traspaso no ejecutó reparación ni cambio de esquema. La discrepancia se deja como trabajo técnico de continuidad, con evidencia suficiente para investigarla sin repetir migraciones a ciegas.
## H9 — 27 de septiembre de 2026

Dos migraciones aditivas aplicadas por MCP después de reproducir los fallos en Auth/REST/Storage locales:

- `20260927153539_h9_case_update_review_notification.sql` → remoto `20260927154149`. La segunda decisión sobre un avance actualiza su notificación y conserva ambas revisiones auditadas.
- `20260927154019_h9_moderated_media_visibility.sql` → remoto `20260927154152`. Fotos de avances, avatar aprobado y actividad pública respetan visibilidad vigente del caso/verificación.

Antes: cuerpos remotos de las tres funciones de visibilidad coincidieron por MD5 con las migraciones originales; definición de revisión comparada. Después: los cuatro cuerpos coinciden exactamente normalizando CRLF a LF (hashes 7bd109951cc78d100788ddb619eedfc2, 243c968cf30d76fa29d2554ba850eccc, 8c358d9b8ebc416e378409c494680c8b, 06f26759f44bae4f492791dffab81696). Firmas, grants y search_path vacío conservados; sin push/repair ni replay histórico. URLs previamente firmadas conservan su vigencia breve (60 segundos); el cambio impide nuevas firmas/accesos autorizados cuando el contenido deja de ser público.

Adición H9: `20260927154814_h9_preserve_approved_avatar.sql` conserva el avatar del snapshot aprobado cuando el propietario edita otro borrador. Niega escritura/borrado de esa ruta, permite cargar una ruta nueva. Integración Storage real: intento de borrado por dueño y lectura pública posterior aprobados. Aplicación remota y verificación de cláusula/grant realizadas por MCP; no cambia firma.

## H10 — 28 de septiembre de 2026

Después de consultar el historial remoto y sin ejecutar `db push` ni repair:

- local `20260928205058_h10_terms_account_deletion.sql` → remoto
  `20260928211754_h10_terms_account_deletion`;
- local `20260928211922_h10_account_deletion_content_retention.sql` → remoto
  `20260928212147_h10_account_deletion_content_retention`.

La segunda migración sustituye únicamente la rutina servidor de eliminación para
archivar y anonimizar publicaciones, redactar mensajes propios y conservar los
mensajes del otro participante. Ambas se reprodujeron en la suite PGlite antes
de aplicarse; 402 pruebas completas pasaron después. Se conserva la
correspondencia explícita; no se renombraron migraciones históricas.

## Paridad de personalidad · 30 de septiembre de 2026 (México)

Proyecto de desarrollo `ohqxranynackjignryep`. Local
`20261001042203_adoption_personality_parity.sql` → remoto
`20261001042909_adoption_personality_parity`, aplicado por MCP tras pruebas
PGlite. No push, repair, renombrado ni repetición histórica.

Antes: cuerpos locales/remotos de save y discovery idénticos en UTF-8,
normalizando CRLF; hashes MD5 `936ee5be7b3eab329b14ac2324793892` y
`f722fd54426b62a0fac4085d24ef8424`. Restricción remota confirmó seis claves.
Después: hashes `740811926f07ae14edfdb56b83c66850` y
`0d1e3a6346439b562326d2bbb285ae46` coinciden con la migración nueva.
Firmas, SECURITY DEFINER, search_path vacío y ACL conservados. Consulta remota
de los doce rasgos aceptada. Se conserva cada valor anterior; omitir personalidad
preserva sus datos y una lista vacía los limpia. Guardar cambios devuelve toda
la publicación a borrador y exige aprobación antes de discovery.

Asesores antes/después conservan categorías y conteos: RLS sin políticas27,
RPC SECURITY DEFINER anon15/authenticated68 y protección de contraseñas1.
No se concedieron accesos nuevos. pgTAP local pendiente: Docker no disponible.

## Preflight del loop 42 — Impacto mensual, 1/10/2026

- Acceso MCP de lectura comprobado en desarrollo `ohqxranynackjignryep`; producción no consultada ni modificada. Historial remoto conserva `20260927024547_public_rescuer_and_impact` y termina en `20261001042909_adoption_personality_parity`. No push, repair ni replay.
- Cuerpo local y remoto de `public.dopmi_personal_impact()` idénticos normalizando CRLF: MD5 `55b06e7880046036bea6fdeecdb05277`. Definición remota MD5 `718c6b460232701b0938d954b3b40efc`; stable/SECURITY DEFINER/search_path vacío conservados. EXECUTE anon=false/authenticated=true comprobado por consulta separada.
- Brecha confirmada: la RPC sólo agrega dopmi_donations confirmadas. Guardian no aparece aunque tenga asignaciones. El helper remoto private.dopmi_guardian_funded(uuid,boolean) suma allocated_cents menos reversed_cents, igual que el SQL local de refund_reversals; reservas amount_cents no equivalen a apoyo. Metadatos remotos confirman donor_id en ciclos, allocated/reversed en asignaciones y created_at en settlements. No se consultaron ni exportaron filas privadas de donantes.
- Siguiente implementación: migración nueva que agregue ambas fuentes por caso, filtre identidad vigente/caso público, use neto de asignación mensual confirmado y conserve contrato/copy público. Probar donante distinto, reserva sin pago, reverso parcial/completo, suma con puntual y retiro de publicación antes de aplicación remota. Dinero y Stripe no se modifican. PGlite de payments.test.mjs ya carga todas las migraciones; reutilizar ese gate y añadir prueba de consulta, sin sustituir PostgreSQL real por assertions textuales.

## Loop 42 — Impacto mensual confirmado, 1/10/2026

- Migración creada con CLI2.118.0 después de consultar migration new --help: `20261001110103_personal_guardian_impact.sql`. Reemplaza únicamente la lectura de impacto, conservando firma JSON, stable/SECURITY DEFINER/search_path vacío y ACL. Unión por caso de donaciones confirmadas y asignaciones Guardian con settlement existente, identidad del ciclo y neto allocated_cents-reversed_cents positivo. No usa reservas ni exige plan vigente para ver apoyo histórico; no modifica cobros/transferencias/reglas económicas.
- Dos pruebas PGlite nuevas ejecutan SQL real: reserva sin pago vacía, mensual4314, suma con puntual4400, reverso1000/completo sin duplicar puntual, donante distinto y administrador sin acceso ajeno, caso retirado invisible, identidad suspendida y anon denegados. Todos los campos coinciden con contrato existente y sólo snapshot público. Suite payments350 y gate npm test412 aprobados. Primer intento con test-name-pattern falló por cierre temprano de PGlite/hook del archivo con imports await; corrida completa sin filtro ejecutó ambas pruebas y350 aprobadas, luego gate412. No fallo de SQL ocultado.
- Aplicada sólo en desarrollo `ohqxranynackjignryep` por MCP como `20261001110332_personal_guardian_impact`; historial consultado después confirma versión/nombre. Cuerpo local/remoto MD5 `42ca8e2dbd60424e1158710eec421017` idéntico. EXECUTE anon=false/authenticated=true, stable/definer/search_path verificados. Ejecución remota sin identidad produce42501 comprobada en transacción rollback. No se exportaron identidades, aportaciones ni casos privados; no se atribuye prueba de dinero real.
- Asesores antes/después mantienen categorías/conteos27 RLS privado sin políticas,15 RPC públicas,68 RPC autenticadas y1 protección de contraseñas; ningún permiso nuevo. Docker CLI29.7.2 existe pero daemon Linux no disponible (pipe dockerDesktopLinuxEngine inexistente), pgTAP local continúa pendiente. PGlite412 no equivale a dispositivo ni aceptación instalada.
- Referencia Irlanda cierre `a3c969cd9103fd46dc5cd886999912526ce75efb` sin cambios respecto preflight. No nuevos PNG: contrato preservado, usa composición capturada del loop41. Pendiente siguiente loop entrada Impacto/presentación según estado real y Perfil activo hacia feed; después rutas/gestos/retornoStripe restantes y candidato final Codemagic autorizado. No cierre integral ni publicación atribuidos.

## Loop 58 — totales reales en Mis casos

- Referencia Irlanda inicio/cierre a3c969cd9103fd46dc5cd886999912526ce75efb. Preflight remoto confirmó inexistencia de dopmi_my_cases(integer) y ausencia de columnas target/funded/transferred en dopmi_rescue_records. Historial consultado sin replay/rename y archivo legado preservado. Changelog.md obtenido por HTTP tras formato no soportado en web; documentación oficial database/functions consultada, sin cambio de API pertinente al RPC existente.
- Nueva migración local20261001121739_owned_case_funding: dopmi_my_cases(integer), stable/SECURITY DEFINER/search_path vacío, auth.uid/actor_active y owner_id en PostgreSQL. Retorna20 casos propios por página, total exacto y registros completos propios; agrega objetivo de gastos aprobados/cerrados con snapshot, asignado/transferido netos con dopmi_expense_funding existente. Reservas no son apoyo; reversos Guardian reducen el neto. No admin bypass, metadatos editables, mutation, cobro o transferencia.
- RescueRepository.mine('case',parentnull) usa RPC en una lectura por página; otras entidades conservan consulta actual. Error denegado propaga a LiveSection, nunca se sustituye por falso vacío. Dos pruebas de transporte Dart verifican endpoint/page_number/totales/fotos/datos propios y403 sin fallback. Tres pruebas SQL reales prueban reserva0, mensual4314+puntual4400, reverso1000/completo, transferencia con evidencia, paginación23 registros, otros propietarios/staff/suspensión/anon, páginas inválidas y ACL.
- Gates: analyze limpio;13 dirigidas móvil; payments353 y npm test415 aprobados; configuración12. Docker Linux continúa no disponible (pipe dockerDesktopLinuxEngine), pgTAP local bloqueado. No gate instalado atribuido. Funciones de financiación local/remota MD5 idéntico: expense_funding0e0a1a630e6e95cf32dc2a6088da8853 y public_casesca71a751aa3fc2952fbba1863ea5d5b8. No se cambian sus cuerpos.
- Aplicada sólo DEVohqxranynackjignryep por MCP como20261001122304_owned_case_funding. Nueva definición MD5a3ef9bd271d845f693df0379611c8339 coincide con PGlite; stable/definer/search_path y EXECUTEanon=false/auth=true comprobados remotos. Ejecución como authenticated sin identidad denegada42501 dentro de transacción rollback. No consulta/exportación de expedientes privados ni prueba de dinero real.
- Asesores27 RLS privado/15 RPC anon/1 contraseñas permanecen; RPC authenticated68→69 añade aviso esperado de nueva función propietaria con definer. Su autorización interna está probada; no se declara ausencia de avisos. Correspondencia añadida a migration-history-audit.md. Sin PNG nuevo por contrato de presentación conservado del loop57; no aprobación visual integral RC. Próximo loop navegación rescatista56px/iconbox28/font9 frente a72/40/11 actual, con reflujo/touch accesibles. Codemagic final pendiente del objetivo completo.

## Paridad85 — necesidades planeadas, 1/10/2026
Local20261001123000_case_planned_needs.sql → dev20261001184124/case_planned_needs. Aplicada una vez por MCP tras comparar cuerpos previos e historial; helper/save/validate bodyMD5 coinciden con SQL local. Array sintético/legado y permiso helper verificados por SQL remoto;418PGlite locales. No replay/rename, no producción ni Auth/REST remoto acreditados.

## Paridad94 — nombre opcional, 1/10/2026
Local20261001194500_optional_case_name.sql → DEVohqxranynackjignryep20261001193350/optional_case_name. Aplicada una vez tras comparar validate previo MD5 6e816a1e05430d518938b7440c6d4f68 e historial. validate nuevo MD5 14a02a6b34f343dd0b7fe7812521b3cd coincide local, search_path vacío/securitydefiner, EXECUTEauthenticatedfalse. SQL remoto sintético comprueba que nombre vacío llega al requisito de foto y que ausencia de historia sigue rechazada. No datos privados consultados ni fixture persistida;419PGlite93 prueba submitconStorage. No Auth/REST/app/dispositivo remoto acreditado, no producción, rename/replay.


## Paridad100 — mínimo nuevo Guardian, 1/10/2026
Local20261001203000_guardian_minimum_fifty.sql → DEV20261001201058/guardian_minimum_fifty. Historial y hashes previos verificados antes de aplicar una vez; guards/hashes posteriores activation7e5cab881e0af229d7d20beaebf6a2dc/request736ad31bb7d8f109a26c61971932e2f2 y ACL sin cambio comprobados. Backend423 local99;38 Guardian móvil100/analyze. No Auth/REST/cobro remoto ni producción/repair/replay/rename.

## Paridad180 — total financiero de rescatista con Guardian, 2/10/2026
Local20261002090000_rescuer_dashboard_guardian_totals.sql → DEVohqxranynackjignryep20261002070428/rescuer_dashboard_guardian_totals. Preflight MCP proyecto ACTIVE_HEALTHY, historial anterior termina20261001201058/guardian_minimum_fifty y cuerpo dashboardMD5 6abcd69ce5daeec08d0028d8763c6bc4 coincide archivo local previo. Migración aplicada una vez después de425 pruebas backend aprobadas; sin replay/repair/rename ni acceso a producción. Cuerpo nuevo77b1594f1cdb1afb90a52ce45506b118 coincide SQL local. SECURITY DEFINER/search_path vacío, anonEXECUTEfalse/authenticatedtrue preservados. DO remoto comprueba rechazo de consulta sin actor, sin cuentas/fixtures persistidas. Asesores antes/después conservan categorías/conteos27/15/69/1; no afirmar JSON idéntico ni resolver avisos preexistentes por esta migración. Agrega neto Guardian por gasto propio usando helper vigente con reversos, no reservas ni derechos de cobro. No Auth/REST/pago/dispositivo real verificado por ese chequeo. pgTAP local sigue bloqueado: docker info confirma pipe dockerDesktopLinuxEngine ausente; DOPMI_LOCAL_CONFIG no existe. Reciente actividad de Guardian aún pendiente del siguiente ciclo.
