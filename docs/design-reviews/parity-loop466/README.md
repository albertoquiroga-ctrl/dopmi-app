# Loop 466 — Historial de ciclos

Referencia: irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb. Historial y detalle financieros usan encabezado compacto; esta ruta real de recibos no tiene equivalente literal separado en el mockup.

ContributionFrame conserva los recibos, estados de prueba, paginación, consulta por propietario y conciliación. Regresar vuelve al origen o a /guardian. Capturas de historial con datos y vacío, normal y texto 200 %, generadas con el capturador existente. Captura normal revisada visualmente.

Verificación: flutter analyze sin incidencias (33.4 s); guardian_history_test.dart 12/12 (salida 0, 3 s), log dopmi-loop466-history-final2.log. Capturador pasó en el primer conjunto, cuatro estados. La primera prueba de regreso directo esperaba pumpAndSettle sobre una pantalla Guardian con consulta pendiente; se cambió a bombeo acotado para comprobar navegación sin esperar una consulta fuera del alcance. No se cambió producción para resolver esa espera.

El conjunto completo previo sigue siendo 579/579 sobre 2bba0c25345e701d8b76e2933ae5969db989218d; no acredita este nuevo cambio completo. Sin aceptación instalada ni publicación nueva. Codemagic se reserva para completar el objetivo, conforme a la instrucción del usuario.
