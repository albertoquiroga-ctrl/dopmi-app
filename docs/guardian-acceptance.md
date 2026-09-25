# Guardián — aceptación integrada en pruebas

El hito 5 sigue abierto. Este documento organiza la prueba conjunta de app, Supabase y Stripe; los tests unitarios y las compilaciones no sustituyen esos recorridos.

## Estado vigente de aceptación — 25 de septiembre de 2026

Este resumen sustituye los pendientes de los cortes históricos inferiores. H5 permanece abierto; no repetir los recorridos ya acreditados.

Cruce con cambio incierto aceptado en app/backend/Stripe: respuesta POST real de cambio200→50 consumida antes del SDK, reloj cruzó aniversario con solicitud pendiente; conciliación normal applied conserva fecha original y verifica factura del período. Una factura pagada50, net43.14 transferido una vez, intentos registrados1. Instrumentación retirada y bundles comparados. Capturas1000344188/1000344190 confirman plan50, cambio confirmado desde25/7/2028 y ciclo de esa fecha con pago50, fee1, Stripe5.86 y net43.14 transferido, asignación confirmada. Referencias en progress.md. No repetir este recorrido; no acredita fin de mes ni corte TCP.

Aviso residual tras retirar monto verificado en Android: capturas 1000344174/1000344176 muestran plan activo de 50 y solicitud de 200 retirada; 1000344178 muestra el final completo del formulario después de actualizar, sin «Solicitud recibida», consentimiento desmarcado y botón de cambio deshabilitado. Sustituye el pendiente visual de los cortes inferiores; no muestra versionCode exacto.

Recuperación financiera backend/Stripe acreditada: ciclo 25/4/2028, respuesta real 200 de reversión consumida antes del SDK, servicio conserva asignación mientras el ID está incierto y conciliador normal recupera la misma reversión sin aumentar intentos registrados ni duplicar movimientos (attempts 1). Instrumentación temporal retirada y archivos comparados. Captura Android 1000344170 confirma devolución completa de 50.00 y asignación de 43.14 con reversión confirmada, comisión/asignación/transferido cero. Recorrido integrado aceptado; evidencia completa en progress.md. No equivale al cruce de aniversario incierto ni pérdida en múltiples destinos.

Segundo destino preparado por el titular. Renovación test del 25/6/2028 conciliada por 50 MXN, neto 43.14 distribuido en dos transferencias confirmadas: 20.00 y 23.14. Reservas técnicas de preparación liberadas. Captura Android 1000344110 acredita ambas asignaciones. Devolución total de 50 MXN succeeded y ajuste completed: Stripe confirma exactamente una reversión por destino, de 20.00 y 23.14; SQL registra un intento por reversión, comisión y asignación finales cero. Captura Android 1000344117 confirma devolución de 50.00, reversiones por 43.14, comisión/asignación/transferido cero y ambas asignaciones con reversión confirmada (20.00 y 23.14). Recorrido integrado de devolución total a dos destinos aceptado; referencias en progress.md. No acredita pérdida de respuesta financiera ni recuperación incierta.

Disputa antes de asignación observada y corregida en servidor (`847e184`): el cargo test pagado/disputado del nuevo alta pasó por conciliación normal a attention; no se creó liquidación, plan ni transferencia. La RPC propietaria ya devuelve historial review. CI `36177947929` sobre `5984e16` aprobó los cuatro jobs. Capturas Android 1000344119 y 1000344121 confirman Alta en revisión e historial En revisión, separado del intento anterior cerrado. Revelan un defecto del cliente: conserva Reintentar mi solicitud junto a No vuelvas a pagar. Corrección móvil 0140fbd validada visualmente tras actualización reportada: capturas 1000344166 y 1000344168 muestran Alta en revisión sin reintento ni formulario, con historial conservado. Queda acreditada la presentación de la disputa inicial en dispositivo; no su resolución ni una disputa posterior a transferencias. Número exacto del build instalado no visible. Referencias y despliegues en progress.md.

- Build actualizado verificado en navegador: Codemagic `6ab6e1527e2cdbe815b37fa0`, commit `0140fbd`, 2.3.3 (252), internal completed, no depurable. CI `36187337633`: cuatro jobs success. Revisión independiente del cambio móvil sin hallazgos. Capturas 1000344166/1000344168 validan la corrección tras actualización reportada; no muestran versionCode instalado.
- Android es la ruta elegida. Build anterior publicado verificado directamente: Codemagic `6ab6b1ecd585f0389192548f`, commit `bcbc2e7`, versión 2.3.3 (250), internal completed y no depurable. Incluye `291dcd0`. El titular informa instalación, pero sus capturas no muestran el versionCode instalado. La captura anterior 1000343972 ya acredita la limpieza del aviso tras cancelar el alta.
- Completados con app/base/Stripe: alta y renovación; cambio ordinario de monto; setup/3DS y rechazo; cancelación y ausencia de renovación posterior; omisión por capacidad y renovación siguiente; rechazo mensual y recuperación con tarjeta válida sin recobrar el mes omitido; abandono, reapertura del mismo Checkout y cancelación sin pago; cambio cercano al aniversario, retiro y renovación de febrero por 50 MXN (captura 1000343984).
- Devolución total del alta acreditada también en Android. Devolución parcial del ciclo mensual conservada en revisión y posterior devolución del resto conciliada en backend/Stripe. Este último resultado sustituye la observación histórica de que ese ciclo permanecía sin devolver. Reenvío firmado de invoice.paid sin duplicados y privacidad entre cuentas comprobados; paginación RPC comprobada con tamaño 1.
- Corrección móvil `291dcd0`: elimina el aviso genérico residual después de gestionar solicitudes y conserva el estado autoritativo. Analyze y 51 pruebas aprobados; CI `36163237337` sobre `446d394` aprobó los cuatro jobs. El titular informa nuevo build instalado; captura 1000344033 confirma «Solicitud retirada; se conservó el monto anterior» y plan de 50 MXN. No identifica versión/commit ni muestra el final del formulario: queda pendiente vincular el build y comprobar la ausencia del aviso residual después de una operación en esa versión.

Paginación móvil aceptada: 21 ciclos en el segundo plan, reloj test ready en 25/5/2028, RPC predeterminada devuelve 20 + 1 registros sin duplicados y con cursor final null. Captura Android 1000344002 y confirmación del titular tras pulsar «Ver ciclos anteriores» muestran el alta del 25/9/2026 debajo del ciclo de octubre, con pago 50.00 MXN y neto transferido 43.14. No generar más ciclos ni repetir este recorrido. Evidencia técnica y CI del arreglo de anulación eventual `bf9d566` en progress.md.

Pendientes de aceptación integrada: calendario de fin de mes; disputa posterior a transferencia. Cruce con escritura incierta, aviso residual tras retirar monto, devolución completa a dos destinos y pantalla de revisión de disputa inicial ya aceptados. La captura de paginación no identifica build ni acredita esa corrección. Los tests locales de otros casos no sustituyen evidencia integrada. Conservar H5.3–H5.5 y H5.G–H5.H abiertos hasta satisfacer la matriz completa.

Expiración natural confirmada a las 18:41:41 UTC: ciclo `dfda0ccb-ef61-4435-87e2-64348bf37a65`, activación y reserva expired, reserved_cents 0, cancellation_requested_at null y cero suscripciones. Stripe confirma la misma sesión expired/unpaid, sin PaymentIntent ni suscripción. Captura Android 1000344048 confirma Intento vencido sin pago confirmado, consentimiento desmarcado y Activar en Stripe deshabilitado. Recorrido integrado completo; no repetir. Para pérdida de respuesta se prepara un [instrumento local de transporte](../tools/verification/guardian-response-loss.md), separado de los servicios compartidos. Sus pruebas TCP locales no sustituyen la ejecución integrada con Stripe ni acreditan recuperación financiera real. La credencial local test ya fue validada mediante lectura de la sesión conocida; queda preparar y ejecutar el escenario aislado.

Actualización de transporte, 18:54 UTC: el ejecutor aislado recuperó el mismo precio test después de perder su respuesta 200; precio/producto técnicos archivados y verificados. Detalle y referencias en progress.md y guardian-response-loss.md. Acredita transporte real e idempotencia de creación de precio, no cobros, worker, RPC ni pérdida al cruzar aniversario; esos casos siguen pendientes.

## Corte histórico inicial de aceptación — 25 de septiembre de 2026 UTC

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
## Devolución parcial en revisión y resolución total — 25 de septiembre de 2026

Sobre el ciclo mensual de 200 MXN del plan ya cancelado (06cbe7ae-6e08-4f3c-874c-5735923fe06c), lista Stripe previa sin refunds: devolución test de 1000 centavos re_3UJNwh2ZjyMOQ0uL046SO7HB succeeded. El ajuste pasó a review/guardian_refund_review. Base mantuvo 18301 centavos asignados, cero revertidos y capacidad ocupada 18301; Stripe confirmó transferencia original sin reversión. No se trató la devolución parcial como cierre completo.

Se completó el importe restante con re_3UJNwh2ZjyMOQ0uL0fV9krR0 por 19000, succeeded. Sin modificar estados manualmente, el ajuste pasó a completed, error null, reversión 18301 y capacidad ocupada cero. Este resultado posterior sustituye las menciones históricas de que el ciclo de 200 permanecía sin devolución. El plan nuevo de 50 no fue modificado. Acredita parcial en revisión y recuperación al completarse el total; no acredita disputa ni múltiples destinos.
## Rechazo mensual y recuperación automática — 25 de septiembre de 2026

Captura Android 1000343858 confirma medio actualizado sin cobro, plan activo de 50. Stripe confirmó tarjeta 3178, PaymentMethod pm_1UJatK2ZjyMOQ0uLq8zVJWu8; solicitud 670ca2d3-c9a9-4c13-a512-dd18b9c8d937 applied y revisión de plan 1. Reloj avanzado a 1798209396 (25 de diciembre), ready.

Factura in_1UJav12ZjyMOQ0uL4Gmwfo2N tuvo un intento y amount_paid 0. El ciclo 2c9b5e3b-f8b7-47b0-a4ab-9c6305a9bad5 estuvo transitoriamente en attention/guardian_processor_unavailable tras el rechazo. Cron lo recuperó sin intervención: a las 15:23:04 UTC status skipped, error null, recovery_state voided, recovery_reason payment_failed, recovery_attempts 1. Stripe confirmó factura void, amount_paid 0 y attempt_count 1; InvoicePayment inpay_1UJavs2ZjyMOQ0uLNWyvLdRS canceled, PI pi_3UJavr2ZjyMOQ0uL1IlGGtHn. No se repitió pay, alteró estado manualmente ni cambió código. Captura Android 1000343863 confirma ciclo del 25/12/2026 omitido sin cargo ni deuda, importe autorizado 50 MXN, pago rechazado y opción de actualizar el medio para próximos ciclos; siguiente aniversario 25/1/2027. Verificación posterior de base: reserva released, reserved_cents 0, allocated_cents 0 y reserva activa 0. Pendiente recuperación futura con medio válido sin recobrar diciembre; el titular está realizando el cambio de tarjeta.
## Renovación posterior al rechazo — 25 de septiembre de 2026

Captura Android 1000343865 confirma medio actualizado sin cobro y conserva el aviso de diciembre omitido. Stripe verificó default_payment_method terminado en 4242 antes de avanzar el reloj clock_1UJaEp2ZjyMOQ0uLL5n6YZe1 a 1800887796 (25/1/2027), ready. Factura in_1UJb5P2ZjyMOQ0uLpGC8VV9g paid, total y amount_paid 5000, attempt_count 1. El historial autenticado registra ciclo 0032e0fc-f476-4496-a89f-9e35232919ce, período 25/1–25/2, pago 5000, comisión 100, costo Stripe 586 y asignación 4314. Base y Stripe confirman transferencia tr_3UJb5X2ZjyMOQ0uL1qz4ZTfq por 4314, test, no revertida. Diciembre permanece skipped/payment_failed sin pago ni asignación; octubre sigue skipped/no_capacity. Se cobró sólo el mes nuevo, sin recuperar meses omitidos. Captura Android 1000343881 recibida: enero muestra pago confirmado de 50.00 MXN, comisión 1.00, costos Stripe 5.86 y neto asignado/transferido 43.14; diciembre conserva Ciclo omitido sin cargo ni deuda por pago rechazado. Siguiente aniversario de enero: 25/2/2027. Queda completo este recorrido integrado de rechazo, actualización de medio y renovación futura sin recobro del mes omitido. H5 sigue abierto por los restantes recorridos de aceptación.
## Alta abandonada y recuperación del mismo intento — 25 de septiembre de 2026

Cuenta nueva confirmada y sin plan; preview autenticado permitió 5000 centavos. Tras abrir Checkout sin pagar, cerrar/reabrir la app conservó solicitud e importe (capturas Android 1000343889 y 1000343891). Antes y después del reintento, base devuelve exactamente una activación: ciclo 753e1f89-d319-4846-aa8f-7ab84c93d004, clave 46da3db8-b301-4abd-9abe-93abadaaf08d, sesión cs_test_a1F0yPxMPl63mIoJhGYQHltk4GOroEvsugjI0S8OQrOx7RyzQH6x72pgvS, pending, bruto 5000 y reserva 4900. Stripe previo al reintento confirmó open/unpaid, total 5000, sin PaymentIntent ni suscripción. Captura 1000343893 y confirmación del titular muestran reapertura de Checkout por 50 MXN; referencia persistida posterior idéntica. No se acredita aún cancelación/expiración ni liberación de esta reserva: se solicita cancelar desde la app sin pagar.
Continuación: capturas Android 1000343895 y 1000343899 muestran solicitud de cancelación del alta y después alta detenida/intento vencido sin pago confirmado. Base confirma cancellation_requested_at 2026-09-25T15:45:30.57345Z, activación expired, reserva expired, reserved_cents 0 y cero suscripciones del donante. Stripe confirma la misma sesión expired/unpaid, PaymentIntent null y subscription null. Queda acreditada cancelación de alta abandonada y liberación sin pago; esta expiración fue provocada por cancelación, no por alcanzar el plazo natural. La pantalla terminal aún conserva el aviso transitorio «Solicitud recibida. Consulta el estado para confirmar su aplicación»; pendiente limpiar ese mensaje también al terminar una cancelación de alta (la corrección anterior sólo contempla plan canceled).

Verificación visual posterior: captura Android 1000343972 confirma Alta detenida e Intento vencido sin pago confirmado, sin el aviso transitorio Solicitud recibida. Coincide con la corrección fc4a6ef, validada por Flutter analyze, 51 pruebas y CI 36156881343. La captura no contiene número de build; queda por cotejar la nueva compilación firmada en Codemagic.

Build identificado por captura del titular 1000343974: Codemagic 6ab69f12bbba44dc026a34ef, status finished, duración 6m49s, workflow Dopmi Guardián — Google Play interno, rama codex/stripe-transfer-delivery, commit 9cb3f5f. Git confirma SHA completo 9cb3f5fb420aabb97e1b692c5ad075bf0c0bb77b y que contiene fc4a6ef (corrección del aviso), cuyo CI 36156881343 aprobó cuatro jobs. Se vincula con la instalación reportada por el titular y captura Android 1000343972. El índice 3 de Codemagic no es el versionCode Android; esta captura no muestra versión ni número del artefacto, ni detalle de publicación. Identidad del build/commit acreditada sin inventar esos campos.
## Cambio cerca del aniversario y retiro — 25 de septiembre de 2026

Reloj clock_1UJaEp2ZjyMOQ0uLL5n6YZe1 avanzado a 1803565236, ready, 33 segundos antes del fin de período 1803565269. Plan sub_1UJa0n2ZjyMOQ0uLrY1yEBLv activo por 5000, misma factura de enero. Solicitud móvil 1d4874c7-7fa8-4a22-9e2d-a18975042acf, creada 16:35:12.495147 UTC, cambio 5000 a 20000, revisión 3: servidor pending/near_anniversary, can_withdraw true; captura 1000343980 coincide y mantiene importe anterior. El titular retiró la solicitud; servidor withdrawn a las 16:37:55.87267 UTC, revisión de plan 4, pending_request null, gross_cents 5000. Stripe independiente mantiene active, precio 5000 y misma última factura in_1UJb5P2ZjyMOQ0uLpGC8VV9g. Captura 1000343982 vuelve al formulario de 50 sin consentimiento seleccionado. Pendiente cruzar el aniversario y verificar cobro único del importe conservado. La captura conserva aviso transitorio Solicitud recibida tras el retiro: mejora visual pendiente, sin alterar el resultado autoritativo withdrawn.
Continuación tras retirar monto: reloj avanzado una hora a 1803568836, ready (25/2/2027 09:20 GMT-6). Stripe confirma factura in_1UJcIa2ZjyMOQ0uLv98a7s6r paid, total/amount_paid 5000, attempt_count 1. Historial autenticado registra ciclo 7fcdb931-da82-42fb-9a51-7c96b6aca1a9, período 25/2–25/3, transferred, comisión 100, costo Stripe 586 y neto asignado/transferido 4314, una asignación. El cambio retirado de 200 no alteró el importe del nuevo ciclo; meses omitidos siguen omitidos. Captura Android 1000343984 confirma ciclo 25/2/2027, siguiente aniversario 25/3/2027, autorizado/pagado 50.00 MXN, comisión 1.00, costo Stripe 5.86 y neto asignado/transferido 43.14. GET independiente de Stripe confirma transferencia tr_3UJcIv2ZjyMOQ0uL1WRW0w9B por 4314, test, no revertida. Queda completo este recorrido integrado de cambio cercano al aniversario, retiro y renovación con importe anterior; no acredita otros escenarios de fin de mes o escrituras inciertas.
