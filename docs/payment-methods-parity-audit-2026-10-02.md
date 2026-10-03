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
