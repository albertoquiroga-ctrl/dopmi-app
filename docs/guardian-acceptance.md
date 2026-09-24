# Guardián — aceptación integrada en pruebas

El hito 5 sigue abierto. Este documento organiza la prueba conjunta de app, Supabase y Stripe; los tests unitarios y las compilaciones no sustituyen esos recorridos.

## Entorno y preparación del 24 de septiembre de 2026

- Repositorio `albertoquiroga-ctrl/dopmi-app`, rama `codex/stripe-transfer-delivery`.
- Supabase `ohqxranynackjignryep`; Stripe **Entorno de prueba de DopMi**, `acct_1U2Dyq2ZjyMOQ0uL`, `livemode=false`.
- Migraciones Guardián aplicadas hasta `20260924222351_guardian_refund_reversals`.
- Código de pagos desplegado desde `5a38a36` (implementación de `fc99fd9`): `guardian-client` v1, `payment-worker` v8, `stripe-webhook` v9. Sus archivos remotos se compararon con el repositorio, sin diferencias. `payments` v7 ya coincide y se conserva.
- `payment-return` v6 corrige un problema detectado en HTTP real: el dominio estándar de Supabase convierte HTML a texto plano y reemplaza su CSP. Ahora devuelve instrucciones legibles para volver a la app; no depende de botones HTML que el navegador no renderiza. [Restricción documentada por Supabase](https://supabase.com/docs/guides/functions/limits).
- Webhook `we_1UI5JC2ZjyMOQ0uLhEBONUD1`, habilitado en test y con la misma URL, versión y secreto: se agregaron los 13 eventos faltantes, conservando los ocho anteriores. Su API de eventos permanece `2026-07-29.dahlia`; el servidor consulta la evidencia de Guardián con `2026-08-26.dahlia`.
- Cron `dopmi-payment-worker-reconcile`: cada minuto, token obtenido desde Vault. Respuestas posteriores al despliegue comprobadas con HTTP 200 y `failed=0`.
- Alta cerrada: POST `guardian-client` devuelve HTTP 503 `guardian_disabled`. El procesamiento Guardián ya está habilitado para pruebas; las comprobaciones posteriores no registraron fallos ni operaciones pendientes. Cero ciclos, suscripciones y liquidaciones Guardián durante la preparación. No se emitieron cargos, transferencias ni devoluciones.

## Comprobación repetible antes de abrir la prueba

Configurar `apps/mobile/config.local.json` con la URL indicada y la clave **publicable** `sb_publishable_…`. El archivo está excluido de Git; no usar claves de servidor, Stripe ni el secreto del trabajador.

```sh
node tools/verification/guardian-remote-smoke.mjs
```

Comprueba 18 respuestas reales: alta cerrada, método HTTP y CORS, trabajador sin credencial rechazado, webhook sin firma rechazado, retorno legible y denegación anónima de nueve RPC de servidor y tres consultas privadas. Una RPC ausente no cuenta como permiso verificado. No crea usuarios ni operaciones de pago.

Tras habilitar la prueba, ejecutar el mismo script con `--expect-enabled`: exige HTTP 401 `sign_in_required` para el cliente anónimo. Esa opción **no cambia flags**. Tampoco acredita permisos de la clave Stripe, webhook firmado, pago, ejecución de Cron ni recorrido móvil.

Revisar Cron por separado: una ejecución SQL que encola HTTP no demuestra una respuesta exitosa del trabajador. Inspeccionar `net._http_response` sin revelar headers ni el token de Vault; esperar HTTP 200 y `failed=0`, incluido el resultado `guardian` cuando se habilite.

## Configuración pendiente antes del primer pago

1. Acceso a la configuración de prueba resuelto mediante la automatización existente. No hace falta iniciar una nueva sesión en el navegador para completar esta preparación.
2. Comprobar `STRIPE_SECRET_KEY_H4_TEST` y sus permisos de prueba para los recursos utilizados: Events; Customers; Checkout; SetupIntents y PaymentMethods; Products/Prices; Subscriptions; Invoices e InvoicePayments; PaymentIntents, Charges y BalanceTransactions; cuentas Connect; Transfers y sus reversals; Refunds. Conceder escritura sólo donde el código la utiliza. El acceso de la conexión Stripe de ChatGPT no demuestra los permisos de esta clave de servidor. Conservar Stripe Tax apagado.
3. Preparación del servidor completada. Se mantiene `DOPMI_GUARDIAN_CHECKOUT_ENABLED=false`; los componentes de la tabla ya están habilitados:

   | Variable | Valor para el servidor de prueba |
   | --- | --- |
   | `DOPMI_GUARDIAN_WORKER_ENABLED` | `true` |
   | `DOPMI_GUARDIAN_SCHEDULE_ENABLED` | `true` |
   | `DOPMI_GUARDIAN_COLLECTION_ENABLED` | `true` |
   | `DOPMI_GUARDIAN_CHANGES_ENABLED` | `true` |
   | `DOPMI_GUARDIAN_REFUNDS_ENABLED` | `true` |

   Las respuestas reales de Cron ya se comprobaron sin fallos. Cuando estén listos el dispositivo y los permisos de Stripe, habilitar `DOPMI_GUARDIAN_CHECKOUT_ENABLED=true` y ejecutar el smoke con `--expect-enabled`. El cliente exige los seis flags. Esto habilita el entorno compartido de prueba para usuarios autenticados elegibles; no es una lista de acceso limitada a un donante.
4. La compilación Android conectada ya está disponible y aprobó sus verificaciones automáticas. Se instala como **Dopmi Guardián (prueba)** junto a la app habitual. Descargar el paquete de pruebas y extraer el APK correspondiente al dispositivo: `app-arm64-v8a-debug.apk` para ARM64, `app-armeabi-v7a-debug.apk` para ARM de 32 bits o `app-x86_64-debug.apk` para emulador x86_64. Registrar la versión del paquete y el dispositivo al probarlo. La compilación genérica no sirve como evidencia de aceptación conectada.

La instalación, el inicio de sesión y el recorrido en un dispositivo siguen pendientes. Las compilaciones y pruebas automáticas aprobadas no acreditan esos pasos. Checkout permanece cerrado.

## Primer recorrido en Android

1. Abrir **Dopmi Guardián (prueba)** e iniciar sesión con la cuenta Dopmi donante de prueba confirmada y activa. La instalación separada tiene su propia sesión. Si Android pregunta con qué app abrir un enlace de autenticación, elegir la de prueba. Abrir **Cuenta → Mi plan Guardián**.
2. Seleccionar $50 MXN. Comprobar condiciones, primera aportación, mensualidad, comisión, cancelación y consentimiento. Verificar antes la capacidad de gastos aprobados de prueba y la cuenta Connect lista.
3. Sin capacidad, comprobar el aviso y la ausencia de Checkout, suscripción y cargo. Con capacidad, autorizar **una sola vez** y completar Checkout con datos de prueba de Stripe.
4. En el retorno, volver manualmente a Dopmi y actualizar el plan. No iniciar otro pago si tarda. Confirmar por Stripe y base de datos el mismo intento, un cargo, la asignación completa del neto y las transferencias a sus destinos persistidos.
5. Cerrar y abrir la app; revisar el historial y el calendario. La suscripción mensual debe conservar `send_invoice` y `pause_collection.behavior=keep_as_draft`, sin reanudación programada. Confirmar que reserva, transferencia y depósito bancario se distinguen.

## Recorridos restantes y evidencia de cierre

Todos siguen **pendientes de aceptación integrada**. Usar sólo cuentas y objetos de prueba, conservando su trazabilidad; no alterar aprobaciones reales ni simular firmas.

| Recorrido | Evidencia necesaria |
| --- | --- |
| Alta, abandono, retorno y recuperación | Un mismo intento tras reabrir la app; expiración libera reserva; sin cargo ante falta de capacidad; pago confirmado por servidor. |
| Renovación con capacidad y mes sin capacidad | Reloj de prueba, factura individual pagada una vez y siguiente factura retenida; ciclo sin capacidad cerrado sin deuda ni cobro posterior. |
| Rechazo, 3DS y cambio de medio | Checkout setup/SetupIntent confirmado, medio del mismo cliente; aniversario conservado y ciclos omitidos sin recobro. |
| Cambio de monto y cancelación | Antes/cerca/después del aniversario y fin de mes; precio del período conservado, solicitud pendiente/retiro visible y ausencia de cargos posteriores a cancelación. |
| Historial y privacidad en dispositivo | Importes conciliados, paginación, pantalla sin datos al cambiar cuenta; otra cuenta y admin sin historial ajeno. |
| Devolución total posterior a transferencias | Refund confirmado y cada reversión confirmada una vez; capacidad retenida hasta completar todas; neto/fee/capacidad e historial consistentes. |
| Duplicados, interrupciones y revisión manual | Mismas referencias e importes tras reenvío firmado y Cron; respuesta perdida recuperada sin duplicados; parcial/disputa/resultado incierto conservado en revisión. |

Registrar por recorrido: fecha UTC, commit/APK/dispositivo, identificadores técnicos de ciclo/Stripe, estado antes/después, evidencia de importes, respuesta del trabajador y resultado. No publicar tokens, documentos ni datos personales. Los experimentos aislados ya descritos en `guardian-billing-design.md` no sustituyen estos recorridos completos.

## Operación y detención

- Para impedir nuevas altas, apagar primero **sólo** `DOPMI_GUARDIAN_CHECKOUT_ENABLED`. Esto no cancela planes existentes ni impide que el trabajador procese sus ciclos.
- Si ya existen pagos/planes, conservar conciliación y gestionar cada cancelación con el recorrido normal; verificar Stripe y base antes de retirar el trabajador. Apagar todos los flags no equivale a cancelar ni devolver. Con cero objetos pendientes puede cerrarse completamente la prueba.
- En devolución parcial, disputa o transferencia incierta, conciliar cargo, refunds, transferencias y reversiones por referencias persistidas. No marcar completado, liberar capacidad, reiniciar intentos o emitir otra transferencia para resolver una respuesta perdida.
- La acción administrativa `reprocess_guardian_refund` del trabajador recibe `cycle_id` y requiere su secreto existente; puede responder 503 por revisión o conciliación pendiente. Reprocesar no sustituye resolver la evidencia original.
- No habilitar dinero real hasta completar aceptación y evaluación independiente de H5.5.

## Despliegues siguientes

El workflow `deploy-supabase-payments.yml` incluye ahora `guardian-client`, además de las cuatro funciones anteriores, y acepta `H5-TEST` en su ejecución manual. No configura flags ni modifica migraciones. Para desplegar esta rama mediante Actions, comprobar primero que el workflow pueda ejecutarse sobre ella; esta entrega se desplegó mediante la conexión Supabase y no ejecutó ese workflow.
