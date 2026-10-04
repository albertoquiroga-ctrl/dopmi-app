### 2026-10-04 — Evidencia: respuesta de controles

Referencia inicial a3c969cd9103fd46dc5cd886999912526ce75efb. Inspección ExpenseFrame encontró IconButtons atrás/cierre con overlay Material por defecto. Overlay transparente siguiendo lenguaje táctil de icon-button de referencia; aplicación a formulario real es inferencia de estilo compartido, no comparación directa del mismo formulario Source. Callback nullable, iconos, posiciones y bloqueo preservados.

Test57085 exit0,35/35 en8s: expense_attachment_press/review_press/field. Analyzer38922 exit0 limpio36.4s. No nueva captura de botones presionados ni prueba específica de cierre/bloqueo en este loop; no aceptación total de formulario. Gate736/790 predates este cambio puntual.

Anterior736 completó regresión global actual. Objetivo activo, aceptación visual/movimiento/nativa incompleta; sin Codemagic y dinero test-only.
