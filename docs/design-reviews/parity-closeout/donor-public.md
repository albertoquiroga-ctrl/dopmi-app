# Cierre por lote: donante y contenido público

2026-10-04. Referencia ejecutada: `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`, Edge 377 × 852, runtime local 5176. Cliente inicial `53716dc`; colección Flutter 758 y manifiesto de 419 capturas. Esta revisión reúne siete familias y **99 estados únicos**, no 99 defectos ni aceptación física.

Las 99 imágenes se inspeccionaron sin escalarlas, en hojas de seis imágenes; incluyen texto al 200 %, desplazamiento, errores, carga, teclado sintético y foco. Los 28 px de área superior de Flutter corresponden al área segura del dispositivo y se excluyen del desplazamiento observado frente al HTML. Datos, fotos y cifras reales pueden diferir del ejemplo. Las respuestas de ayuda y texto de Impacto conservan las reglas reales y no las promesas o fondos simulados.

## Inventario cerrado antes de modificar producción

| ID | Diferencia perceptible | Estados afectados | Corrección del lote |
| --- | --- | --- | --- |
| DP01 | «Guardar cambios» de Información básica queda alineado a la izquierda al ocupar dos líneas; la referencia centra las etiquetas. | `basic-info-keyboard-large` | Centrar el texto del botón existente, conservando margen y envío real. |
| DP02 | «Contactar a soporte», «Enviar mensaje» y «Adjuntar/Cambiar imagen» quedan alineados a la izquierda al ocupar varias líneas. | `help-center-footer-large`, `help-center-support-large`, `help-center-support-keyboard-large`, `help-center-support-rescuer-large`, `help-center-support-photo-large` | Centrar las etiquetas existentes, conservando upload, reintento, borrador y guardas. |
| DP03 | «Ver caso» queda alineado a la izquierda cuando se parte en dos líneas. | `public-profile-cases-large` | Centrar la etiqueta en el control actual. |
| DP04 | La columna estrecha de un gasto rompe «veterinario» o «Desparasitante» dentro de la palabra al 200 %. | `case-detail-expenses-large`, nuevo `case-detail-expenses-footer-large` | Icono y chevron arriba del texto y aportación debajo sólo con texto ampliado; conservar escala, expansión inmediata y hitbox de 48 px. |
| DP05 | El icono del acceso «Publica un caso de adopción» tiene fondo amarillo y glifo negro; Source usa fondo `#15110d` y glifo blanco, con sombra oscura. La regla es normal, no hover. | `profile-overview`, `profile-overview-active`, `profile-support`, `profile-overview-large` | Aplicar la variante oscura exclusivamente a `DonorFeature.light`. |

El candidato de icono de Impacto fue descartado: `empty-impact-paw.svg` contiene realmente un corazón y tiene el mismo SHA256 en Source y Flutter (`da16d04a13f915fc820b1914afc9a5efb255b6818e3e49554d47632f345e595d`). No se cambia. No se persiguen diferencias imperceptibles de rasterización/subpíxel.

## Matriz de siete familias

| Familia | Estados revisados | Contraparte y recorrido Source observado | Resultado de la pasada |
| --- | ---: | --- | --- |
| PROFILE | 5 | `/profile`, Guardián inactivo/activo, footer desplazado y diálogo para modo Rescatista | DP05; resto de composición, tarjetas, diálogo y accesos concordantes. |
| SETTINGS | 11 | `/settings` y `/settings/basic-info`; campos, fotografía, botón y footer | DP01. Las opciones adicionales corresponden a funciones reales de privacidad e historial; errores y confirmación permanecen legibles al 200 %. |
| SUPPORT | 38 | `/donate` vacío/lleno; `/help`, temas, contacto, formulario y recibo simulado local | DP02. Rail, hero, dock, FAQ y estados de recuperación conservan composición y acciones. El recibo real no promete respuesta el mismo día. |
| CASE | 14 | `/case/rocky`, top, gastos expandidos, galería y footer mediante `.pet-detail-scroll` | DP04. Sólo evidencia pública aprobada se muestra; estados sin evidencia y costos estimados son extensiones reales, no fotos privadas. |
| PUBLIC | 18 | `/rescuer-profile/Mar%C3%ADa%20R.`, Actividad, En adopción y Casos | DP03. Métricas reales, carga, error y no disponible se revisaron también al 200 %. |
| IMPACT | 6 | `/impact` con Guardián activo, vacío y con historias; promoción adicional corresponde al cliente real | Sin diferencia perceptible pendiente en esta pasada. Icono idéntico; atribución, asignaciones y fechas se conservan reales. |
| REPORT | 7 | Reportar desde perfil público, diálogo y formulario | Sin diferencia perceptible pendiente en esta pasada. Error, espera y teclado sintético revisados; no se considera el punto del spinner inicial un defecto de movimiento. |

PUBLIC excluye los siete estados REPORT de su cuenta, y excluye el editor privado de perfil (frente rescatista). No hay hover en el inventario de aceptación.

## Evidencia y verificación del lote

Imágenes de inspección: `C:/Users/betoq/AppData/Local/Temp/dopmi-public-closeout/`. Hay 19 hojas Flutter por familia y capturas Source `source-profile*`, `source-settings`, `source-basic-info`, `source-support*`, `source-case*`, `source-public*`, `source-help*`, `source-impact*`, `source-report`. Las primeras capturas de footer sin selector no se usan como prueba de desplazamiento: las válidas terminan en `-scrolled` o `-gallery-story` y ejecutan el contenedor observado.

Source confirmó por estilo computado `text-align:center` y `padding:11px 18px` en los botones de soporte, y `text-align:center`/`padding:7px 12px` en «Ver caso». La variante oscura de Publicar está en `.profile-feature--mode .profile-feature-cta` y su máscara. Toda la pasada y el inventario inicial precedieron las modificaciones de producción. Browser de esta revisión cerrado.

DP01–DP05 se implementaron en un batch de seis archivos. El integrador reportó gate de 386/386 aprobado y una captura completa exit 0. Revisión posterior directa de PNG frescos del 2026-10-04, 13:06–13:07, en `C:/Users/betoq/AppData/Local/Temp/.tools/design-review/`:

| ID | Resultado posterior | Evidencia |
| --- | --- | --- |
| DP01 | Cerrado. «Guardar cambios» ocupa dos líneas centradas y con margen visible. | `basic-info-keyboard-large`; normales `basic-info` y `basic-info-saved` idénticos por SHA256 a 758. |
| DP02 | Cerrado. Contactar, adjuntar/cambiar imagen y enviar mensaje centran todas sus líneas sin corte ni solapamiento. | Los cinco estados ampliados registrados; normales footer, soporte, teclado, rescatista y foto idénticos por SHA256 a 758. |
| DP03 | Cerrado. «Ver caso» centra ambas líneas; acciones y footer siguen separados. | `public-profile-cases-large`; normal `public-profile-cases` idéntico por SHA256 a 758. |
| DP04 | Cerrado tras recaptura dirigida. «Desparasitante» ocupa una sola línea completa; cifras, evidencia y aportación conservan márgenes y acciones separadas. | Tres PNG de gastos frescos de 13:18:29–13:18:30, conservados en `C:/Users/betoq/AppData/Local/Temp/dopmi-public-closeout/postbatch-1318/`. El normal mantiene SHA256 idéntico a 758. El defecto previo de 13:07:08 queda conservado en `postbatch-1307/`. |
| DP05 | Cerrado. Publicar usa negro/blanco, confirmado directamente en el footer; Guardián inactivo y activo conservan su icono amarillo. | `profile-support`, `profile-overview`, `profile-overview-active`; la parte superior al 200 % de `profile-overview-large` es idéntica por SHA256 a 758. El tile Publicar queda fuera de esa captura superior. |

DP04: el texto tenía 206 px disponibles a viewport 320; «Desparasitante» en el Inter real 700 a 30 px necesita 223.17 px sin hinting (224 px con PIL). Reducir padding exterior de 20 a 12 sólo entrega 222 px. El ajuste final refluye la aportación a una fila inferior de 48 px únicamente en modo ampliado y deja 254 px al texto; la estructura normal conserva la fila, sus controles y padding. El estado nuevo de footer pertenece al cierre dirigido y no se suma retroactivamente a los 99 estados del inventario inicial.

`public_expense_reflow_test.dart` agrega cuatro recorridos a 100 % y 200 %, con Inter real: selección de palabras completas, hitbox sin solapar el título, abrir/cerrar evidencia, monto faltante y navegación al gasto/caso/centavos exactos. El integrador ejecutó el gate dirigido final: **67/67 pruebas aprobadas en 22 s**, incluyendo esos cuatro recorridos; log `closeout-final-directed.log`. Este agente inspeccionó directamente las tres recapturas de gastos posteriores y verificó sus hashes. Este agente no inició Flutter ni hizo commits. Se reutilizan los 55 checks de movimiento existentes; las nuevas comprobaciones verifican lectura e interacción, no constantes de estilo.

Los cinco IDs perceptibles registrados para estas siete familias quedan cerrados. Hashes de gastos finales: normal `3cac94f09b8a94daa9f39158358c58171be63de1146b97d9c0e4f57fb4d8ee35` (igual a 758), ampliado `4c2770efe842799e0a9948e30d2c40df8cfffd0db2edef5775857255b5b74cd9`, footer ampliado `4432317b017d2b42b2d198bcbd4fb0ca9615bf7a7614be862fa3cf1488d09cf0`.

La revisión visual del lote no reemplaza los recorridos en el candidato Android final con teclado/gestos nativos ni los servicios de pagos test. Esas verificaciones y Codemagic pertenecen al cierre integrado.
