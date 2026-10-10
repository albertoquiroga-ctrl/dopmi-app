# Métodos tras cancelación y conciliación — loop440

Cinco capturas Flutter fixture de la app actual, 377×852 y texto 100%/200%.
Referencia viva reconsultada: a3c969cd9103fd46dc5cd886999912526ce75efb.
No hay contraste pixel con Source ni prueba SDK/Stripe/teléfono en este corte.

Canceled presenta acciones reales independientes; waiting conserva tarjetas y
explica conciliación. Footer grande confirma scroll hasta Actualizar estado.
Capturer filtrado pasa 1 test con cinco estados y assertions de acciones,
mensaje, cero submits y ausencia de layout exceptions (65092/79ef4c).

La primera corrida capturó cuatro estados pero sus assertions estaban en una
rama incorrecta; fueron trasladadas antes de generar estas capturas finales.
Producción no modificada; analyzer437 es la última verificación móvil de código.
