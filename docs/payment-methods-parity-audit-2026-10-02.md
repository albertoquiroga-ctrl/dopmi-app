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
