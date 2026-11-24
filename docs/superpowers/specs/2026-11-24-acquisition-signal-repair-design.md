# Reparación de señales de adquisición

## Objetivo y autorización

El24/nov el titular pidió arreglar el diagnóstico: Meta gastó773.72MXN en las cuatro
campañas revisadas17–23nov sin instalaciones atribuidas; GA tiene cobertura parcial
y Google Ads sí conserva141 conversiones Play. Autoriza la reparación; conserva
campañas, públicos, creativos, presupuestos y la conversión principal de Play.
Se continúa autónomamente bajo la autorización previa de ejecutar el trabajo.

Base estable408fdde5c2a207cb8846474b997114a9b351e877, rama
codex/acquisition-signal-repair-20261124, checkout Meta existente. Incluye b471 y
Tienda442/443. Tutorialedcdd5aa/CI45470332828 se concilia por separado antes de
congelar el candidato; no se pierde Tienda ni se arrastra una CI fallida como éxito.

## Analytics: revisar el legado sin fabricar consentimiento

El servidor ya prueba el recibo vigente con notice_version. has_choice sigue
significando que existe fila; no se cambia su contrato ni se borran históricos.
El cliente distinguirá hasCurrentExplicitChoice. Sin recibo vigente mostrará una
revisión y pausará colección sin resetear la identidad del mismo actor/entorno.
El legado comienza con selección OFF; una ausencia genuina sin veto local puede
proponer ON. Ninguna preselección habilita medición. Guardar usa la RPC con CAS;
abrir/cancelar/error de lectura no escribe ni avanza revisión. Un fallo de red tras
Guardar puede ser ambiguo: se mantiene OFF hasta confirmar, sin reintento ciego.
Un OFF explícito vigente no
vuelve a preguntarse. Se conservan barreras de actor, veto OFF local y diagnóstico.

## Meta: instalación y apertura separadas del valor de adopción

Se usa App Events API oficial v27.0/1156849688851390/activities desde el cliente,
no SDK automático ni Edge anónimo. Autenticación pública AppID|ClientToken en
cuerpo POST HTTPS; ClientToken inyectado, nunca AppSecret/tokenCAPI en la app.
MOBILE_APP_INSTALL representa instalación elegible; CUSTOM_APP_EVENTS contiene
fb_mobile_activate_app/_logTime real. advertiser_id real permitido y extinfo de
16posiciones a2/i2,paquete,build,versión,SO y vacíos. No correo, cuenta, contenido,
ubicación,anon_id,IDFV,SDKversion inventado o datos adicionales.

Permiso Lifecycle por instalación/dispositivo, namespace/entorno y aviso nuevo
meta-lifecycle-2026-11-24, inicialmente OFF, antes de login. Permitir o continuar
sin activar no bloquean la app. Se puede retirar en Cuenta y privacidad. No es el
permiso CAPI de cuenta: Contact/SubmitApplication y su preferencia siguen intactos.
La elección de dispositivo no crea ni altera el permiso CAPI de ninguna cuenta.
No se transfiere entre propósitos, entornos o versiones del aviso.
iOS requiere además ATT.authorized; sin él, ni lectura de IDFA ni envío/fallback.
Android respeta AAID eliminado/limitado. IDs sólo en RAM durante envío autorizado.

Control operativo: nueva RPC pública de sólo lectura dopmi_meta_lifecycle_enabled()
expone únicamente el bool del gate Meta existente. No permite escribir ni ver
preferencias/datos. Se consulta antes de leer ID y antes de POST; fallo/valor
incierto/OFF =>no envío. El cierre del gate controla futuros envíos de ambas rutas;
una solicitud ya despachada puede terminar. No abrir PROD antes de readiness/QA.

Instalación no equivale a update o primera ejecución del código nuevo. Sólo en la
primera sesión observada, sin marca previa y con evidencia conservadora del SO:
Android firstInstallTime==lastUpdateTime; iOS16+ AppTransaction verificada/production
con originalAppVersion igual a CFBundleVersion actual. Update/prueba inconclusa,
iOS15 y sandbox/TestFlight =>sólo Activate. Android no distingue infaliblemente
clear-data/restauraciones; Meta deduplica installs90d y la limitación se documenta.
Rechazar la primera elección/cerrar la primera sesión no deja Install por reenviar.

Una activación por foreground real, con60s de debounce para ATT/cámara/reaperturas.
Persistir marca mínima de intento antes de POST, sin AAID/payload. No reintentar una
entrega ambigua automáticamente ni inventar event_id idempotente. OFF cancela el
transporte dedicado, limpia contexto y revalida revisiones tras cada espera.
El mensaje/registro/subida/navegación nunca esperan que Meta funcione.

## Configuración, privacidad y prueba

Feature explícita META_LIFECYCLE_ENABLED=false por defecto; META_APP_ID fijado al
activo1156849688851390 y META_APP_CLIENT_TOKEN público inyectado/validado, no logueado.
Codemagic habilita con DOPMI_META_LIFECYCLE_ENABLED=true sólo en candidato autorizado;
el recibo muestra estado e AppID, no token. No upgrades Supabase/SDK ni cambios Ads.

Nuevo aviso móvil y público para instalación/aperturas Android+iOS y revocación.
Conservar términos generales. Conciliar Play DataSafety y Apple DeviceID/Product
Interaction publicitarios/tracking antes de público. La aceptación adicional del
panel Meta sólo se solicita si la operación efectivamente la exige.

Salida: pruebas negativas/positivas, regresión integrada exacta, binarios firmados
verificados, actualización Samsung sin falsa instalación, y una instalación limpia
válida con permiso y recepción estándar en Meta. QA sin permiso no envía; reinicio
no repite Install. iOS Install real exige AppStore; TestFlight no se afirma prueba.
No activar campañas de valor hasta que su QA/recepción/público estén confirmados.

## Adenda — registro confirmado antes de la elección de Analytics

El evento actual se descarta si la confirmación de correo o primera aceptación
legal termina antes de resolver la elección opcional. Sólo ese registro confirmado
podrá quedar pendiente en RAM para el mismo actor y proceso, sin colección ni
envío mientras falta consentimiento. ON confirmado lo descarga una sola vez;
OFF, negativa explícita, error, salida, cambio de cuenta o reinicio lo descartan.
Los dos productores conservan su disparador de negocio y pasan el actor confirmado;
no se reconstruyen registros históricos ni se difieren otros eventos. La descarga
ocurre fuera de la cola de configuración/consentimiento, con barreras vigentes.
