# Mensajes — actualización bccd040

Referencia fija: `irlanda/apoyar-detalle-perfil@bccd040`, delta desde
`889c096ade9479b348530db7ba169f023b472ab9`. Base app `ed4b788`, Play295.
Este lote cubre los cuatro grupos asignados de Mensajes; no reabre chat,
favoritos ni las familias cerradas del lote889.

## Diferencias reunidas en una pasada

1. Selector horizontal Todos/mascota, tarjetas78, foto52, selección morada,
   badge global9+; sustituye grupos expandibles.
2. Lista plana con Mascota · Persona, foto, último mensaje, hora, unread real,
   panel22 y separadores interiores.
3. Filtro Sin leer/Mostrar todos combinado con mascota, aplicado en consulta
   paginada de servidor antes de total y página.
4. Vacíos contextuales y actualización tras regreso/lectura; selección retirada
   vuelve a Todos. Historial y Mis conversaciones conservados.

No existe nueva acción de archivar/restaurar en Source: archived sólo aparece
como fixture. Conservamos el historial real y cierre previos. No se copian
rutas por mascota que mezclan personas: cada chat usa su UUID real. El contador
de pendientes Sin responder de Inicio es independiente de estos badges de
mensajes Sin leer.

## Evidencia Source

Una pasada auxiliar en Temp aislado bccd: seis estados, 377×852 y320×640
con tipografía al200%, Inter/Fraunces cargadas, cero imágenes rotas y cero
error overlays/errores de navegador. Manifest privado auxiliar:
`C:/Users/betoq/AppData/Local/Temp/dopmi-plan-bccd040/capture-messages/manifest.json`.
Incluye Todos, mascota, mascota+Sin leer, Sin leer vacío, normal vacío y texto
ampliado. El mock recorta texto al200%; el app amplía tarjetas y envuelve filas
para conservar lectura y controles. No se guardan PNG con datos de usuario.

El primer arranque auxiliar usó cwd del app y sirvió Source anterior; se descartó
antes de la inspección. Runtime corregido4192 con raíz Temp explícita y DOM nuevo
verificado. El repositorio de referencia conserva HEAD y archivos originales.

## Implementación y comprobaciones

`rescuer_threads_screen.dart` usa consulta plana `rescuerThreads(page, groupId,
unreadOnly, history)`. Selector separado `rescuerInbox` carga páginas adicionales
sin aplanar sus20×20 conversaciones. Badges provienen de totales de servidor.
Recargas conservan selección y verifican páginas posteriores antes de invalidar
una mascota que cambió de posición. Respuestas obsoletas quedan descartadas.
Regreso del chat actualiza lista y badges; estado y scroll permanecen en el
navegador anterior. Historial tiene Back contextual a la selección activa.

Pruebas propias preparadas: filtros/badges y toque frente a scroll en normal/200;
lectura/error/reintento; paginación plana y selector >20; respuesta tardía;
selección retirada; historial/Back; UUID distintos para dos adoptantes y lectura;
regreso con scroll; Mis conversaciones sin envío. Sin ejecutar Flutter por este
agente: dirigidos, contraste Flutter y operaciones PostgreSQL/nativas corresponden
a la cola central. Cierre visual y funcional pendientes de esa evidencia.

## Verificación central6/10

Los trece dirigidos propios aprobaron en la ronda inicial salvo dos tests200% de visibilidad; ambos aprobaron al revelar cada control antes de tocarlo, sin modificar UI. Regreso, privacidad, paginación>20 y separación de conversaciones también aprobaron. Capturador existente/CAPTURE_FILTER=bccd-messages generó siete estados válidos (los seis Source y Samsung115%); contraste conjunto de composición, selector, lista, combinados y vacíos realizado por integrador. Sin defectos perceptibles conocidos en este lote. Excepciones funcionales: Historial y Mis conversaciones conservan acceso; hora real HH:mm; texto200% fluye legible en vez de recortarse como Source.

Auth/RPC DEV con dos adoptantes: UUID distintos y saludo único, filtro mascota+Sin leer, lectura elimina sólo el no leído y no cambia pendiente de respuesta; respuesta real/idempotente sí lo cambia. Reviewer/tercero sin acceso a mensajes ni inbox ajeno. Pruebas PostgreSQL cubrierontotales/filtrosantespaginación>20. Pendientes exclusivamente transversales: auditoría independiente, gate final y recorridos nativos/instalados. Capturas privadas `.tools/design-review/bccd-messages-*`.


## Entrega instalada6/10

Candidato Androidf3808f1 publicado una sola vez por Codemagic6ac512ac762af530b028e23f; Playinternal/completed296 comprobado aparte. Samsung2.3.3(296)/Android16/115% aprobado: Inicio/carruseles, casos/filtros/Archivo, inbox/selección/Sin leer/Historial/Back/refresh, teclado, FAB/cancelación, galería6 y swipe corto/largo. Sesión y modo Adoptante conservados; no se escribieron borradores ni mensajes personales. Cierres/reactivación se acreditan por21checks controlados del emulador. Gate móvil476/f380913tests y bloques equivalentes474/f362 aprobados. Cero defectos perceptibles conocidos. Sólo cleanup administrativo del único archivo QA cerrado pendiente; detalle vigente en tablero.


Cierre final6/10: entrega instalada y limpieza exacta aprobadas. Postflight DEV19conteos QA cero; singleton de activación conservado. No quedan puertas pendientes de este lote/corte; ver tablero vigente.
