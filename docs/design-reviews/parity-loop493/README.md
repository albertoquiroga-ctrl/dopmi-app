# Loop493 — entrada de tarjetas

Referencia reconsultada: `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`. Cliente basado en `e2add4b`, cambios de este loop pendientes de commit al iniciar la verificación.

El mockup ejecutado en Edge a 377 × 852 sale con translateX ±420 y rotación ±18 grados durante 280 ms. La siguiente tarjeta comienza en esa posición y entra durante 250 ms con cubic-bezier(.22,1,.36,1), opacidad 1. `source-next-card.json` filtra eventos por la propia tarjeta y registra el cambio Rocky → Toby. El registro preliminar `source-motion.json` contiene eventos propagados de hijos y no debe contarse como múltiples salidas.

El cliente antes estrenaba la siguiente tarjeta en posición cero. DiscoveryCardMotion ahora admite posición inicial y anima la entrada; adopciones y tarjetas de apoyo comparten el comportamiento. Movimiento reducido conserva cambio inmediato. Durante arrastre se usan los valores actuales directamente. Favoritos siguen persistiendo sin esperar la animación.

Pruebas dirigidas finales: discovery_motion_test.dart, 9/9, handle2337 exit0, log `dopmi-loop493-motion-coordinate.log`. Incluyen inicio, punto medio y final de entrada, nuevos gestos en ambas direcciones, cancelación, movimiento reducido, curva de regreso y salida. El delta del gesto se verifica en coordenadas locales de la tarjeta rotada; los dos fallos previos de 0.0022 px provenían de comparar delta global con delta local. La tolerancia no se amplió.

Source Adoptar y Apoyar capturados y comparados con widgets actuales del loop492: composición, tipografías, tarjetas y botones. El mockup muestra ubicación simulada; el cliente conserva la selección real. Las imágenes repetidas de la fixture de Apoyar no representan los datos de producción. Modo prueba no pertenece al cliente.

Los eventos Source se ejercitaron con puntero de ratón en navegador. Esta evidencia no acredita gestos físicos Android, aceptación instalada, Stripe nativo ni paridad global. Regresión completa y analyzer iniciados en handles6893 y90804; registrar su resultado terminal antes de atribuir aprobación. Sin push ni Codemagic.

Resultado terminal: full601/601, 3m37s, handle6893 exit0; analyzer90804 exit0 limpio183.8s. Fuente c57974a77c25745a5af0436ac8ea950727c088c9.228Dart iguales raiz/scratch y hashes sin cambios al terminar. No sustituye aceptacion instalada.
