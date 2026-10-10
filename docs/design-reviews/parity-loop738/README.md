### 2026-10-04 — Evidencia: cancelación y bloqueo verificados

Referencia inicial a3c969cd9103fd46dc5cd886999912526ce75efb. Anterior737 ajustó respuesta visual de header ExpenseFrame; se añade prueba real de callbacks con320×640/text1 y2, enabled/locked.

Gesto150ms/cancel en atrás y cierre conserva rect y callbacks0. Enabled tap invoca atrás1/cierre1; tap fuera invoca cierre2. Locked callbacks null: atrás/cierre/fondo no ejecutan acciones. No excepciones/overflow. El test mide comportamiento widget, no teléfono físico ni igualdad de píxeles durante presión.

Test38705 exit0,19/19 en7s:expense_frame_controls cuatro variantes y expense_field. Analyzer85886 exit0 limpio20.5s. No código productivo cambiado, no nueva captura. Full736/790 predates estas cuatro pruebas y737. Objetivo activo, dinero test-only, sin Codemagic hasta terminar.
