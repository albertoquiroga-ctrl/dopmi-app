# Stripe Connect — activación segura en modo prueba

Este procedimiento activa el hito de aportaciones sin aceptar dinero real. El código rechaza claves de producción y objetos de Stripe con `livemode=true`.

Esta guía conserva la operación H4. Para H5, seguir también [guardian-acceptance.md](guardian-acceptance.md) y [codex-handoff.md](codex-handoff.md): se añadió `guardian-client`, el webhook de prueba tiene 21 eventos según el último registro y el trabajador incluye Guardián. La lista mínima H4 de abajo no debe reemplazar ni reducir la configuración vigente del webhook. Los pasos de migración/despliegue son procedimientos históricos: comprobar qué está aplicado antes de repetirlos.

## Requisitos

- Proyecto Supabase de Dopmi con las migraciones actuales aplicadas.
- Cuenta Stripe en modo prueba.
- Stripe Connect habilitado para México.
- CLI de Supabase autenticada por el responsable del proyecto.

No se deben copiar secretos en Git, en el cliente Flutter, en capturas ni en conversaciones. Se cargan directamente en Supabase.

## Secretos de las funciones

Configura en Supabase:

- `STRIPE_SECRET_KEY_H4_TEST`: clave restringida de prueba (`rk_test_…`) aislada para este hito. Las funciones la prefieren sobre `STRIPE_SECRET_KEY`, que se conserva intacta como respaldo temporal.
- `STRIPE_WEBHOOK_SECRET_H4_TEST`: secreto del endpoint de webhook de prueba (`whsec_…`). Las funciones lo prefieren sobre `STRIPE_WEBHOOK_SECRET`, que se conserva intacto como respaldo temporal.
- `DOPMI_WORKER_SECRET`: valor aleatorio largo usado exclusivamente para invocar el trabajador.

Las variables `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` son provistas por el entorno de Edge Functions.

## Funciones a desplegar

- `payments`: crea/reanuda Checkout y onboarding Connect autenticados.
- `stripe-webhook`: valida la firma, registra y reclama el evento, concilia el cargo y completa sus transferencias/devoluciones antes de responder éxito.
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

Para usar Supabase Cron, guarda **el mismo** valor de `DOPMI_WORKER_SECRET` en Supabase Vault con el nombre `dopmi_payment_worker_token` desde el panel privado del proyecto; no generes otro valor sin actualizar también la Edge Function. Después ejecuta [`docs/payment-worker-schedule.sql`](payment-worker-schedule.sql) en el SQL editor. El trabajo obtiene el token de Vault al ejecutarse; no queda en el texto de `cron.job`. Comprueba en Cron que el trabajo está activo y que los intentos periódicos devuelven HTTP 200. Un trabajo programado sin ejecuciones HTTP exitosas no cuenta como respaldo activo. Evita crear un segundo programador si ya existe uno externo.

## Aceptación interna

1. Un rescatista aprobado completa Connect en modo prueba y Dopmi muestra `ready=true` solo después de que Stripe habilite transferencias y depósitos.
2. Un donante abre Checkout desde un gasto aprobado y paga con una tarjeta de prueba de Stripe.
3. El webhook confirma el pago; la URL de retorno por sí sola no cambia el estado.
4. El webhook crea una sola transferencia aunque lleguen ambos eventos simultáneamente. El trabajador conserva el respaldo para reintentos/conciliación.
5. El historial distingue pago, asignación, transferencia y depósito.
6. Un evento repetido, una respuesta perdida o un objeto `livemode=true` no genera movimientos duplicados.

Antes de habilitar producción se requiere una revisión separada de negocio, cumplimiento, comisiones, devoluciones, disputas, privacidad y conciliación. Este hito no autoriza dinero real.

## Corrección de entrega — orden de despliegue

1. Aplicar primero `supabase/migrations/202609230001_payment_delivery.sql` y registrar esa versión en el historial de migraciones del proyecto. Es aditiva: conserva aportaciones, cuentas conectadas y trabajos existentes.
2. Desplegar juntas `payments`, `stripe-webhook` y `payment-worker`. No desplegar las funciones nuevas sin sus RPC; las funciones anteriores siguen siendo compatibles durante la aplicación de la migración.
3. Mantener el trabajador programado como respaldo; comprobar su ejecución, no asumir que está habilitado por tener la función desplegada.
4. Verificar una transferencia de prueba y repetir los eventos. Deben conservarse el mismo `stripe_transfer_id` y el mismo acumulado, sin otro Checkout ni cargo.
5. Publicar una nueva compilación móvil para mostrar acumulados reales y errores específicos de configuración. El backend corrige las transferencias independientemente de esa compilación.

El modelo es **cobros y transferencias separados**: `transfer_data=null` en el PaymentIntent es esperado. La transferencia usa el cargo original en `source_transaction`, la cuenta conectada guardada al abrir Checkout y `dopmi-transfer-<donation_id>` como clave de idempotencia.

El evento queda pendiente ante comisión aún no disponible, otra ejecución en curso o un fallo necesario de Stripe/base de datos. El webhook responde `503`, no `200 {received:true}`. Los trabajos tienen arrendamiento, reintento con espera y límite de intentos/ventana; un resultado confirmado no se degrada si se pierde la respuesta del guardado.

## Reprocesar una aportación existente sin otro cobro

Solo desde un entorno administrativo seguro con el secreto del trabajador ya configurado:

```sh
curl --fail-with-body --request POST \
  "$DOPMI_SUPABASE_URL/functions/v1/payment-worker" \
  --header "Authorization: Bearer $DOPMI_WORKER_SECRET" \
  --header 'Content-Type: application/json' \
  --data "{\"action\":\"reprocess_donation\",\"donation_id\":\"$DOPMI_DONATION_ID\"}"
```

Este endpoint lee la aportación y su Checkout/PaymentIntent ya existentes. No crea sesiones de pago ni cargos. Si ya hay una transferencia confirmada, devuelve su referencia sin llamar otra vez a `transfers`. Si está pendiente, reclama el mismo trabajo y conserva su clave de idempotencia.

Alternativa sin compartir el secreto del trabajador: reenviar desde Stripe el evento original `payment_intent.succeeded` o `checkout.session.completed` al endpoint actualizado. La firma vuelve a validarse y se consulta el evento real en Stripe. También funciona para eventos antiguos marcados como completados cuya transferencia quedó pendiente. No generar otro pago ni simular una firma.

**No reiniciar contadores, borrar trabajos ni cambiar claves para forzar un reintento.** Si el primer intento de transferencia/devolución tiene más de 23 horas o el trabajo necesita revisión, se detiene con `manual_reconciliation_required`. Antes de cualquier actuación posterior, conciliar en Stripe la cuenta destino, cargo, importe y grupo `dopmi_<donation_id>`; Stripe puede eliminar claves de idempotencia después de 24 horas. Un `503` también puede significar trabajo ocupado: consultar estado antes de reintentar, nunca volver a pagar.

## Historial y diagnóstico de permisos

### Devolución total después de una transferencia

El evento firmado `charge.refunded` consulta el cargo y sus devoluciones. Cuando la devolución total ha finalizado y la transferencia original está registrada, reclama un trabajo `reversal:<donation_id>`. Comprueba cuenta destino, cargo, moneda e importe y revierte la transferencia con `dopmi-full-reversal-<donation_id>` como clave de idempotencia. Si Stripe ya la revirtió, consulta y conserva esa evidencia sin emitir otra reversión.

Los importes anteriores se conservan en `private.dopmi_refund_adjustments`. Solo después de verificar devolución y reversión, una transacción marca pago devuelto, transferencia revertida, comisión Dopmi 0, asignación 0 y trabajo completado. La comisión de Stripe original queda como pérdida de plataforma. El historial conserva referencias originales; el acumulado del gasto y del caso deja de incluir esa aportación.

Saldo insuficiente, respuesta perdida o devolución pendiente mantienen el trabajo reintentable y el gasto reservado. Una cuenta destino distinta requiere revisión. El alcance actual automatiza devoluciones totales sobre transferencias completadas: las devoluciones parciales, reversiones parciales o transferencias con resultado incierto requieren conciliación manual y no reciben confirmación silenciosa. No reiniciar trabajos ni claves para saltar el límite de reintentos.

Aceptación de sandbox del 23 de septiembre: devolución de $50 MXN completada, una reversión automática de $43.14 MXN, referencias conciliadas y acumulado 0. No equivale a una prueba de depósito bancario ni habilita producción.

- El historial móvil lee `dopmi_donations` directamente con RLS, limitado al donante o rescatista dueño activo. No usa la acción `connect_status` de `/payments` ni necesita aprobación de rescatista para leer aportaciones previas.
- `connect_status` permite consultar el estado propio a una cuenta activa y confirmada aunque su verificación esté pendiente. El alta de Connect y los nuevos cobros mantienen la validación de rescatista aprobado.
- Un `403` de Stripe (clave restringida sin permisos) se devuelve como `503 stripe_permission_denied`, separado de `403 access_denied` / `rescuer_verification_required` del usuario. Revisar permisos de lectura de Events, PaymentIntents, Charges, Balance Transactions, cuentas y Payouts, y escritura de Checkout, Accounts/Account Links, Transfers y Refunds según el recurso/ámbito utilizado. No ampliar permisos indiscriminadamente ni cambiar a una clave live.
- Los logs estructurados identifican operación, SQLSTATE o código HTTP de Stripe, request/event/job/donation IDs y resultado. No incluyen cuerpos de Stripe, claves, correos, documentos ni datos bancarios.
- `funded_cents` representa neto asignado; `transferred_cents` suma solo transferencias confirmadas con referencia. El caso acumula sus gastos. Ninguno equivale por sí solo a depósito bancario.

Referencias: [transferencias separadas](https://docs.stripe.com/connect/separate-charges-and-transfers), [idempotencia](https://docs.stripe.com/api/idempotent_requests), [claves restringidas](https://docs.stripe.com/keys).
