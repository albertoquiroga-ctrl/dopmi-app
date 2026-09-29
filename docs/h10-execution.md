# H10 — Identidad, privacidad y preparación operativa

Autorizado por el titular el 28/9/2026. H9 se considera suficientemente aceptado
para avanzar; no se atribuyen recorridos nuevos en dispositivos ni aceptación
visual a Irlanda. Referencia visual a246fa6, sin cambios al iniciar este ciclo.

## Decisiones

- México, cuentas de mayores de 18 años y operación por persona física.
- Supabase conserva la identidad. No migrar usuarios de Firebase anterior:
  eran pruebas; conservar sus recursos hasta una retirada separada.
- Firebase Analytics y Crashlytics con permisos independientes, opcionales y
  desactivados antes del consentimiento; sin contenido privado ni IDs financieros.
- Buzón humano soporte@dopmi.org en GoDaddy; envío transaccional separado.
- Producción Supabase separada, restringida y sin dinero real. No contratar
  recursos sin presentar su costo y obtener aprobación.
- La identidad de distribución y firma existentes permanecen. Las pantallas
  actuales se conservan. H11 conserva aceptación integral Android/iOS; H12 live.

## Cola y aceptación

1. **H10.0** Inventario de accesos/proyectos, configuración por entorno y guardas
   de builds. Preparar esquema limpio de producción sin copiar datos ni legado.
   Cierre: configuración cruzada rechazada y cada entorno verificado.
2. **H10.1** Google Android/iOS, Apple nativo iOS y OAuth Android; vinculación
   explícita segura; callbacks Supabase y aceptación de edad/términos.
   Cierre: registro/login/cancelación/recuperación en dispositivos, sin duplicar
   identidades vinculables. No habilitar Apple sin revocación en servidor.
3. **H10.2** Eliminación idempotente, reautenticación y solicitud web; bloqueo
   inmediato en PostgreSQL, retirada pública y cancelación de ciclos futuros.
   Separar identidad de evidencia financiera antes de borrar Auth. Eliminar
   contenido propio sin borrar mensajes del otro participante; revocar Apple.
   Cierre: concurrencia/reintentos/privacidad y obligaciones pendientes probados.
   Producción requiere matriz aprobada de retención, plazos y purga.
4. **H10.3** Interfaces y proveedores de analítica/errores con consentimiento
   independiente; eventos mínimos tipados, sin texto libre. Probar ausencia de
   envíos previos y limpieza de pendientes al retirar consentimiento/cambiar cuenta.
5. **H10.4** Buzón, SMTP, DNS, Private Relay; páginas soporte/privacidad/términos/
   eliminación y declaraciones de tiendas. Cierre: entrega real de correo y
   textos aprobados sin campos provisionales. Domicilio legal por canal privado;
   RFC fuera del repositorio.
6. **H10.5** Contraseñas filtradas, límites/redirects, accesos, vencimientos;
   entregas Codemagic Internal y TestFlight con SHA y publicación verificadas.

Cada bloque: implementar, probar, registrar evidencia y continuar. Ejecutar
Flutter analyze/tests, admin, backend/PostgreSQL, configuración móvil y las
regresiones financieras afectadas. Compilar/publicar no equivale a aceptación
instalada. No cerrar H10 con integraciones simuladas o pendientes.

## Inventario verificado

- 28/9: PR6 abierto/draft, continuación ef9f009 sobre codex/design-foundation;
  principal ba9f897. No integrar automáticamente hasta comprobar nueva entrega.
- MCP Supabase: proyecto test ohqxranynackjignryep, ACTIVE_HEALTHY; no se encontró
  proyecto producción. Historial remoto debe cotejarse antes de migraciones.
- Lectura previa en Chrome: Firebase dopmi-e3b6a, Google habilitado con el ID
  aportado por el titular; Apple habilitado pero campos de flujo web vacíos.
  Esto no verifica login en la app Supabase.
- App Store Connect accesible por lectura; Apple Developer y GoDaddy requieren
  comprobar sesión administrativa. Se solicitó al titular abrirlas sin compartir secretos.
- DNS consultado en planificación: sin MX en dopmi.org; no hay buzón verificado.

## Evidencia por ciclo

### Accesos administrativos y preparación — 28/9

- Sesiones Chrome Google Cloud, Apple Developer y GoDaddy comprobadas tras
  autenticación del titular. Google confirmó que el ID aportado es un cliente
  web; existen clientes Android/iOS antiguos, aún pendientes de cotejar firma.
- Apple: com.mycompany.dopmi ya tiene Sign in with Apple como App ID primario.
  Se registró la clave KLYH2Y22TT, `Dopmi Supabase Auth`, limitada a Sign in
  with Apple para ese App ID. Su `.p8` de descarga única quedó fuera del repo
  en `%USERPROFILE%/.dopmi-secrets/apple`, con ACL exclusiva del usuario.
  Services ID `com.mycompany.dopmi.auth` registrado y asociado al App ID
  primario `com.mycompany.dopmi`. Apple conserva como dominio
  `ohqxranynackjignryep.supabase.co` y como retorno
  `https://ohqxranynackjignryep.supabase.co/auth/v1/callback`. El proveedor de
  Supabase aún permanece sin activar ni probar.
- GoDaddy: el titular completó la compra preparada de Pro Light por MXN263.88;
  el producto ya aparece en `Correo electrónico y Office`. Renovación indicada
  para septiembre 2027 por MXN479.88, sujeta a cambios. El titular confirmó
  después el alta de `soporte@dopmi.org`. La recepción y
  respuesta todavía requieren una prueba real antes de declarar el buzón
  operativo para H10; el correo transaccional sigue separado.
- Aviso de privacidad integral de la nueva app publicado en
  `https://dopmi.org/privacy-policy`. Fuente en
  `albertoquiroga-ctrl/dopmi-landing-mockup`, commits `654b86d`, `e77237f` y
  `aa9a355`. La ruta anterior `/pages/privacy-policy` se conserva mediante
  redirección permanente.
  Responde HTTP 200 por HTTPS, sin autenticación, con título, responsable,
  domicilio autorizado, datos/finalidades, proveedores, conservación,
  derechos ARCO, permisos y contacto. Compilación Vite y TypeScript aprobadas;
  comprobación visual de escritorio aprobada. La política excluye expresamente
  versiones anteriores. Esto no acredita todavía eliminación dentro de la app,
  ficha Seguridad de los datos ni revisión jurídica profesional.
- El conector Vercel instalado no tiene autorización sobre el scope `dop-mi`
  (403 al consultar el equipo). La publicación sí quedó comprobada por el
  dominio público y la integración GitHub existente; ampliar ese scope facilitará
  consultar despliegues y logs por API, pero no bloquea la página publicada.
- CI36447795107, SHA d45a3673d3b40ae1c849dd6fa400aa9cf7b807f6:
  completed/success consultado por API. No hay build H10 nuevo ni OAuth real probado.

### Credenciales Apple — 28/9

Servidor de registro/revocación preparado y desplegado en test, deshabilitado.
`apple-credentials` v1 verifica el JWT Supabase y vincula el subject de Apple a
`auth.identities`; el ID token de Apple requiere firma RSA, issuer, audience,
vigencia y nonce. Credenciales cifradas AES-256-GCM con propietario como contexto.
RPC sólo service_role, tabla privada con RLS, eliminación Auth restringida hasta
retirar la credencial. No se expone revocación como acción elegible por el cliente.

La configuración futura requiere APPLE_NATIVE_CLIENT_ID=com.mycompany.dopmi,
APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY y una clave de cifrado aleatoria
de 32 bytes en base64 DOPMI_IDENTITY_ENCRYPTION_KEY con su KEY_ID. Deben residir
en secretos de Edge, no en Flutter ni Git. DOPMI_APPLE_CREDENTIALS_ENABLED sigue
apagado. No rotar la clave de cifrado sin recuperar/recifrar los registros previos.
El secreto cliente de Apple se firma en servidor con vigencia de cinco minutos.
La configuración del proveedor OAuth web de Supabase se gestiona por separado.

Si falla la persistencia se comprueba primero si la escritura sí se guardó; si
no, se intenta revocar el grant consumido. Una caída simultánea de proveedor y
persistencia no se considera resuelta: exige nueva autenticación y revisión al
implementar la eliminación. No afirmar revocación Apple real antes de sus pruebas.

Verificado remoto: RLS=true, execute anon/authenticated=false, service_role=true,
cero credenciales guardadas; HTTP401 sin Authorization y HTTP503 deshabilitado.
Pendientes: acceso Apple Developer, secretos, integración del cliente nativo,
registro de capacidades/perfiles, OAuth Android y prueba de revocación real.

### Legal, eliminación y medición — 28/9

- La app exige mayoría de edad y aceptación versionada
  `terms-2026-09-28` / `privacy-2026-09-28`; retiró el aviso de desarrollo
  y enlaza la política pública. `/terms` y `/delete-account` responden 200.
- Supabase test contiene la solicitud idempotente y el proceso servidor. La
  solicitud bloquea sesiones a nivel PostgreSQL, retira contenido público,
  detiene ciclos futuros y la finalización anonimiza identidad. Mensajes de
  terceros y evidencia financiera permanecen; medios prescindibles se eliminan.
- `account-deletion` v2 autentica, exige acceso reciente, revoca Apple antes
  de Auth, cierra sesiones globales y admite reintento/atención parcial.
- Analytics y Crashlytics quedaron separados, apagados por defecto y por
  cuenta. Sólo aceptan eventos tipados; cambiar de cuenta o retirar permiso
  desactiva la recopilación sin reproducir eventos anteriores.
- Firebase `dopmi-e3b6a` corresponde a `com.mycompany.dopmi` en Android/iOS.
  Sus archivos nativos están excluidos de Git y Codemagic los reconstruye desde
  variables seguras del grupo `dopmi_firebase`.
- Verificación local: Flutter analyze limpio y 86 pruebas; backend 402 pruebas;
  administración 23 pruebas y build; configuración móvil 10 pruebas.

### Proveedores y producción — 28/9

- Google y Apple quedaron habilitados en Supabase test y las dos iniciaciones
  OAuth responden con redirección al proveedor. La vinculación manual está activa.
  Apple usa el Services ID `com.mycompany.dopmi.auth`; sus secretos y la clave de
  cifrado sólo existen en Supabase/almacenamiento privado local. Codemagic recibió
  los clientes y configuraciones Firebase mediante grupos seguros; ambos flags de
  login están activos para los workflows de aceptación.
- Se creó `Dopmi Production` (`ysaoeuidcvgtlmphmeyb`) en `us-east-1` con costo
  confirmado de USD0/mes. Recibió las 47 migraciones base, las siete funciones
  actuales y los cuatro buckets privados, sin usuarios, datos demo ni objetos
  Storage. No tiene secretos Stripe ni proveedores sociales; nuevos registros
  permanecen deshabilitados. Por ello no puede procesar dinero real ni recibir
  usuarios antes de una activación separada.
- La corrección `h10_auth_reference_cleanup` anonimiza referencias de moderadores
  al retirar Auth. Se aplicó como test `20260928221654` y producción
  `20260928221656`, sin tocar contenido ni contabilidad.

Pendientes de aceptación: inicio/cancelación/vinculación social en dispositivos,
revocación Apple con una identidad real, correo transaccional/Private Relay y
entregas Android/TestFlight del mismo SHA. No se cierra H10 por las redirecciones.

### Entrega candidata — 28/9

SHA `c8894b4ccf5da5063e1617a1f3a8870e586bc9fc`, CI
[36491606164](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36491606164):
cuatro trabajos aprobados, incluidas compilaciones Android/iOS y backend local.

- [Android 6abae7c8c3323875fd396d2e](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abae7c8c3323875fd396d2e):
  2.3.3 (260), análisis/pruebas/firma/AAB aprobados; publicación Google Play
  `internal` reconsultada como `completed`.
- [iOS 6abae7c91b8a7fd2eacfde7b](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abae7c91b8a7fd2eacfde7b):
  2.3.3 (261), análisis/pruebas/perfil/IPA aprobados; carga a App Store Connect
  terminó `UPLOAD SUCCEEDED` sin errores. Falta comprobar su procesamiento y
  disponibilidad en TestFlight, que la carga por sí sola no acredita.

- Configuración inicial: Python 9 pruebas; Flutter analyze limpio y 82 pruebas
  aprobadas sobre copia temporal fuera de OneDrive. Aún sin CI/build de H10.
- Producción permanece rechazada explícitamente hasta registrar su proyecto;
  no constituye provisión o verificación de producción.
- Acceso nativo en desarrollo; flags siguen apagados. Credenciales externas,
  vinculación y revocación Apple todavía pendientes.
- Código inicial 7b3e589, CI 36427481966 en curso al registrar. Última suite
  local: analyze limpio, 84 Flutter y 10 Python. Versiones de proveedores fijadas.
- Google Cloud solicita reautenticación del titular; se conserva la pestaña de
  Chrome para el handoff. No se accedió a secretos ni se configuraron proveedores.

### Medición transaccional y correo operativo — 28/9

- Los cinco eventos permitidos quedaron conectados únicamente después de
  respuestas reales: registro confirmado/consentido, conversación creada,
  publicación enviada, Checkout creado y pago confirmado por servidor. El
  contrato rechaza eventos desconocidos y cualquier payload; no admite correos,
  UUID, texto, ubicación, importes o referencias financieras.
- La medición es de mejor esfuerzo: una falla de Firebase no cambia el resultado
  de contacto, publicación o pago. Los intentos de aportación se marcan localmente
  para evitar duplicados al regresar de Stripe y para no reproducir eventos que
  ocurrieron sin consentimiento.
- Los candidatos internos incorporan una acción de diagnóstico no fatal detrás
  de `ENABLE_MEASUREMENT_TEST`; los workflows estándar la mantienen ausente.
- Resend quedó operativo con `dopmi.org` verificado. Una clave dedicada de envío
  para pruebas permanece fuera del repositorio y separada de la integración SMTP
  de Supabase. Un correo desde `soporte@dopmi.org` fue enviado y entregado, y su
  respuesta llegó al buzón humano. Private Relay sigue pendiente del acceso Apple.
- Verificación local: Flutter analyze y 90 pruebas desde copia temporal limpia;
  backend 402; administración 23 y build; prototipo 4 y build; configuración
  móvil 11. El primer intento Flutter dentro de OneDrive chocó con su caché de
  archivos; no fue un fallo de código y se repitió fuera de OneDrive.
- La protección contra contraseñas filtradas requiere Supabase Pro. El titular
  decidió diferirla a H12, antes del lanzamiento público; no se presenta como
  activa durante H10/H11.

Pendientes de cierre: pruebas sociales y eliminación en Android/iPhone, evento y
diagnóstico visibles en Firebase, Private Relay y un candidato Android/TestFlight
del mismo SHA con instalación comprobada.

### Candidato conjunto de medición — 28/9

SHA `3472c5b4ba5785ab9ab695f4a5d96a3e0befd4a3`. Los dos disparos de CI
[36501932519](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36501932519)
y [36501928018](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36501928018)
aprobaron sus cuatro trabajos.

- [Android Codemagic 6abb04b63e1e341b2e6b97fb](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abb04b63e1e341b2e6b97fb):
  análisis, 90 pruebas, firma, AAB y publicación aprobados. Play Console muestra
  `2.3.3 (262)` disponible para testers internos desde las 18:30.
- [iOS Codemagic 6abb04b74427c92a169daabd](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abb04b74427c92a169daabd):
  análisis, 90 pruebas, firma, IPA y carga aprobados. App Store Connect recibió
  y terminó de procesar `2.3.3 (263)`. Apple exige completar la declaración de
  cifrado y añadirlo al grupo interno antes de poder instalarlo; esos pasos no se
  presentan como disponibilidad todavía.

La aceptación física se registra en `docs/h10-device-acceptance.md`. H10 continúa
abierto hasta comprobar instalación, proveedores sociales, eliminación, Firebase
y Private Relay en ambos dispositivos.

Apple Developer registró `dopmi.org` como dominio de Private Email Relay con SPF
válido. App Store Connect aceptó para iOS 263 la declaración de que el cliente no
implementa los algoritmos de cifrado listados, cambió el build a **Lista para las
pruebas** y lo hizo disponible al grupo interno existente. El grupo ya registra
una instalación de 263 en iPhone 14 Pro Max con iOS 18.7.8; esto acredita entrega,
no los recorridos sociales, de consentimiento o eliminación. La entrega al alias
privado de Apple continúa pendiente hasta crear la identidad desechable acordada.
