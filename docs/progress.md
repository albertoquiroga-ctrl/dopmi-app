# Dopmi — registro de avance

## Hito 4 — en curso

- Inicio de hito autorizado: Aportaciones base, consultas administrativas y lógica de asignación por cola.
- Verificación incremental del 21 de septiembre de 2026:
  - `cd tools/verification; npm test` → **23 pruebas, OK**. La cobertura nueva comprueba que el alta de Stripe Connect es reanudable, no duplica cuentas, solicita transferencias para México y consulta depósitos usando el contexto de la cuenta conectada.
  - `cd apps/admin; npm test` → **18 pruebas, OK**; `npm run build` → build de producción **OK**.
  - La migración `202609130007_donations.sql` se aplicó en el proyecto remoto. Un evento `payment_intent.succeeded` generado por Stripe CLI llegó al webhook remoto y respondió **HTTP 200** después de encolarse; el `404` previo de `dopmi_payment_server` quedó resuelto.
  - Los secretos aislados `STRIPE_SECRET_KEY_H4_TEST` y `STRIPE_WEBHOOK_SECRET_H4_TEST` tienen prioridad; los nombres existentes se conservan solamente como respaldo para no reemplazar la configuración previa.
  - El flujo permanece restringido deliberadamente a claves Stripe de prueba (`sk_test_`/`rk_test_`); no se habilitaron cobros reales.
  - `supabase test db` no pudo ejecutarse en este entorno porque no incluye daemon de Docker. `flutter analyze` y `flutter test` tampoco pudieron ejecutarse porque Flutter no está instalado. Las mismas comprobaciones quedan delegadas al CI versionado antes de considerar cerrado el hito.
- Implementación completada en este ciclo:
  - `apps/admin/src/api.ts`: se añadió tipo `Contribution` y API `listContributions`.
  - `apps/admin/src/App.tsx`: nueva sección “Aportes” en navegación administrativa.
  - `apps/admin/src/Contributions.tsx`: lista de aportaciones con filtro, estado, paginación y resumen económico con formato en MXN.
  - `apps/admin/src/Contributions.test.tsx`: pruebas de listado, recarga y error.
  - `apps/admin/src/App.test.tsx`: navegación a “Aportes” y llamada al RPC con `status='all'`.
  - `supabase/migrations/202609130007_donations.sql`: base de datos de aportaciones (`dopmi_donations`, `dopmi_donation_allocations`, funciones `dopmi_record_donation`, `dopmi_admin_donations`, `dopmi_apply_donation`, `dopmi_donation_status_summary`).
  - `supabase/tests/contributions.test.sql`: suite pgTAP para idempotencia, reintentos, estados e integración de asignación.
- Verificaciones del ciclo:
  - `cd apps/admin; npm test` → **18 pruebas, 4 archivos, OK**.
  - `cd apps/admin; npm run build` → build de producción **OK**.
  - `supabase test db` con `contributions.test.sql`: **bloqueado por falta de conexión local a PostgreSQL** (`ECONNREFUSED 127.0.0.1:54322`).
  - `docker version`: cliente OK, **daemon no disponible** (`dockerDesktopLinuxEngine` no encontrado).
- Pendiente de cierre del hito:
  - Ejecutar `supabase test db` al tener Docker/local stack activo.

## Hito 3 — completado

- Inicio autorizado y una sola secuencia de trabajo por ciclo, sin saltar H4.
- MCP Supabase conectado a `ohqxranynackjignryep` con estado `ACTIVE_HEALTHY`; acceso a tablas H1/H2 validado y Figma activo para contraste UX.
- Migración aplicada en remoto: `202609130006_rescue.sql` (borradores y expedientes, historial privado, publicación aprobada separada, reglas de Storage y funciones de revisión).
- Verificaciones locales de base:
  - `npm test` en `tools/verification` → **10 pruebas de identidad** (pasó).
  - `supabase test db` con `DOPMI_LOCAL_CONFIG` → **3 archivos, 120 pruebas** (pasó), incluyendo `supabase/tests/rescue.test.sql`.
- Verificaciones locales de mobile:
  - `flutter pub get`
  - `flutter analyze` sin incidencias.
  - `flutter test` → **16 pruebas** (pasó).
  - `flutter test test/rescue_test.dart` → **2 pruebas** (pasó).
  - `flutter test test_backend/rescue_backend_test.dart` → **1 prueba** (pasó).
- Verificaciones locales de panel admin:
  - `npm test` → **14 pruebas** (pasó).
  - `npm run build` (salida en `apps/admin/dist`) (pasó).
- Cierre funcional entregado en este hito:
  - `apps/mobile/lib/features/rescue/*` para registro, correcciones y revisión de estado desde móvil.
  - `apps/admin/src/Rescues.tsx` y `apps/admin/src/Rescues.test.tsx` para revisión de expedientes con evidencia privada y motivos de decisión.
  - `supabase/tests/rescue.test.sql` cubre acceso privado, versionado, rechazo de cambios inválidos, aprobación con monto/urgencia y publicación pública solo aprobada.

## Conexiones previas al hito 3 — 13 de septiembre de 2026

- Proyecto de desarrollo fijado a `ohqxranynackjignryep` y scopes de acceso confirmados en sesión.
- MCP Supabase y Figma activos. No se detectan restricciones nuevas de acceso.

## Hito 2 — completado

- Inicio autorizado: adopción, revisión administrativa, catálogo, guardados, perfiles públicos, mensajes y notificaciones internas.
- Se conserva la base de identidad y el trabajo posterior de emulación. Una sola secuencia de implementación está activa.
- Migraciones 003–005 aplicadas en PostgreSQL local: publicaciones moderadas, conversación privada y fotos en Storage privado. Las 58 comprobaciones nuevas de pgTAP y las once de identidad aprobaron.
- Flutter incorpora catálogo con filtros/paginación, detalle, favoritos, perfil público, borradores, fotos sin EXIF, revisión/correcciones, retirada/adopción realizada, conversación, cierre y notificaciones. El panel incorpora revisión con versión y motivos, fotos privadas e historial.
- Panel: nueve pruebas y build aprobados. Flutter: análisis sin incidencias y catorce pruebas aprobadas, incluidas catálogo, conservación de borrador, reintento de mensajes y eliminación de EXIF. Diez pruebas PGlite aprobadas.
- `verify-backend.ps1` aprobó las 69 comprobaciones SQL y los tres recorridos contra servicios reales: dos de identidad y uno de adopción, Storage, moderación, filtros, favoritos, perfil público, conversación, idempotencia concurrente, privacidad y cierre. Cuentas desechables eliminadas al terminar.
- Remoto: migraciones 003–005 aplicadas juntas desde SQL Editor en `ohqxranynackjignryep`. Las 58 comprobaciones nuevas de permisos aprobaron en una transacción revertida; diagnóstico vacío. Recibo final: cero usuarios/publicaciones temporales, diez perfiles conservados, cuatro tablas en Realtime y bucket privado. API anónima: catálogo público permitido y datos privados denegados.
- Primer CI de H2 (`f0457d0`, ejecución 34791108970): web, Android e iOS simulator aprobaron. La integración detectó una carrera de arranque: el join de Realtime se confirma antes de que PostgreSQL pueda emitir cambios. Se reprodujo en una base desechable nueva; aumentar la espera no la resolvía. La app ahora vuelve a leer al recibir `system: postgres_changes/ok`, también al reconectar. El recorrido completo pasó desde otra base nueva, sin precalentar Realtime. Referencia: https://supabase.com/docs/guides/realtime/protocol.
- Revisión visual local: cuenta responsable creó borrador, subió foto, envió a revisión y conservó los datos tras correcciones. El panel mostró foto, versión e historial; aprobó la versión corregida. Otra cuenta vio la publicación en el catálogo, la guardó y abrió una conversación. El mensaje enviado apareció en pantalla; al volver a la cuenta responsable, su notificación abrió el mismo mensaje recibido. Recibo de limpieza: cero cuentas de aceptación visual, publicaciones, mensajes y fotos. Los servicios locales se cerraron conservando los volúmenes del proyecto principal.
- Remoto: el panel restauró la sesión administrativa existente, mostró diez cuentas y abrió Adopciones con conexión activa y cola vacía. La vista Flutter ofrece el catálogo real conectado a Supabase; no se dejaron publicaciones de demostración en remoto.
- APK local 0.2.0+2 reconstruido correctamente el 13 de septiembre a las 18:19 con la corrección final, en `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. Es un build debug conectado al proyecto de desarrollo, no una distribución de tiendas.
- [CI final 34792258918](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34792258918), commit `7039f3517e9407eeb02ce57554c825217c6014a8`: los cuatro jobs terminaron con `success` (`web-and-database`, `flutter`, `ios`, `identity-and-adoption-backend`). Incluye Android, iOS simulator en macOS y los tres recorridos de backend reales. Código subido a `codex/Dopmi` en `albertoquiroga-ctrl/dopmi-app`; el cierre posterior modifica solo documentación.
- Hito 2 cerrado dentro del alcance de desarrollo. La revisión visual se realizó en Flutter web y React; la compilación nativa Android/iOS está comprobada. Galería tras interrupción del proceso, permisos/enlaces y almacenamiento seguro en dispositivos físicos se validarán en la beta del hito 6. Las notificaciones son internas; push permanece fuera de este hito. El siguiente alcance propuesto es H3: verificación de rescatistas y gastos con evidencias y revisión, sin iniciar todavía pagos.

## Hito 1

Estado: **hito 1 completado**. Flujos de identidad comprobados, Android e iOS simulator compilados, acceso administrativo del titular habilitado y cuatro jobs del CI ampliado aprobados.

- Referencias revisadas: prototipo, fuente funcional y documentos del ZIP; acceso al Figma comprobado.
- Proyecto de desarrollo: `ohqxranynackjignryep`. El usuario confirmó que las nueve identidades previas son de prueba. Se preservaron las tablas antiguas y sus datos.
- Entorno inicial: Windows, Node disponible; Flutter, Docker y Supabase CLI no disponibles en PATH.
- El cambio previo en el `package-lock.json` del prototipo pertenece al estado inicial y se conserva.

## Implementado

- Flutter con onboarding, registro, confirmación por enlace/código, sesión persistente, recuperación, perfil editable, consentimiento de desarrollo y cambio de experiencia. Almacenamiento seguro de sesión/PKCE en Android e iOS; callbacks configurados en ambos proyectos nativos.
- Panel administrativo con sesión real, permiso comprobado en servidor, búsqueda, paginación y detalle de usuarios. Las lecturas administrativas quedan registradas.
- Migración `202609130001_identity.sql` aplicada desde el dashboard: perfiles, RLS, membresías privadas, auditoría y RPC. Las nueve cuentas existentes tienen perfil. La función antigua `is_admin(uuid)` quedó intacta; la nueva es `dopmi_is_admin()`.
- Migración `202609130002_legacy_identity_boundary.sql` aplicada: se cerró la lectura y escritura de la tabla heredada `public.users` desde clientes. Su trigger de protección comprobaba `current_user` dentro de una función con `SECURITY DEFINER`, por lo que no impedía elevar el rol propio. Se preservaron datos y acceso del servidor. Se verificó que no hay vistas públicas que consulten esa tabla.
- Confirmación de correo habilitada en el remoto (antes estaba desactivada). Mínimo diez caracteres, mayúscula/minúscula/número y cambio seguro de contraseña. Tres callbacks exactos autorizados.
- Plantillas de confirmación y recuperación en español, con enlace y código. Copias versionadas en `supabase/templates`.
- Instrucciones, backlog, script de desarrollo y workflow de CI para web, SQL, Flutter, Android e iOS simulator.
- Se corrigió el tipo del sexo de las mascotas del prototipo, que impedía compilar con TypeScript. Sin cambio de comportamiento.

## Evidencia del 13 de septiembre de 2026

- PGlite/PostgreSQL: diez pruebas de RLS, privilegios, consentimiento, suspensión, búsqueda, auditoría y aislamiento de identidad heredada aprobadas. La segunda migración también se comprobó sin tablas anteriores.
- Supabase remoto: once comprobaciones pgTAP ejecutadas en una transacción con rollback. Sin diagnósticos de fallo; último resultado `ok 11 - anonymous profile access blocked`.
- API remota: Auth responde, exige confirmación y rechaza acceso anónimo a perfiles y RPC administrativas. La comprobación ampliada también incluye la tabla heredada.
- Admin: cinco pruebas aprobadas y compilación de producción correcta. Comprobación visual del login; una cuenta inexistente recibió el rechazo de credenciales de Supabase.
- Flutter: diez pruebas aprobadas, incluidas pantallas de 390×844, persistencia de recuperación, cierre de sesión y conservación de datos al fallar un guardado. El desbordamiento encontrado en el estado de correo confirmado se corrigió.
- Flutter analyze: sin incidencias en la comprobación final.
- Prototipo: cuatro pruebas aprobadas y build correcto después de corregir el tipo estrecho en `src/data.ts`.
- Vista Flutter abierta en `http://localhost:5175`; panel en `http://127.0.0.1:5174`.
- Android: compilación debug correcta tras limitar Gradle a 2 GB y dos trabajadores. APK `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, versión 0.1.0, paquete `io.dopmi.dopmi_mobile`, target SDK 36. Se comprobaron en el APK el nombre Dopmi, permiso de red, backups deshabilitados y callback `io.dopmi.app://auth/callback`.
- Reversión de las pruebas remotas confirmada: cero identidades temporales y cero membresías administrativas dejadas por las pruebas; nueve perfiles previos conservados.
- Activación administrativa posterior: el titular creó su cuenta y confirmó el correo. Supabase devolvió correo confirmado, perfil activo y membresía ausente. Se habilitó exclusivamente su membresía mediante una consulta de servidor condicionada a esos requisitos; el recibo devolvió `admin_active = true`. Al recargar su sesión del panel, apareció el directorio con diez cuentas y conexión activa. No se cambió su contraseña ni se omitió la confirmación de correo.
- Instalación inicial de contenedores: Docker Desktop 4.90.0, cliente 29.7.2, WSL 2.7.14.0 y kernel 6.18.33.2-2 instalados. En ese momento Windows tenía un reinicio pendiente y el motor no estaba disponible. Ese bloqueo se resolvió con el reinicio y las comprobaciones descritas abajo.
- Durante la instalación se comprobaron Supabase CLI 2.117.0 y las diez pruebas de `tools/verification` con `npm.cmd test`.

## Cierre de validaciones del hito 1

- Después del reinicio: Windows inició el 13 de septiembre de 2026 a las 16:36; no hay reinicio pendiente. `docker version` devuelve cliente y servidor 29.7.2 y WSL tiene la distribución `docker-desktop` en versión 2. Se inició Supabase local con las dos migraciones y los servicios reales Auth, REST y Mailpit.
- PostgreSQL local: `supabase test db` aprobó las once comprobaciones pgTAP. Ya no existe el bloqueo de Docker.
- CI existente verificado mediante la API de GitHub: [ejecución 34786807228](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34786807228), commit `f0ade1a`, terminó con éxito en sus tres jobs. Incluye pruebas/build del prototipo y admin, permisos PostgreSQL, análisis/pruebas Flutter, APK Android e iOS simulator compilado en macOS. La compilación de iOS ya está comprobada.
- Sesión del titular: después de reiniciar Windows y abrir de nuevo la vista Flutter, se restauró el perfil confirmado sin pedir credenciales. La experiencia se cambió a rescatista desde el formulario, se guardó en Supabase y persistió al recargar. Se restableció y guardó la experiencia original donante/adoptante. El panel también restauró la sesión administrativa y mostró las diez cuentas, incluida la experiencia original restaurada.
- Integración Flutter/Supabase: dos recorridos aprobados con cuentas locales desechables. Ambos comprueban registro con confirmación obligatoria, perfil editable persistente, cierre/restauración de cliente, denegación administrativa, recuperación, contraseña anterior rechazada y nueva contraseña aceptada. Uno consume el código recibido en Mailpit; el otro consume el enlace PKCE después de reiniciar el cliente. También se restaura una sesión interrumpida durante la recuperación sin permitirle entrar al perfil antes del cambio.
- Estas pruebas usan las clases de producción del repositorio, controlador y almacenamiento. Los servicios de Auth/PostgreSQL/SMTP son reales; las APIs nativas de preferencias y almacenamiento seguro están simuladas en el ejecutor de Flutter. No se declara una prueba de hardware móvil ni de Keychain/Keystore en dispositivo. La limpieza dejó cero identidades de aceptación y cero perfiles en la base local.
- `scripts/verify-identity.ps1` prepara el entorno local y ejecuta los permisos y ambos recorridos. El comando completo se ejecutó correctamente: once comprobaciones SQL y dos recorridos de identidad aprobados. El análisis final de Flutter no encontró incidencias.

## Resultado final

- [Ejecución 34788208103](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34788208103), commit `788a236278122c977190e91278f20709b6c7ca01`: resultado global `success`. Los cuatro jobs aprobaron: `web-and-database`, `flutter`, `ios` e `identity-backend`. Esto incluye las diez pruebas Flutter de estado/interfaz, cinco del admin, cuatro del prototipo, diez de PGlite, once comprobaciones pgTAP, dos recorridos completos de identidad, compilaciones web/Android/iOS simulator y formato/análisis de Flutter.
- Implementación y pruebas subidas a `codex/Dopmi` en `albertoquiroga-ctrl/dopmi-app`. El registro final es un cambio exclusivo de documentación; no modifica el código validado por esa ejecución.
- No quedan tareas abiertas del hito 1. El alcance de esta aceptación es desarrollo: los puntos de beta/distribución siguientes mantienen su hito original.

## Condiciones para los hitos posteriores

- La recuperación del titular no se ejecutó cambiando su contraseña personal; el recorrido completo se comprobó con identidades locales de prueba y las mismas clases de producción.
- Las compilaciones de Android e iOS simulator están comprobadas. Instalación, enlaces desde clientes de correo de cada sistema, almacenamiento seguro en hardware y firma de distribución requieren dispositivos y forman parte de la validación de beta/lanzamiento del hito 6.
- El correo integrado de Supabase sigue activo. SMTP propio es necesario para ampliar destinatarios/volumen de la beta. Google/Apple permanecen deshabilitados hasta configurar y verificar sus proveedores.

El siguiente alcance es H2: adopción y comunicación. No se inicia automáticamente como parte del cierre de identidad.

## Emulación solicitada después del cierre del hito 1

- Android Emulator 37.1.11 y la imagen oficial Android 15 / API 35 / x86_64 instalados en `.tools/android-sdk`, fuera de Git. Se creó `Dopmi_API_35`, con dos núcleos, 1536 MB de RAM y pantalla de 720×1520. El equipo tiene 8 GB de RAM y poca memoria libre; el primer arranque fue lento.
- La consulta de componentes de Windows indicó `HypervisorPlatform` desactivado, pero la comprobación directa `emulator -accel-check` devolvió `WHPX(10.0.19045) is installed and usable`. El registro de arranque confirmó aceleración operacional. No fue necesario cambiar componentes de Windows ni reiniciar.
- `emulator-5556` inició con `sys.boot_completed = 1`. Se instaló correctamente el APK de desarrollo existente, versión 0.1.0, que contiene x86_64. El primer `am start -W` agotó su espera; una comprobación posterior confirmó proceso activo, `MainActivity` reanudada y en primer plano, motor Flutter iniciado y búfer de errores de cierre vacío. Esto verifica instalación y ejecución nativas en el emulador; no añade una comprobación visual ni un recorrido autenticado de usuario en Android.
- `flutter analyze`: sin incidencias. `flutter test`: diez pruebas aprobadas en esta sesión.
- Se añadió `scripts/emulate-android.ps1` para abrir el dispositivo e instalar el APK; `-Rebuild` recompila cuando cambian código/configuración. El comando y las instrucciones para iOS están en `docs/development.md`. La sintaxis PowerShell se comprobó; el arranque/instalación se ejecutó con ese script y las comprobaciones posteriores usaron ADB.
- iOS interactivo queda pendiente por plataforma: esta sesión dispone de Windows, sin una Mac/Xcode conectada. El simulador oficial requiere macOS. Se conserva la evidencia previa de compilación iOS en CI; no se declara una ejecución interactiva de iOS nueva.



