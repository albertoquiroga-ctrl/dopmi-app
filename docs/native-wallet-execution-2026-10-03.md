# Billeteras nativas — contrato y avance390

Referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb. Alcance: sección Billeteras digitales y autorización real sin cobro desde Métodos de pago. Se preservan los colores/medidas Source, sujeto a disponibilidad móvil real; no se copia el toast de vinculación simulada.

La base portable y endpoint tienen20tests factory/API; SQL local90000 tiene11casos PostgreSQL adicionales. Backend557/55725.9189576s y Deno check de tres entrypoints pasan. Endpoint/runtime/worker/webhook integrados localmente con bandera de solicitudes nativas apagada por defecto. Desplegada en DEV: local90000→remote20261003092721, worker27/webhook27/client20 ACTIVE, bundles sin diferencias y25smoke remoto pasan. NO conectada a móvil ni autorizada una billetera real; config PK/MerchantID no acreditada.

Implementación siguiente:

- Extender jobs de tarjeta existentes con wallet_type nullable apple_pay/google_pay. Consentimiento vigente describe guardar tarjeta para apoyos futuros autorizados, sin cargo/activación/default. Clave+proveedor inmutables y customer compartido propietario, mismo advisory lock y guards contra setup/método/altaGuardian concurrentes.
- native_setup persiste SetupIntent sólo bajo lease válido, provider nativo y customer reservado; nunca puede sustituir su id. native_saved exige ese SetupIntent y PM id confirmado, job sin Checkout; constraints separan Checkout normal de nativo.
- claim distingue SetupIntent persistido de operación no iniciada y permite conciliar/cancelar tras vencimiento; nunca expira ciegamente una autorización ya confirmada. native_ready exige cuenta activa/confirmada, job pendiente/SetupIntent esperado/fecha válida/sin lease en curso y serializa con guards financieros antes de exponer clientsecret. No SQL browser/write ni owner/customer editables.
- OwnRPC devuelve provider/receipt mínimo autenticado, sinsecret. Runtime/worker concilian por flow correcto; endpoint authenticado añade add_wallet con key/provider/consent allowlist. No cliente SDK success como prueba final: ownreceipt+lista fresca antes de mostrar vinculación.
- Cliente nativo sólo ofrece proveedor soportado/listo; preserva UUID local por cuenta y reanuda sin nuevo intento/consentimiento ante cancelación/fallo. Nunca persiste clientsecret ni PAN. Interacción requiere PK test/config real; AppleMerchantID/certificado/entitlement está pendiente de identificar. No suponer listo por plataforma.
- Verificar SQL/RLS/lease/replay/guards, endpoint y servidor/Stripe test, después cliente normal/200% y regreso. La publicación Codemagic permanece sólo para el objetivo global terminado.

Fuentes primarias consultadas3/10/2026:

- [Stripe Google Pay Android](https://docs.stripe.com/google-pay?platform=android): disponibilidad ReadyCallback y presentForSetupIntent; producción requiere aprobación Google, no implica activar dinero.
- [Stripe Apple Pay iOS](https://docs.stripe.com/apple-pay?platform=ios): MerchantID, certificado y capacidad, comprobación del dispositivo antes de ofrecer opción.
- [Flutter Stripe del mantenedor,14.1.0](https://pub.dev/packages/flutter_stripe): publicación actual y requisitos Android/AppCompat/FlutterFragmentActivity, initPK. Paquete14.1.0 instalado en388, requisitos Android preparados; compilación nativa pendiente.

No cambiar identidad com.mycompany.dopmi/firma, guardas test-only ni flujos Guardian aceptados. Wallets en aportación y tarjeta guardada en Checkout puntual siguen como trabajo separado dentro del objetivo original.


Adapter389: NativeWalletSdk sólo pk_test/ENABLE_NATIVE_WALLETS_TEST, AndroidGoogle/iOSApple conMerchantID y no web. Disponibilidad SDK real antesde autorizar, Googletest/existingPaymentMethodRequired, confirmPlatformPaySetupIntent sin PI. ResultadoSDK noesreceipt.7tests adapters/repositorio con callbacks sustitutos pasan; NO prueba nativa real. Config build/entitlement y cliente visual/reanudación siguen pendientes. Apple resumen0.00 para guardar sin cargo, aceptación real aún requerida; no presenta mensualidad ni autorización Guardian. Referencias: docs.page/flutter-stripe/flutter_stripe/apple_pay y google_pay; API local14.1.0 confirma SetupIntent y tiposparams.


Configuración390: write-mobile-config transfiere ENABLE_NATIVE_WALLETS_TEST=true únicamente con --guardian-test y variabletrue. Requiere STRIPE_PUBLISHABLE_KEY_TEST=pk_test; APPLE_PAY_MERCHANT_ID opcional para Android y necesario para ofertaApple en adapter. Sólo nombres/metadatos aquí, ningún valor real.16tests config pasan; feature no habilitada ni variables remotas configuradas. Identificar configuración existente antes de añadir MerchantID/entitlement/certificado.
