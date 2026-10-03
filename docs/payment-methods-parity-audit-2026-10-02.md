# Estado vigente — loop370, 3/10/2026

ClienteAgregar independiente conectado (consentimiento/key/recuperación owner-scoped/retorno/lista confirmada/toast2600),58/58 dirigidas/analyze limpio/capturas4normal200%,320/37 inventario. Servidor369DEV cliente18/worker25/webhook25 y21smoke verificados. AuthCheckoutpositivo/Stripe real todavía pendientes; capturas no dispositivo. Composición aún sinbilleteras y enlacesauxiliares extraSource; default/remove sinGuardian y uso de cardguardada en apoyo puntual pendientes. No paridadglobal/aceptaciónIrlanda; CM únicamentefinal.

## Corte369 anterior

# Estado vigente — loop369, 3/10/2026

Alta independiente desplegada en DEV: local70000/71000→remote65211/65233; worker25/webhook25/cliente18ACTIVE y17/16/16archivos0mismatches. Guards/ACL/RLS comprobados,21smoke real5.77s. Endpoint/lista nonsuscrito ycustomercompartido en servidor; UIAgregar/retorno y AuthCheckoutreal todavía pendientes. No anunciar aceptación completa. Default/remove sinGuardian, billeteras y matrizglobal siguen abiertos. Codemagic únicamente final.

## Corte368 anterior

# Estado vigente — loop368, 3/10/2026

Servidor local de alta independiente ahora incluye endpointallowlist, lookup de cliente nonsuscrito, reader real y runtime/cron/webhook. AltaGuardian comparte customer guardado y serializa solicitudes para evitar duplicar cliente.503/503 backend24.41s y Deno3entrypoints limpios. Migraciones70000/71000 y Edge NO desplegados aún; UIAgregar y aceptación Auth/Stripe real pendientes. Default/eliminación para cuentas sinGuardian todavía no implementados; billeteras y matrizglobal abiertas.

## Corte367 anterior

# Estado vigente — loop367, 3/10/2026

Eliminación real aislada Stripe365 confirmada sin segundo detach/cobros y cleanup completo; Auth/SQL integrados siguen pendientes. Feedback366 implementado, confirmado por lista nueva y sin replay/histórico; toast2600ms, eliminación sin popup visual, anuncio accesible.44dirigidas y capturas/analyze documentados; commit29d37df.

Alta independiente: base local de registro/jobs SQL y saved-card.mjs,494/494 backend26.50s con19casos nuevos SQL/servicio. Aún NO desplegada/cableada: identidad de customer coherente con futura altaGuardian, endpoint/lista nonsuscritos/runtime/worker/webhook/UI y aceptación real pendientes. No presentar el botón como terminado. Billeteras reales y matrizglobal/aceptación permanecen abiertas. Codemagic únicamente final.

## Corte363–364 anterior

# Estado vigente — loops363–364, 3/10/2026

Eliminación desplegada en DEV: migraciónremota20261003055326/local60000, worker24/webhook24/cliente17ACTIVE y bundles0diferencias. Cliente8b7798a conecta trash real, confirmación, estado propietario y reintento sin desaparición optimista.42 pruebas dirigidas y analyze limpio;4capturas revisadas normal/200%,314estados/37URLs. Sourcefeedbacktoast2600ms aún pendiente; estado actualNotice no equivale paridad completa. La prueba Stripe aislada real de eliminación y Auth integración siguen pendientes. Alta independiente/billeteras tampoco se completaron. Codemagic sólo candidato final.

## Corte362 anterior

# Estado vigente — loop362

Lectura propietaria y selección predeterminada están desplegadas en DEV (351–357); cliente353/358 y recuperación360 implementados. Servicio selección real en fixture cero361 confirmó calendario y recuperación sin segundo update, sin Auth/SQL integrados. Eliminación segura implementada en servidor local20db360:475pruebas backend aprobadas22.44s, Deno limpio, aún sin migración/Edge remotos ni icono cliente. No interpretar el inventario350 siguiente como estado actual.

Pendientes: despliegue de eliminación en todos sus consumidores, trash Source/confirmación/reintento/200% con respuesta real; alta independiente para no suscritos y guardado sin cambiar el medio activo; capacidades reales de billeteras; aceptación autenticada/instalada. Dinero test-only, sin legado/CM/push intermedios.

## Auditoría histórica350

# Métodos de pago: brecha real, loop350

Referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb.
Código inspeccionado755c67d. No aceptación completa ni cambio financiero remoto.

## Evidencia de implementación

- guardian-client.mjs admite sólo checkout/method, requiere actor Auth confirmado y flags completos. Ignora identificadores financieros suministrados por cliente; no tiene operación de listado.
- guardian-method.mjs crea Checkout mode setup con customer del trabajo privado, comprueba livemode=false/owner, confirma SetupIntent y actualiza la suscripción con calendario intacto. Es una actualización del medio activo, no una cartera general ni una eliminación de tarjeta.
- guardian-runtime.ts usa Stripe22.6.0/API2026-08-26.dahlia y requireTestKey. No actualizar versiones ni reemplazar este proceso aceptado para presentar tarjetas.
- dopmi_guardian_subscription_server lookup exige stripe_subscription_id; no ofrece lookup privado por actor para esta nueva lectura. Registry almacena stripe_customer_id privado. Estado móvil RPC no expone tarjetas/brand/last4.
- payments.mjs aportación puntual crea sesión payment sin customer ni setup_future_usage. No acredita tarjetas guardadas tras una aportación. No inventar esa lista ni convertir consentimiento puntual en autorización para guardar.
- Las tablas históricas payment_methods están archivadas en dopmi_legacy, sin acceso; no restaurarlas.

## Siguiente unidad implementable

Primero lectura privada de métodos del cliente Guardian existente: PostgreSQL deriva customer desde actor autenticado/activo, endpoint servidor no acepta customer/pm/subscription arbitrarios, Stripe sólo test y coincidencia de ownership/livemode. Respuesta minimizada brand,last4,exp_month/year,wallet y predeterminado confirmado; excluir billing_details, direcciones, fingerprint, secrets y metadatos. Sin cliente confirmado, lista vacía; errores recuperables no se presentan como lista vacía. Tests actor inválido/ajeno, live rechazado, respuesta mínima y lectura sin mutación, antes de deploy.

Esta lectura no completa Agregar/Hacer predeterminada/Eliminar. Después adaptar operaciones existentes bajo revisión/idempotencia y comprobar que eliminar no desconecte el método de cobro activo o trabajos en vuelo. Las acciones no podrán indicar éxito antes de confirmación servidor. Para no suscritos hará falta registro de cliente y SetupIntent independiente con consentimiento explícito, no activación automática de Guardian. Verificar historial remoto real antes de migración: correspondencias locales/remotas difieren.

## Billeteras

Source simula Apple Pay/Google Pay vinculados. Esa simulación no prueba una API de vinculación de wallet. Stripe documenta disponibilidad por superficie/dispositivo y setup de métodos para uso posterior. Implementar la capacidad real ofrecida por Stripe y comprobar retorno/estado, sin un toast de vinculación ficticia. La interfaz debe conservar composición cuando la capacidad real esté disponible; capturas sintéticas no la acreditan.

Documentación oficial leída350: [listado](https://docs.stripe.com/api/payment_methods/list), [SetupIntent](https://docs.stripe.com/api/setup_intents/create), [Checkout setup](https://docs.stripe.com/payments/checkout/save-and-reuse?payment-ui=stripe-hosted), [Apple Pay web](https://docs.stripe.com/apple-pay?platform=web), [Google Pay web](https://docs.stripe.com/google-pay?platform=web). Las tres últimas devuelven200 mediante urllib Accept text/markdown; web herramienta falló variantes.md. Skill Stripe payments reference local leída. No claves/cuentas/datos reales consultados ni cambios de API/schema/flags.


### Loop371 — Auth y Checkout reales para Agregar tarjeta, 3/10/2026

Referencia remota a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Fixture desechable Auth confirmada en DEV y customer Stripe test, sin cuenta humana: login real, consent/allowlist inválidos400, RPC privado403/42501, lista vacía antes de alta, mismo key devuelve la misma sesión pendiente. Checkout hosted completado por UI con Visa sintética4242; SetupIntent succeeded/off_session, sesión setup/test sin payment_intent ni subscription. Endpoint real devuelve saved/card_id y ownstate coincide; methods una tarjeta4242, defaultfalse y siete campos minimizados. Replay saved idéntico. Gate acceptance verify exit0/b2c4f0 5.46s; charges/PaymentIntents/invoices/subscriptions0.

Chrome volvió a payment-return pero mostró ERR_BLOCKED_BY_CLIENT; PNG checkout-return-blocked conserva evidencia. GET independiente200/textplain/no-store y CSP sandbox no demuestra retorno visible correcto ni identifica la causa. No se desactivaron protecciones/extensiones. Corregir/investigar retorno antes de cerrar recorrido; alta server integrada probada, no aceptación instalada.

Limpieza Stripe verificada deletedtrue (cleanup exit0/869d9f), SQL propia protegida por UUID/email/job/key y ausencia de filas financieras: Auth/identidades/sesiones/refresh_tokens/jobs/wallet0. Profiles no cascada desde auth.users: se observó1 y eliminó explícitamente sólo UUID fixture; comprobación final0. Journal externo limpio, contraseña retirada; ningún secreto/captura con tarjeta real comprometido. No producción/flags/cobros/CM/push. Objetivo completo sigue pendiente: retorno, default/remove sin Guardian, billeteras, apoyos con tarjetas y matriz/aceptación global.


### Loop372 — diagnóstico de representación y retorno de tarjetas, 3/10/2026

Previo371 progreso e38a59c: Auth+Checkout Stripe test confirmado y fixture limpio. Referencia a3c969c reconsultada sin cambios. Reproducción local en Chrome controlado: text/plain CSPdefaultnone+sandbox bloqueado; mismo texto con sandbox allow-same-origin bloqueado; mismo texto sólo defaultnone también bloqueado. HTML con sandbox/defaultnone abre y muestra contenido. Esto contradice atribuir el fallo exclusivamente a sandbox; apunta a manejo de MIME en este entorno, sin identificar extensión/causa exacta ni demostrar defecto en Android. No se desactivaron protecciones, no se cambió CSP y no se afirmó retorno instalado aceptado. Tres servidores locales terminados por sus handles29963/35069/44564.

Retorno agrega instrucciones reales Perfil > Métodos de pago, consultar el mismo intento y guardar sin cobro/activar Guardian. Supabase dominio estándar continúa text/plain, sin HTML/deep-link inventado ni confiar en parámetros. Deno check exit0/dbdf48 3.06s. Preflightpayment-return9ACTIVE únicoarchivo coincidefuente; deploy sólo éste en DEV a10ACTIVE, verify_jwtfalse previo conservado, cuerpo posterior coincide CRLFnormalizado. HTTPsmoke21/21 exit0/a9ab24 5.82s incluyendo copia nueva/CSP/no-store/nosniff. No schema/flags/Stripewrite/PROD/CM/push. Loop371 confirmaalta servidor, retorno visible en browsercontrolado queda limitado; aceptación teléfono y resto objetivo pendientes.


### Loop373 — actualización por gesto en Métodos de pago, 3/10/2026

Previo372 progresof654bbf: retorno10DEV y diagnósticoMIME. Referencia remota a3c969cd9103fd46dc5cd886999912526ce75efb sin cambios. Métodos agrega RefreshIndicator negro/blanco sobre listaAlwaysScrollable: permite consultar el estado propio deslizando incluso lista corta/vacía, bloquea lectura desde gesto mientras busy/confirming o identidad obsoleta. Reusa load existente, no crea Checkout/consent/key ni anuncia éxito optimista. Composición en reposo, confirmaciones y feedback permanecen; botónActualizar y enlaceGuardian extrasSource aún pendientes junto billeteras, default/remove sinGuardian y uso tarjeta en apoyo puntual. Es adaptación de actualización al teléfono, no prueba de un gestoidéntico del mockup web.

Primer comando fue lanzado desde scratch con rutas relativas de repo incorrectas: format/copy fallaron, test viejo detenidohandle93736 y no computado. Sincronizados los dos archivos propios, test50 primero49pass/1fail porque drag400 bajo viewport artificial2400 no alcanzaba umbral;900 pasó50/50 10s handle96816/exit0. Prueba final usa390x852/drag400 y comprueba una lectura adicional, calls0/opened0/emptyreal; focused1/1 1s handle48447/exit0. Analyze limpio41.4s61658/exit0 sobre mismo códigoapp. No captura visual nueva/aceptacióndevice/fullnuevo, suite504/359 antecede373. Sin backend/schema/flags/Stripe/CM/push. Goal completo sigue abierto.


### Loop374 — composición de tarjetas contra Source, 3/10/2026

Previo373 progreso45de3ab. Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada; CSS content-pad20/16/32 y list-stackgap10, PaymentMethods sin enlaceGuardianextra. Cliente ajusta heading/filas/Agregar a10 y paddinginferior32; elimina enlace secundario Guardian sólo en Métodos, acceso real Perfil > Suscripción y pagos conservado. Actualizar estado aún extraSource; billeteras/default-remove sinGuardian/apoyo cardguardada pendientes, no pantalla completa declarada.

50/50guardian10s handle18944/exit0 despuésespacios antesquitarenlace. Capturador final filtro payment-methods-cards exit0/80981 6s; normal377x852 y320/text200% guardadasparity-loop374 y ambas inspeccionadas. Lista realwidget condatos sintéticos, íconos/acciones/consent/feedbackcapturados por filtro sinoverflow; no teléfono. Capturas muestran billeteras faltantes y Actualizar extra, no ocultar brechas. Analyze final limpio25.9s handle47417/exit0. Sin backend/flags/dinero/CM/push. Continúa objetivo completo.


### Loop375 — base de acciones independientes de tarjeta, 3/10/2026

Previo374 progreso030bb70. Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. Nuevo saved-card-method.mjs local: jobserverpropio/claimlease/snapshot/writeauthorization/prooffresh/release, rechaza subscription_id para conservar flujoGuardian. Default actualiza sólo customer.invoice_settings.default_payment_method; remove desvincula únicamente cardtestpropia sin uso/default. Suscripciones activas bloquean default; facturasdraft/open y PaymentIntentsen curso bloqueanuso, factura con método heredado aún no resuelto bloquea eliminación. Listadospaginados/incoherentes fallan cerrado; live/foreign/noncard rechazan. No crea ni paga facturas/PaymentIntent/subscriptions ni Checkout. Key estable porjob; trasrespuesta aceptada perdida consulta propiedad/default/detach y no repite write.

13tests nuevas adaptadorcheckpoint yStripefake: exactmutation, lostresponse/replay, owned/live/noncard, cancelanteswrite/expired, uso/sub/invoice/PI, incompletepage y rechazoGuardian. Primer12/12 dirigido6058bc antesguardinvoiceheredada; fullfinal516/51627.23s3050/exit0 incluye13 y todasmigracionesSQL previas. Deno check móduloexit0/22e0f1, no entrypointruntime nuevo porque aún no importado.

Esta base NO está conectada/desplegada y no acredita acciones de cuentas sinGuardian enapp. Siguiente contratoPostgreSQL con registryowner/confirmed/RLS/ACL/sharedlock ambasdirecciones/intentstable/lease/expiry23h, endpoint allowlist/minimizedstate yreaderfresh, workerreconcile/UI/capturas/AuthStripeacceptance. Nada de dinero real/flags/migración/PROD/CM/push. Móvil full504/359 continúa anterior; objetivo global abierto.


### Loop376 — reservas privadas SQL para acciones sin Guardián, 3/10/2026

Previo375 progreso7696c1d. Referencia a3c969cd9103fd46dc5cd886999912526ce75efb sin cambios. Migración local20261003080000_saved_card_methods nueva: registrycustomer derivado delpropietario, jobsprivados RLS/ACL, key/action/targetimmutable y replay; consentexplicit versionada, owneractivo/emailconfirmada, no cliente browser. CualquierregistryGuardian usa flujoGuardian existente; altas/activacionespendientes bloquean reserva. Locksdopmi-saved-card compartidos y guards añadidos enambossentidos: savedsetup/activación no avanzan sobre methodpending/attention. Rate10/h, lease2min, snapshotanteswrite, autorizaciónjustoantesmutación, comprobaciónde cuenta nuevamente, targetproofexacto para applied/removed. Expiraciónsinwrite y ventana23h despuéswrite→attention, no repetir mutación incierta. Stateauthowner minimizado key/action/status/card_id, sincustomer/session/secret.

Seis testsSQL nuevos: key/targetreplay/browserdenial/otherstaffstate; lease/snapshot/proof; expired/attention23h; methodbloquea setup/activation; reverseguards; confirmaciónrevocadaanteswrite. Toda migración cargada enPGlite. Primer comando ruta incorrecta no contó; filtroNode provocó PGliteclosed enbootstrap y no se usa como gate. Ejecucióncompleta425 primero424pass/1fail por helpersavedCardCall inexistente, corregido a savedCardRpc/activationPrepare. Gate520/52022.39s86352 con4casos; final522/52222.95s19548/exit0 incluyeseis nuevos. gitdiffcheck limpio. No stackDocker/pgTAPnuevo ni aceptaciónremote.

NO aplicada remotamente/endpoint/worker/UI conectado. ServicioStripe375 tiene checkpointadapterfake; SQL376 aún necesita integrarse con servicio y pruebasrespuestaperdida desde RPCreal local, luego preflightdefinicionesremotas/deployautorizado/cliente y fixtureAuthStripe. No migración repair/replay/PROD/flags/CM/push/dinero. Objetivo global sigue abierto, dinero test-only.


### Loop377 — integración SQL/Stripe/endpoint de acciones independientes, 3/10/2026

Previo376 progreso89c9e0e. Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. savedCardMethodService.submit preparaSQL owner/key/consent/action/target y run; devuelve sólo key/action/status/card_id, sincustomer/lease. Reconcile usa candidatesRPC25 y contabilizaapplied/removed/fail. Runtime importa módulo y RPC privado con erroresprepare409tipados; worker invoca sólo bajo flagchangesexistente y cuenta saved_methods_applied. Guardian-client añade acciones saved_card_default/remove, allowlistexactasinrevision/owner/customer, Authconfirmada y nueva consentversion; flujoGuardianaceptado conserva susacciones/revisión/consent. Entrycliente usa mismafunciónruntime testkey/API/flags.

Dos pruebas nuevas integran servicio con RPCPostgreSQL/PGlite real y Stripefake: default/remove aceptados conrespuesta perdida, pendingpersistido, lease liberada, recuperarporlectura y replay sin segunda escritura. ConfirmaciónSQLexacttarget y receiptminimizado; customerbalance0 y cero filasdonación/activación. Otrasdos HTTP cubren allowlist/consent/card/op y cuenta no confirmada sinwrite. Full526/52626.00s75727/exit0; Deno tres entrypoints limpio6.39s192b57 despuésmaperrorprepare. No aceptaciónStripe/Authreal deestasacciones, ni UI nueva.

Migraciónlocal80000 y overlays aún NO desplegados. Próximo preflightfuncionesdefiniciones/historialremoto y aplicar80000una vez, preservarbundlesremotos/flags y verificarRPC/Edge, después accionesmóvil nonsuscrito/default/remove/capturas/fixtureAuthStripe. Sin schema/flags/cuentas/Stripewrite/PROD/CM/push; dinero test-only y objetivo global conservado.


### Loop378 — acciones independientes desplegadas en DEV, 3/10/2026

Previo377 progreso3ffc721 (backend526/52626s/Deno3entrypoints6.39s). Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. PreflightDEVohqxranynackjignryep latest20261003065233/tablemethodausente, fragmentossetup/activationpresentes. Bundlesworker25/webhook25/client18 recuperados, archivosareemplazar coincidenbase89c9e0e normalizandoCRLF. Migraciónlocal20261003080000_saved_card_methods aplicadauna vez como remote20261003075406/saved_card_methods. Post RLStrue/serveranon-authfalse/service_roletrue/stateauthtrue/anonfalse/guardssetupactivationtrue. No repair/replay/rename/dbpush/PROD.

Overlay mínimo yordenworker→webhook→client: worker25→26 runtime reemplazado+saved-card-method nuevo/16otrosconservados/18archivos; webhook25→26 mismo/15otrosconservados/17; client18→19 runtime+handler+indexreemplazados/módulonuevo/13otrosconservados/17. TodosACTIVE verify_jwtfalse previo conservado, autenticacióngetUser/worker-secret/firmadewebhook sigue enentrypointspreservados. GetEdge posterior18/17/17 coincideoverlay0mismatches/0extras. No publicarotroscambiosajenos.

Smokeampliado dosRPC nuevos23/23real7.84s41ac01/exit0: cliente401/worker401/webhook400sinfirma,return200 yserver/stateanónimos401/42501 explícito. No RPCmissing. No Authpositivo/Stripewrite/reconcilepositivo/device acreditados. No flags/cuentas/dinero/CM/push/goalcomplete. Siguecableadoclientepropietario/consent/key/retry/listaconfirmada/accionesnonsuscrito/capturas/fixtureAuthStripe y restoobjetivoglobal.


### Loop379 — repositorio móvil de acciones sin Guardián, 3/10/2026

Previo378 progresoaa9531d; servidorDEV RPC75406/client19/worker26/webhook26. Fuentea3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. GuardianRepository.savedCardMethodState consulta ownerRPC sin identificadorbrowser; receipt exigeUUID/actiondefault-remove/statuscompatible/pmopaque y conserva sólo key/action/status/card_id. submit saved_card_method usa accionesendpointnuevas/key/target/consentversion exacta, sinrevision/owner/customer; response200 ykey/action/cardmatching requeridos, no éxitooptimista. RutasGuardianprevias sincambios.

Trespruebas nuevas HTTPdefault/remove y validaciónreceipt: AuthBearer, bodyallowlist, misma keyreplay, camposprivados descartados y RPCowner sinparams (JSONnull). Primer9test7pass/2fail por MockResponse sinrequestrequiredPostgrest, corregido; luego2expectations{}erróneas para RPCsinparams corregidas a null. Gatefinal59/59(9HTTP+50Guardian)21s96565/exit0, analyze limpio40.3s47892/exit0; scratch dosarchivos propios sincronizados. No fixtureAuthrealnuevo/captura/device/globalfullnuevo.

Esta capa NO habilita todavía botonesnonsuscrito: siguiente loopstateowner/keypersistida/consent/confirmaciones/retry y lista fresh antesfeedback/pérdida de fila. Billeteras, apoyo puntual con tarjeta y matrizglobal siguenpendientes. Sin backend/schema/flags/dinero/CM/push; objetivoactivo.


### Loop380 — acciones reales de tarjetas sin Guardián en el cliente, 3/10/2026

Previo df7c276. Referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada al cierre sin cambios. Ruta Métodos de pago sin registro Guardian habilita predeterminar/eliminar tarjeta no predeterminada mediante endpoint existente de loop378. Consentimiento explícito, UUID y destino conservados por propietario antes de enviar; mismo intento en reintento, recuperación del receipt propietario pendiente y bloqueo de nueva escritura si no se puede consultar el estado. Nunca elimina la fila ni anuncia éxito por respuesta optimista: exige receipt propio terminal y lista fresca compatible. Rutas Guardian aceptadas conservadas. Terminal histórico no repite feedback; rechazo/expiración libera intento con aviso.

Gate final 64/64 (55 Guardian+9 HTTP), 11s, handle25127/exit0; analyze limpio29s handle88099/exit0. Pruebas nuevas default/remove con respuesta perdida y misma key, estado indisponible, recuperación servidor sin almacenamiento local y lista fallida sin éxito prematuro/repetición. Una invocación se lanzó por error desde root sin pubspec; otra nombró archivo HTTP inexistente (55 widgets pasaron pero gate exit1); corregidas, no se cuentan como aprobación. Analyze previo señaló9infos de llaves, corregidos, sin errores. Capturer cuatro estados/3s handle71941/exit0; normal377x852 y320/text200%, sin overflow. Inspección visual detectó palabra partida/título y acciones desalineadas en texto grande; título más corto y acciones centradas, recapturadas/revisadas. Inventario324 estados/37URLs.

No aceptación Auth+Stripe real nueva de default/remove, ni dispositivo. Cuentas con registro Guardian cancelado no cubiertas por rama independiente; wallets reales, tarjeta en apoyo puntual, composición completa y matriz global siguen pendientes. Full móvil504/359 antecede estos cambios; siguiente gate regresión completa. Sin schema/backend/flags/dinero real/CM/push; Codemagic únicamente al completar objetivo global.
