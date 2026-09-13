# Dopmi — registro de avance

## Hito 1

Estado: flujos de identidad comprobados, Android e iOS simulator compilados y acceso administrativo del titular habilitado. Validación final en curso del CI ampliado con integración de Auth/SMTP.

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
- Entorno de contenedores: Docker Desktop 4.90.0 instalado para el usuario con backend WSL 2; el instalador terminó correctamente y agregó su CLI al PATH del usuario. `docker --version` confirmó el cliente 29.7.2. WSL 2.7.14.0 y kernel 6.18.33.2-2 instalados; los componentes WSL y VirtualMachinePlatform figuran habilitados, pero Windows confirmó un reinicio pendiente. `wsl --status` aún devuelve `WSL_E_WSL_OPTIONAL_COMPONENT_REQUIRED` y `docker version` no encuentra el motor. No se ha comprobado la ejecución de contenedores ni de pgTAP local.
- Verificación durante la instalación: Supabase CLI 2.117.0 comprobada y las diez pruebas de `tools/verification` aprobadas nuevamente con `npm.cmd test`. El reinicio de Windows queda a cargo del usuario; después se debe abrir Docker Desktop y ejecutar la comprobación local indicada en `docs/development.md`.

## Cierre de validaciones del hito 1

- Después del reinicio: Windows inició el 13 de septiembre de 2026 a las 16:36; no hay reinicio pendiente. `docker version` devuelve cliente y servidor 29.7.2 y WSL tiene la distribución `docker-desktop` en versión 2. Se inició Supabase local con las dos migraciones y los servicios reales Auth, REST y Mailpit.
- PostgreSQL local: `supabase test db` aprobó las once comprobaciones pgTAP. Ya no existe el bloqueo de Docker.
- CI existente verificado mediante la API de GitHub: [ejecución 34786807228](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34786807228), commit `f0ade1a`, terminó con éxito en sus tres jobs. Incluye pruebas/build del prototipo y admin, permisos PostgreSQL, análisis/pruebas Flutter, APK Android e iOS simulator compilado en macOS. La compilación de iOS ya está comprobada.
- Sesión del titular: después de reiniciar Windows y abrir de nuevo la vista Flutter, se restauró el perfil confirmado sin pedir credenciales. La experiencia se cambió a rescatista desde el formulario, se guardó en Supabase y persistió al recargar. Se restablece la experiencia original donante/adoptante al terminar la prueba.
- Integración Flutter/Supabase: dos recorridos aprobados con cuentas locales desechables. Ambos comprueban registro con confirmación obligatoria, perfil editable persistente, cierre/restauración de cliente, denegación administrativa, recuperación, contraseña anterior rechazada y nueva contraseña aceptada. Uno consume el código recibido en Mailpit; el otro consume el enlace PKCE después de reiniciar el cliente. También se restaura una sesión interrumpida durante la recuperación sin permitirle entrar al perfil antes del cambio.
- Estas pruebas usan las clases de producción del repositorio, controlador y almacenamiento. Los servicios de Auth/PostgreSQL/SMTP son reales; las APIs nativas de preferencias y almacenamiento seguro están simuladas en el ejecutor de Flutter. No se declara una prueba de hardware móvil ni de Keychain/Keystore en dispositivo. La limpieza dejó cero identidades de aceptación y cero perfiles en la base local.
- `scripts/verify-identity.ps1` prepara el entorno local y ejecuta los permisos y ambos recorridos. El nuevo job `identity-backend` incorpora la misma comprobación al workflow; su ejecución remota está pendiente de confirmar.

## Verificación final pendiente

- Confirmar el CI ampliado después de publicar la nueva prueba y su workflow.

## Condiciones para los hitos posteriores

- La recuperación del titular no se ejecutó cambiando su contraseña personal; el recorrido completo se comprobó con identidades locales de prueba y las mismas clases de producción.
- Las compilaciones de Android e iOS simulator están comprobadas. Instalación, enlaces desde clientes de correo de cada sistema, almacenamiento seguro en hardware y firma de distribución requieren dispositivos y forman parte de la validación de beta/lanzamiento del hito 6.
- El correo integrado de Supabase sigue activo. SMTP propio es necesario para ampliar destinatarios/volumen de la beta. Google/Apple permanecen deshabilitados hasta configurar y verificar sus proveedores.

El siguiente alcance es H2: adopción y comunicación. No se inicia automáticamente como parte del cierre de identidad.
