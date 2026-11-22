# Expediente y acciones de moderación por reporte

Fecha:22/nov/2026 CDMX. Alcance solicitado por el titular en este chat y acceso
limitado a la conversación autorizado expresamente en la respuesta de hoy.
Base de análisis3e52c871/a24408be, mockf693 conservado. Rama de trabajo
codex/admin-report-context-20261122. Esto no autoriza sancionar usuarios reales
como prueba ni abrir una bandeja general de conversaciones.

## Problema comprobado

Producción muestra un reporte abierto de adopción con motivo, UUID, texto y
Resolver/Descartar. No muestra contexto ni acciones reales. La tabla conserva al
reportante, pero dopmi_admin_reports lo omite. Resolver sólo cambia estado y nota.
Retirar una adopción existe en Adopciones; suspender/reactivar cuenta no tiene RPC
administrativa. Los mensajes/fotos de chat sólo son accesibles a participantes.

Se comprobó VercelPROD dpl_8MLN3k2TThpEZA6DtH8eGLJh7kiz/ee3ef773 READY; apps/admin
es idéntico entre esa fuente y3e52c871. Las migraciones de push tienen procedencia
remota adicional: conciliar historia y funciones reales antes de aplicar SQL, sin
replay/repair. Lecturas de hashes remotos no equivalen a una ejecución de moderación.

## Resultado para quien modera

La cola conserva motivo, fecha y estado y ofrece Abrir expediente. Dentro se ven:

1. Reporte: texto enviado, fecha y estado; la resolución queda separada de acciones.
2. Publicación: nombre, fotos, descripción, ubicación pública aproximada, estado y
   versión. Distinguir contenido vigente de una instantánea al reportar, que los
   reportes históricos no guardan. No exponer domicilios, documentos ni borradores.
3. Personas: reportante y responsable derivados por servidor; nombre, estado de
   cuenta, antigüedad y resumen de publicaciones/reportes/decisiones. No mostrar
   conversaciones o identidades de otros reportantes en ese resumen.
4. Conversación vinculada: texto y remitente de ese hilo y esa publicación entre
   reportante y responsable, paginado y limitado a la fecha del reporte. Sólo los reportes de adopción pueden derivar ese hilo. Si no hay
   vínculo inequívoco, mostrar Sin conversación vinculada con la razón. No buscar
   conversaciones arbitrarias entre las personas ni incluir mensajes posteriores.
   Adjuntos se indican como tales; este alcance no abre archivos privados del chat.
5. Historial: acciones y resoluciones, quién las realizó, fecha, motivo y resultado.

Diseño: reutilizar el panel y los diálogos existentes, navegación por teclado y
ancho móvil del APK. Los botones permanecen alcanzables con aumento. Carga, error,
recarga y expediente eliminado tienen estados explícitos; no presentar datos de
un reporte anterior durante otra carga. No nuevo APK: Administración carga el panel
web existente; su actualización y una prueba instalada se comprueban por separado.

## Acciones y controles

Retirar publicación, suspender cuenta, reactivar cuenta y resolver/descartar son
operaciones separadas. Cada mutación exige motivo, confirmación que nombra el
objeto afectado, versión/estado esperado, actor administrativo vigente y recibo
idempotente. Un clic fallido no se reintenta como una nueva sanción; se concilia.
No se marca resuelto automáticamente después de retirar o suspender.

La retirada de adopción conserva historial y guarda la publicación fuera del
catálogo; no prometer deshacer un archivo como si fuera una suspensión temporal.
El retiro individual de casos de apoyo queda deshabilitado con una explicación
sobre sus controles financieros; el de perfil indica que corresponde suspender
la cuenta, sin revocar el sello. Suspender cuenta permanece disponible para los
tres tipos. Ningún cambio modifica pagos, asignaciones, reembolsos o Stripe.

La suspensión se aplica al responsable del objeto, nunca a un UUID arbitrario;
no puede afectar al actor, una cuenta administrativa ni una cuenta eliminada.
La reactivación sólo revierte una suspensión creada por este mecanismo y aún
vigente, sin restablecer contenido retirado ni anular otra sanción posterior.
Preservar acceso a cancelación/privacidad que ya tengan cuentas suspendidas.
No crear ni revocar membresías administrativas ni modificar credenciales.

## Frontera de datos

RPC nuevas específicas por report_id: detalle, conversación y acción. El servidor
deriva destino, responsable e hilo, valida membresía real/estado del administrador,
registra lecturas de chat y decisiones y limita páginas. No ampliar RLS de mensajes
ni fotos, no exponer claves de servicio ni usar metadata editable para permisos.
No enviar datos del expediente a Analytics, servicios externos ni logs del cliente.

El historial mínimo conserva referencia de reporte/objeto/actor/acción/estado y
motivo; no copia cuerpos de conversaciones. Debe tolerar eliminación del reportante
sin depender de un FK con borrado en cascada. El historial no concede navegación
hacia reportes o conversaciones sin el expediente y sus guardas.

## Verificación y salida

Datos sintéticos para pruebas de UI/servidor: participantes incorrectos, hilo de
otra publicación, mensajes posteriores al corte, adjuntos, paginación, cuenta
eliminada, no administrador, administrador suspendido, concurrencia y repetición.
Cubrir lectura sin mutación de negocio, rechazo de auto-suspensión/admin, restauración
segura y retiro antes/después de suspensión. Probar reportes sin contexto histórico.

Una única integración del panel. Revisión independiente UI/UX/código/seguridad;
npm test y npm run build en apps/admin, verificación backend y CI exacta. Preparar
migración aditiva con historia remota/fingerprints/ACL/preflight/reserva/readback.
Aplicación SQL, publicación Vercel y comprobación del panel real son estados
separados. No cambiar Flutter, Play, TestFlight, push, medición, finanzas ni servicios.
No resolver el reporte real ni bloquear sus cuentas para validar la implementación.

## Decisiones técnicas del integrador

La interfaz concreta y el contrato tipado se fijan en el plan. Adjuntos de chat no
se descargan en este lote. Los vínculos ausentes/ambiguos se explican. Ninguna
suspensión se dispara por el solo hecho de recibir un reporte. La revisión del
contenido y la decisión sobre el reporte real siguen correspondiendo al titular.
