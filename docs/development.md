# Desarrollo de Dopmi

## Continuidad y alcance de esta guía

Para retomar en Codex, empezar por [codex-handoff.md](codex-handoff.md). Rama de continuación al 25 de septiembre de 2026: `codex/stripe-transfer-delivery`; H5 sigue abierto para aceptación. El titular usa [Codemagic → TestFlight](guardian-acceptance.md). La configuración y las instalaciones descritas como «este Windows» son históricas del equipo original; no están incluidas en Git ni garantizadas en otra sesión.

En una máquina nueva: Node 24, Flutter 3.47.4 / Dart 3.13.3 y Python 3; Docker para pruebas PostgreSQL. Instalar con `npm ci` en raíz, `apps/admin` y `tools/verification`; luego `flutter pub get` en `apps/mobile`. Los comandos reproducibles y las diferencias Java/Flutter entre CI y Codemagic están en la guía de continuidad. El panel actual también incluye rescates y aportaciones; la sección H2 conserva su descripción histórica.

Para ver Guardián localmente, establecer `ENABLE_GUARDIAN_TEST` en `config.local.json` con el proyecto y clave publicable de prueba. No abre el alta del servidor. Los seis flags remotos y el estado de preparación se documentan en la guía de aceptación; no copiar claves de servidor a ese archivo.

## Áreas del repositorio

- `src/`: prototipo React conservado como referencia, puerto 5173.
- `apps/mobile/`: Flutter 3.47.4 / Dart 3.13.3, Riverpod, go_router y Supabase. Android e iOS; la salida web sirve para revisión local.
- `apps/admin/`: React/TypeScript, consulta de usuarios y revisión de adopciones, puerto 5174.
- `supabase/`: migraciones, permisos, plantillas de correo y pruebas pgTAP.
- `tools/verification/`: pruebas de la migración con PostgreSQL mediante PGlite y CLI de Supabase fijada por el lockfile.

No hay autenticación simulada en `apps/`. Sin configuración, las apps muestran un estado de conexión pendiente.

## Adopción y comunicación (hito 2)

La app permite explorar publicaciones aprobadas sin cuenta. Para guardar, publicar o conversar se requiere una cuenta activa, correo confirmado y aceptación del aviso de desarrollo en Cuenta. Las pestañas son Adoptar, Guardados, Publicar, Mensajes y Cuenta; la campana abre las notificaciones internas.

En Publicar se guardan borradores, se adjuntan hasta cinco fotos y se envía a revisión. El panel permite aprobar, pedir correcciones, rechazar o retirar, con la versión revisada y el historial. Editar una publicación aprobada la devuelve a borrador y la oculta hasta otra revisión. Una adopción realizada deja de aceptar contactos nuevos; las conversaciones existentes se conservan y pueden cerrarse.

Storage usa el bucket privado `dopmi-adoption-photos`, límite de 5 MiB y formatos JPG/PNG/WebP. La app prepara JPEG sin EXIF y con lado máximo de 1600 píxeles. Los enlaces firmados duran 60 segundos: retirar una publicación impide generar enlaces nuevos, pero un enlace ya emitido puede funcionar hasta su vencimiento. No hay direcciones particulares, teléfonos ni documentos en los perfiles públicos.

Mensajes y notificaciones usan Realtime con RLS. Al recibir la confirmación de PostgreSQL (`system`, `extension=postgres_changes`, `status=ok`) se vuelve a consultar la información persistente: el join del canal por sí solo no garantiza que ya reciba cambios. También se consulta al volver a primer plano y mediante un intervalo de respaldo. Las notificaciones de este hito son internas, sin push. Los mensajes incluyen un UUID de envío que se reutiliza ante una respuesta perdida.

Pruebas completas de backend local:

```powershell
.\scripts\verify-backend.ps1
```

El script inicia Auth, PostgreSQL, Storage, Realtime y Mailpit, aplica migraciones locales y ejecuta pgTAP y los recorridos Flutter de identidad/adopción. Si el stack ya estaba iniciado excluyendo Storage/Realtime, ejecuta `supabase stop` antes para reiniciarlo con esos servicios. Las cuentas de aceptación solo se crean en loopback y se eliminan al terminar. La membresía administrativa de prueba se asigna mediante Docker/psql al UUID de la cuenta temporal, nunca desde el cliente.

Las migraciones `202609130003`, `202609130004` y `202609130005` se aplicaron históricamente en el dashboard en una transacción. Revisar el historial actual y la auditoría enlazada abajo antes de decidir si necesitan reparación; no asumir que ese trabajo sigue pendiente.

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

### Emulador Android en este equipo

El dispositivo local `Dopmi_API_35` usa Android 15 (API 35), arquitectura x86_64, pantalla de 720×1520, dos núcleos y 1536 MB de RAM. El SDK y la imagen están en `.tools/android-sdk`; los datos persistentes del dispositivo están en `%USERPROFILE%/.android/avd`, fuera del repositorio.

Para abrirlo e instalar el APK ya compilado:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\emulate-android.ps1
```

Agrega `-Rebuild` después de cambiar el código o la configuración de conexión. Sin ese parámetro se reutiliza el APK existente. El script usa el puerto 5556, espera el arranque de Android y abre Dopmi. Se puede cerrar la ventana del emulador al terminar; la cuenta y la sesión se conservan en su disco. Los registros de arranque quedan en `.tools/android-emulator*.log`. La opción de ejecución de PowerShell aplica únicamente a ese proceso.

Para desarrollo con recarga en caliente, una vez iniciado el dispositivo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 mobile
```

Selecciona `emulator-5556` si Flutter pregunta por el dispositivo. Esta máquina tiene 8 GB de RAM; cerrar aplicaciones pesadas que no estés usando ayuda al emulador.

Para recrear el dispositivo en otra instalación con el SDK y JDK configurados, instala `emulator` y `system-images;android-35;default;x86_64` con el administrador del SDK. Luego ejecuta `avdmanager create avd --name Dopmi_API_35 --package "system-images;android-35;default;x86_64" --device pixel_4`. Comprueba `emulator -accel-check` antes de iniciar; el script muestra el resultado efectivo del hipervisor.

### Simulador iOS

El simulador oficial requiere macOS y Xcode; no se ejecuta localmente en Windows. En una Mac preparada según la [guía de Flutter](https://docs.flutter.dev/platform-integration/ios/setup), copia la configuración publicable de desarrollo a `apps/mobile/config.local.json`, abre el simulador desde Xcode y ejecuta:

```sh
cd apps/mobile
flutter pub get
flutter devices
flutter run -d <id-del-simulador> --dart-define-from-file=config.local.json
```

La compilación para simulador en el CI de macOS está documentada en `progress.md`; ese resultado no equivale a una sesión interactiva de iOS comprobada en esta computadora.

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

Las migraciones `202609130001_identity.sql` y `202609130002_legacy_identity_boundary.sql` se aplicaron desde SQL Editor el 13 de septiembre de 2026; entonces no había historial CLI. **Antes de cualquier `db push` o reparación**, comparar el historial remoto actual, el SQL/esquema aplicado y los archivos según [migration-history-audit.md](migration-history-audit.md). Solo usar `migration repair` cuando esa comparación demuestre la correspondencia. No reparar en bloque ni volver a ejecutar migraciones sobre tablas ya creadas.

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

Para revocar, un operador cambia `private.admin_memberships.active` a `false`. Cada consulta administrativa vuelve a comprobar el permiso; las consultas de personas registran `users.list` en `private.admin_access_log`. La sección de personas es de consulta, sin edición ni borrado; la sección de adopciones registra las decisiones de moderación y su versión.

## Pruebas y entrega

```powershell
.\scripts\dev.ps1 verify
node tools/verification/remote-smoke.mjs
```

La primera instrucción verifica SQL, admin y Flutter. La segunda comprueba de solo lectura el remoto configurado: Auth, confirmación, catálogo público y denegación anónima de tablas privadas/RPC administrativas. Las pruebas pgTAP requieren PostgreSQL/Supabase local o el entorno de pruebas; las de PGlite no requieren Docker y ejecutan las migraciones reales con roles de PostgreSQL.

Para ejecutar el recorrido completo de identidad con servicios reales y cuentas desechables locales:

```powershell
.\scripts\verify-identity.ps1
```

El comando de identidad inicia Auth, PostgreSQL, REST y Mailpit, ejecuta las comprobaciones pgTAP disponibles y los dos recorridos de `apps/mobile/test_backend/identity_backend_test.dart`. Comprueba registro, rechazo antes de confirmar, código recibido por correo, edición del perfil, sesión restaurada, denegación administrativa, recuperación por código y enlace PKCE, restauración durante recuperación, cambio de contraseña y salida. Las cuentas creadas se eliminan al terminar; los correos quedan en el buzón local para inspección. Para la aceptación completa del hito 2 usa `verify-backend.ps1`, que incluye Storage, Realtime y adopción.

La prueba usa el repositorio, controlador y almacenamiento de sesión/PKCE de la app. Auth, base de datos y SMTP son reales; las APIs de preferencias y almacenamiento seguro de la plataforma se sustituyen por sus implementaciones de prueba. No equivale a probar hardware de Keystore/Keychain ni a instalar en un teléfono. Solo acepta URLs de loopback. La clave de servidor usada para limpiar las identidades pertenece exclusivamente al entorno local y permanece en `.tools/supabase.local.json`, ignorado por Git; nunca se incorpora a la app.

`.github/workflows/milestone-1.yml` comprueba el prototipo, panel, permisos, Flutter y el recorrido contra Supabase local; compila Android e iOS simulator. La compilación iOS se ejecuta en macOS/Xcode. El registro de avance enlaza las ejecuciones comprobadas. Para publicar en tiendas faltan firma de distribución, pruebas de dispositivos y preparación del hito de lanzamiento.

El registro de resultados efectivos está en `docs/progress.md`. Sigue `docs/backlog.md` para el siguiente ciclo. Los avisos legales de esta versión son provisionales de desarrollo.
