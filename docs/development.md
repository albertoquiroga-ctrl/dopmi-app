# Desarrollo de Dopmi

## Áreas del repositorio

- `src/`: prototipo React conservado como referencia, puerto 5173.
- `apps/mobile/`: Flutter 3.47.4 / Dart 3.13.3, Riverpod, go_router y Supabase. Android e iOS; la salida web sirve para revisión local.
- `apps/admin/`: React/TypeScript, consulta administrativa de usuarios, puerto 5174.
- `supabase/`: migraciones, permisos, plantillas de correo y pruebas pgTAP.
- `tools/verification/`: pruebas de la migración con PostgreSQL mediante PGlite y CLI de Supabase fijada por el lockfile.

No hay autenticación simulada en `apps/`. Sin configuración, las apps muestran un estado de conexión pendiente.

## Iniciar en este Windows

Las herramientas descargadas están en `.tools/`, fuera de Git. Los archivos locales de conexión ya apuntan al proyecto de desarrollo `ohqxranynackjignryep` y usan exclusivamente su clave publicable.

Desde la raíz, en terminales separadas:

```powershell
.\scripts\dev.ps1 mobile-web
.\scripts\dev.ps1 admin
```

Abre `http://localhost:5175` para la app y `http://127.0.0.1:5174` para administración. Usa el mismo navegador y origen durante registro/recuperación: PKCE guarda allí el verificador del enlace. También puedes escribir el código del correo en la app. Las sesiones del panel y de la app son independientes.

En un emulador o teléfono conectado:

```powershell
.\scripts\dev.ps1 mobile
.\scripts\dev.ps1 android
```

El segundo comando genera `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. Es un APK de desarrollo, no un paquete firmado para publicar. El callback móvil registrado es `io.dopmi.app://auth/callback` y las sesiones usan almacenamiento seguro nativo. Las claves PKCE también se guardan en almacenamiento seguro.

## Configurar otra máquina

Instala Node 24 y Flutter 3.47.4. Ejecuta `npm ci` por separado en la raíz, `apps/admin` y `tools/verification`; luego `flutter pub get` en `apps/mobile`.

1. Copia `apps/mobile/config.example.json` a `config.local.json` y agrega la URL y **clave publicable** de desarrollo.
2. Para revisar en navegador, crea `config.web.local.json` con el mismo contenido y `AUTH_REDIRECT_URL` igual a `http://localhost:5175/auth/callback`.
3. Copia `apps/admin/.env.example` a `.env.local` y completa la clave publicable.
4. Nunca uses `service_role`, `sb_secret_…` ni credenciales de Stripe en ninguna app cliente. Los archivos locales están ignorados por Git.

## Base de datos y correos

En este Windows están instalados y funcionando Docker Desktop 4.90.0 y WSL 2.7.14.0. El reinicio posterior a la instalación ya se realizó. Abre Docker Desktop y espera a que indique que el motor está en ejecución antes de iniciar las pruebas locales.

Para comprobar solamente PostgreSQL y los permisos, ejecuta desde la raíz del repositorio:

```powershell
docker version
.\tools\verification\node_modules\.bin\supabase.cmd db start
.\tools\verification\node_modules\.bin\supabase.cmd test db
```

`docker version` debe mostrar tanto Client como Server. La primera ejecución de `db start` descarga la imagen de PostgreSQL y aplica las migraciones locales. Esta comprobación no modifica el proyecto remoto.

Para una base local nueva con Docker:

```powershell
.\tools\verification\node_modules\.bin\supabase.cmd start
.\tools\verification\node_modules\.bin\supabase.cmd db reset
.\tools\verification\node_modules\.bin\supabase.cmd test db
```

El correo local se consulta en el servidor de pruebas que muestra `supabase status`. Para Android Emulator, usa `10.0.2.2:54321` como URL local del backend; para dispositivo físico, una dirección accesible de tu computadora. No ejecutes `db reset --linked` en un proyecto compartido.

El proyecto remoto ya tenía nueve identidades de prueba y tablas de otra versión. Se preservaron; la app usa `public.profiles` y `private.admin_memberships`. `public.dopmi_is_admin()` evita usar la función antigua `is_admin(uuid)`.

Las migraciones `202609130001_identity.sql` y `202609130002_legacy_identity_boundary.sql` se aplicaron desde el editor SQL del dashboard el 13 de septiembre de 2026. No había historial de Supabase CLI. **Antes del primer `db push` hacia ese proyecto**, enlázalo con la CLI y registra cada versión como aplicada con `supabase migration repair VERSION --status applied --linked`; revisa primero `supabase migration list`. No vuelvas a ejecutar la primera migración sobre las tablas ya creadas.

La segunda migración cierra el acceso de `anon` y `authenticated` a `public.users`, incluidos permisos por columna. Esa tabla permitía actualizar el rol propio mediante una protección heredada ineficaz. Sus registros y triggers quedan disponibles para el servidor; los clientes antiguos que consulten esa tabla deberán migrar a los endpoints nuevos. No hay vistas públicas que consulten `users` en el entorno revisado.

En Auth del proyecto de desarrollo:

- Confirmación de correo: obligatoria; registro anónimo deshabilitado.
- Contraseña: mínimo 10 caracteres, mayúscula, minúscula y número; cambio seguro habilitado.
- Retornos exactos: `io.dopmi.app://auth/callback`, `http://localhost:5175/auth/callback` y `http://127.0.0.1:5175/auth/callback`.
- Plantillas de confirmación/recuperación: `supabase/templates/`, enlace PKCE y código de ocho dígitos; vencimiento de una hora.
- El envío remoto usa el correo integrado de Supabase. Tiene límites y restricciones de destinatarios. Configura SMTP propio para una beta con más personas; no desactives la confirmación para evitar esos límites.

Google y Apple están implementados detrás de `ENABLE_GOOGLE_AUTH` y `ENABLE_APPLE_AUTH`, deshabilitados por defecto. Actívalos únicamente después de configurar el proveedor, credenciales y retornos en Supabase y verificar el flujo. No se han validado inicios sociales.

## Crear un administrador

La persona crea su cuenta en la app y confirma su correo. Un operador del servidor ejecuta `supabase/bootstrap-admin.sql` con la variable psql `admin_email`. El script solo habilita identidades confirmadas; si no existe la cuenta, no concede nada. No hay registro público administrativo ni privilegios en metadata editable.

```sh
psql "$DATABASE_URL" -v admin_email='correo-del-administrador' -f supabase/bootstrap-admin.sql
```

No pases la URL privada de la base al frontend ni la guardes en Git. También puedes adaptar esa consulta para ejecutarla desde el editor SQL del proyecto.

Para revocar, un operador cambia `private.admin_memberships.active` a `false`. Cada consulta administrativa vuelve a comprobar el permiso y registra `users.list` en `private.admin_access_log`. El panel es de consulta, sin edición ni borrado de personas.

## Pruebas y entrega

```powershell
.\scripts\dev.ps1 verify
node tools/verification/remote-smoke.mjs
```

La primera instrucción verifica SQL, admin y Flutter. La segunda hace cinco comprobaciones de solo lectura contra el remoto configurado: Auth, confirmación y denegación anónima de perfiles, usuarios heredados y RPC. Las pruebas pgTAP requieren PostgreSQL/Supabase local o el entorno de pruebas; las de PGlite no requieren Docker y ejecutan las migraciones reales con roles de PostgreSQL.

Para ejecutar el recorrido completo de identidad con servicios reales y cuentas desechables locales:

```powershell
.\scripts\verify-identity.ps1
```

El comando inicia Auth, PostgreSQL, REST y Mailpit, ejecuta las once comprobaciones pgTAP y los dos recorridos de `apps/mobile/test_backend/identity_backend_test.dart`. Comprueba registro, rechazo antes de confirmar, código recibido por correo, edición del perfil, sesión restaurada, denegación administrativa, recuperación por código y enlace PKCE, restauración durante recuperación, cambio de contraseña y salida. Las cuentas creadas se eliminan al terminar; los correos quedan en el buzón local para inspección.

La prueba usa el repositorio, controlador y almacenamiento de sesión/PKCE de la app. Auth, base de datos y SMTP son reales; las APIs de preferencias y almacenamiento seguro de la plataforma se sustituyen por sus implementaciones de prueba. No equivale a probar hardware de Keystore/Keychain ni a instalar en un teléfono. Solo acepta URLs de loopback. La clave de servidor usada para limpiar las identidades pertenece exclusivamente al entorno local y permanece en `.tools/supabase.local.json`, ignorado por Git; nunca se incorpora a la app.

`.github/workflows/milestone-1.yml` comprueba el prototipo, panel, permisos, Flutter y el recorrido contra Supabase local; compila Android e iOS simulator. La compilación iOS se ejecuta en macOS/Xcode. El registro de avance enlaza las ejecuciones comprobadas. Para publicar en tiendas faltan firma de distribución, pruebas de dispositivos y preparación del hito de lanzamiento.

El registro de resultados efectivos está en `docs/progress.md`. Sigue `docs/backlog.md` para el siguiente ciclo. Los avisos legales de esta versión son provisionales de desarrollo.
