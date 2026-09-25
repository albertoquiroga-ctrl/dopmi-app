# Auditoría del historial de migraciones

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

## Procedimiento de comprobación

1. Confirmar el proyecto `ohqxranynackjignryep`, la rama de continuación y acceso de solo lectura. Consultar la ayuda de la CLI instalada antes de utilizar sus comandos.
2. Leer las versiones/nombres/SQL disponibles del historial remoto. Contrastar con las 26 migraciones locales, `progress.md` y el esquema real: tablas, funciones, definiciones, restricciones, índices, RLS y grants. Que dos nombres se parezcan no acredita que ejecutaron el mismo SQL.
3. Distinguir SQL equivalente con identificador distinto, migración aplicada fuera de CLI y diferencia real de esquema. Para las primeras migraciones, no asumir que sigue faltando historial solo porque así era el 13 de septiembre.
4. Preparar un plan explícito por migración. Si hace falta `migration repair`, usarlo solo después de demostrar qué SQL está aplicado y conservar el registro original; no usarlo para ocultar diferencias. Una reparación de historial no ejecuta el SQL faltante.
5. Si se necesita corregir el esquema, crear una migración nueva y probarla primero localmente/CI. No editar el contenido histórico ya desplegado ni resetear el proyecto compartido.
6. Registrar fecha, proyecto, versión local/remota, resultado de comparación, acción y evidencia sin secretos. Actualizar este documento con la tabla de resultados.

Este traspaso no ejecutó reparación ni cambio de esquema. La discrepancia se deja como trabajo técnico de continuidad, con evidencia suficiente para investigarla sin repetir migraciones a ciegas.
