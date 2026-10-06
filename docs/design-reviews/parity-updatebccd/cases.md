# Mis casos — actualización bccd040

Referencia fija: `irlanda/apoyar-detalle-perfil@bccd040d3a4b1c391bc6ab9eeccc479198868a7f`.
Delta desde `889c096ade9479b348530db7ba169f023b472ab9`; app base `ed4b788`, Play295.
Este frente cubre ocho grupos. No reabre publicación, las familias889 ni los
contratos financieros aceptados. La edición de apoyo aprobado sigue bloqueada
por decisión expresa del usuario.

## Lista reunida antes de editar

| Grupo | Diferencia Source nueva | Prueba y evidencia necesaria |
|---|---|---|
| C1 | Lista unificada Adopción/Apoyo, grupos y enlaces de Inicio | Query inicial por programa/estado, cambio de ruta y alcance; PNG01/02/08 |
| C2 | Cuatro filtros y archivo, vacíos y paginación | Filtro antes de página, último desmarcado repone todos, total global distinto del filtrado; PNG05/11/12/14 |
| C3 | Tarjetas de adopción por estado, conversaciones y vistas | Métricas reales, acciones por estado, toque frente a scroll; PNG01/02/05/13 |
| C4 | Tarjetas de apoyo, barra y desglose expandible | Conteos y montos reales; catálogo público completo, orden estable, sin CTA ni evidencia privada; PNG08/09/11 |
| C5 | Cerrar adopción con motivo y apoyo Dopmi | RPC real, versión, texto libre y sí/no; error conserva campos, no éxito anticipado; PNG03/04 |
| C6 | Cerrar apoyo y archivar completado | Confirmar faltante; cierre real; aviso posterior a RPC, temporizador sólo descarta aviso; PNG10/15 |
| C7 | Descartar borrador/corrección | Archivo real con copia honesta, no borrado de historial; PNG07 |
| C8 | Retomar/corregir y reactivar adopción | Mismo ID, fotos/rasgos/texto privados íntegros; borrador requiere revisión; PNG06 |

## Evidencia Source de una sola pasada

Quince PNG auxiliares en
`C:/Users/betoq/AppData/Local/Temp/dopmi-plan-bccd040/capture-cases`.
Viewport377×852 y320×640 con tipografía200%; Inter/Fraunces cargadas,
cero imágenes rotas y cero errores del navegador. `manifest.json` conserva la
geometría/computed CSS de los catorce estados iniciales. La imagen14 fue
corregida al final para usar una sola ampliación de fuente: la geometría de ese
estado en el manifest inicial no corresponde a su PNG corregido.

El primer servidor compartido arrancó con cwd del app y sirvió889. Se descartó
antes de esta pasada; runtime4192 corregido con raíz Temp explícita y DOMbccd
verificado. Fixture Source sintético; sus conteos no acreditan las operaciones
de la app. Las capturas no contienen datos reales de usuarios.

## Implementación

`owned_cases_screen.dart` consume `ownedCases(page, program, statuses, archived)`
y el total global del servidor; filtros, programa y página quedan aislados por
cuenta. Cambiar alcance o deep link restablece la primera página y el scroll;
volver de un editor actualiza la lista sin perder sus filtros. Se conserva el
widget anterior `OwnedCasesHeading` para sus otros consumidores.

Los cierres envían ID y versión. Adopción registra `adopted/other`, apoyo Dopmi
y descripción real; apoyo usa su transición existente. Archivo completado usa
`archiveSupport` antes de mostrar el aviso; el temporizador nunca escribe.
Descartar conserva historial y llama a archivo real. Reactivación de adopción
envía todo el registro privado y vuelve a borrador, sin publicación automática.

El desglose reutiliza `PublicExpenseCard(canContribute:false,
showContributeAction:false)`, llama `completeCaseCatalog` y usa `orderedNeeds`: sólo instantáneas
públicas aprobadas y cifras existentes, con orden estable Veterinario, Medicina,
Comida, Otra. No muestra recibos privados ni controles de aportación. Los días
usan fecha real de publicación/aprobación; vistas y conversaciones son totales
reales. No se copian las cifras simuladas ni un supuesto crédito financiero.

Excepciones conscientes del prototipo: la copia de descartar describe archivo,
la confirmación de cierre no renuncia a derechos sobre dinero registrado, y
apoyo aprobado conserva el bloqueo de edición. El texto200% refluye y permite
scroll de los diálogos en lugar de reproducir recortes del mock.

## Comprobación pendiente de cola central

Trece pruebas propias preparadas en `owned_cases_screen_test.dart`: alcance, filtros,
página21, total global, cierre simple, fallo/reintento, metadatos, bloqueo de
edición de apoyo, confirmación del faltante, aviso posterior a RPC, reactivación
íntegra, archivo honesto, catálogo público completo y accesibilidad normal/200%.
`owned_case_card_gesture_test.dart` entra ahora explícitamente por `program=support`
para conservar sus seis recorridos privados existentes. Este agente sólo
formateó Dart; no ejecutó Flutter, comandos de dispositivo ni cambios remotos.

La primera dirigida central pasó las trece pruebas propias, los gestos y el
detalle antes del ajuste agrupado final de presentación y la reutilización.
La cola central repetirá lo afectado en el candidato actual. El fixture auxiliar
`tool/bccd_cases_fixtures.dart` reutiliza los dobles propios y reproduce los
catorce registros Source, sus fotos, días, conteos y centavos sintéticos. Incluye
los dos programas y sus archivos; no se importa en producción.

Cierre visual y funcional aún pendiente de pruebas/capturas Flutter y
comprobaciones PostgreSQL/nativas de la cola central. No se declara aceptación
por la sola captura Source.

## Primera comparación conjunta y corrección agrupada

El 5 de octubre se compararon los quince PNG Source con los dieciséis estados
Flutter `bccd-cases-*` de la pasada central70672, fechados22:43, en
`C:/Users/betoq/AppData/Local/Temp/.tools/design-review`. La pasada incluyó
tarjetas, archivo, filtros, cierre/otros motivos, reactivación, descarte,
desglose y texto200%. Se reunieron seis grupos perceptibles antes de editar:

| Grupo | Diferencia comprobada | Corrección en archivos propios |
|---|---|---|
| V1 | Selector gris sin contorno; filtro y archivo con color/fondo distinto | Selector blanco con borde violeta fino, filtro gris y archivo transparente; icono blanco al seleccionar |
| V2 | Subtítulos grises, importe sin énfasis, cierre pendiente negro, chat Material y pista blanca | Tipografía/color/énfasis Source, cierre rojo, SVG de mensajes y pista gris crema; sombra de tarjetas activas |
| V3 | Títulos/párrafos de diálogos alineados a la izquierda y fondo demasiado oscuro | Texto centrado y capa45%; conservar scroll con fuente ampliada |
| V4 | Labels flotantes y borde enfocado amarillo; Sí/No negro | Labels externos, borde violeta y selección lila de Sí/No; texto real conservado |
| V5 | Filtros pequeños y demasiado separados; peligro rosa saturado | Tamaño/espaciado de filtros y acción roja con fondo rosa pálido/borde; blancos accesibles |
| V6 | Adopción se parte dentro de la palabra al200% | Selector refluye a dos filas completas sin reducir la fuente; excepción accesible al recorte Source |

La misma corrección resuelve un defecto funcional demostrado: se retiró
`IgnorePointer` de las fotos de tarjeta. El botón real de recuperación debe
interceptar su toque sin abrir el caso. Los seis recorridos de toque frente a
scroll ahora precargan píxeles reales mediante `PhotoRuntime`; una séptima
prueba fuerza fallo de transporte en apoyo aprobado y comprueba que tocar
Reintentar inicia una descarga, muestra carga pendiente y conserva ruta/lista
sin lecturas de detalle ni escrituras. Al fallar de nuevo, el botón vuelve a
estar operable. La recuperación con píxeles se comprueba en la suite existente
PhotoRuntime; esta prueba de gesto evita esperar codecs/Futures de FakeAsync
dentro de runAsync. No se ocultó ni simuló el botón de retry.

Tres diferencias pertenecían al fixture de la captura central: Bruno/Flecha
sin píxeles precargados, badge de notificación sintético0 frente a2 Source y
aviso completado capturado tras vencer su temporizador. La cola central ajusta
esos datos/instantes. Las listas activas tampoco tenían el mismo offset:
Source02 desplazado325 y Source08/09 desplazados369; no se añade espacio de
producto para copiar un encuadre. El aviso real conserva el archivo confirmado
por RPC detrás de él, aunque el mock retrasa su cambio hasta descartarlo.

La segunda pasada selectiva revisó los estados centrales de23:10. Los seis
grupos están corregidos. Encontró tres residuos dentro de V3/V4: el estilo
explícito del Dropdown no heredaba Inter y producía Ahem en pruebas/fallback de
plataforma en Android, el borde visible del textarea era más corto que Source y
la X coincidía con títulos de pregunta largos. Se estableció Inter en el
control, un área de cuatro líneas y el título Source22px con la X situada en
la esquina superior (objetivo48px conservado). No se amplió el alcance.

La dirigida central pasó13 pruebas propias y16 de gestos, encabezado,
desglose/lectura y reflow; esta última incluye los siete gestos actuales. La
captura del aviso completado requiere aún corregir el instante del harness:
su PNG23:10 muestra archivo y no el aviso, aunque su prueba de RPC/temporizador
pasó. La evidencia no sustituye esa captura por una simulación. Los dos campos
y el encabezado modal residuales quedan para la verificación final dirigida
central; no se reabre una tercera comparación general ni otras familias.

## Cierre en desarrollo6/10

Segunda comparación selectiva y verificación del residuo V4: Inter visible en
ambos motivos, área de cuatro líneas y títulos sin choque con la X. Captura
central35471 aprobada; el aviso real «Caso finalizado» se capturó después del
RPC, conservando el archivo confirmado detrás. El harness necesitaba un pump
inicial para procesar la respuesta antes de avanzar300ms, sin cambiar producto,
temporizador ni simular confirmación. Fotos archivadas decodificadas verificadas.
Los otros estados de la pasada1010 siguen vigentes. Ocho grupos cerrados en
desarrollo; pendientes auditoría del delta, gate/nativo/instalado y cleanup.
