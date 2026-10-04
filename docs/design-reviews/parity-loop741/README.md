# Loop 741 — Movimiento medido contra la referencia ejecutada

2026-10-04. Fuente `4f49d80`; Source `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`, reconsultada al inicio y cierre. Sin cambios productivos.

Suite actual52055 terminal0,55/55 en10s: route_motion, onboarding_motion, discovery_motion, guardian_promotion, case_gallery_lifecycle, support_rail_gesture, owned_case_card_gesture y reference_switch. Cubre navegación inmediata/regreso, entrada450, swipe280/retorno250, interrupción, carrusel por distancia, galerías, desplazamiento frente a toque y reducción de movimiento. No sustituye percepción/render nativo ni otros diálogos.

Source ejecutado Edge377×852 `/onboarding/donor`, clic Continuar real. Se obtiene Web Animation del nuevo `.onb-gate-body`, se pausa y fija currentTime para medir frames reproducibles. Duración450ms, keyframesopacity0→1/translateY10→0, easingcubic-bezier(.22,1,.36,1). A225ms: opacity0.961383 y desplazamientoY0.386175px; a0:0/10px, a450:1/none. Esto prueba frames calculados del navegador, no cronometraje de vídeo/pantalla.

La prueba Flutter de entrada ahora contrasta también esos valores independientes del runtime Source, con tolerancia0.0005 para opacity y0.005px para desplazamiento por interpolación entre motores. Prueba final onboarding_motion: terminal0,9/9 en1s. El cálculo previo por Curves se conserva; ya no es la única evidencia intermedia. No se ejecutó analyzer nuevo en este loop de test; analyzer740 antecede esta adición.

Las reglas CSS históricas de acordeón no se reinterpretan como animaciones activas: loop503 midió su ausencia. Los diálogos de contacto/filtro tienen AnimationStyle.noAnimation; panel de ubicación adicional para permisos reales no tiene contraparte idéntica encontrada en Source. No se cambia ese comportamiento por una búsqueda incompleta.

Objetivo global activo; sin Codemagic, dinero test-only.
