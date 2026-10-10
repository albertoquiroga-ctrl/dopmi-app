# Loop 740 — Publicación completa y desplazamiento

2026-10-04. Fuente productiva `e737732`; referencia `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`, reconsultada sin cambios. Sin cambios productivos en este loop.

Captura Flutter `CAPTURE_FILTER=publish-`, sesión70518 terminal0, 1/1 en12s: 14 PNG actuales (selector, fotos, cuadrícula, información, revisión, revisión social y salud, normales/grandes). Se inspeccionaron fotos normal y revisión grande. No se atribuye revisión visual a los otros doce. Source ejecutado Edge377×852 `/rescuer/publish` → Dar en adopción; captura fotos inspeccionada. Composición inicial concordante; indicaciones adicionales de privacidad de archivos reales conservadas. No comparación global automática de píxeles.

Nueva prueba en publication_frame_test: viewport320×640/texto200%, publicación real de borrador fixture, avance hasta revisión; desplazamiento táctil temporizado hasta leer inicio y final del aviso de privacidad. Botón Enviar a revisión conserva rect y acceso táctil. No se envía a revisión durante esta comprobación.

Primer intento exigía ver simultáneamente todo el aviso: hipótesis inválida, porque el texto mide420px y viewport277px. Se corrigió para comprobar lectura secuencial, sin modificar la producción para satisfacer una hipótesis de test. Un intento intermedio usó parámetro de API incorrecto, corregido a timedDragFrom.

Suite previa10135 terminal0,29/29; suite final50259 terminal0,30/30 en10s (publication_frame/case_publication/publication_choice_press). La nueva prueba no sustituye aceptación nativa, fotos reales ni equivalencia global de movimiento. Codemagic diferido hasta terminar el objetivo.

Analyzer final59385 terminal0, sin problemas31.9s. Manifiesto14PNG con SHA256 y mtime; PIL verifica integridad. No prueba aceptación visual de los catorce.
