# Billeteras nativas — contrato y avance383

Referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb. Alcance: sección Billeteras digitales y autorización real sin cobro desde Métodos de pago. Se preservan los colores/medidas Source, sujeto a disponibilidad móvil real; no se copia el toast de vinculación simulada.

La base portable native-saved-wallet.mjs tiene12tests factory, backend538/538 y Deno check. NO está expuesta, desplegada ni conectada a móvil. El adaptador SQL requerido aún no existe.

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
- [Flutter Stripe del mantenedor,14.1.0](https://pub.dev/packages/flutter_stripe): publicación actual y requisitos Android/AppCompat/FlutterFragmentActivity, initPK. No paquete instalado todavía.

No cambiar identidad com.mycompany.dopmi/firma, guardas test-only ni flujos Guardian aceptados. Wallets en aportación y tarjeta guardada en Checkout puntual siguen como trabajo separado dentro del objetivo original.
