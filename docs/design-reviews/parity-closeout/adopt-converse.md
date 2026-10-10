# Cierre por lote: Adoptar y conversar

2026-10-04. Base de la pasada: `53716dc`. Referencia local comprobada:
`irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.
Las diferencias de rasterización imperceptibles quedan admitidas por el titular;
esta pasada busca diferencias visibles, recortes, animaciones y gestos.

## Inventario revisado

Se inspeccionaron las **59 capturas** de las siete URLs de este lote, sin repetir
la generación. Son 56 imágenes de la colección758 y tres vacíos de Adoptar
actualizados por760. Se verificaron sus hashes frente al manifiesto758; sólo
esas tres sustituciones difieren. La agrupación por familia siguiente no duplica
fixtures. Las capturas son widgets con repositorios de prueba, no pruebas remotas.

| Familia | Fixtures revisadas | Evidencia y alcance |
| --- | ---: | --- |
| DISC | 9 | Mazo normal/200, arrastre, vacío normal/200/ancho200, final y tarjeta de apoyo normal/200. Source `/adoption` ejecutado a377×852; composición normal coincide a simple vista. Movimiento existente493/494/741 y reparación nativa654–658 se reutilizan. |
| FILTER | 2 | Diálogo normal/200; Género, Tamaño y Personalidad. Runtime495 del mismo SHA comprueba apertura inmediata, cierre/descartar y reapertura; pruebas actuales conservan aplicar/limpiar, permisos y resultados tardíos. |
| PET | 4 | Detalle y diálogo de contacto normal/200. Source `/adoption/rocky` ejecutado e inspeccionado, incluidas historia, reportar y barra inferior. Contacto743 del mismo SHA se reutiliza. AC-02 corrige CTA ampliada. |
| MATCH | 14 | Favoritos/chats, Ver más/ordenar, vacíos, búsqueda, foto y foco normal/200. Source `/messages` ejecutado e inspeccionado; datos/favoritos diferentes se clasifican como estados, no como diferencias de diseño. AC-01 corrige encabezado ampliado. |
| SAVED | 11 | Mascotas, vacío, rescatistas, contenido retirado y páginas1/2 al200. Source `/saved` y `/saved-rescuers` ejecutados e inspeccionados. Vacío/CTA759 se reutiliza. AC-03 corrige palabras partidas; AC-05 añade el icono Source del encabezado. |
| CHAT | 19 | Conversación normal/donante/rescatista/200, foco, teclado sintético, inbox rescatista lleno/vacío normal/200 y ocho notificaciones. Source `/notifications` y `/rescuer/messages` ejecutados e inspeccionados; AC-04 corrige nombre ampliado. |

Las59 imágenes están enumeradas en el inventario758 mediante rutas
`/adoptions`, `/adoptions/post`, `/messages`, `/messages/thread-one`, `/saved`,
`/saved?kind=rescuer` y `/notifications`. La separación anterior asigna dos
filtros aFILTER, dos confirmaciones aPET y cuatro inboxrescatista aCHAT.

La inspección completa se hizo antes de corregir. Las composiciones temporales
`C:/Users/betoq/AppData/Local/Temp/dopmi-parity-closeout-adopt/sheet0.png` a
`sheet9.png` conservan los píxeles originales y etiquetas exteriores.
Las siete vistas Source se guardaron en esa carpeta como `source-adopt.png`,
`source-pet.png`, `source-messages.png`, `source-saved.png`,
`source-saved-rescuers.png`, `source-notifications.png` y
`source-rescuer-messages.png`; se inspeccionaron completas. El distintivo
Modo prueba es una herramienta de Source, no un elemento del producto.

## Diferencias finitas

| ID | Defecto observado | Corrección | Estado verificable |
| --- | --- | --- | --- |
| AC-01 | Al200%, Mis favoritos y Ver más se enciman; la acción queda recortada por80×44. | Con texto16 escalado>25, título y acción pasan a filas separadas; la acción crece según texto. La rama normal conserva su geometría. | Cerrado en gate integrado y `match-home-large` actual: título y Ver más separados, completos. Normal idéntico por SHA a758. |
| AC-02 | Quiero adoptar se divide en dos líneas alineadas a la izquierda y sin margen vertical. | Alineación centrada; padding12 sólo con texto16 escalado>25. La barra sigue fija y operativa. | Cerrado en gate integrado y `adoption-detail-large` actual: CTA centrada con margen vertical. Normal idéntico por SHA a758. |
| AC-03 | Filas guardadas estrechas parten Guardado y Contenido/disponible al200%. | En ancho<360 y texto16 escalado>25, foto/quitar ocupan una fila y el contenido recibe el ancho completo debajo. Datos retirados siguen ocultos. | Cerrado en gate integrado y guardados/páginas actuales: Guardado19/20/21 y Contenido no disponible completos. `saved-adoptions` normal idéntico por SHA a758. |
| AC-04 | Inbox rescatista parte Hernandez entre el avatar y la insignia al200%. | Con la misma condición de ancho/escala, avatar/insignia van arriba y nombre/fecha/vista previa reciben el ancho completo. | Cerrado en gate integrado y `rescuer-messages-large` actual: Hernandez completo e insignia3 visible. Normal idéntico por SHA a758. |
| AC-05 | Encabezado Rescatistas guardados omite el bookmark que Source declara enTopBar. | Añade el SVG20 con separación8 en normal; al200 se coloca encima para conservar palabras. Otros tipos de guardados conservan encabezado. | Cerrado en gate integrado y `saved-rescuers` normal/200 actuales: bookmark visible, título completo y sin superposición. Cambio normal intencional. |

No se detectaron otras diferencias perceptibles en esta pasada. Esa observación
se limita a las vistas y estados inspeccionados; no afirma aceptación instalada.
Contenido fuera del viewport por desplazamiento deliberado no se clasificó como
recorte. Menús adicionales de categorías, paginación, contenido retirado,
reintentos, cierre de conversación y datos verdaderos siguen siendo funciones
reales necesarias; no se copian identidades, distancias o resultados simulados.

## Verificación centralizada

- **AC-V1 — cerrado, gate dirigido:** `adopt_converse_reflow_test.dart`, `community_test.dart`,
  `adoption_detail_layout_test.dart`, `rescuer_threads_test.dart` y
  `match_thread_row_test.dart`. Cuatro pruebas nuevas usan Inter/Fraunces reales:
  separación de encabezado, pintura centrada/márgenes CTA, palabras completas y
  privacidad en guardados, nombre completo y destino con mensajes sin leer.
  Las suites existentes aportan favoritos, cancelación/contacto, paginación,
  aislamiento, cierre/lecturas y regreso. El coordinador ejecutó el gate integrado
  sobre `53716dc5669dd5b55eb690d1ca071b9902868e7e` más los cambios de los lotes
  todavía sin commit: sesión71673, exit0, **386/386 en1m41s**. Se leyó el resultado
  `+386: All tests passed!` en
  `C:/Users/betoq/AppData/Local/Temp/dopmi-parity-20260930/closeout-batches-tests.log`.
  Esta revisión no inició otro proceso Flutter.
- **AC-V2 — cerrado, capturas posteriores:** se inspeccionaron a tamaño original
  las12 imágenes afectadas enumeradas abajo. Sus mtimes son del2026-10-04 entre
  13:05:37 y13:07:13; muestran los controles, no sólo contenido desplazado. Las
  cuatro normales sin cambio de producto son idénticas por SHA a758; en
  `saved-rescuers` la adición deAC-05 es intencional y no introduce otra diferencia
  perceptible. Se reutilizó el capturador común del coordinador, sesión6522,
  `closeout-profile-captures.log`; no se regeneró el lote en este frente.
- **AC-N1 — recorrido Android del candidato final:** mazo con arrastre corto/largo
  e interrupción; filtro aplicar/cancelar; detalle/galería/contacto; favoritos y
  regreso; conversación con teclado/envío/reconexión y notificación. Comprobar
  también guardados con contenido retirado y texto ampliado. La evidencia748
  utiliza viewInsets sintéticos y el APK es anterior a cambios posteriores.

Los contratos de swipe280ms/retorno250ms, navegación inmediata, rail sin apertura
durante arrastre, pulsación/cancelación y reducción de movimiento ya tienen
pruebas por componente. Se reutilizan; no se repiten por cada fixture.
Pruebas remotas de autorización ya aceptadas no se vuelven a implementar por
estos cambios de layout. No se alteraron backend, reglas económicas niSDKs.

El lote queda pendiente únicamente deAC-N1; los cinco defectos tienen corrección,
gate y evidencia visual actual. Este cierre de defectos no sustituye la revisión
instalada ni afirma aceptación global. Codemagic pertenece al cierre coordinado del
objetivo y dinero continúa sólo en modo prueba.

## Evidencia posterior de controles afectados

Todas las PNG siguientes están en
`C:/Users/betoq/AppData/Local/Temp/.tools/design-review/`. El SHA identifica la
imagen realmente inspeccionada; las entradas anteriores de758 quedan como base.

| Fixture | Hora local 2026-10-04 | SHA256 actual |
| --- | --- | --- |
| adoption-detail | 13:05:37 | `789ee6909c8790cd62625aaafb2e5836abbb04fa8d4de700a5e12518673734f6` |
| adoption-detail-large | 13:05:37 | `82c0d04d392172e2da89e952d9c03250794cce2dcca217fedf00094e87527120` |
| match-home | 13:07:12 | `64d30df96bd95abe3c3c7c02d93587ed9f5547ea9d0e3e73a67369d2a452b0aa` |
| match-home-large | 13:07:13 | `95dac1d872e746f43ec0c67450a175febe8af768b35e688f5cb281815458a46d` |
| saved-adoptions | 13:06:43 | `3be607974a33d2f93d3c24d7a73625b0325dbb67d0ce0a37daefcea179f37199` |
| saved-adoptions-large | 13:06:44 | `0b4fd62486894b3e775a9486014850dfce1aac08383d45918f44705e848c39be` |
| saved-rescuers | 13:06:46 | `faf8f1fca72e197d422355038da54ae432b03f2209c5415fab9088505c422a1a` |
| saved-rescuers-large | 13:06:46 | `5cc819bb1ca07b2addaa87824627111380836b9cfe533461265c0460a21f89c7` |
| saved-pagination-large | 13:06:47 | `4f29e9c2675da5440bd88c723a3346f0ca67258480436b8088627abe7f4ec93c` |
| saved-pagination-second-large | 13:06:47 | `4cc052ed128281569416447a3ffcecadecf32a147685cb5781dde180e8ee8cf4` |
| rescuer-messages | 13:07:08 | `930157506f336f09feb011e38740ec9b7048b4630513c883779ceb3aece751bf` |
| rescuer-messages-large | 13:07:09 | `1b395adac8df656a0b6d9ac233e39edc7befc043485a7699668fd847422ba5ac` |

## Revisión auxiliar de pagos para el coordinador

Se inspeccionaron11 PNG posteriores de pagos, sin editar producción ni reemplazar
la ficha autoritativa PAYMENT/GUARD: tres pares
`payment-methods-cards-independent-default-confirm{,-large}`,
`payment-methods-cards-independent-remove-confirm{,-large}` y
`payment-methods-cards-add-confirm{,-large}` de13:06:24–26 cierranPM-A por margen
vertical y centrado. `payment-methods-cards-remove-confirm{,-large}` de13:06:29
cierraPM-B por centrado; `payment-methods-cards-default-toast{,-large}`
de13:06:28 cierraPM-C, con predeterminado completo. Los cinco pares normales no
muestran otra diferencia perceptible. `guardian-billing-amount-tile-large`
de13:06:31 muestra Aportación completa en los dos tiles visibles y verifica la
adaptación preventiva; el candidatoPM-D nunca se elevó a defecto confirmado.
