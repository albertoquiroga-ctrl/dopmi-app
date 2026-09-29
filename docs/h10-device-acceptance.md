# H10 — aceptación en dispositivos

Esta hoja registra exclusivamente resultados observados en instalaciones de
Internal Testing y TestFlight. No anotar contraseñas, tokens, correos privados
completos, UUID ni referencias de Stripe. Para una identidad desechable basta
un alias como `google-a`, `apple-a` o `apple-relay-a`.

## Candidato

| Campo | Android | iOS |
|---|---|---|
| SHA | `f1c0f7b63042122156536d626d5930cf296cc272` | `f1c0f7b63042122156536d626d5930cf296cc272` |
| Workflow | `android-guardian-internal` | `ios-testflight` |
| Codemagic | build 23 (`6abc0b9355f874ca95621932`) | build 9 (`6abc16a31bed101ce54ac895`) |
| Versión disponible | `2.3.3 (275)` | `2.3.3 (276)` |
| Dispositivo / SO | dispositivo Android del titular; SO no registrado | pendiente |
| Tienda disponible | Internal Testing desde 29/9/2026 | TestFlight interno, **En pruebas**, desde 29/9/2026 |

El candidato anterior quedó **superado** para la aceptación de cuenta: Android 262
mostró pantalla negra al abrir **Información básica**, no expuso la eliminación
desde Configuración y conservó el texto obsoleto **Aviso de desarrollo**. La
cancelación inicial de Google sí quedó comprobada sin crear una identidad. Los
demás recorridos deben ejecutarse en el candidato 264/265 descrito arriba.

La revisión de Android 264 confirmó que la eliminación de cuenta se completó y
permitió volver a autenticar con Google. También descubrió dos defectos altos:
**Información básica** seguía mostrando una pantalla negra y un perfil social
anterior podía entrar sin aceptar la mayoría de edad, términos y privacidad
vigentes. El servidor registró las solicitudes de eliminación como `completado`,
sin atención pendiente. El candidato 264/265 queda superado para continuar esta
aceptación; la corrección requiere un nuevo candidato conjunto.

El candidato 266/267 contenía la primera pantalla obligatoria de mayoría de edad,
términos y privacidad para cualquier perfil incompleto o desactualizado. También
mueve **Información básica** fuera de la navegación por pestañas y publica Google
y Apple en **Crear cuenta**. CI, compilación y publicación Android aprobaron; la
corrección de la pantalla negra y el gate de consentimiento permanecen pendientes
de confirmación instalada.

La prueba instalada no reprodujo el aviso ni el alta social, y Supabase confirmó
que el perfil Google seguía sin ninguna de las tres aceptaciones. El candidato
actual 268/269 añade una barrera independiente que falla cerrada aunque no cargue
el perfil, muestra el build exacto en Configuración y conserva acceso a términos,
eliminación y cancelación de Guardián. Android 268 está disponible; iOS 269 fue
cargado correctamente, pero su procesamiento en TestFlight aún no se verificó.

El titular confirmó mediante las capturas `1000346255`, `1000346257`,
`1000346259` y `1000346261` que Android **2.3.3 (268)** muestra el gate
**Antes de continuar**, exige confirmar 18 años/términos/privacidad, identifica
la versión instalada y abre **Información básica** con el perfil real sin la
pantalla negra. Estos dos defectos quedan aceptados en Android. La captura del
formulario de alta confirma el consentimiento de registro; no alcanza a mostrar
el botón Google situado más abajo, por lo que ese punto conserva su prueba
separada.

## Recorrido Android

1. Instalar o actualizar desde Google Play Internal Testing y comprobar la
   versión del candidato.
2. Con Analytics y Diagnóstico apagados, cancelar Google antes de autorizar.
   Confirmar que no se creó una identidad Dopmi.
3. Entrar con Google usando `google-a`, aceptar mayoría de edad y términos,
   cerrar y volver a abrir la app. Comprobar sesión persistente, cierre de sesión
   y acceso repetido al mismo perfil.
4. Desde una sesión existente, vincular Google explícitamente. Comprobar que el
   proveedor regresa al mismo perfil. Un correo distinto nunca debe fusionarse
   automáticamente.
5. Repetir cancelación y acceso con Apple en navegador. Comprobar el regreso a
   la app y el mismo aislamiento de identidades.
6. Habilitar Analytics, completar una acción real permitida y comprobar su evento
   en Firebase. Retirar el consentimiento y confirmar que cesan los envíos.
7. Habilitar Diagnóstico, usar **Enviar diagnóstico de prueba** y comprobar el
   error no fatal fijo en Crashlytics. Retirar el consentimiento y confirmar que
   no se envían diagnósticos posteriores.
8. Solicitar eliminación de `google-a`. Repetir la solicitud y comprobar bloqueo
   inmediato, rechazo de la sesión anterior y ausencia de publicaciones públicas.
   Confirmar que la cuenta Google externa sigue funcionando.

## Recorrido iPhone

1. Instalar el mismo SHA desde TestFlight y comprobar la versión del candidato.
2. Repetir cancelación, alta, aceptación, reinicio, cierre y acceso repetido con
   Google usando una identidad desechable.
3. Cancelar Apple nativo antes de autorizar y confirmar que no se creó cuenta.
4. Entrar con Apple nativo usando **Ocultar mi correo** (`apple-relay-a`), aceptar
   mayoría de edad y términos, reiniciar la app y comprobar el mismo perfil.
5. Vincular Apple desde una sesión existente y comprobar que regresa al perfil
   original. No intentar unir correos diferentes por inferencia.
6. Repetir las pruebas de Analytics y Diagnóstico, incluida la retirada inmediata
   de cada consentimiento.
7. Probar confirmación, recuperación y comunicación de eliminación hacia el alias
   privado de Apple. Registrar sólo recepción y hora aproximada, nunca el alias.
8. Eliminar `apple-relay-a`; comprobar bloqueo, rechazo de sesión, revocación de
   Apple y ausencia de la credencial cifrada en servidor. Repetir la solicitud
   para acreditar idempotencia. La cuenta Apple externa debe permanecer intacta.

## Evidencia de servicios

| Comprobación | Resultado | Evidencia mínima |
|---|---|---|
| Sin Analytics antes del consentimiento | pendiente | DebugView o eventos del dispositivo sin actividad Dopmi |
| Eventos permitidos con consentimiento | pendiente | nombre del evento y hora; sin parámetros privados |
| Sin Analytics después de retirar | pendiente | intervalo observado sin eventos nuevos |
| Crashlytics apagado | pendiente | ausencia antes del consentimiento |
| Diagnóstico interno habilitado | aprobado en Android 270 | Firebase recibió 1 no fatal `dopmi_diagnostics_test`, motivo `internal_acceptance_test`, tras consentimiento explícito |
| Crashlytics retirado | interfaz aprobada en Android 270; ajuste pendiente de candidato | titular apagó Diagnóstico y desapareció la acción de prueba; cliente actualizado para borrar reportes locales al retirar, activar o cambiar de cuenta |
| Private Relay | dominio registrado; entrega pendiente | `dopmi.org` aceptado por Apple con SPF; falta prueba al alias |
| Eliminación Google | pendiente | estado final y sesión antigua rechazada |
| Eliminación Apple | pendiente | estado final, grant revocado y credencial ausente |

Consulta de servicios del 29/9/2026, antes de continuar la aceptación física:

- Supabase test registra 17 cuentas, 16 identidades por correo y 3 por Google;
  una sola aceptación legal vigente, tres eliminaciones `completado`, ninguna
  eliminación pendiente y ninguna credencial Apple almacenada. Las cantidades
  se registran sin correos ni UUID.
- Firebase DebugView no detectó dispositivos de depuración ni eventos de debug
  en los 30 minutos observados. El panel general contiene actividad histórica
  de la aplicación anterior y no sirve como evidencia del consentimiento H10.
- Crashlytics todavía muestra el estado inicial **Add SDK** para Android. La
  integración está compilada, pero falta habilitar Diagnóstico y emitir el error
  no fatal controlado desde el candidato instalado para verificar la recepción.
- Administración: 23 pruebas y build aprobaron. Verificación de backend: 105
  pruebas aprobaron. Configuración móvil: 11 pruebas aprobaron. Flutter no está
  instalado en esta estación; el `analyze` y la suite Flutter del mismo SHA se
  acreditan mediante los dos trabajos CI aprobados ya vinculados al candidato.

La prueba instalada del 29/9 activó Diagnóstico, registró el error controlado y
reinició la aplicación. Firebase detectó el SDK, pero continuó esperando el
primer reporte. No se acepta como entrega. El cliente ahora solicita el despacho
explícito inmediatamente después de registrar el diagnóstico consentido; esta
corrección requiere un nuevo candidato y repetir sólo este recorrido.

El candidato de corrección parte de `5c505c2fca03aaf1753d8fbe23a77fe79f2368cc`.
Android Codemagic `6abbc365a2cb55def9efff17` aprobó configuración, análisis,
95 pruebas, firma, AAB y Publishing. Play Console confirmó **2.3.3 (270)**
disponible para Internal Testing el 29/9/2026 a las 08:08, con versionCode 268
desactivado. iOS Codemagic `6abbc3656e8a9a4c7f26ae72` permanece pendiente; el
candidato conjunto no se acepta hasta comprobar su carga e instalación.

El titular activó exclusivamente Diagnóstico en Android 270 y la app confirmó el
envío. Firebase Crashlytics recibió un único no fatal originado en
`MeasurementController.diagnosticTest`, con error `dopmi_diagnostics_test` y
motivo `internal_acceptance_test`. La recepción consentida queda aprobada; falta
apagar el control y confirmar que no exista una nueva vía de envío.

La captura `1000346267` confirma que el titular apagó Diagnóstico en Android 270
y que la acción **Enviar diagnóstico de prueba** desapareció; Analítica también
permaneció apagada. La documentación de Firebase advierte que Crashlytics puede
guardar reportes locales mientras la recopilación está desactivada. Por ello el
cliente se reforzó para llamar `deleteUnsentReports` al retirar consentimiento,
antes de una nueva activación y al cambiar de cuenta. El análisis quedó limpio,
7 pruebas dirigidas y la suite completa de 96 pruebas aprobaron. Este refuerzo
requiere un candidato posterior; la interfaz de retirada sí queda aceptada.

iOS `6abbc3656e8a9a4c7f26ae72` generó y firmó correctamente el IPA **2.3.3
(271)**. Apple respondió HTTP 500 al cerrar estados internos del upload; `altool`
también informó `UPLOAD SUCCEEDED` y entregó un UUID, pero Codemagic marcó
Publishing como fallido. App Store Connect requiere una nueva sesión para
confirmar si 271 quedó procesándose antes de reintentar.

## Resultado

H10 sólo se acepta cuando las dos columnas del candidato corresponden al mismo
SHA, cada recorrido anterior tiene evidencia observada y no quedan defectos
críticos o altos. Una compilación o carga a la tienda no sustituye la instalación
ni las pruebas físicas.

## Diagnóstico dirigido de Analytics — Android 275

El candidato interno **2.3.3 (275)** corresponde al SHA
`f1c0f7b63042122156536d626d5930cf296cc272` y quedó publicado en Play Internal
Testing por Codemagic `6abc0b9355f874ca95621932`. Después de instalarlo:

1. Conservar **Analítica de uso** encendida.
2. Desde Adoptar, abrir **Contactar** sobre una mascota sin conversación previa
   y confirmar el contacto.
3. Abrir Perfil → Configuración → Privacidad y eliminación.
4. Registrar el aviso interno exacto: aceptado por Firebase, omitido sin
   consentimiento o error tipado. El aviso no contiene el mensaje, correo,
   identificadores ni datos de la mascota.

Sólo el resultado **aceptado por Firebase** habilita la comprobación posterior
en GA4. La señal local acredita que el método nativo terminó; la recepción en
GA4 se registra por separado.

El titular completó este recorrido el 29/9/2026 con Analítica encendida y una
conversación nueva sobre Nina. La app mostró **Firebase aceptó
contact_started**. La entrega al SDK queda aprobada. GA4 Realtime tenía
actividad y 49 eventos, predominantemente heredados de FlutterFlow, pero no
mostró todavía `contact_started` en los resultados visibles consultados. Falta
confirmar su procesamiento posterior; esto no justifica emitir eventos
sintéticos ni agregar parámetros identificables.

## Candidato conjunto vigente

El tag `codex-h10-android-275` fija el SHA funcional ya instalado en Android.
Codemagic iOS `6abc16a31bed101ce54ac895` tomó ese tag, aprobó configuración,
análisis, 97 pruebas, firma, IPA, Publishing y limpieza. App Store Connect aceptó
el IPA **2.3.3 (276)** con `UPLOAD SUCCEEDED with no errors`. La carga no acredita
procesamiento ni instalación; la sesión web de App Store Connect estaba
expirada al intentar consultarlo.

Tras renovar la sesión, App Store Connect mostró la carga 276 como
**Finalizado** y el build como **En pruebas**, asignado a `DopMi Inner Team`,
con tres invitaciones y cero instalaciones en el momento de la consulta. Queda
acreditada su disponibilidad interna; falta instalarlo y ejecutar el recorrido
iPhone.

Una consulta agregada de Supabase test registró 17 cuentas, identidades por
proveedor `email: 16` y `google: 3`, una aceptación vigente completa
`terms-2026-09-28` / `privacy-2026-09-28`, tres eliminaciones completadas,
ninguna pendiente y cero credenciales Apple. No se consultaron ni documentaron
correos, UUID o tokens.

## Aceptación iOS/iPadOS — build 276

El titular instaló **2.3.3 (276)** desde TestFlight en un iPad. La disposición
horizontal amplia queda registrada como diferencia visual de tablet, sin
bloquear los recorridos H10 de identidad. Google y Apple regresaron limpiamente
al inicio al cancelar, sin crear sesión ni mostrar un error técnico.

El acceso nativo con Apple creó una identidad desechable usando **Ocultar mi
correo**. Dopmi mostró el gate **Antes de continuar**, exigió mayoría de edad y
aceptación de términos/privacidad, y conservó la sesión tras cerrar y volver a
abrir la aplicación. Supabase test registró la identidad Apple y su credencial
cifrada; no se copió el alias a esta evidencia.

Se emitió una recuperación por el SMTP/Auth configurado. Resend registró
`delivered` al alias de Apple y el titular confirmó el mensaje reenviado en su
buzón. Esto acredita la entrega real por Apple Private Relay.

El titular eliminó la misma cuenta desde la app. La función `account-deletion`
v3 respondió HTTP 200; su diseño sólo finaliza después de que Apple acepta la
revocación y la credencial se elimina con comparación del hash. La comprobación
posterior confirmó: estado `completado`, perfil `deleted`, marca de finalización,
sin atención pendiente, cero filas en Auth/identidades/sesiones y cero
credenciales Apple. Los logs de Auth acreditan cierre global y eliminación por
servidor. Producción no fue consultada ni modificada.

Google nativo inicialmente volvió al acceso con un mensaje genérico. Auth
registró HTTP 400: el token iOS no incluía nonce y el proveedor exigía uno. Se
activó **Skip nonce check** exclusivamente en Google del proyecto test, según la
configuración indicada por Supabase para Flutter iOS; la repetición terminó
HTTP 200, reutilizó una identidad existente con aceptación legal vigente y
conservó la sesión tras reiniciar la app. No se creó una cuenta duplicada.

El acceso aprobado emitió además la advertencia preventiva de Auth de que el
`access_token` será obligatorio junto al ID token en versiones futuras. El
cliente siguiente obtiene ambos tokens de Google y los envía de forma común en
inicio, vinculación y reautenticación. Esta corrección requiere un candidato
nuevo y no invalida la aceptación observada de 276.

## Candidato final con access token de Google

El tag `codex-h10-final-277` fija el SHA
`7e0a4b09ece6833c74afa44e2eb30e0651a6cff6`. La compuerta integrada
[36632568776](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36632568776)
aprobó sus cuatro trabajos: formato, análisis y pruebas Flutter, APK Android de
desarrollo, compilación iOS, administración, backend de identidad/adopción,
permisos PostgreSQL y concurrencia de Guardián.

[Codemagic Android `6abc2e07bb271484cec0e088`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc2e07bb271484cec0e088)
aprobó configuración, firma, análisis, pruebas, AAB, publicación y limpieza.
Google Play confirmó **2.3.3 (277)** en `internal`, estado `completed`.
[Codemagic iOS `6abc2e104ec1ec8d686c0180`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc2e104ec1ec8d686c0180)
aprobó configuración, firma, análisis, pruebas, IPA, publicación y limpieza;
App Store Connect aceptó **2.3.3 (278)** con `UPLOAD SUCCEEDED with no errors`.
Ambos artefactos proceden del mismo SHA. Falta confirmar procesamiento y
disponibilidad de iOS 278 e instalar los dos candidatos. El recorrido afectado
que debe repetirse es Google: acceso y persistencia de sesión, comprobando que
Auth ya no emita la advertencia por falta de `access_token`.

El titular instaló ambos candidatos y confirmó el resultado esperado en los
dos sistemas: Google completó el acceso y la sesión sobrevivió al cierre y
reinicio de Dopmi. Supabase test registró dos accesos Google recientes con
HTTP 200 y `grant_type=id_token`. No reapareció la advertencia anterior que
exigía enviar `access_token`. En uno de los recorridos el ID token no incluía
`at_hash`; Supabase indicó que el access token recibido no era necesario para
ese token concreto. Es una observación informativa y no afectó la sesión.
No se copiaron correos, UUID, tokens ni direcciones a esta evidencia.

Queda aceptada la corrección Google del candidato conjunto. El titular confirmó
además que la vinculación regresa al mismo perfil Dopmi. Por decisión de
producto, Apple se ofrece únicamente en iOS/iPadOS; Android conserva acceso por
Google y correo y no requiere Apple mediante navegador. Con esto queda cerrada
la aceptación instalada de H10.1.
