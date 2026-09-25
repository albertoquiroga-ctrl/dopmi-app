# Guardián — aceptación integrada en pruebas

El hito 5 sigue abierto. Este documento organiza la prueba conjunta de app, Supabase y Stripe; los tests unitarios y las compilaciones no sustituyen esos recorridos.

## Estado de aceptación actualizado — 25 de septiembre de 2026 UTC

Esta sección prevalece sobre los cortes históricos de preparación que siguen. Ruta vigente: **Android desde Google Play interno**, build **2.3.3 (247)**, commit `3fe7a1d`; publicación comprobada en Codemagic y recorrido del titular visible en las capturas. Dispositivo confirmado por captura del titular: Samsung Galaxy S25 Ultra (SM-S938B). Android 16 y One UI 8.5 confirmados por captura de Información de software.

Checkout test ya está habilitado; el smoke de 18 respuestas con `--expect-enabled` aprobó y Cron devolvió HTTP 200 sin fallos Guardián. La clave del servidor aprobó 16 lecturas; las escrituras se acreditan por cada recorrido, no por el preflight.

Primera aportación: ciclo `8724966d-3a05-47c4-9c0d-cd968e3a6c81`, pago de 50.00 MXN, comisión 1.00, costo Stripe 5.86 y neto asignado/transferido 43.14. Base, consulta Stripe y pantallas del titular coinciden. En el alta, plan activo; retorno manual e historial básico comprobados. El estado posterior de cancelación y devolución se describe abajo. La transferencia Connect no acredita depósito bancario. Los identificadores y consultas están registrados en [el avance](progress.md).

Cambio de 50 a 200 MXN comprobado mediante consentimiento y «Solicitar cambio de monto»: solicitud aplicada en base y precio mensual 20000 centavos en Stripe, aniversario conservado y sin factura generada por el cambio. En ese momento seguía existiendo un solo ciclo, pagado por 5000 centavos y asignado por 4314. Tras «Actualizar estado», la captura del titular muestra «Confirmado. Aplica desde 24/10/2026» y plan de 200 MXN. Esto acredita el cambio ordinario; no las condiciones límite de aniversario ni fin de mes.

Cambio de tarjeta completo en app/base/Stripe: consentimiento, Checkout setup, tarjeta test 3155, 3DS challenge authenticated y confirmación móvil sin cobro. El plan conserva monto y aniversario. Privacidad comprobada al cambiar a otra cuenta y volver: plan/historial vacíos para la otra identidad, estado propio restaurado al regresar. La identidad ajena también es administradora; las RPC no le exponen el ciclo. Detalle móvil de la asignación inicial coincide con el servidor. La paginación RPC con tamaño 1 devuelve los dos ciclos distintos y termina sin cursor; el botón móvil de más páginas aún no está acreditado.

Renovación integrada del mismo plan: reloj `clock_1UJNsh2ZjyMOQ0uLXx9GXAwl` asociado al cliente existente y avanzado hasta `1792891615`. Factura `in_1UJNvd2ZjyMOQ0uLTRvFgXMK` paid por 20000 centavos, attempt_count 1, auto_advance false, suscripción con pausa keep_as_draft. Ciclo `06cbe7ae-6e08-4f3c-874c-5735923fe06c`: costo Stripe 1299, comisión 400, neto 18301 asignado/transferido. Transferencia `tr_3UJNwh2ZjyMOQ0uL0ePNuZko` verificada directamente en Stripe: mismo cargo origen, destino y ciclo, test, sin reversión. Cron se recuperó automáticamente de consultar el reloj mientras avanzaba. Captura móvil mensual recibida y coincidente en todos los importes. Sigue pendiente el escenario mensual sin capacidad.

Tarjeta rechazada durante setup y recuperación en el mismo Checkout también comprobadas, incluida confirmación móvil. Esto no sustituye rechazo de cobro mensual off-session.

Cancelación comprobada en Android/base/Stripe, con ambos ciclos conservados en historial. Reloj avanzado después al 24/11/2026 (`1795570015`, ready): plan canceled, misma última factura y dos ciclos, sin renovación posterior. Avisos residuales de la pantalla corregidos en `37895d2`, 51 pruebas locales y CI `36142869179` aprobados; el titular informó compilación e instalación de la actualización sin problemas. Captura Android 1000343790 confirma Plan cancelado y Cancelación confirmada, sin los avisos residuales de solicitud recibida ni medio actualizado para próximos ciclos. Codemagic comprobado: build 6ab683fc22e9e13c30dbd3f0, commit a1e3b76267ff39200a47c720dbf472da044dc007, versión 2.3.3 (248), finalizado en 6m14s; publicación internal completed, paquete com.mycompany.dopmi, no depurable. SHA256 del AAB b80de273c64815ddb7b3843aa720a82f399429bcffcbea8b8531a55874e8552b.

Devolución total del alta de 50: refund `re_3UJNdz2ZjyMOQ0uL11JJyIzs` succeeded, reversión automática única `trr_1UJZR32ZjyMOQ0uLWuhjvjkX` por 4314 centavos. Ajuste completed y capacidad ocupada cero; comisión anulada, costo Stripe 586 registrado como pérdida de plataforma. Reprocesamiento autenticado 2396 respondió completed sin otra reversión. Captura Android 1000343782 recibida: devolución confirmada de 50.00 MXN, transferencias revertidas 43.14, comisión/asignado/transferido cero y costo Stripe histórico 5.86; el aviso explica que se devuelve el pago completo. El ciclo mensual permanece sin devolver, con neto transferido 183.01 MXN. No sustituye reenvío firmado, interrupción durante escritura ni devolución de múltiples destinos.

No borrar el reloj: elimina también el cliente y suscripciones. La asociación de clientes existentes está soportada desde 2026-05-27; no se modificaron fechas de base para simular el cobro. [Restricciones de los relojes](https://docs.stripe.com/billing/testing/test-clocks/api-advanced-usage).

Nueva cuenta de aceptación: captura Android 1000343788 confirma plan activo de 50 MXN. Consulta autenticada de estado/historial en servidor confirma revisión 0, sin solicitudes pendientes ni pago en vuelo; ciclo inicial `7e93d285-de6d-4548-9599-9d728297eb2c` creado 2026-09-25T14:20:37.917199Z, pago 5000, comisión 100, costo Stripe 586, neto asignado/transferido 4314 centavos. Este nuevo plan queda disponible para los escenarios pendientes; aún no acredita omisión mensual ni una nueva consulta directa a Stripe.

## Ruta elegida por el titular: Google Play interno (25 de septiembre de 2026)

El titular eligió probar primero en Android desde Google Play y ejecutar personalmente Codemagic. Usar rama `codex/stripe-transfer-delivery`, workflow **`android-guardian-internal` — Dopmi Guardián — Google Play Internal Testing**. El workflow anterior `android-internal` mantiene Guardián apagado y no sirve para esta aceptación.

El nuevo workflow conserva `com.mycompany.dopmi`, firma `dopmi_upload_2026` y grupos `dopmi_supabase`/`dopmi_google_play`; fija Flutter 3.47.4, valida el proyecto test y activa Guardián mediante `--guardian-test`. Publica exclusivamente a `internal`, versión 2.3.3, build `PROJECT_BUILD_NUMBER + 231`. No usar el sufijo de la APK independiente. Descargar `guardian-build-info.txt` para registrar commit y número de build. Comprobar publicación exitosa en Codemagic y disponibilidad de esa misma versión para el tester en Play; instalar/actualizar y abrir Cuenta → Mi plan Guardián.

Preflight remoto `1616` ya aprobó las 16 lecturas Stripe con la clave restringida de prueba. Los permisos de escritura se configuraron con autorización y SMS del titular, pero solo los recorridos integrados acreditarán su funcionamiento. Las 18 comprobaciones HTTP remotas aprobaron con Checkout cerrado. Mantener ese gate cerrado hasta que esté disponible el dispositivo/build y se prepare el recorrido; la compilación no lo activa.

**Corte histórico del traspaso: Codemagic → TestFlight**, sustituido después por la elección Android indicada arriba. [Continuidad y evidencia de CI](codex-handoff.md). El estado remoto de las secciones de preparación de abajo corresponde a ese corte, no al estado actualizado de aceptación.

## Entorno y preparación del 24 de septiembre de 2026

- Repositorio `albertoquiroga-ctrl/dopmi-app`, rama `codex/stripe-transfer-delivery`.
- Supabase `ohqxranynackjignryep`; Stripe **Entorno de prueba de DopMi**, `acct_1U2Dyq2ZjyMOQ0uL`, `livemode=false`.
- Migraciones Guardián aplicadas hasta `20260924222351_guardian_refund_reversals`.
- Esa es la versión remota documentada; el archivo local es `20260924220619_guardian_refund_reversals.sql`. Comprobar [el historial](migration-history-audit.md) antes de aplicar o reparar migraciones.
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
4. Preparar el build TestFlight según la sección siguiente. Como alternativa, la compilación Android conectada ya está disponible y aprobó sus verificaciones automáticas. Se instala como **Dopmi Guardián (prueba)** junto a la app habitual. Descargar el paquete de pruebas y extraer el APK correspondiente al dispositivo: `app-arm64-v8a-debug.apk` para ARM64, `app-armeabi-v7a-debug.apk` para ARM de 32 bits o `app-x86_64-debug.apk` para emulador x86_64. Registrar la versión del paquete y el dispositivo al probarlo. La compilación genérica no sirve como evidencia de aceptación conectada.

La instalación, el inicio de sesión y el recorrido en un dispositivo siguen pendientes. Las compilaciones y pruebas automáticas aprobadas no acreditan esos pasos. Checkout permanece cerrado.

## Codemagic → TestFlight (alternativa)

1. Seleccionar `albertoquiroga-ctrl/dopmi-app`, rama **`codex/stripe-transfer-delivery`** y workflow YAML **`ios-testflight` — Dopmi iOS — TestFlight**. La rama predeterminada anterior al traspaso no incluye la preparación de `8e6663d`.
2. Conservar integración **`dopmi_app_store`**, firma `app_store` y bundle **`com.mycompany.dopmi`**. No crear otra ficha ni cambiar el identificador de la app existente.
3. Verificar el grupo **`dopmi_supabase`**: URL del proyecto test y `SUPABASE_PUBLISHABLE_KEY` de cliente. No incorporar claves de servidor, Stripe ni el secreto del trabajador al build.
4. El workflow fija Flutter **3.47.4**, ejecuta `write-mobile-config.py --guardian-test` y activa `ENABLE_GUARDIAN_TEST=true`. Usa versión **2.3.3**, build **`PROJECT_BUILD_NUMBER + 231`**; comprobar que el número sea nuevo en App Store Connect. Exporta con `testFlightInternalTestingOnly=true`. Los otros workflows Codemagic mantienen Guardián apagado.
5. El YAML publica con `auth: integration`, `submit_to_testflight: false` y `submit_to_app_store: false`; conservar el flujo interno existente y verificar la carga/procesamiento efectivos en App Store Connect. Esas opciones, la presencia del YAML y un build de simulador no acreditan que el IPA esté disponible para testers.
6. Guardar **`guardian-build-info.txt`** (SHA, versión/build y distribución). Esperar procesamiento de Apple y disponibilidad para el tester interno; instalar desde TestFlight. Si no aparece, revisar carga y grupo interno antes de repetir builds.
7. Registrar dispositivo/iOS e iniciar sesión. Si falta **Cuenta → Mi plan Guardián**, comprobar rama/SHA/flag cliente. Si está visible pero rechaza el alta, comprobar gates/permisos de servidor; no quitar controles ni volver a pagar.

El titular compila e instala. Codex prepara backend y revisa evidencia; el flag cliente no habilita Checkout en el servidor. El APK Android conectado descrito arriba queda como alternativa, no como requisito para TestFlight.

### Preflight Stripe pendiente

`8e6663d` agrega `guardian_preflight` a `payment-worker`, detrás de su secreto existente. Devuelve estados de lecturas sin objetos ni credenciales. Comprobar primero si ese código está desplegado: un `400 invalid_action` puede corresponder al trabajador anterior. El último despliegue registrado precede a esta acción.

El preflight **no acredita permisos de escritura/reversión**, pagos, webhook firmado ni Cron. Verificar también los permisos necesarios indicados en la preparación; no confundir acceso de un conector con permisos de la clave del servidor.

## Primer recorrido en dispositivo

1. Abrir **Dopmi desde TestFlight** e iniciar sesión con la cuenta donante de prueba confirmada y activa. Abrir **Cuenta → Mi plan Guardián**. En la alternativa Android usar **Dopmi Guardián (prueba)**: conserva una sesión separada; elegirla si Android pregunta qué app debe abrir el enlace de autenticación.
2. Seleccionar $50 MXN. Comprobar condiciones, primera aportación, mensualidad, comisión, cancelación y consentimiento. Verificar antes la capacidad de gastos aprobados de prueba y la cuenta Connect lista.
3. Sin capacidad, comprobar el aviso y la ausencia de Checkout, suscripción y cargo. Con capacidad, autorizar **una sola vez** y completar Checkout con datos de prueba de Stripe.
4. En el retorno, volver manualmente a Dopmi y actualizar el plan. No iniciar otro pago si tarda. Confirmar por Stripe y base de datos el mismo intento, un cargo, la asignación completa del neto y las transferencias a sus destinos persistidos.
5. Cerrar y abrir la app; revisar el historial y el calendario. La suscripción mensual debe conservar `send_invoice` y `pause_collection.behavior=keep_as_draft`, sin reanudación programada. Confirmar que reserva, transferencia y depósito bancario se distinguen.

## Recorridos restantes y evidencia de cierre

La sección de estado al inicio registra los recorridos ya comprobados y sus límites. La siguiente matriz conserva el alcance completo; los casos todavía no acreditados siguen pendientes de aceptación integrada. Usar sólo cuentas y objetos de prueba, conservando su trazabilidad; no alterar aprobaciones reales ni simular firmas.

| Recorrido | Evidencia necesaria |
| --- | --- |
| Alta, abandono, retorno y recuperación | Un mismo intento tras reabrir la app; expiración libera reserva; sin cargo ante falta de capacidad; pago confirmado por servidor. |
| Renovación con capacidad y mes sin capacidad | Reloj de prueba, factura individual pagada una vez y siguiente factura retenida; ciclo sin capacidad cerrado sin deuda ni cobro posterior. |
| Rechazo, 3DS y cambio de medio | Checkout setup/SetupIntent confirmado, medio del mismo cliente; aniversario conservado y ciclos omitidos sin recobro. |
| Cambio de monto y cancelación | Antes/cerca/después del aniversario y fin de mes; precio del período conservado, solicitud pendiente/retiro visible y ausencia de cargos posteriores a cancelación. |
| Historial y privacidad en dispositivo | Importes conciliados, paginación, pantalla sin datos al cambiar cuenta; otra cuenta y admin sin historial ajeno. |
| Devolución total posterior a transferencias | Refund confirmado y cada reversión confirmada una vez; capacidad retenida hasta completar todas; neto/fee/capacidad e historial consistentes. |
| Duplicados, interrupciones y revisión manual | Mismas referencias e importes tras reenvío firmado y Cron; respuesta perdida recuperada sin duplicados; parcial/disputa/resultado incierto conservado en revisión. |

Registrar por recorrido: fecha UTC, commit, versión/build TestFlight o APK, dispositivo/sistema, identificadores técnicos de ciclo/Stripe de prueba, estado antes/después, evidencia de importes, respuesta del trabajador y resultado. No publicar tokens, documentos ni datos personales. Los experimentos aislados ya descritos en `guardian-billing-design.md` no sustituyen estos recorridos completos.

## Operación y detención

- Para impedir nuevas altas, apagar primero **sólo** `DOPMI_GUARDIAN_CHECKOUT_ENABLED`. Esto no cancela planes existentes ni impide que el trabajador procese sus ciclos.
- Si ya existen pagos/planes, conservar conciliación y gestionar cada cancelación con el recorrido normal; verificar Stripe y base antes de retirar el trabajador. Apagar todos los flags no equivale a cancelar ni devolver. Con cero objetos pendientes puede cerrarse completamente la prueba.
- En devolución parcial, disputa o transferencia incierta, conciliar cargo, refunds, transferencias y reversiones por referencias persistidas. No marcar completado, liberar capacidad, reiniciar intentos o emitir otra transferencia para resolver una respuesta perdida.
- La acción administrativa `reprocess_guardian_refund` del trabajador recibe `cycle_id` y requiere su secreto existente; puede responder 503 por revisión o conciliación pendiente. Reprocesar no sustituye resolver la evidencia original.
- No habilitar dinero real hasta completar aceptación y evaluación independiente de H5.5.

## Despliegues siguientes

El workflow `deploy-supabase-payments.yml` incluye ahora `guardian-client`, además de las cuatro funciones anteriores, y acepta `H5-TEST` en su ejecución manual. No configura flags ni modifica migraciones. Para desplegar esta rama mediante Actions, comprobar primero que el workflow pueda ejecutarse sobre ella; esta entrega se desplegó mediante la conexión Supabase y no ejecutó ese workflow.

## Omisión mensual integrada — 25 de septiembre de 2026

Nuevo plan test sub_1UJa0n2ZjyMOQ0uLrY1yEBLv, cliente cus_VKESR2SH0tfryp: Stripe confirmó activo, 5000 MXN centavos, send_invoice, pausa keep_as_draft sin resumes_at y sin factura inicial de suscripción. Reloj clock_1UJaEp2ZjyMOQ0uLL5n6YZe1 asociado al cliente y avanzado a 1792938996, ready (25 de octubre).

Preparación técnica: dos reservas mediante dopmi_guardian_reserve, sin Checkout ni pago, bajo el donante del plan anteriormente cancelado. Claves 71e2ae69-5f36-4c1c-af16-735a12c9c921 y 71e2ae69-5f36-4c1c-af16-735a12c9c922; ciclos 2827bb80-5f80-43f9-add8-e0844e28ef37 y ee303b96-3083-459c-8b1f-e01aa5a53e62. Reservaron 980000 y 539000 centavos de la capacidad disponible de 1520585; preview del nuevo donante rechazó reservar 4900. No se alteraron gastos aprobados, fechas, reglas ni evidencia de Stripe. Son fixtures técnicos, no aportaciones autorizadas desde la app.

Cron procesó el aniversario: ciclo 0bc6abf4-bf0a-43bf-9d17-801c36506e56, skipped/no_capacity, sin asignaciones ni transferencia. Stripe confirmó factura in_1UJaGh2ZjyMOQ0uLFtWeva0Q void, amount_paid 0, attempt_count 0, plan activo. El campo amount_remaining conserva 5000 en la factura anulada; su estado void es la evidencia de que no queda cobrable. Ambas reservas técnicas fueron liberadas mediante dopmi_guardian_release, estado released confirmado. La continuación y su evidencia móvil se registran abajo.
Continuación con capacidad restaurada: preview del donante can_activate=true, reloj avanzado a 1795617396 (25 de noviembre), ready. Stripe confirma factura in_1UJaIx2ZjyMOQ0uL9nYyg7HQ paid, total/amount_paid 5000, attempt_count 1. Historial autenticado confirma ciclo 241c4c4c-da18-4a1b-8af8-42b54a44b6f5 transferred, comisión 100, costo Stripe 586 y neto 4314; el ciclo de octubre sigue skipped/no_capacity, sin asignación ni pago. El cobro de noviembre fue únicamente 50 MXN, sin sumar el mes omitido. Captura Android 1000343853 recibida en build 248: octubre muestra Ciclo omitido sin cargo ni deuda y falta de capacidad; noviembre muestra pago de 50.00 MXN, comisión 1.00, costo Stripe 5.86 y neto asignado/transferido 43.14. El alta de septiembre conserva sus importes. Queda acreditado este recorrido integrado de omisión y renovación sin recobro del mes omitido.
## Reenvío firmado integrado — 25 de septiembre de 2026

Desde Workbench del destino we_1UI5JC2ZjyMOQ0uLhEBONUD1 se reenvió invoice.paid evt_1UJaJD2ZjyMOQ0uLLeYmXw37, correspondiente a in_1UJaIx2ZjyMOQ0uL9nYyg7HQ. Stripe mostró entrega manual recuperada con HTTP 200 a las 08:46:04 CST, posterior a la entrega original 08:41:09. Antes y después, la base conserva una sola asignación de 4314 y transferencia tr_3UJaJA2ZjyMOQ0uL1lbjpFQx para el ciclo 241c4c4c-da18-4a1b-8af8-42b54a44b6f5. Consulta Stripe posterior: misma factura paid por 5000, attempt_count 1. Esto acredita repetición firmada de invoice.paid y conservación de referencias/importes; no simula una respuesta perdida durante la primera escritura ni todos los tipos de evento.