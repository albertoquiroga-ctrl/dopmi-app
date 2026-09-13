# Dopmi — registro de avance

## Hito 1

Estado: implementación disponible, APK Android generado y acceso administrativo del titular comprobado. Aceptación final pendiente de las validaciones móviles restantes, recuperación de acceso e iOS.

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

## Pendientes de aceptación

- Registro, confirmación y entrada administrativa del titular comprobados. Falta comprobar con esa cuenta persistencia móvil al reiniciar, edición de perfil y recuperación de acceso por correo.
- iOS: proyecto, Keychain, callback y job de macOS preparados. Compilación y pruebas en Xcode/dispositivo todavía no ejecutadas en este Windows.
- Docker/Podman no están instalados; las pruebas locales de Supabase CLI no pueden arrancar aquí. Las pruebas SQL sí se ejecutaron en PGlite y en Supabase remoto.
- CI está escrito; no se ha enviado al repositorio remoto ni ejecutado en GitHub Actions.
- El correo integrado de Supabase sigue activo. SMTP propio es necesario para ampliar destinatarios/volumen de la beta. Google/Apple permanecen deshabilitados hasta configurar y verificar sus proveedores.

No se declara completo el hito mientras falten las verificaciones externas indicadas. El siguiente alcance, una vez aceptada identidad, es H2: adopción y comunicación.
