# Calendario Stripe → validación → historial propietario

Ejecutar desde `tools/verification`:

```text
node guardian-calendar-readonly.mjs <archivo-local-clave-test> <fixture-json>
```

El archivo de clave contiene `STRIPE_SECRET_KEY_H4_TEST`; no pasar su valor en argumentos ni incorporarlo al repositorio. El JSON identifica `subscription`, `customer` y `price` de una suscripción técnica test, con ancla 31, `send_invoice` y pausa `keep_as_draft`.

El transporte permite exclusivamente GET a Stripe. El programa lee las facturas completas, excluye el alta `subscription_create`, aplica `guardianRenewalCandidate` sin modificar las respuestas y carga todas las migraciones en PGlite efímero. Crea una identidad y registro local sintéticos, sin liquidaciones ni transferencias. Las referencias `SYNTHETICCalendarSeed` y el calendario inicial son preparación de fixture, no evidencia de pago inicial ni de elegibilidad para crear una suscripción.

Para cada renovación, ejecuta la RPC real de preparación dos veces, comprueba el mismo ciclo y la decisión de omitir, y consulta el historial bajo el rol propietario. Verifica que los límites de período de Stripe se conservan exactamente y que no se presenta un pago confirmado. `fresh:false` evita atribuir elegibilidad de cobro a facturas históricas; no ejecuta el servicio completo de cobro/anulación.

Ejecución del 25/9/2026: dos renovaciones reales aceptadas, `in_1UJhNA2ZjyMOQ0uLoTPtIK17` (28/2→31/3/2027, 14 UTC) e `in_1UJhNF2ZjyMOQ0uLeLZ4LlKx` (31/3→30/4/2027, 14 UTC), ambas draft/paid0. RPC e historial conservaron los períodos y el reprocesamiento reutilizó el ciclo. Cero escrituras remotas.

**Límite:** es integración de lecturas Stripe con código y SQL reales en una base preparada. No acredita alta en día 31, cobro mensual, año bisiesto, Supabase remoto ni visualización móvil. H5 permanece abierto.
