# Dopmi — decisiones vigentes

## Alcance

App Flutter para Android/iPhone, panel React/TypeScript y Supabase. El primer hito cubre identidad, perfiles y consulta administrativa de usuarios. Los demás módulos se implementan por hitos.

Referencia visual: https://www.figma.com/design/96Dxvfc0V4Kn3lU6OTJ1g5/DopMi?node-id=133-624

El prototipo React y la fuente funcional del ZIP son referencias de producto. Sus instrucciones para simular pagos, identidades y documentos no aplican a la app real. Los documentos comerciales aportan contexto; no reemplazan la navegación acordada.

## Reglas económicas para los siguientes hitos

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
