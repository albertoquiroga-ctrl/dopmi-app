# Verificación social — registro consolidado

## 17/10/2026 — Coordinador confirmado y límites del procedimiento privado

Titular confirma «Yo coordino también la verificación»; decisión en product-decisions.md. Exploración independiente de fuentes y revisión de seguridad contrastan tres ramas: Supabase actual ya tiene recuperación oficial y reautenticación con mismo UUID; archivo Supabase requiere vínculo individual acreditado antes del inventario; Firebase anterior sigue separado, sin mapa de identidad implementado acreditado. El trigger histórico insertaba users.id=Auth NEW.id, pero no prueba correspondencia individual. Lectura remota **sólo de catálogo**17oct22:13:11.430124CDMX: dopmi_legacy.users existe con PK UUID y sin FK Auth ni columna Firebase. Cero registros personales/solicitudes leídos; no restauración, migración ni borrado.

Preparación ampliada en legacy-deletion-release-gates.txt existente y lectura/evidencia privadas legacy-user-structure.readonly.sql / legacy-user-structure-result.private.json. No ejecutar plantilla por reclamante sin vínculo y alcance autorizados. Pendiente decisión humana si no se recupera ningún factor: solicitud abierta/escalada con prueba concreta revisada por caso (recomendación) o ampliar alcance para diseñar recuperación adicional. No inferir permiso por coordinar soporte; no recolectar documentos por defecto. Política de conservación, compatibilidad integral del legado, publicación/valores Meta y demás gates siguen pendientes. No dictamen jurídico ni aceptación MVP.

## 17/10/2026 — Desconexión Instagram D y teléfono visible verificados

D Instagram cerrada17oct22:06:37.5527CDMX en Play2.3.3(318)/7caea887: permiso específico, una confirmación en Dopmi y postflight único. Facebook0/Instagram0;20 grupos propios conservan exactamente conteos/huellas frente al baseline fresco. UI asentada muestra «Retiramos la conexión de Dopmi», sin cuenta conectada ni controles Desconectar; Conectar sigue deshabilitado. Revisiones independientes de producto y seguridad cerradas. No acredita retirada del permiso Instagram en Meta ni denegación OAuth. Modo Adoptante original restaurado después del cotejo. Sin SMS, cambios de teléfono, pagos, flags, OAuth, build ni reconexión.

QA de teléfono no vacío en318 cerrada en este recorrido: la pantalla «Teléfono de tu cuenta» muestra «Vinculado» y una lectura READ ONLY ligada al dueño confirma coincidencia con Auth y phone_confirmed_at presente17oct22:07:49.688015CDMX. Fuentes y pruebas vigentes revisadas, sin repetir suites. No se reprodujo caché SDK obsoleta en dispositivo ni se capturó GET de red; SMS incorrecto/reenvío siguen pendientes por falta del otro número controlado ya informada. Captura con contactos sólo privada.

Evidencia privada: `.tools/b5-social-preparation-20261017/negative-qa-no-global-flag/instagram-app-d/operation/operation-completed.private.json`; ligado fresco SQL5145476023e1438040e5344ebb7a070577164a800a920bf6be5e8849b81b67c2. Postflight preserva sólo el instante/alcance cotejado; el cambio de modo posterior puede modificar perfil. Revisión previa del ligado consta en orden del transcript, sin timestamp exacto inventado.

Retro independiente de proceso: preparación y comprobación previa cumplen funciones distintas; no se repitieron suites/builds. D distingue frescura operativa y permiso sin inventar TTL; no se atribuye ahorro ni causalidad sobre el éxito. Único ajuste propuesto/aplicado: el recibo terminal identifica revisión previa y artefactos históricos supersedidos, dueño integrador; verificación en próximo relevo: distinguir estado terminal y siguiente acción sin repetir QA. Los originales se conservan; corregir sólo el resumen si contradice evidencia.

Pendientes concretos: denegación OAuth real, SMS con otro número aún no disponible, mecanismo privado de reclamantes/compatibilidad legado y revisión/publicación de contenido y requisitos Meta, aceptación con Irlanda diferida. No habilitar conexiones ni iniciar otro flujo OAuth por esta autorización. TalkBack post-MVP. Dueños: integrador prepara operaciones; titular resuelve revisión/autoridad y disponibilidad; Irlanda evalúa el candidato. Siguiente dependiente: revisión humana del procedimiento de privacidad/eliminación preparado; ninguna publicación o eliminación autorizada.

## Corte17/10/2026 — retención aplicada y límites de acceso general

Paridadd304535, producto33b12a77/Play2.3.3(317) instalado. QA social positiva311
se conserva donde es equivalente; no nuevos OAuth, desconexión, revocación ni
denegación real. SOCIAL_VERIFICATION_ENABLED no fue cambiado por esta operación.

RetenciónDEV V5 soportada recibió autorización propia SQL26d8…5f6e6 y una sola
aplicación: historia20261017223822/total79, función postgres-only, tres índices,
job5 horario17GMT. Ocho checks y otros4jobs/digest intactos. **Primer run90561
succeeded23:17:00UTC=17:17CDMX**, posterior al COMMIT: ocho catálogo y tres ejecución true, otros4jobs/digest intactos y conteos vencidos0/0/0. Lectura de cron.job_run_details ligada al primer run, sin purga manual; no prueba IDs concretos por conteos. Política conservada:
intentos vencidos hace24h, recibos/tombstones vencidos; no cuentas Auth ni pruebas
sociales vigentes. V3rechazada42501/rollback se conserva sin retry.
Detalle y límites operativos en [auditoría](migration-history-audit.md).

Consola Meta autenticada reconsultada17oct sólo lectura por integrador:
**appInstagram2033254194048655** sigue Sin publicar. go_live muestra pendiente
URL de privacidad, caso Instagram y botón Publicar deshabilitado. Su permiso
instagram_business_basic figura Listo para prueba y ofrece Añadir a la revisión;
no se seleccionó esa acción. Dashboard ofrece TechProvider para solicitar revisión
y acceso a datos de usuarios/otras empresas con verificación de acceso; no hubo
enrolamiento ni aceptación de términos. El nivel efectivo/aprobación para usuarios
ajenos al rol y condiciones completas de esa revisión no quedan acreditados.
La fila automática public_profile vista en ESTA appInstagram **no verifica** la
appFacebook1156849688851390 distinta. No se guardó configuración ni publicó nada.
Evidencia privada meta-go-live-20261017 y meta-permission-readiness-20261017
en `.tools/b5-social-preparation-20261017/`; investigación primaria enlazada allí.

Pendientes concretos conservados: revisión humana de contenido/canal de privacidad
y eliminación compatible con legado; inventario por reclamante y paquete destructivo
aislado antes de cualquier borrado legado; autorización de publicación de contenido,
valores Meta/enrolamiento/revisión según requisitos reales. No reemplazar el callback
legado por borrado exclusivamente social ni presentar el borrador como capacidad
entregada. Titular/operador coordinan contenido y permisos; integrador prepara técnica.
Negativos sociales reales requieren ventana/consentimientos propios; SMS espera otro
número controlado no vinculado. Aceptación UI/UX se evaluará con Irlanda.

## Preparación de cierre MVP posterior17oct — sin repetir QA

Responsable de soporte@dopmi.org confirmado: el titular ([decisión](product-decisions.md)); entrega de buzón ya acreditada en h10-store-privacy-declarations.md. No se envió otro correo. Falta validar procedimiento privado para reclamantes sin acceso/legado; nombrar responsable no autoriza inventario ni borrado.

Contraste técnico de datos sociales/teléfono y borradores de cobertura preparados en el apéndice privado de meta-public-values-review.txt, con fuentes de código y límites de retención/logs/proveedor/legado. Insumo para revisión humana; no política publicada ni dictamen legal. Procedimiento operativo acotado añadido al paquete de gates legado existente; ninguna solicitud real procesada.

Paquete negativo separado D/R en .tools/b5-social-preparation-20261017/negative-qa-no-global-flag/: list/disconnect y deauthorize no necesitan abrir el flag global según fuente revisada. D y R sobre la misma prueba no acreditan dos retiradas; cada etapa necesita actor/proveedor conectado y consentimiento propio. No se ejecutó ni está lista para ejecución genérica: faltan baseline/lecturas ligadas y evidencia correlacionada del callback real para R. No extraer signed_request, sujeto o JWT para demostrarlo. Denegación OAuth requiere otro paquete/ventana; no reusar cancelación local como prueba de denegación.

Retención ya cerrada por V5 y primer run90561: el ítem3 «no implementada» del historial inferior está superado, no volver a aplicar ni probar. TalkBack post-MVP por decisión humana; no cambia los gates SMS/sociales/Meta ni la aceptación con Irlanda. Producto sigue7caea887/2.3.3(318)/Play interno; paquete técnico no crea candidato ni autoriza nueva build/pago/OAuth/publicación.

Revisión independiente de seguridad de la preparación cerrada: hashes fuente del paquete coinciden; apéndice corregido c3ef3cca476effb9ab0ad71adc214a46ef9f292e2ac0f3b3ddaa26250f6e84c2 limita headers a ramas reales y recoge responsable humano. No hallazgo material restante en esta preparación, sin certificar remoto/privacidad jurídica/ejecución. UI real318 de la sesión actual Irlanda no tiene prueba Facebook ni Instagram y muestra Conectar no disponible; no inferir valor de secreto por UI. Modo Rescatista usado sólo para inspección y Adoptante restaurado; no nueva prueba positiva ni desconexión/revocación. Falta cuenta previamente conectada y consentimiento del dueño para baseline específico.

Preparación R específica posterior17oct: el titular preparó Facebook en Chrome, conservando SamsungIrlanda. AppFacebook histórica1156849688851390 observada activa; su email antiguo se conserva, sin cambios de permisos. Digests de Supabaseconfirman CLIENT_ID de esa app y flagfalse, sin valores secretos revelados. CallbackdeauthorizeDEV y redirectsFirebase/DEV preservados. DosEdge social-verification y meta ACTIVEv9: tres fuentescadauno normalizadas igualeslocal; supersede sólo versiónv1 histórica, no hubo despliegue. Consulta agregada por hash del identificador visible encontró una pruebaFacebook vigente verificada9oct19:06CDMX y otraInstagram del mismoowner; no UUID/subject/contactos/finanzas exportados. BaselineR read-only21:24:21CDMX17oct: target1/FB1/IG1/profile1/Auth1/21grupos count/hash/tombstonenulo. Ligado/revisión seguridad cerrados, postflight285dcec09bb814b6b1bad8ff2b874213d6ce9a87704ac82e46ee35c92cbe2029, ventana21:34:21CDMX. Paquete privado facebook-provider-r/REVIEW-FOR-OWNER.md preparado para permiso específico; todavía ninguna retirada autorizada/ejecutada. QA propuesta proveedor+backend, sin UIde esa cuentaDopmi; appwebactual no preparada, no inventarotroacceso. No desconectar esa misma prueba enDopmi antesdeR.

Panel específico de renovación Facebook muestra vencimiento10dic2026; aviso básico de10oct no basta para inferir desactivación. Renovación no iniciada/enviada/certificada. UI permisosFacebook email/public_profile «Ya se puede publicar» observado sólo lectura; no equivale veredicto de acceso general/permisos deInstagram. Borradolegado/páginas/Meta conservan gates.

## Cierre R, 17/10 — revocación Facebook en proveedor y backend

Permiso específico recibido: «Autorizar sólo esta retirada de Facebook». Se autorizó un máximo de una confirmación; el operador no hizo ningún clic de retirada. El titular informó que no veía el diálogo o veía algo distinto. No se observó su secuencia final: no afirmar que confirmó una vez, que no había casillas ni una causa de interfaz. Facebook dejó de mostrar DopMi entre las autorizaciones activas y la incluyó en «Aplicaciones y sitios web suprimidos»; captura privada conservada.

Único postflight: 17oct21:34:19.644117 CDMX, dentro del corte21:34:21.016781. Desaparecieron la prueba Facebook del dueño y la del sujeto objetivo; Instagram permanece en1 y los21 pares conteo/hash son iguales al baseline. Tombstone exacto nuevo:21:33:14.479517 CDMX, vencimiento21:43:14.479517. La correlación con el estado del proveedor y el callback autenticado desplegado respalda este resultado; no se capturó una petición HTTP de Meta ni se auditó la ausencia de administradores externos. No se hizo otra consulta, retirada, replay o reconexión.

Revisores independientes inspeccionaron fuentes, SQL, JSON y píxeles; cerraron producto/UI y seguridad en ese alcance. La proyección Auth acredita existencia de cuenta y campos de teléfono conservados, no toda la fila Auth ni un inicio de sesión futuro. El inventario no es una auditoría financiera global ni una consulta a Stripe. Esto cierra sólo R: desconexión desde Dopmi, denegación OAuth y UI de esta cuenta en Dopmi siguen sin acreditar. SMS, legado, Meta y evaluación con Irlanda conservan sus gates.

Retro independiente: quedaron1.372664s respecto al corte operativo del baseline, mientras el tombstone conservaba534.8354s de TTL. Son criterios distintos. Una mejora propuesta para el siguiente paquete, a cargo del integrador y revisor: justificar por separado la vigencia del consentimiento/lecturas previas y el TTL del evento antes de pedir autorización. Verificar ambos sin confundirlos; conservar el límite conservador si no hay justificación suficiente. No modificar el paquete consumido, el producto ni crear timers globales.

Recibo terminal privado: facebook-provider-r/operation-completed.private.json. Producto7ca/318 sin cambios, sin build, pago, flag u OAuth nuevo. El integrador conserva la cola. Para D hace falta una sesión Dopmi autenticada de ese dueño con Instagram aún conectado y permiso propio, sin cerrar la sesión de Irlanda. No utilizar Facebook ya retirado para contar otra desconexión.

## Historial conservado — cierre9/10/2026

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
