# Verificación social — registro consolidado al cierre, 9/10/2026

**PLAY311_OAUTH_INSTAGRAM_FACEBOOK_VERIFICADO_DEV_CERRADO; entrega pendiente.**
Estado global y siguiente conversación: [checkpoint](mock-sync-current.md).
Este registro sustituye la preparación histórica de consola; no inventaría otro mock.

## Decisión y configuración entregadas

Verificación social desde cuenta Dopmi autenticada, no acceso a Dopmi. Instagram
personal: enlace y revisión manual; profesional Empresa/Creador: OAuth. La evidencia
privada de control social no sustituye identidad legal ni moderación/snapshot público.
Titular autorizó creación/configuración mínima DEV, aceptó tester y consentimientos
directamente en Meta. No compartió contraseñas/códigos. No atribuir aprobación global.

- Facebook existente DopMi1156849688851390, publicada. Flujo nuevo sólo public_profile;
  aprobación antigua email preservada, no solicitada. Callback Firebase legado
  https://dopmi-e3b6a.firebaseapp.com/__/auth/handler conservado.
- Instagram app2033254194048655, cliente1653707599767005; sólo instagram_business_basic.
  Meta agrupa perfil/multimedia, Dopmi consulta identidad user_id/username/account_type;
  Graphv24, BUSINESS/MEDIA_CREATOR. Sin mensajes/comentarios/publicaciones/insights.
- Callback ambos: https://ohqxranynackjignryep.supabase.co/functions/v1/social-verification-callback.
  Deauth: /functions/v1/social-verification-meta/{facebook|instagram}/deauthorize.
  Eliminación IG: /functions/v1/social-verification-meta/instagram/delete.
- Facebook conserva instrucciones https://www.dopmi.app/comming-soon; compatibilidad de
  eliminación con app legado sigue siendo gate, no reemplazar con borrado sólo social.
- Supabase DEVohqxranynackjignryep exclusivamente. Secretos sólo Edge Function Secrets;
  SOCIAL_VERIFICATION_ENABLED=false restaurado y comprobado al terminar QA.
  Proyecto producción intacto. Etiqueta PRODUCTION del dashboard refiere tipo de rama.
- Migración local20261009205039_social_verification.sql aplicada una vez como remota
  20261009210425; SHA256 LF f6b68d0cec66600c806b0aac97000dfcd8c9ec0e9a3d43e7f7117fee67a222d8.
  Mapeo en [auditoría histórica](migration-history-audit.md); no reparar/reaplicar.
- social-verification, social-verification-callback, social-verification-meta ACTIVEv1,
  fuentea941815. verify_jwt=false por callbacks públicos; operaciones privadas validan
  getUser y session_id JWT; callbacks Meta validan HMAC.

## Fuente, gates y publicación

Producto sociala9418154a964a02043ecb4f03f0b8c98b88c5aa2; fixture1efe72cd69f0e3e44dfe30f42324879a5add6b9b;
producto finalf71c4440f261b10455eb38b9948fd3d68ef321ca corrige entrada del perfil real.
Candidato943dc1c773d87e85f97251db358b34902d7c5159 sólo añade docs a ese producto.

- [FULLCI38001865589](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/38001865589)
  exactof71c444: cuatro jobs/todos pasos success, web/DB permisos y concurrencia,
  Flutter/analyze/tests/capturas/Android debug, iOSsim, integración identidad/adopción.
- Backend638/638, Deno tres entrypoints, seis pruebas backend nuevas; móvil cuatro
  funcionales nuevas y doce sociales existentes, captura320px/200%, entrada real2/2,
  analyze0 y configuración móvil16/16. Reutilizar resultados válidos, no repetir.
- [CI37993212803](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/37993212803)
  verde después de fixture1efe72c; CI37991530876 falló por auth.sessions ausente en
  PGlite, corregido sólo fixture, sin debilitar autorización. Push concurrentes no son candidatos.
- Codemagic6ac9772639c0d173f3b4330a
  identificador de job; consulta fiable API /builds/{id}. android-guardian-internal,
  MacminiM2 overrideXcode26.5, fuente943dc1c, success. Inicio17:22:22.768 y fin17:46:45.914,
  9/10 hora México. Publicación confirmada por Publishing y tracks get internal/completed311.
  Dashboard/artifacts requieren acceso del titular; no son archivos públicos de GitHub.
- com.mycompany.dopmi2.3.3(311), Guardiantrue/dinero test. AAB SHA256
  c380904954f4e5d109b7c09cefa7d7f1fe4db4225e8a349cadfc7fcf65acca97.
  Samsung SM-S938B/Android16 comprobado por ADB:311, installer com.android.vending.

## Revisiones y evidencia vigente

| Revisión | Resultado y límite |
|---|---|
| Eficiencia | Cola Flutter única, revisión cruzada acotada, reutilización de QA anterior. Sin retoques imperceptibles, polling OAuth ni builds duplicados simultáneos. Repeticiones sólo por fallo/corrección/candidato obligatorio. |
| UI | Inter320px/texto200%, título Redes sociales sin recorte, controles alcanzables; estados de ambas conexiones vistos en311. No aceptación global de diseñadora. |
| UX | Navegador externo y regreso explícito «Ya autoricé, comprobar»; personal/manual explicado; misma cuenta/sesión. Entrada real fallaba en310 y se corrigió en f71c444. |
| Código | Perfil real RescuerProfileHero conectado; regresión entrada100/200%2/2. Gates fuente exacta verdes; no cambios en identidad Auth. |
| Seguridad | Cuatro tablas privadas RLS y cinco RPC sin acceso anon/authenticated; cuerpos SQL comparados. State hash un uso/10min ligado actor/sesión/proveedor, límite5/10min, finish atómico/propiedad única. Replay de revocación y carrera primera prueba corregidos por revisión cruzada; mutex/tombstones. Tokens sólo servidor y descartados. Sin admin por metadata. Negativos reales restantes pendientes. |

En311: perfil real→Verificar mis redes sociales→Instagram consentimiento→callback→
comprobar, prueba verificada; Facebook consentimiento→callback→comprobar, prueba
verificada. SQL confirmó mismo propietario/sesión y nuevos intentos verificados;
UI ambos conectados. Se preservaron UUID/acceso Dopmi y teléfono; sólo prueba social privada.
Consentimientos pulsados por titular, no aceptación global de entrega.

Primer intento Facebook caducó durante login humano (>10min): callback rechazó,
sin prueba Facebook; cancelación en app dejó intento denied e Instagram conservado.
Nuevo intento exitoso. Eso acredita expiración/cancelación local, **no denegación por
proveedor ni desconexión/revocación real**. Prueba anterior denied no se reclasifica
por existir prueba válida posterior. DEV cerrado después, conexiones conservadas.

## Pendientes obligatorios, sin excepción aprobada

1. QA real desconexión/revocación y denegación del proveedor, conservando cuenta Dopmi.
2. Resolver eliminación Facebook compatible con integración legado antes de uso general.
3. Retención/purga programada: no implementada; caducidad lógica de intentos/recibos y
   limpieza de tombstones en revocación siguiente no sustituyen política ejecutada.
4. Meta App Review/requisitos de publicación y acceso general; tester aceptado no lo acredita.
5. Aprobación explícita UI/UX por titular/diseñadora donde siga ausente.

La QA SMS incorrecto/reenvío de dde1bb9 continúa pendiente por separado. No rebajar
estos gates a mejoras opcionales. Si requieren corrección, validar efecto y candidato
final de Play; no iniciar ese trabajo en este cierre.

## Continuidad práctica: fallos y herramientas fiables

- OneDrive bloqueó unit_test_assets: copia exacta temporal fuera de OneDrive y pubget
  offline. SDK Flutter C:/Users/betoq/dopmi-functional-mockup/.tools/flutter/bin/flutter.bat.
  Captura requiere runAsync y scrollUntilVisible para hijos lazy; error de copia desde
  cwd equivocado corregido copiando desde raíz, no era defecto del producto.
- Widget aislado RescuerSocialSection no estaba montado en perfil real: detectado en
  dispositivo310, f71c444 añade acceso en hero real y regresión. Revisar entrada real,
  no inferir accesibilidad por pruebas de pantalla aislada.
- Cola CM6ac960211a4f58756e2f8efd cancelada terminal antes de reemplazar. Ticket21219:
  proveedor reportó demanda del pool; override API Xcode26.5 sin YAML/firma nuevos.
  CM6ac96931a20af0c26fabf6c0 publicó310 (fuente75e79f1), reemplazado por311 tras corrección.
  No jobs activos pendientes documentados. API https://api.codemagic.io/builds/{id}
  reconcilió cancelación tras fallo de transporte; nunca duplicar POST por timeout.
- Invitación IG no apareció en app nativa; Chrome oficial accounts/manage_access/,
  Invitaciones de prueba funcionó; aceptación humana. Un am start VIEW fue rechazado
  por revisión automática sin motivo detallado; no reintentado, se usaron toques visibles
  ADB autorizados. Control nativo habitual no admite Android.
- ADB C:/Users/betoq/dopmi-functional-mockup/.tools/android-sdk/platform-tools/adb.exe,
  seleccionar dispositivo explícito (-s) por entrada fantasma offline. Esperar estado
  estable con uiautomator antes de capturar; no repetir capturas de transición.
- GitHub readAPI .tools/update9ced/github-read.py; Codemagic token CM_API_TOKEN en entorno
  Windows del usuario, no imprimir. Helpers/journals .tools/meta-social/cm-entryfix-*
  conservan envío y resultado privado. No volver a consultar suites verdes por cierre.

Capturas .tools/meta-social/social-both-connected-play311.png, instagram-connected,
facebook-consent y dev-closed-after-social-success.png: privadas/ignoradas, sólo equipo
local, **no disponibles en GitHub**. No publicar nombres de tester, números, secretos,
tokens ni datos personales. Evidencia compartible: commits, CI y este registro.
Cambios locales ajenos no publicados siguen excluidos; consultar Git antes de continuar.
