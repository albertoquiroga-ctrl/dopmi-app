# Stripe Connect — activación segura en modo prueba

Este procedimiento activa el hito de aportaciones sin aceptar dinero real. El código rechaza claves de producción y objetos de Stripe con `livemode=true`.

## Requisitos

- Proyecto Supabase de Dopmi con las migraciones actuales aplicadas.
- Cuenta Stripe en modo prueba.
- Stripe Connect habilitado para México.
- CLI de Supabase autenticada por el responsable del proyecto.

No se deben copiar secretos en Git, en el cliente Flutter, en capturas ni en conversaciones. Se cargan directamente en Supabase.

## Secretos de las funciones

Configura en Supabase:

- `STRIPE_SECRET_KEY_H4_TEST`: clave restringida de prueba (`rk_test_…`) aislada para este hito. Las funciones la prefieren sobre `STRIPE_SECRET_KEY`, que se conserva intacta como respaldo temporal.
- `STRIPE_WEBHOOK_SECRET`: secreto del endpoint de webhook (`whsec_…`).
- `DOPMI_WORKER_SECRET`: valor aleatorio largo usado exclusivamente para invocar el trabajador.

Las variables `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` son provistas por el entorno de Edge Functions.

## Funciones a desplegar

- `payments`: crea/reanuda Checkout y onboarding Connect autenticados.
- `stripe-webhook`: valida la firma sobre el cuerpo sin modificar y registra cada evento una sola vez.
- `payment-worker`: procesa transferencias y devoluciones con arrendamiento e idempotencia.
- `payment-return`: devuelve al usuario a Dopmi sin marcar pagos como confirmados.

El endpoint de Stripe debe apuntar a:

`https://<project-ref>.supabase.co/functions/v1/stripe-webhook`

Eventos mínimos:

- `checkout.session.completed`
- `checkout.session.expired`
- `payment_intent.succeeded`
- `account.updated`
- `charge.dispute.created`
- `charge.refunded`

## Trabajador programado

Invoca periódicamente `payment-worker` con `POST` y el encabezado `Authorization: Bearer <DOPMI_WORKER_SECRET>`. El secreto debe vivir en el gestor de secretos del programador, nunca en SQL público ni en una app cliente. Un intervalo de un minuto es suficiente para la prueba interna.

## Aceptación interna

1. Un rescatista aprobado completa Connect en modo prueba y Dopmi muestra `ready=true` solo después de que Stripe habilite transferencias y depósitos.
2. Un donante abre Checkout desde un gasto aprobado y paga con una tarjeta de prueba de Stripe.
3. El webhook confirma el pago; la URL de retorno por sí sola no cambia el estado.
4. El trabajador crea una sola transferencia aunque se reintente la misma operación.
5. El historial distingue pago, asignación, transferencia y depósito.
6. Un evento repetido, una respuesta perdida o un objeto `livemode=true` no genera movimientos duplicados.

Antes de habilitar producción se requiere una revisión separada de negocio, cumplimiento, comisiones, devoluciones, disputas, privacidad y conciliación. Este hito no autoriza dinero real.
