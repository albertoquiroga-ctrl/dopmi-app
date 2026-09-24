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

El validador puro `supabase/functions/_shared/guardian-billing.mjs` implementa el rechazo preventivo de facturas inseguras, verifica de nuevo la identidad y el importe después de finalizar una factura individual y genera una clave de ciclo determinista. Aún no se conecta a un endpoint de cobro. Stripe documenta que la factura inicial de una suscripción de cobro automático se finaliza de inmediato y que una renovación puede finalizarse pese a fallas prolongadas del webhook; por eso el control no puede depender de pausar una suscripción después de crearla. Véase [facturación de suscripciones](https://docs.stripe.com/billing/invoices/subscription) y [pausar cobros](https://docs.stripe.com/billing/subscriptions/pause-payment).

## Experimento aislado en Stripe de prueba (24 de septiembre de 2026)

- En el entorno de prueba de DopMi creé el reloj `clock_1UJ06k2ZjyMOQ0uLcb0LUBio`, un cliente de prueba sin medio de pago y la suscripción `sub_1UJ08t2ZjyMOQ0uLcijjnhDr` con `collection_method=send_invoice` y un día de prueba. Antes de su primer ciclo de pago, Stripe confirmó `pause_collection={behavior:keep_as_draft,resumes_at:null}`.
- Cancelé inmediatamente esa suscripción: Stripe confirmó `status=canceled`. No hubo intento de cobro a una persona ni se usó modo real.
- La conexión API disponible no expone adelantar el reloj de prueba ni pagar una factura. Tras preparar una segunda suscripción, la persona titular adelantó el reloj manualmente al 25 de septiembre de 2026, 01:05 UTC.
- La suscripción `sub_1UJ0mY2ZjyMOQ0uLww3GOJag` produjo la factura de renovación `in_1UJ0vp2ZjyMOQ0uLQmm5EaZG` por 5000 centavos MXN. Stripe confirmó `status=draft`, `auto_advance=false`, `attempted=false`, `amount_paid=0`, `billing_reason=subscription_cycle` y la suscripción `active`, con `pause_collection.behavior=keep_as_draft` y sin `resumes_at`.
- Stripe permitió finalizar **únicamente esa factura**, con `auto_advance=false`; quedó `open`, `attempted=false`. La suscripción siguió pausada. Después anulé esa factura (`status=void`, `amount_paid=0`) y cancelé la suscripción (`status=canceled`). No hubo cargo.
- **Pago individual y renovación posterior verificados por API el 24 de septiembre de 2026:** la tercera suscripción aislada `sub_1UJ1iv2ZjyMOQ0uLKEGSvbck` (metadata `guardian_individual_invoice_payment`) tiene una factura de 5000 centavos MXN `in_1UJ1pT2ZjyMOQ0uL81pzKuhJ` con `status=paid`, `amount_paid=5000`, `amount_remaining=0` y `attempt_count=1`. Su InvoicePayment está pagado y vinculado al PaymentIntent de prueba `pi_3UJ1sM2ZjyMOQ0uL0gxWjBrO`; `livemode=false`.
- Después del avance manual del reloj a octubre, la factura siguiente `in_1UJ1zH2ZjyMOQ0uLHEQ3y9og` permanece `draft`, `auto_advance=false`, `attempted=false`, `attempt_count=0`, `amount_paid=0` y `next_payment_attempt=null`. Ambas facturas pertenecen a la misma suscripción. La suscripción aislada está `canceled` y conserva `pause_collection.behavior=keep_as_draft`, sin reanudación programada. Esta verificación recupera la prueba ya realizada; no crea otro cobro.
- **Pendiente:** integrar este mecanismo con reservas y asignación del neto real, devolución, autorización del usuario, y probar falla/reintento del servidor y conciliación tras pérdida de respuesta. El experimento de Stripe por sí solo no acredita el flujo completo de Guardián ni habilita dinero real.

## Lectura de evidencia de pago para el servidor

`readGuardianPaidEvidence` recibe una instancia StripeClient configurada con API `2026-08-26.dahlia` y `lookupSubscription`, que debe consultar `dopmi_guardian_subscription_server` con operación `lookup` usando exclusivamente `service_role`. Solo el ID de factura entra a la lectura; propietario, precio e importe esperado proceden del registro privado. Obtiene la factura con `expand: [payments]` y el PaymentIntent con `expand: [latest_charge.balance_transaction]`. Listas incompletas o varios pagos exitosos requieren revisión; nunca se ignora una página para calcular el neto.

La salida acredita identidad e importes del pago consultado, no autoriza asignaciones. La liquidación descrita abajo bloquea y verifica el enlace factura/ciclo y su reserva en PostgreSQL. Cancelar una suscripción no impide consultar evidencia de un pago pasado, pero sigue impidiendo preparar otro cobro. El lector se conecta al procesador mediante `guardianService`; por sí solo no crea operaciones Stripe.

## Liquidación y trabajos de pagos confirmados

La RPC exclusiva de servidor `dopmi_guardian_settlement_server` exige una factura ya vinculada a un ciclo y verifica donante, suscripción, importes y unicidad de los identificadores. Bajo bloqueos de rescatistas en orden, convierte toda la reserva en asignaciones del neto real, o registra devolución completa. El costo Stripe lo absorbe Dopmi al devolver todo; la comisión de plataforma queda en cero. Los importes públicos y las reservas individuales incluyen las asignaciones Guardián.

`guardianService` obtiene evidencia de Stripe, liquida y procesa una cola privada de transferencias/devoluciones. Los intentos usan arrendamiento de cinco minutos, máximo ocho intentos y ventana inferior a 23 horas desde el primero. Un resultado incierto después de esa ventana requiere revisión. La devolución consulta primero las existentes y no marca éxito mientras esté pendiente. Una transferencia requiere identidad de cargo, ausencia de disputa/devolución, destino persistido y cuenta habilitada.

El trabajador se integra al cron existente solo con `DOPMI_GUARDIAN_WORKER_ENABLED=true`, clave H4 de prueba y migración aplicada. La acción autenticada `reprocess_guardian_invoice` acepta un ID de factura previamente vinculada. Ese procesador de facturas no paga facturas ni activa suscripciones. El primer Checkout tiene su propio recorrido, descrito abajo. Faltan el calendario y cobro mensual condicionado, la reversión de transferencias ante devoluciones posteriores y la aceptación remota antes de habilitarlo.


## Primer pago: alta privada y Checkout

`guardianActivationService` y `dopmi_guardian_activation_server` preparan el primer pago con consentimiento versionado `guardian-2026-09-24`. El servidor identifica al donante; nunca se toma de metadata de un evento o de un parámetro de retorno. La reserva completa precede a cualquier llamada Stripe. Sin capacidad se registra `no_capacity` y no se crea Checkout ni suscripción.

La petición de Checkout es un pago único MXN, guarda el medio de pago para uso posterior con `setup_future_usage=off_session`, conserva la misma clave de idempotencia y vence a los 35 minutos. La reserva dura 40 minutos para dar margen a la conciliación. Dos dispositivos no pueden mantener dos altas pendientes del mismo donante; una concesión de ejecución de dos minutos, ocho intentos y una ventana máxima de 23 horas acotan los reintentos. Las respuestas perdidas se recuperan con la misma petición. Un intento incierto fuera de esa ventana queda en `attention`; nunca se abre otro cobro para resolverlo.

La sesión persistida vincula el pago a su reserva. Al confirmar se vuelve a consultar Checkout, PaymentIntent, cargo y comisión; se validan identidad, modo prueba, importes, cliente y medio de pago. `settle_initial` comparte la liquidación atómica y los trabajos de transferencia/devolución de las renovaciones, sin inventar una factura o suscripción para el pago inicial. Expiración o fallo asíncrono libera la reserva; cualquier pago tardío se devuelve completo, incluso si ya existe otra solicitud de alta.

El webhook firmado atiende sesiones conocidas de Guardián y el trabajador recupera altas pendientes bajo `DOPMI_GUARDIAN_WORKER_ENABLED`. El código no expone todavía un endpoint de alta para la app. Un pago inicial asignado queda en `funded_pending_schedule` hasta que el servicio de calendario descrito abajo verifica y registra Billing; entonces devuelve `active`. Antes de exponerlo faltan implementar cobro condicionado/cambio/cancelación y completar la aceptación de Stripe. Stripe Tax sigue desactivado conforme al alcance de prueba existente.


## Calendario mensual protegido después del primer pago

`guardianScheduleService` y `dopmi_guardian_schedule_server` sólo preparan Billing cuando el primer pago quedó asignado completo, todas sus transferencias terminaron y la cuenta sigue habilitada. Se vuelven a consultar cargo, cliente y medio de pago en Stripe. El cargo inicial no puede estar disputado o reembolsado y el medio debe seguir perteneciendo al cliente guardado.

Se crea un precio mensual en MXN y una suscripción `send_invoice`, con `proration_behavior=none`, sin factura inicial y con `cancel_at_period_end=true`. El ancla conserva día/hora UTC del cargo inicial mediante `billing_cycle_anchor_config`; se contemplan meses cortos y años bisiestos. Sólo una actualización conjunta que establece `pause_collection.behavior=keep_as_draft` y retira la cancelación puede dejarla preparada para futuras facturas. Se vuelve a leer la suscripción antes de registrar la relación en PostgreSQL. Si el servidor pierde conectividad antes de esa actualización, permanece la cancelación de protección; no se abre una segunda suscripción para recuperarse. Una pausa preexistente inesperada, especialmente con `resumes_at`, no se sobrescribe.

Precio y suscripción se guardan por etapas con claves estables, concesión de ejecución de cinco minutos, ocho intentos y ventana de reintento inferior a 23 horas. La creación empieza con más de 48 horas hasta la primera renovación; fechas ya próximas o antiguas requieren revisión. Webhooks firmados y lectura periódica sincronizan cancelaciones y detectan configuraciones alteradas. Las cancelaciones no borran pagos pasados.

Este paso está protegido adicionalmente por `DOPMI_GUARDIAN_SCHEDULE_ENABLED=true`, junto con el flag del trabajador y la clave de prueba. Todavía no paga facturas, no habilita un endpoint de alta en la app y no implementa solicitudes de cambio/cancelación desde el cliente. La creación protegida se comprobó aisladamente en Stripe test como se describe abajo; falta aceptar el recorrido integrado antes de habilitarlo. Las pruebas locales usan Stripe simulado; la prueba de concurrencia usa PostgreSQL real en CI y aprobó para `0f95d8f`. Stripe Tax continúa desactivado en este alcance.

Referencias: [configurar el ciclo y evitar la factura prorrateada inicial](https://docs.stripe.com/billing/subscriptions/billing-cycle), [cancelación al final del período](https://docs.stripe.com/billing/subscriptions/cancel) y [actualizar la pausa de cobro](https://docs.stripe.com/api/subscriptions/update).


### Comprobación aislada de creación y pausa — 24 de septiembre de 2026

En el entorno de prueba de DopMi, un cliente sintético sin medio de pago (`cus_VJr55MmEsLOYzo`) y el precio mensual de $50 MXN `price_1UJDMU2ZjyMOQ0uLOkG8OTrI` permitieron crear `sub_1UJDNX2ZjyMOQ0uLrGrkDiSp` con la misma configuración de ancla, sin prorrateo y con cancelación al final del período. Stripe devolvió `active`, `livemode=false`, `latest_invoice=null` y fin de período `1792850945` (24 de octubre de 2026, 14:09:05 UTC), correspondiente al ancla solicitada.

La actualización conjunta `pause_collection.behavior=keep_as_draft` y `cancel_at_period_end=false` conservó la fecha y la ausencia de factura. Una lectura independiente confirmó `resumes_at=null`, `cancel_at=null` y la pausa. Se canceló inmediatamente con `invoice_now=false` y `prorate=false`; respuesta final `canceled`, `latest_invoice=null`. No se creó factura ni se hizo un cargo. El precio sintético permanece activo: Stripe rechazó archivarlo porque es el precio predeterminado de su producto; no tiene una suscripción activa de esta prueba.

El primer intento con otro cliente sintético sin correo fue rechazado por Stripe antes de crear una suscripción. `send_invoice` exige correo; el flujo inicial usa Checkout con `customer_creation=always`, que recoge el correo del cliente. La aceptación integrada deberá comprobar también ese dato persistido y su ausencia/modificación. La prueba válida usó `guardian-calendar-test@example.invalid`.

Límites: llamadas aisladas del conector con especificación `2026-08-26.preview`, sin PaymentMethod, sin ejecutar el servicio Guardián desplegado ni adelantar un reloj. El runtime fija `2026-08-26.dahlia`. Esto verifica el mecanismo de protección/pausa; no acredita el alta integral, la facturación futura ni un cobro mensual. La prueba anterior de factura individual pagada y siguiente factura en borrador sigue siendo evidencia separada.
