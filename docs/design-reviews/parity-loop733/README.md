### 2026-10-04 — Movimiento renderizado del interruptor

Referencia inicio a3c969cd9103fd46dc5cd886999912526ce75efb; componente productivo00d553c ya usa CSS180ms/ease/13px. Nueva prueba mide DecoratedBox de la perilla debajo del Transform, no el origen externo del AnimatedContainer.

Final68219 exit0,11/11 en3s: dos pruebas normal/reduced y payment_history_screen. A90ms desplazamiento normal13*Curves.ease(.5)=10.425899px, tolerancia.02; final13 tolerancia.001; reduced13 inmediato. Gesto cancelado conserva posición y callback0; tap llama una vez. Target48×48 medido. Verifica render Flutter, no teléfono físico.

Inicial23162 falló por medir contenedor exterior, ambos deltas0; corregido finder al hijo visible. Analyzer66171 limpio24.4s anterior a ese cambio de finder. No código productivo cambiado. Objetivo activo, aceptación global pendiente y sin Codemagic. Anterior732 avanzó implementación del interruptor.
