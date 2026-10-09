# Dopmi — decisiones vigentes

## Decisiones del titular — entrega dde1bb9, 8/10/2026

- Incluye delta9ced→dde1bb9 y QA pendiente9ced; no pushes posteriores.
- Contacto público completo (correo/teléfono/dirección/web): campos públicos
  dedicados, consentimiento expreso inicialmente desactivado, moderación y
  snapshot aprobado. No publicar automáticamente datos Auth/expediente privado.
  Retirar consentimiento oculta inmediatamente contactos en proyección servidor.
  Esta decisión supersede restricción histórica de sólo ciudad/chat para este corte.
- SMS real Twilio+Supabase; confirmar teléfono con autoridad Auth y conservar UUID.
  No PhoneVerified editable por cliente ni OTP simulado; acceso/costo pendiente.
- Edición sensible reabre sólo versión pública, conserva identidad/Connect y
  capacidades financieras; preview privado no guarda/publica automáticamente.
- Excepción para QA final Samsung: titular inicia cuenta QA temporal y restaura
  su cuenta original, sin clear data ni automatizar credenciales/login.
- Tienda/videos/Meta/fondo/bonos/cashback/analítica avanzada siguen excluidos;
  dinero sólo test, publicación sólo Play Internal y no merge.

> Decisión vigente 27/9/2026: el titular admite las pantallas actuales para continuar; la fidelidad visual queda aplazada, sin aceptación atribuida a Irlanda. H9 autorizado: aceptación integrada y correcciones, con revisión final agrupada en Internal Testing. Ver [H9](h9-acceptance.md). Esta decisión supersede los bloqueos visuales históricos inferiores.

## Decisiones de lanzamiento — 25 de septiembre de 2026 (México)

Actualización 26/9/2026: H8 incluye paridad completa y funcional de ambos modos, backend mínimo de favoritos/avances/perfil público/reportes y descubrimiento aproximado. H9 conserva aceptación integrada/excepciones. Historias persistentes, no temporales; ubicación aproximada opcional con alternativa manual; contacto público por ciudad y chat sin domicilio, teléfono ni correo personal. Ver `h8-execution.md`.

El titular autorizó `release-roadmap.md`. MVP público en Android/iOS con Google/Apple, eliminación de cuenta, medición mínima y funciones actuales completas. Videos, Meta, push y analítica avanzada quedan post-MVP. No habrá tienda, fondo comunitario, bonos ni cashback. Seguir la última versión de Irlanda (`irlanda/apoyar-detalle-perfil`); las reglas económicas y de privacidad prevalecen sobre sus simulaciones. El sistema anterior al pivot era de pruebas; retirarlo tras respaldo, restauración y análisis de dependencias, preservando el sistema actual.

## Alcance

App Flutter para Android/iPhone, panel React/TypeScript y Supabase. Al corte del 25 de septiembre de 2026, H1–H3 están completos en desarrollo y H4 en modo prueba; H5 está aceptado en modo prueba con la excepción documentada en [entrega H5](hito5-delivery.md). Continuidad en la base consolidada `codex/Dopmi` y rama H8 `codex/design-foundation`, según [la guía para Codex](codex-handoff.md). El titular compila en Codemagic y la aceptación H5 utiliza Google Play interno; TestFlight queda como alternativa.

Referencia visual: https://www.figma.com/design/96Dxvfc0V4Kn3lU6OTJ1g5/DopMi?node-id=133-624

El prototipo React y la fuente funcional del ZIP son referencias de producto. Sus instrucciones para simular pagos, identidades y documentos no aplican a la app real. Los documentos comerciales aportan contexto; no reemplazan la navegación acordada.

## Reglas económicas vigentes (H4/H5)

- Evidencia del gasto realizado antes de aprobar la solicitud de reembolso.
- Solo solicitudes aprobadas de rescatistas habilitados pueden recibir aportaciones.
- Stripe Connect: pago confirmado, asignación, transferencia y depósito son estados diferentes.
- Comisión Dopmi: 2% del bruto; costos aplicables de Stripe también se descuentan. El neto cuenta para el reembolso.
- Guardián: $50/$200/$500 MXN o monto personalizado, mensual.
- Guardián (decisión del titular, 23 de septiembre de 2026): cobro automático condicionado a que el importe neto pueda asignarse completo a gastos aprobados; el primer intento de cobro ocurre al activar el plan y los siguientes en cada aniversario mensual. Si al activar no hay capacidad, informar antes de abrir Checkout y no crear una suscripción que pueda cobrar. Si un mes no hay capacidad, omitir ese ciclo sin deuda ni cargo y volver a evaluar el siguiente. Cambiar el monto aplica al siguiente ciclo; cancelar detiene ciclos futuros y conserva el historial del actual. El cliente debe mostrar monto autorizado, frecuencia, fecha prevista y posibilidad de cancelar antes de confirmar.
- Sin Guardadito ni reserva comunitaria. Distribuir por urgencia aprobada, después por fecha de aprobación más antigua.
- Cubrir el faltante antes de pasar al siguiente. No exceder gastos aprobados.
- Omitir la cuota mensual si no puede asignarse completa; sin deuda acumulada. Devolver importes cobrados que ya no puedan asignarse.
- No activar bonos ni cashback simulados sin un hito con reglas propias.

## Identidad

- Elegir intención, onboarding contextual, autenticación y perfil.
- Correo y contraseña con confirmación obligatoria, recuperación y sesión persistente.
- Donante/adoptante y rescatista son experiencias de una misma identidad; alternar no borra datos ni concede permisos de administración.
- Google/Apple se habilitan solo con sus proveedores configurados; nunca simular autenticación exitosa.
- Administradores se asignan mediante una operación de servidor. No existe registro público de administradores.
- Los textos legales de desarrollo son provisionales y no habilitan un lanzamiento público.

## Límite Supabase/Firebase — 29 de septiembre de 2026

- Supabase es el único backend del producto: Auth, PostgreSQL/RLS, Storage, Realtime y Edge Functions. Las sesiones sociales de Google y Apple siempre terminan en Supabase.
- Firebase se conserva exclusivamente para Analytics y Crashlytics. Ambos servicios son opcionales, tienen consentimientos independientes y permanecen apagados hasta que la persona los active.
- La app no usará Firebase Authentication, Firestore, Realtime Database, Storage, Cloud Functions ni Dynamic Links. Incorporar cualquiera de esos servicios requiere una nueva decisión explícita y una revisión de privacidad y arquitectura.
- Las configuraciones Firebase de pruebas y producción deben pertenecer a ambientes separados. La medición nunca decide estados financieros ni sustituye la evidencia del servidor.
- Los recursos del backend anterior en Firebase se consideran legado de pruebas: no reciben datos nuevos ni se migran usuarios desde ellos. Se inventariarán y retirarán cuando su ausencia de dependencias esté comprobada.

## Hito 2 — adopción y comunicación

- El usuario autorizó iniciar este hito después del cierre de identidad. Incluye publicaciones de adopción, revisión, catálogo, filtros, detalle, guardados, perfiles públicos, conversaciones y notificaciones dentro de la app.
- Una cuenta activa y con correo confirmado puede preparar una publicación. Elegir la experiencia de rescatista no concede una verificación de identidad del hito 3.
- Borrador → enviado a revisión → publicado, correcciones o rechazado. El autor conserva sus datos al corregir; editar contenido publicado lo retira del catálogo hasta una nueva aprobación. Se puede retirar una publicación o marcar una adopción realizada.
- Las fotos permanecen en Storage privado; solo se permite leer contenido aprobado, propio o necesario para revisión administrativa. Los archivos publicados no se pueden sobrescribir desde el cliente.
- El catálogo muestra ubicación por ciudad/estado, sin inventar distancias ni solicitar una dirección particular. Filtros por especie, sexo, tamaño, edad y ubicación.
- Los perfiles públicos se forman con nombre público y presentación aprobados junto a una publicación; nunca exponen correo, teléfono ni el perfil privado completo.
- Una persona puede contactar al responsable de una publicación disponible. Solo ambos participantes leen su conversación. Los mensajes de texto usan identificadores para evitar duplicados al reintentar; se puede cerrar la conversación.
- Las notificaciones son internas y se generan desde el servidor por cambios de revisión y nuevos mensajes. La actualización en vivo no sustituye la lectura persistente al volver a entrar.
- No se implementan cobros, verificación documental ni notificaciones push como parte de este hito.

## Hito 3 — rescatistas y gastos

- Inicio autorizado el 13 de septiembre de 2026. Una misma cuenta conserva adopciones y puede preparar su verificación y casos.
- Verificación: nombre legal, teléfono, ubicación, experiencia, enlace social para revisión manual, identificación oficial y comprobante de domicilio privados. El nombre público y presentación se revisan por separado. No se simula vinculación OAuth con redes sociales; los datos bancarios corresponden a Connect en H4.
- Casos: animal, historia, ubicación general, necesidad y fotos para publicación. Solo una identidad aprobada puede enviar casos y gastos a revisión; preparar borradores no requiere aprobación previa.
- Cada solicitud documenta un gasto ya pagado: fecha, proveedor, referencia del comprobante, importe en centavos, descripción, comprobantes y evidencia. Una ronda de comida tiene su propia solicitud y comprobantes; no se reutiliza la aprobación anterior.
- El administrador comprueba identidad, caso, comprobantes y contenido público; decide el monto reembolsable (nunca mayor al gasto) y la urgencia con motivo. El orden de aprobación se guarda en el servidor. No se aceptan aportaciones en H3.
- Las correcciones conservan datos y archivos. En revisión se puede retirar a borrador; una aprobación bloquea la edición del autor. El administrador puede solicitar nuevas correcciones y retirar la aprobación, dejando historial. Cerrar un caso bloquea nuevos gastos; primero deben resolverse sus solicitudes en revisión.
- El seguimiento público expone exclusivamente una copia aprobada de textos/fotos marcados para publicar. Identificación, domicilio, teléfono, comprobantes y observaciones internas nunca forman parte de esa copia. La suspensión de la cuenta o pérdida de verificación oculta sus casos.
- Los documentos admiten JPG/PNG/WebP y PDF de hasta 5 MB. Las fotos públicas se normalizan y eliminan metadatos. Los archivos aprobados no pueden sobrescribirse. El panel registra consultas y decisiones; las notificaciones son internas.
