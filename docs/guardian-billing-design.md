# Guardián — contrato de cobro de prueba

Decisión confirmada por el titular el 23 de septiembre de 2026: cobrar al activar y después cada mes, solamente si puede asignarse completo el neto a gastos aprobados; sin saldo comunitario ni deuda por meses omitidos.

## Experiencia y estados

- Antes de confirmar: mostrar importe bruto mensual en MXN ($50/$200/$500 o personalizado), primera fecha de cobro (hoy), fecha aproximada siguiente, comisión y costo de Stripe estimado como tal, posibilidad de cambiar monto y cancelar. Exigir confirmación explícita; no tomar como autorización la selección de modo donante.
- Sin capacidad inicial suficiente: no abrir Checkout ni crear suscripción; mostrar que Guardián aún no se pudo activar, sin cargo. Permitir reintentar.
- Con capacidad: el servidor crea una reserva idempotente y un Checkout de pago único inicial en modo de prueba. Una sesión abandonada o vencida libera la reserva; un pago inicial sin confirmar no se presenta como aportación confirmada. Tras conciliar el primer pago, crea el calendario mensual en Stripe Billing con facturas futuras retenidas en borrador; nunca crea una suscripción de cobro automático y después intenta pausarla.
- En renovaciones: cada factura debe estar asociada a un ciclo único; comprobar y reservar capacidad antes de que Stripe intente cobrarla. Si no hay capacidad, impedir que esa factura se cobre y registrar el mes como omitido, sin deuda ni saldo a favor. Nunca usar la respuesta HTTP del webhook como única garantía de que Stripe omitirá un cobro: Stripe puede finalizar facturas aunque haya fallado la entrega de eventos.
- Si se cobró pero la capacidad dejó de estar disponible o el neto real no cabe, devolver el importe completo por el mismo medio de pago. No transferir ni contar como financiado hasta conciliar el cargo y la asignación. No asignar parcialmente un ciclo.
- Cambio de monto: informar el nuevo importe, aplicar a ciclos futuros sin prorratear el vigente. Cancelación: detener renovaciones futuras y mostrar el estado de los pagos pasados; no revertir automáticamente un pago ya entregado.

## Condiciones técnicas antes de activar

1. Una clave estable por usuario y ciclo, vinculada con `subscription_id`, `invoice_id`, `payment_intent_id`, `charge_id` y reserva, con unicidad en PostgreSQL. Sólo el servidor usa `service_role`; el cliente ve exclusivamente su historial mediante RLS.
2. Primera reserva antes de crear Checkout; reconciliar abandono, expiración y devolución. El límite superior retenido actualmente es bruto menos 2 %; al confirmar se conoce la comisión real de Stripe y se debe reducir la reserva y reasignar exactamente el neto real de forma atómica, o devolver todo.
3. Para cada renovación, usar una suscripción `send_invoice` con `pause_collection.behavior=keep_as_draft` antes de su primer ciclo. Validar que la factura está en `draft`, `auto_advance=false`, nunca intentada, con cliente, importe y suscripción correctos antes de reservar y cobrar. Probar en sandbox si puede finalizarse y pagarse una factura individual sin reactivar el cobro automático de las siguientes; si Stripe no lo permite, rediseñar antes de habilitar Guardián. No confiar sólo en `invoice.upcoming`, `invoice.created`, una pausa tardía o un webhook que responde 200. Cubrir factura inicial, reintentos, entrega duplicada o desordenada, bloqueo de concurrencia, cambio de monto, cancelación y conciliación tras pérdida de respuesta.
4. Transferir sólo el neto confirmado a las cuentas Connect correctas con claves idempotentes y evidencia persistida. Conciliar devoluciones y reversiones con los mismos criterios del hito 4.
5. Mantener `sk_test_`/`rk_test_`; no crear suscripciones en producción ni habilitar Stripe Tax automáticamente antes de resolver el tratamiento fiscal aplicable.

La reserva SQL existente **no realiza cobros**. Hasta cumplir esas condiciones, Guardián no se expone como opción activa en la app.

El validador puro `supabase/functions/_shared/guardian-billing.mjs` implementa el rechazo preventivo de facturas inseguras y genera una clave de ciclo determinista. Aún no se conecta a un endpoint de cobro. Stripe documenta que la factura inicial de una suscripción de cobro automático se finaliza de inmediato y que una renovación puede finalizarse pese a fallas prolongadas del webhook; por eso el control no puede depender de pausar una suscripción después de crearla. Véase [facturación de suscripciones](https://docs.stripe.com/billing/invoices/subscription) y [pausar cobros](https://docs.stripe.com/billing/subscriptions/pause-payment).

## Experimento aislado en Stripe de prueba (24 de septiembre de 2026)

- En el entorno de prueba de DopMi creé el reloj `clock_1UJ06k2ZjyMOQ0uLcb0LUBio`, un cliente de prueba sin medio de pago y la suscripción `sub_1UJ08t2ZjyMOQ0uLcijjnhDr` con `collection_method=send_invoice` y un día de prueba. Antes de su primer ciclo de pago, Stripe confirmó `pause_collection={behavior:keep_as_draft,resumes_at:null}`.
- Cancelé inmediatamente esa suscripción: Stripe confirmó `status=canceled`. No hubo intento de cobro a una persona ni se usó modo real.
- La conexión API disponible no expone adelantar el reloj de prueba; por ello **no se verificó todavía** si Stripe permite finalizar y cobrar individualmente una factura mensual mientras mantiene pausada la suscripción. El experimento tampoco prueba el comportamiento de una factura futura si el servidor deja de responder. Esta prueba sigue siendo un requisito antes de habilitar el cobro.
