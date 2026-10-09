# Vinculación social — encargo del 9/10/2026

Estado vigente: IMPLEMENTADO_DEV_DESACTIVADO_CONFIGURACION_META_PENDIENTE.
El registro actualizado al final supersede la preparación histórica de consola.
Este encargo nuevo no modifica la referencia congelada dde1bb9 ni acredita
el pendiente SMS de Play308. No requiere repetir su QA válida.

## Decisión del titular

Facebook e Instagram se conectan desde una cuenta Dopmi ya autenticada para
demostrar control de la cuenta social. No son métodos nuevos para acceder a
Dopmi ni sustituyen su revisión de identidad/documentos o aprobación de perfil.
Instagram personal mantiene enlace y revisión manual; OAuth se ofrece para
cuentas profesionales (Empresa/Creador). Decisión respondida expresamente.

## Consola comprobada

- App existente DopMi:1156849688851390, publicada, Facebook Login disponible.
  public_profile/email muestran «Ya se puede publicar»; user_link no añadido.
  Esto no prueba el nuevo flujo ni aprobación de permisos adicionales.
- Redirección existente de Facebook a Firebase:
  https://dopmi-e3b6a.firebaseapp.com/__/auth/handler. Conservarla y conservar
  la integración anterior; no reenviar OAuth a ella para verificar en Supabase.
- «Añadir casos de uso» de esa app sólo ofrece anuncios; Instagram no aparece.
  La propia consola indica crear otra app para casos incompatibles.
- Nueva alta preparada, NO creada: «Dopmi Verificación Social», porfolio DopMi
  con verificación de empresa completada, caso «Administrar mensajes y contenido
  en Instagram». Es el nombre general del producto: no autoriza solicitar lectura
  de mensajes, publicaciones, comentarios, anuncios ni administración de contenido.
- Resumen final exige aceptar Condiciones de plataforma/Políticas de Meta.
  Crear está pendiente de confirmación expresa del titular. No se concedieron
  permisos nuevos ni se cambiaron callbacks, roles, secretos o la app anterior.

## Implementación prevista y requisitos de seguridad

1. Botones Conectar Facebook/Conectar Instagram profesional dentro del perfil.
   Instagram personal conserva edición de enlace con etiqueta de revisión manual.
2. OAuth dedicado a vinculación; no usar signInWithOAuth/linkIdentity para crear
   una nueva vía de inicio de sesión en Dopmi. UUID y sesión Dopmi se conservan.
3. Inicio autenticado en servidor, state aleatorio de un uso con caducidad y
   vinculado al actor/proveedor/intento; callback HTTPS exacto. Cancelación y
   cambio de sesión no vinculan nada. Consumo atómico evita replay y carreras.
4. Servidor intercambia código y comprueba identidad/proveedor/aplicación.
   El cliente no puede escribir una bandera «verificado». Secretos/tokens fuera
   de app, URLs de retorno, logs y Git. Minimizar datos y retención de tokens.
5. Guardar evidencia privada de proveedor/ID/fecha; impedir apropiación de una
   cuenta ya vinculada a otro actor. No inferir propiedad de un enlace escrito
   manualmente a partir de una autenticación que no devolvió ese enlace.
6. La publicación del perfil sigue snapshot y moderación existentes. Revocación,
   desconexión y eliminación de cuenta retiran la evidencia correspondiente.
7. Permiso mínimo: perfil básico. Evaluar user_link sólo si Meta lo aprueba y
   es necesario para certificar la URL de Facebook; no pedir email por defecto.
   Instagram: comprobar instagram_business_basic en el producto nuevo antes
   de configurar el flujo. Publicación/revisión de Meta separadas de QA propia.

## Siguiente acción

Confirmar el alta preparada que acepta condiciones de Meta; después revisar
permisos reales del producto, preparar backend y callback de DEV y configurar
su URI exacta. No activar credenciales ni callbacks sin endpoint comprobado.
Verificar únicamente el nuevo flujo (éxito/cancelación/denegación, state caducado
o repetido, cambio de sesión y conflicto de propiedad), después gate obligatorio
y candidato instalado. No afirmar que configuración de consola implementa UI.

Fuentes: consola Meta autenticada del titular y colección oficial de Meta
[Instagram API](https://www.postman.com/meta/instagram/collection/6yqw8pt/instagram-api).
La documentación directa de developers.facebook.com respondió429 durante esta
consulta. Limitación profesional corroborada por la colección; permisos exactos
y revisión siguen pendientes de inspección del producto nuevo.

## Actualización vigente — 9/10/2026

Fuente implementada y subida: a9418154a964a02043ecb4f03f0b8c98b88c5aa2,
remoto codex/design-foundation comprobado. App creada tras autorización expresa y
reautenticación del titular: Meta ID2033254194048655, Instagram Client ID1653707599767005,
nombre Dopmi Verificación Social. No publicada. instagram_business_basic muestra
«Añadir»: pendiente. Su alcance incluye perfil y multimedia; el servidor sólo
consulta ID/usuario/tipo de cuenta. No solicitar mensajes/comentarios/publicación.
No se revelaron/copiarion secretos ni se modificaron callbacks o roles.

Cliente implementado: pantalla Redes sociales, navegador externo, comprobación
explícita al volver, cancelación/desconexión; sin polling. Actor y sesión estables,
URL de proveedor validada. Instagram personal conserva edición/revisión manual.
Servidor: state con hash de un uso, caducidad10min, consumo atómico y sesión Dopmi;
cinco inicios/10min, identidad social única, intercambio sólo servidor sin guardar
tokens, callbacks firmados Meta, revocación y eliminación idempotentes. No modifica
Auth identities/teléfono, snapshots públicos ni moderación.

Revisión independiente de código/seguridad backend↔cliente: corregidos replay de
revocación que podía retirar una reconexión y carrera antes de la primera prueba;
en cliente, cambio de sesión y cancelación si falla apertura. Advisors DEV sólo
INFO esperado para tablas RLS privadas sin policies, ACL anon/authenticated cerradas.
No inferir autorización de metadata editable ni verificación de URLs manuales.

UI/UX: captura sintética320px/texto200% con Inter revisada, título reducido a
«Redes sociales» para evitar truncamiento; controles alcanzables con scroll.
No acredita teléfono, nuevo mockup ni aprobación de Irlanda. Eficiencia: cola Flutter
única/agente backend acotado/revisión cruzada, QA previa reutilizada, sin otro build.

Evidencia técnica válida: seis pruebas backend con subcasos SQL/PGlite y Deno check
de tres entrypoints; cuatro pruebas funcionales Flutter y doce de enlaces manuales;
prueba final320px/200%; analyze sin observaciones; config móvil16/16. OneDrive bloqueó
unit_test_assets: copia exacta Temp/dopmi-social-mobile-dskvruky, pub get offline,
sin borrar trabajo ajeno. Exportación de captura se corrigió con runAsync y
scrollUntilVisible para hijos perezosos. Captura privada .tools/meta-social/social-320-200.png,
no disponible en GitHub. No repetir pruebas válidas por estos fallos de harness.

CI automático [37991530876](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/37991530876)
en curso al registrar, fuente a941815; push37991525217 cancelado por concurrencia.
Consultar conclusión antes de build, sin dispatch duplicado.

Backend sólo DEV ohqxranynackjignryep: migración local20261009205039 aplicada una
vez como remota20261009210425 (hash/mapeo en migration-history-audit.md). Cuatro tablas
RLS sin SELECT anon/authenticated, cinco RPC sin EXECUTE anon/authenticated, cuerpos
SQL comparados y cero filas. Funciones social-verification, social-verification-callback
y social-verification-meta ACTIVE v1, verify_jwt=false con autorización propia.
Postflight HTTP: list sin sesión401, callback con state no emitido400, delete
Instagram sin configuración503. Sin tráfico de usuario/SMS. Producción intacta.
No secretos Meta ni SOCIAL_VERIFICATION_ENABLED=true configurados por este encargo.

| Criterio | Estado |
|---|---|
| Implementado | a941815, cliente/backend |
| Verificado técnicamente | Dirigidas válidas; CI integral en curso |
| Backend desplegado | DEV desactivado |
| Meta | App creada; permisos/callbacks/secretos/revisión pendientes |
| Play nuevo | Ningún build nuevo |
| Dispositivo | Último84687bb / Play2.3.3(308), Samsung Vending; Meta no probado |
| Aprobación humana | Decisión funcional/creación sí; aceptación del flujo no |

Siguiente acción exacta: confirmar transferencia de secretos Facebook/Instagram al
servidor Supabase DEV y alta sólo instagram_business_basic; registrar callback
https://ohqxranynackjignryep.supabase.co/functions/v1/social-verification-callback
conservando Firebase. Deauthorize/delete bajo /functions/v1/social-verification-meta/
{facebook|instagram}/{deauthorize|delete}. La política de navegador exige confirmación
por transmisión de credenciales/ampliación de acceso; nunca pedir secretos en chat.
Después comprobar contrato real Graph v24.0 y OAuth con cuenta profesional controlada,
consentimiento/cancelación/denegación/revocación y requisitos de revisión Meta.
Antes de uso general resolver retención física: intentos/recibos tienen caducidad
lógica pero no job de purga; tombstones se limpian en próximas revocaciones. No
presentarlo como resuelto ni desplegar limpieza global. Con gate y configuración
real válidos, candidato android-guardian-internal, publicación y QA en teléfono.
La QA SMS incorrecto/reenvío de Play308 sigue pendiente con Irlanda.
**Entrega pendiente: retomar este encargo, sin iniciar otro delta.**

### Configuración autorizada en curso

El titular autorizó expresamente permiso mínimo, callbacks y secretos sólo en DEV.
instagram_business_basic añadido, estado «Listo para prueba». Callback OAuth DEV
y URLs Instagram deauthorize/delete guardados; consola confirmó guardado correcto.
La URL de ejemplo que genera Meta incluye scopes amplios por defecto: no copiarla;
el servidor construye su URL únicamente con instagram_business_basic.
Meta exige reautenticación personal para mostrar secreto Instagram: pendiente del
titular, ningún secreto transferido todavía. Facebook conserva configuración previa.

CI37991530876 detectó auth.sessions ausente en el bootstrap PGlite antiguo de
payments/legacy que aplica todas las migraciones. Corrección exclusiva de fixture
añade tabla de sesión con FK/owner/not_after; no cambia producto ni migración.
Suite tools/verification completa ejecutada una vez:638/638 PASS, cero omitidas.
El commit de fixture requiere nuevo gate automático; no repetir checks locales válidos.

Último corte de repositorio1efe72cd69f0e3e44dfe30f42324879a5add6b9b, subido y
remoto comprobado; producto sigue equivalente a941815 (sólo fixture/documentación).
Tras reautenticación personal, secreto Instagram guardado exclusivamente en Edge
Function Secrets DEV junto con SOCIAL_INSTAGRAM_CLIENT_ID, SOCIAL_FACEBOOK_CLIENT_ID,
SOCIAL_VERIFICATION_CALLBACK_URL y SOCIAL_VERIFICATION_ENABLED=false; guardado
confirmado por consola. No se escribió secreto en archivos/Git/chat/logs.
Facebook solicita reautenticación independiente: secreto Facebook aún no transferido,
callbacks Facebook aún pendientes. Conservar Firebase y las demás configuraciones.
No copiar la URL de ejemplo generada por Meta con scopes amplios.

Actualización posterior a reautenticación Facebook: SOCIAL_FACEBOOK_CLIENT_SECRET
guardado en Edge Function Secrets del mismo DEV, comprobado por su registro en
consola; secretos nunca escritos en archivos/Git/chat/logs. Callback OAuth DEV
añadido junto al Firebase anterior y deauthorize Facebook guardado; confirmación
«Se han guardado los cambios». HTTPS/modo estricto conservados. Activación false.
Captura privada .tools/meta-social/facebook-dev-config.png, no disponible en GitHub.

Eliminación Facebook conserva instrucciones anteriores de la app publicada:
https://www.dopmi.app/comming-soon. No reemplazar silenciosamente por /facebook/delete,
que elimina sólo evidencia social y no los datos del flujo anterior. La ruta nueva
existe pero no está registrada en Meta Facebook. Resolver compatibilidad de ambas
responsabilidades antes de uso general; no hay excepción aprobada a eliminación.
Instagram sí tiene OAuth/deauthorize/delete nuevos registrados.
Próximo requisito externo: cuenta Instagram profesional controlada y aceptación
de rol tester; solicitud al titular pendiente. No se concedieron roles ni se
generaron tokens de usuario. Integración OAuth real y nuevo candidato Play pendientes.
Gate exacto del fixture1efe72c: CI37993212803, automático; no repetir dispatch.

Cuenta profesional controlada proporcionada por el titular e invitación autorizada
como Evaluador de Instagram únicamente en app2033254194048655. Meta confirmó estado
Pendiente; falta aceptación desde Instagram → Aplicaciones y sitios web → Invitaciones
de tester. Cuenta concreta/captura se mantienen privadas en
.tools/meta-social/instagram-tester-pending.png (no disponibles en GitHub).
Primer envío no guardó selección; seleccionar explícitamente la coincidencia exacta
del desplegable resolvió el formulario. No reenviar invitación ya pendiente ni
conceder rol Desarrollador/Administrador para probar. OAuth aún no verificado.

Aceptación de tester comprobada en Chrome del Samsung: «Autorizado por ti el
9 de octubre de 2026». El titular pulsó Aceptar personalmente. En Instagram nativo
no aparece la pestaña de invitaciones: ruta fiable Configuración → buscar «sitios»
→ Permisos de apps y sitios web → Apps y sitios web sólo muestra tres estados.
Usar en navegador https://www.instagram.com/accounts/manage_access/ con sesión de
la cuenta controlada → Invitaciones de prueba. ADB usado con autorización explícita
para navegar; no capturar contraseñas ni códigos. Captura privada
.tools/meta-social/instagram-tester-accepted.png, no disponible en GitHub.
Esto acredita rol de tester, no OAuth de Dopmi ni aceptación del producto.

Gate FULLCI37993212803 completado SUCCESS en sus cuatro jobs sobre1efe72c:
web/base de datos, Flutter/Android, iOS e integración identidad/adopción. Se reutiliza
para candidato1879d7d9793e5a2e42477d1618cb1396813d77c0: diferencia sólo documental,
producto equivalente a941815. Codemagic6ac960211a4f58756e2f8efd enviado una sola vez,
workflow android-guardian-internal, índice48; inicialmente queued. No acredita aún
compilación, publicación, instalación ni OAuth real. Consultar ese mismo job;
no reenviar por espera. Tester aceptado; activación DEV sigue false hasta QA real.

2026-10-09 — titular solicita repetir workaround por demanda del ticket21219.
Anterior6ac960211a4f58756e2f8efd confirmado canceled/sin inicio antes de reemplazar.
Nuevo6ac96931a20af0c26fabf6c0, android-guardian-internal/M2: API confirma
Xcode26.5 mediante dynamicConfig.environment.softwareVersions.xcode y fuente
75e79f1752e1b72f915bb0887d3ec8d915f6a9af. Sólo documentación difiere del candidato
1879d7d; producto/gate1efe72c sin cambios. Inicialmente queued; consultar únicamente
nuevo handle. No cambiar YAML ni repetir CI válido. No acredita aún arranque o Play.
Incidencia transitoria de red después de cancelar: reconciliada con GET
api.codemagic.io/builds/{id}, que confirmó cancelación; POST nuevo realizado una vez.
Journal privado .tools/meta-social/cm-xcode265-submit.json, no disponible en GitHub.

2026-10-09 — candidato310 publicado e instalado desde Play, acceso social fallido.
Codemagic6ac96931a20af0c26fabf6c0 terminó16:43:54 México con todos los pasos
success. Publishing confirma internal/completed/versionCode310/2.3.3 y posterior
tracks get coincide. AAB SHA256
11e12a44ccaf9b12bdbfc9d75e1eaa17b9a441379dcbc245a21d1cec22dfa486.
Samsung ADB comprueba com.mycompany.dopmi2.3.3(310), installer com.android.vending;
sesión conservada. Fuente75e79f1, producto a941815. No aceptación humana global.
QA nueva encontró un defecto material: RescuerSocialSection quedó sin referencias
tras cambios previos del perfil; el botón existía sólo en widget sin montaje.
Revisión anterior de pantalla aislada no cubrió navegación desde perfil real.
Corrección mínima en RescuerProfileHero: botón propietario autenticado abre
SocialVerificationScreen; no cambia aprobación ni proyección pública/enlaces.
Regresión nueva desde perfil real a320px, escalas1 y2, confirma acceso y una lectura
list, cero start/escrituras.2/2 PASS. Suite social reutilizada5/5 PASS; primer comando
auxiliar falló por copia relativa desde scratch (test nuevo ausente), corregido con
ruta de copia desde raíz; no fallo productivo ni repetición de suites generales.
Flag DEV se habilitó brevemente para QA y se restauró false al descubrir acceso
faltante; digestfalse comprobado. Sin OAuth ni tokens/proofs nuevos. Cambio de modo
Adoptante→Rescatista sólo para llegar al perfil; editor abandonado sin guardar.
Capturas/journals .tools/meta-social privados/no disponibles en GitHub.
Siguiente: gate de corrección, un nuevo Play con overrideXcode26.5 y QA OAuth real;
no probar SMS ni repetir QA dde1 válida.310 acredita instalación, no verificación social.
Análisis dirigido posterior de corrección: cero observaciones. Producto corregido
f71c4440f261b10455eb38b9948fd3d68ef321ca subido/remoto comprobado;
gate automático PR38001865589 pendiente al registro (push38001860198 sujeto a
concurrencia habitual). No otro dispatch ni Codemagic hasta gate verde.

2026-10-09 — gate de acceso corregido38001865589 SUCCESS/cuatro jobs f71c444.
Codemagic6ac9772639c0d173f3b4330a enviado una vez, fuente943dc1c (sólo docs
sobre f71c444), overrideXcode26.5/M2/android-guardian-internal. API confirma inicio
17:22:22 México/preparing; workaround salió de cola. No duplicar ni repetir CI.
Journal/status privados .tools/meta-social/cm-entryfix-{submit.json,status.ps1}.
Publicación, versionCode y QA real todavía pendientes; DEV sigue false.

2026-10-09 — Play311 instalado y OAuth Instagram llega a consentimiento real.
CM6ac9772639c0d173f3b4330a finished17:46:45 México, fuente943dc1c; Publishing
+tracks get internal/completed/versionCode311. AAB SHA256
c380904954f4e5d109b7c09cefa7d7f1fe4db4225e8a349cadfc7fcf65acca97.
Samsung confirma com.mycompany.dopmi2.3.3(311), installer com.android.vending.
Perfil real→Verificar mis redes sociales→Redes sociales aprobado en dispositivo.
Flag DEV true guardado/comprobado para QA; Actualizar estado habilitó proveedores.
Conectar Instagram profesional crea un intento pending (consulta agregada sin PII)
y abre Chrome oficial con consentimiento Dopmi Verificación Social-IG. Scope básico
obligatorio perfil/multimedia; producto consulta sólo identidad. Titular debe pulsar
Permitir personalmente; solicitud pendiente. No consentimiento ni proof atribuidos.
No repetir start mientras intento vigente. Captura privada instagram-consent-play311.png.
