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
