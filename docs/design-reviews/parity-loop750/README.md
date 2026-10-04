# Loop750 — Apertura y descarte de preguntas

2026-10-04. Base0b564c3, Sourceirlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb sin cambios inicio/cierre.

Source ejecutado Edge377x852/help: Adoptar, primera pregunta abierta muestra una respuesta; tocar segunda sustituye la primera (una sola faq-row.open); tocar segunda de nuevo deja0 abiertas. Tocar Adoptar seleccionado elimina preguntas y muestra «Elige un tema para ver las respuestas.». Browser propio cerrado. Contenido Source es distinto del real en algunas preguntas; se compara mecanismo y no se copian afirmaciones simuladas.

Dos pruebas nuevas ejercitan la ruta real Flutter a320x640, escalas1/2: mantener150ms y cancelar no abre respuesta; tap abre en primerpump; segunda cierra primera; segundo tap cierra; tema seleccionado vuelve al estado inicial. Repositorio de identidad fake, no servidor ni Android físico. No cambios de producción.

16475 falló localización de fila no construida;94584 falló retorno hacia tema arriba;87160 pasó normal y falló hint todavía fuera de viewport ampliado. Se añade scroll en dirección correcta y localización visible del hint, conservando todas las assertions. Final80623 exit0:4/4 en4s (dos nuevas, dos existentes footer). No se atribuye aceptación a intentos fallidos.

Full748/801 anterior a parche749 y estas dos pruebas; no full803 ejecutado. Capturas749 actuales para composición FAQ; APK748 anterior749. Apertura manual/nativo/global siguen pendientes; sin Codemagic ni dinero real.
