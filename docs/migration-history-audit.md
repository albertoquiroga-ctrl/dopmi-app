# Auditoría pendiente del historial de migraciones

Corte: 25 de septiembre de 2026. Comparación de archivos del repositorio en `8e6663d` con las versiones remotas **registradas en `docs/progress.md`**. No es una consulta nueva de `supabase_migrations.schema_migrations` ni prueba de que el SQL remoto sea diferente.

Hay 26 archivos locales; en 18 nombres, el timestamp del archivo difiere del timestamp registrado para su aplicación remota. Las primeras migraciones también tienen antecedentes de aplicación por SQL Editor sin historial CLI. El próximo agente debe resolver la correspondencia antes de cualquier `db push` o reparación del historial. **No renombrar ni ejecutar de nuevo migraciones para hacer coincidir números.**

| Nombre | Versión del archivo en Git | Versión remota documentada |
| --- | --- | --- |
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
