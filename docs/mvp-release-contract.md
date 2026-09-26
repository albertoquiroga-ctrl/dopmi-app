# Dopmi — contrato del MVP público

> Actualización autorizada el 25 de septiembre de 2026 (México): `release-roadmap.md` y `backlog.md` gobiernan el alcance vigente. Referencia viva: rama `irlanda/apoyar-detalle-perfil`; se registra el SHA por entrega. Videos, Meta, push y analítica avanzada son post-MVP; tienda, fondo comunitario, bonos y cashback están excluidos. La regla histórica de implementar todo el mockup no incorpora esas simulaciones. Google/Apple, eliminación de cuenta y medición mínima sí forman parte del MVP. H5 está aceptado en test; dinero real requiere aceptación separada.


> Lectura de continuidad, 25 de septiembre de 2026: este contrato conserva el alcance y la checklist histórica de lanzamiento, no es el estado operativo más reciente. Consultar [codex-handoff.md](codex-handoff.md) y [backlog.md](backlog.md). R0–R6 y H1–H6 son listas diferentes. El repositorio ya configura iOS con `com.mycompany.dopmi`, integración `dopmi_app_store`, versión 2.3.3 y TestFlight; falta acreditar la nueva aceptación Guardián en dispositivo. Las casillas de credenciales/tiendas deben contrastarse con las cuentas antes de repetir o rotar configuraciones existentes. Una fecha programada de activación no acredita que se completó.

Estado: **alcance completo autorizado**  
Referencia funcional fijada: `albertoquiroga-ctrl/dopmi-functional-mockup@961b557cfb4163aceaf6283fd077ab2e659037ba`  
Base de producción: `albertoquiroga-ctrl/dopmi-app@5e49f497edaad4b770203b5072423e6a2ba91a8a`  
Backend de desarrollo: Supabase `ohqxranynackjignryep`  
Android de producción confirmado: `com.mycompany.dopmi` (Google Play, 4.2 mil instalaciones visibles al 20 de septiembre de 2026)

## Regla de alcance

El MVP público implementará todas las funcionalidades descritas y navegables en el Functional Mockup. El trabajo se divide en entregas verificables, pero dividirlo no elimina ni pospone funcionalidades del contrato.

El prototipo es la referencia de experiencia y contenido. Sus simulaciones no se trasladan a producción: autenticación, permisos, pagos, verificación, evidencia y publicación deben operar contra servicios reales y con autorización en servidor.

## Inventario funcional

### Acceso, identidad y legal

- Splash y selección de intención.
- Onboarding diferenciado para donante/adoptante y rescatista.
- Bienvenida, registro e inicio de sesión.
- Acceso con Google y Apple cuando sus proveedores estén configurados.
- Confirmación de correo, recuperación y cambio de contraseña.
- Sesión persistente y cambio entre experiencias sin duplicar identidad.
- Términos, privacidad y aceptación versionada.

### Donante y adoptante

- Catálogo de adopción, vacío, filtros, detalle y guardados.
- Solicitud/contacto y conversaciones privadas.
- Perfil público del rescatista, guardado, redes aprobadas, reporte y pestañas.
- Catálogo de casos y detalle público.
- Donación por necesidad, éxito, error, historial y notificaciones.
- Tu Impacto antes y después de ser Guardián.
- Guardián mensual con montos predefinidos o personalizado.
- Perfil, información básica, métodos de pago, billing, cambio/cancelación de suscripción e historial.
- Centro de ayuda.

### Rescatista

- Home por estado de verificación, Cuenta Dopmi, pendientes y actividad.
- Verificación con información, experiencia, redes y documentos privados.
- Estado sin verificar, en revisión, correcciones, aprobación y suspensión.
- Publicación de adopciones y casos.
- Borradores, revisión, rechazo, correcciones, retiro y cierre.
- Necesidades de comida, medicina y veterinario.
- Evidencia por categoría, comprobantes y ciclos recurrentes de comida; videos post-MVP.
- Mis casos, progreso de fondeo, adopción y estados.
- Mensajes.
- Perfil público y privado, edición, pagos, datos bancarios y centro legal.

### Operación administrativa

- Personas y membresías administrativas seguras.
- Revisión de adopciones.
- Verificación de rescatistas y documentos privados.
- Revisión de casos, gastos, evidencia y correcciones.
- Moderación de contenido y reportes.
- Aportaciones, conciliación, asignación, transferencias y auditoría.
- Suscripciones Guardián, cobros, distribución y devoluciones.
- Historial de decisiones y acceso administrativo.

### Plataforma pública

- Landing en `dopmi.org`.
- Panel en `admin.dopmi.org`.
- Android en Google Play Internal Testing y producción.
- iOS en TestFlight y App Store.
- Data Safety, privacidad, fichas, iconos, capturas y soporte.
- Observabilidad, manejo de errores y procedimiento de incidentes.

## Matriz inicial de rutas del prototipo

El Functional Mockup contiene 53 rutas explícitas antes de la ruta de respaldo:

| Área | Rutas de referencia |
|---|---|
| Acceso | `/`, `/choose-intent`, onboarding, welcome, login, signup |
| Recuperación/legal | cuatro estados de recuperación, términos y privacidad |
| Adopción | catálogo y detalle |
| Donaciones | catálogo, caso, pago, éxito y error |
| Impacto/Guardián | impacto, selección, éxito y error |
| Comunicación | bandeja, conversación y notificaciones |
| Cuenta donante | historial, perfil, guardados, settings, pagos, billing y ayuda |
| Perfil público | perfil del rescatista desde un caso |
| Rescatista | home, verificación, casos, detalle y publicación |
| Evidencia | evidencia por necesidad y ciclo de comida |
| Cuenta rescatista | mensajes, perfil, edición, pagos, legal y settings |

La revisión de aceptación usará el recorrido y los estados, no solamente la existencia de una pantalla.

## Entregas

### R0 — Base de lanzamiento

- [ ] Congelar esta referencia y conciliar documentación.
- [ ] Mantener CI verde en web, admin, base, Android e iOS simulator.
- [x] Confirmar Android package name: `com.mycompany.dopmi`.
- [ ] Verificar identidad/firma con la ficha existente de App Store Connect en la nueva entrega. El repositorio ya configura `com.mycompany.dopmi`; no cambiarlo ni volver a crear la configuración TestFlight.
- [x] Añadir `codemagic.yaml` sin secretos.
- [x] Configurar versionado reproducible de Android desde `2.3.0+227`.
- [x] Confirmar que Google Play App Signing protege la app de producción.
- [x] Recuperar el upload keystore generado por FlutterFlow y comprobar que corresponde a un certificado anterior.
- [x] Generar un upload keystore nuevo y solicitar el reset en Play Console.
- [ ] Activación del nuevo upload certificate: programada por Google Play para el 22 de septiembre de 2026 a las 22:39 UTC.
- [ ] Cargar el nuevo keystore en Codemagic con referencia `dopmi_upload_2026`.
- [ ] Configurar las credenciales de Google Play y Supabase como secretos de Codemagic.
- [ ] Ejecutar y verificar el primer despliegue a Internal Testing.
- [ ] Documentar recuperación de credenciales y responsables.
- [ ] Publicar la política de privacidad en `dopmi.org` y registrar su URL en Play Console.
- [ ] Crear checklist de Data Safety y privacidad.

### R1 — Paridad de identidad y navegación

- [ ] Comparar pantalla por pantalla contra la referencia.
- [ ] Completar onboarding, acceso social, recuperación y legal.
- [ ] Pruebas de navegación, accesibilidad y sesiones en dispositivo.

### R2 — Adopción y comunicación

- [ ] Completar paridad visual y funcional.
- [ ] Verificar revisión, catálogo, guardados, perfiles y mensajes.
- [ ] Notificaciones internas y preparación de push.

### R3 — Rescatistas, publicación y evidencia

- [ ] Completar paridad del home y perfil.
- [ ] Verificación, casos, necesidades, evidencia y ciclos.
- [ ] Operación administrativa y privacidad de documentos.

### R4 — Dinero real

- [ ] Stripe Connect y onboarding del rescatista.
- [ ] Donación, conciliación, asignación, comisión y transferencia.
- [ ] Guardián mensual, distribución, cambios, cancelación y devoluciones.
- [ ] Webhooks idempotentes, recibos, auditoría y pruebas financieras.

### R5 — Superficie pública y operación

- [ ] Landing y panel desplegados.
- [ ] Ayuda, términos, privacidad y soporte definitivos.
- [ ] Analítica mínima, errores y monitoreo.

### R6 — Beta y tiendas

- [ ] Google Play Internal Testing en dispositivos reales.
- [ ] TestFlight en dispositivos reales.
- [ ] Data Safety y App Privacy consistentes con el comportamiento real.
- [ ] Pruebas de instalación, actualización, enlaces, permisos y recuperación.
- [ ] Cero defectos bloqueantes y plan de reversión.

## Definición de terminado

Una casilla solo puede cerrarse cuando existe evidencia de:

1. Código integrado.
2. Prueba automatizada pertinente.
3. Compilación aprobada.
4. Recorrido funcional real o bloqueo externo documentado.
5. Seguridad y privacidad revisadas.
6. Paridad suficiente con el Functional Mockup.
7. Registro en `docs/progress.md`.

## Credenciales y recuperación

Nunca se enviarán secretos por chat ni se guardarán en Git.

- **Android:** Play App Signing está activo para `com.mycompany.dopmi`; Google conserva la app signing key. El keystore recuperado de FlutterFlow correspondía a un upload certificate anterior. Se creó un keystore nuevo, Google aceptó la solicitud de reset el 20 de septiembre de 2026 y anunció su activación para el 22 de septiembre de 2026 a las 22:39 UTC. La app signing key administrada por Google no debe descargarse ni sustituirse.
- **Google Play API:** se puede crear una nueva cuenta de servicio y revocar la anterior.
- **Apple:** se puede crear una nueva App Store Connect API key. Certificados y perfiles de distribución pueden regenerarse.
- **Stripe:** se crean o rotan claves restringidas y secretos de webhook.
- **Supabase:** las claves publicables pueden obtenerse de nuevo; las claves secretas se rotan si existe duda de exposición.
- **Codemagic:** la configuración reproducible vive en `codemagic.yaml`; los secretos y archivos de firma se cargan cifrados en el servicio.
- **GoDaddy:** si se conserva acceso a la cuenta, solo harán falta cambios DNS guiados.

## Próximos datos externos requeridos

Pendientes externos de la planificación inicial; verificar cuáles siguen abiertos. El YAML ya usa las referencias siguientes, pero su presencia no demuestra acceso vigente ni una publicación exitosa:

- cargar el nuevo upload keystore en Codemagic con referencia exacta `dopmi_upload_2026`;
- crear o recuperar una cuenta de servicio de Google Play para Codemagic;
- añadir las variables públicas de Supabase al grupo `dopmi_supabase`;
- verificar la integración/firma existentes y la publicación efectiva del nuevo build TestFlight con `com.mycompany.dopmi`.
