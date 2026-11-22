# Expediente de reportes — plan de implementación

> **For agentic workers:** usar subagent-driven-development por tareas con dueños exclusivos. Root integra contratos, pruebas finales y operaciones remotas; ningún agente despliega o modifica usuarios reales.

**Goal:** Permitir revisar un reporte con contexto comprobable y decisiones separadas, sin abrir conversaciones ajenas.

**Architecture:** RPC aditivas de detalle, chat acotado y acción idempotente. El panel consume un contrato tipado y conserva cola/push. Las autorizaciones y objetivos se derivan en PostgreSQL.

**Tech Stack:** React/TypeScript/Vitest, Supabase/PostgreSQL y Vercel existentes. Sin Flutter ni nuevos paquetes.

**Spec:** [Diseño y alcance humano](../specs/2026-11-22-admin-report-context-design.md).

## Límites

- Fuente de análisis3e52c871; AdminPROD ee3ef773 idéntico en apps/admin. Mockf693 sin cambio de referencia.
- El titular aprobó acceso auditado sólo al hilo inequívoco de esa adopción y pareja, hasta el reporte. Perfil/caso/ambigüedad no habilitan chats.
- Adjuntos de chat: sólo marcador, sin ruta, URL o apertura Storage.
- Ninguna sanción, cierre de reporte real ni datos de negocio de QA en producción.
- No dinero, nuevos servicios, roles, SDK, campañas, consentimiento, push o builds móviles.
- Acciones con motivo5–1000 caracteres, confirmación, CAS y UUID de solicitud; lectura también de reportes resueltos, sin ampliar cutoff.

## Contrato compartido

Crear `apps/admin/src/reportModeration.ts` con tipos y adaptador RPC. `AdminApi` conserva compatibilidad de propiedades opcionales y recibe estas tres capacidades:

- `reportDetail(id:string): Promise<ReportDetail>` → `dopmi_admin_report_detail({report_id})`.
- `reportConversation(id:string, version:number, threadId:string, cursor?:ReportCursor): Promise<ReportMessages>` → `dopmi_admin_report_conversation({report_id,expected_report_version,thread_id,before_time,before_id})`.
- `reportAction(input:ReportActionInput): Promise<ReportActionResult>` → `dopmi_admin_report_action({report_id,expected_version,action,reason,request_id,expected_target_version,expected_account_updated_at,expected_suspension_action_id})`.

`ReportDetail`:
- report: ContentReport existente + version:number,reported_at:string,cutoff_basis:reported_at|legacy_created_at.
- reporter y subject: `{id,name,account_status,created_at,city,published_adoptions_count,reports_received_count}` o null si eliminado; subject incluye account_updated_at:string y active_suspension_action_id:string|null.
- content:null o `{kind:adoption|case|rescuer,id,title,status,version,description,city,region,public_photos:string[],public_url:string|null,current_snapshot:true}`. Fotos son paths aprobados; usar photoUrl para adoption y rescueFileUrl para otros tipos. Ningún archivo privado/documento.
- conversation:`{available:boolean,reason:string|null,cutoff:string,threads:Array<{id,post_id,pet_name,message_count_before_cutoff}>}`. Máximo un hilo y sólo adopción. No selector de hilos entre personas.
- capabilities: withdraw_publication/suspend_account/reactivate_account, cada una `{allowed:boolean,reason:string|null}`.
- history:Array<{id,actor_name,action,reason,created_at,previous_state,next_state}>; estados son objetos mínimos de moderación, sin chats ni datos privados.

`ReportCursor`={before_time:string,before_id:string}. `ReportMessages`={report_id,report_version,thread_id,cutoff,items:Array<{id,sender_id,sender_role:reporter|subject,body,has_attachment:boolean,created_at}>,next_cursor:ReportCursor|null}. Máximo40, newest-first estable; renderizar conversación con fechas explícitas sin asumir orden recibido distinto.

`ReportActionInput`={report_id,expected_version,action:reviewing|resolve|dismiss|withdraw_publication|suspend_account|reactivate_account,reason,request_id,expected_target_version?:number|null,expected_account_updated_at?:string|null,expected_suspension_action_id?:string|null}. `ReportActionResult`={action_id,replayed:boolean,report_version:number,target_state,account_state}. Estados son resumen mínimo; UI recarga detalle tras éxito. El mismo intento conserva UUID y payload ante respuesta incierta; no reenviar otro UUID automáticamente.

## Revisión enfocada

- Nuevo envío o cambio de reporte durante carga/paginación: invalidar páginas viejas, mostrar recarga, sin mezclar contexto.
- Reportante/responsable/publicación eliminados: ausencia explícita, sin convertirla en una cuenta activa ni habilitar acciones.
- Retiro después de suspensión: permitir archivo administrativo de adopción sin exigir owner activo, preservando todos los otros checks.
- Reintentos y decisiones simultáneas: un recibo por UUID/payload; CAS fallido deja cero efectos y no cierra reporte.
- Fotos o chat que fallan/caducan: estado explícito y recarga, sin mostrar contexto de otro expediente.

## Tarea1 — Contratos y servidor (backendagent)

Files: nueva migración creada con CLI, `tools/verification/admin-report-context-sql.test.mjs`; root agrega gate/npm una vez.

- [x] Escribir pruebas sintéticas SQL que fallen por ausencia del nuevo contrato.
- [x] Ejecutar y registrar RED real; implementar y registrar GREEN con Postgres/PGlite y suite real disponible.
- [x] Agregar versión/fecha de reporte sin inventar fecha legacy; cutoff de primera recepción etiquetado legacy, sólo reenvío cambia fecha.
- [x] Detalle derivado, cuenta/objeto/hilo limitados y auditados. ACL sólo authenticated con staff real activo; no ampliar RLS de mensajes/fotos.
- [x] Acciones y bitácora privada inmutable, sin FK que borre historial con el reportante. No auto-resolver al retirar/suspender.
- [x] Reutilizar retiro de adopción, variando sólo su guardia owner activo para archived. Casos/perfil retiro deshabilitado con razón.
- [x] Suspender noadmin/noactor/noeliminado. Reactivar sólo última suspensión de este flujo con updated_at y action_id exactos; preservar retiro y controles financieros.
- [x] Probar noadmin, admin inactivo, hilo incorrecto, post incorrecto, cutoff, cursor, reporteversion, adjuntos sin rutas, CAS, idempotencia y conservación de estados.

## Tarea2 — Expediente de interfaz (UIagent)

Files: `ReportDetail.tsx`, `ReportDetail.test.tsx`, `ModerationQueues.tsx`, `ModerationQueues.test.tsx`, estilos específicos en styles.css.

- [x] RED de Abrir expediente y contexto faltante con el componente actual.
- [x] Crear diálogo responsive con reporte/publicación/personas/conversación/historial y carga/error/ausencia explícitos.
- [x] Botones separados, capabilities del servidor y confirmación que nombre el objetivo. Sin sanción por abrir o cerrar el diálogo.
- [x] Bloquear doble click y mantener UUID/payload del intento incierto; recargar tras éxito/conflicto sin anunciar cambios fallidos.
- [x] Pruebas de foco/escape/móvil, imágenes fallidas, no selección de chats ajenos, paginación y versiones obsoletas. No HTML sin escapar.

## Tarea3 — Integración (root)

Files: `reportModeration.ts`, `reportModeration.test.ts`, `api.ts`, gates/package.json si corresponde.

- [x] Pruebas RED de mapping de frontera: IDs derivados sólo por report_id, errores propagados, cursor y payload exactos de idempotencia.
- [x] Adaptador mínimo y AdminApi; tipos compartidos congelados antes de implementación paralela.
- [x] Revisión integrada UI/UX/código/ciberseguridad independiente y ajuste de hallazgos.
- [ ] npm test y npm run build en apps/admin; npm test tools/verification, SQL real y CI por SHA. Sin repetir Flutter local al no cambiar móvil; gate CI obligatorio se conserva.

## Tarea4 — Operación y comprobación (root)

- [ ] Cotejar historia/defs/ACL remotos reales, incluido push; paquete SQL con preflight/reserva/postflight y recuperación sin replay.
- [ ] Aplicar únicamente el paquete revisado al entorno autorizado, conciliar respuesta incierta antes de otra escritura; preservar servicios.
- [ ] Publicar panel desde fuente exacta, conservar alias/env/identidad APK y verificar Vercel+UI real por separado.
- [ ] Leer el expediente real con acceso aprobado, sin acciones de sanción/resolución. Comprobar móvil/accesibilidad con datos sintéticos y reportar límites.
- [ ] Actualizar fuentes existentes sólo con estados materiales y recibos; aceptación del titular distinta de implementación/publicación.

## Evidencia intermedia

Builder check independiente: nothing important left. Adaptador: RED por módulo inexistente y GREEN41pruebas de frontera/API; instalación de dependencias existente con npm ci, sin cambios de lockfile. La ausencia inicial de Vitest fue una dependencia local faltante, no cuenta como RED. UIagent registró RED por ausencia de Abrir expediente.

Referencia técnica: [funciones y permisos Supabase](https://supabase.com/docs/guides/database/functions), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security). Las funciones definer requieren guardas de filas y EXECUTE acotado además del search_path.

## Correcciones integradas de la revisión

Historial desanida sólo estados/versiones seguros de account/target; no pierde la
sanción real ni vuelca JSON arbitrario. Chat conserva ordenSQL, sin truncar microsegundos.
Borrador privado rearchivado no se devuelve como contenido público: archived produce
contentnull; el hilo histórico se valida contra report.target_id y puede consultarse
sin exponer el borrador. Se rechazaron hilo futuro y reactivación desde otro reporte.
Nuevos negativos RED→GREEN, última fuente SQL29521B/57f52fc1…83833f,25PASSsinSKIP
con PGreal; UI37PASS. La publicación remota sigue sin ejecutarse.
