# Publicación · actualización 889

Source fijado: `889c096ade9479b348530db7ba169f023b472ab9` de `irlanda/apoyar-detalle-perfil`.
Base de app revisada: `8785f6674c676ac6eb55fa716a75e0cb21d01388`.

## Lote implementado

- REF11: encabezado «Mis Casos», marca/notificaciones, conteo real y estado vacío.
- REF14: selección animada de tipo; el toque selecciona y «Continuar» ejecuta navegación y consulta real de verificación.
- REF15–16: publicación de adopción en tres pasos; principal + cinco adicionales, nueve personalidades, seis opciones de convivencia, edad por rango, salud y descripción real de cuidados. Edad precisa y datos históricos se conservan.
- REF17: caso en tres pasos; perfil con tamaño obligatorio y gastos ya pagados que crean borradores hijos privados reales. Cada gasto conserva centavos, fecha, proveedor, referencia, comprobante y evidencia. Retomar/cancelar el picker conserva el borrador previo; nunca se incluyen archivos privados en `need_items` públicos.
- REF18: previews reutilizan los layouts públicos con galería/desplazamiento activos y acciones externas desactivadas. El caso presenta la suma real capturada como «Solicitado», sin inventar montos elegibles, y usa la identidad del autor del borrador. Sólo una respuesta real `submitted` muestra «Enviado a revisión».

## Contratos conservados

Los gastos se envían por separado tras aprobar el caso y verificar al rescatista. El wizard no publica, aprueba, declara capacidad reembolsable ni habilita dinero. Eliminar solicita confirmación y usa `removeDraftExpense(id, version)`; sólo borradores nunca revisados admiten borrado. Un rechazo del servidor mantiene el elemento. Los archivos privados huérfanos no se eliminan automáticamente.

Las necesidades previstas históricas mantienen su editor y datos dentro de una sección adicional. Los nombres/edades largos y personalidades históricas no se truncaron. No se copió el video post-MVP, mínimos simulados de gastos ni hover.

## Comprobación del lote

`dart format` confirmó parseo de los archivos del lote. Las pruebas se ejecutan únicamente en la cola Flutter central. El último cierre dirigido, `.tools/update889-flutter-publication4.log`, pasó 3/3: edad precisa y conservación del borrador ante error, principal + cinco adicionales, y teclado/elecciones reales tras reconstruir el marco. La causa del último fallo era una colisión de PageStorage entre el estado expandido del acordeón y el desplazamiento interno del campo; cada campo tiene ahora su identificador propio.

La cola central reportó aprobadas las pruebas de casos/gastos en la pasada anterior. El registro central consolidará analyze y las suites `publish_choice_test`, `publication_frame_test`, `publication_personality_test`, `case_publication_test`, `case_photo_recovery_test` y `adoption_photo_recovery_test` sobre el candidato integrado; esta ficha no sustituye la regresión final.

Cobertura dirigida del lote: selección sin writes/consulta prematura, destinos reales y respuesta tardía; teclado/scroll y pickers cancelados al 200%; salud y edad histórica sin pérdida; límite de tres nuevos rasgos sin borrar legacy; principal + cinco adicionales y recuperación sexta sin séptima; tres pasos/Back; gasto hijo privado sin envío automático; borrado confirmado con respuesta real y bloqueo de revisados; éxito de moderación sólo tras respuesta real.

Diez estados Source con fuentes cargadas y datos equivalentes quedaron en `Temp/dopmi-source889-adopt/capture889-publish`, con manifiesto y README. El capturador Flutter se adaptó a tres pasos y permite prefijos separados por coma mediante `CAPTURE_FILTER`, para regenerar sólo los grupos afectados. Source conserva cuatro pasos de caso por el video de agradecimiento excluido; su ubicación simulada «Monterrey, MX» no sustituye la ubicación real guardada.

Pendiente para cierre perceptual: comparación Source/Flutter con datos equivalentes y capturas del lote integrado; pasada nativa Android de pickers/teclado/Back e interrupciones. Esta ficha no acredita aceptación visual ni dispositivo por sí sola.

## Pasada perceptual integrada · 2026-10-05

Se descartaron PNG históricas de las 13:08 que todavía mostraban el wizard anterior. La tanda central renovó Publicación a las 23:57 y completó después principal/fotos, casos y Mis Casos. La comparación con los diez estados Source encontró seis grupos perceptibles, corregidos juntos:

1. Elección: icono de adopción ausente por ruta inexistente, logo/campana, composición vertical vacía/seleccionada, labels y CTA negro de píldora.
2. Perfil: «Perfil» precede a la foto también en caso; especie antes de sexo, sin ayuda adicional del nombre ni «Por determinar» cuando existe sexo concreto.
3. Iconos y tamaño: siluetas Source con color heredado; icono arriba del texto de tamaño. El gato procede del asset `publish-species-cat.svg` de Source889.
4. Rasgos: salud en caja, convivencia con tarjetas de72px y personalidad en chips ajustados al contenido, conservando límites y edición histórica.
5. Preview: intro de16px/copy13px, separación y hero adaptado al viewport; caso utiliza acento morado y abrevia sólo el nombre mostrado, conservando identidad real.
6. Gastos/Mis Casos: eliminar en la misma fila del gasto, encabezado con paw/campana real y fuente explícita de «Nuevo». Las fotos adicionales reales de caso permanecen en una sección opcional plegada.

No se cambiaron API, persistencia, permisos ni cálculos financieros durante esta pasada. El monto de caso continúa rotulado «Solicitado» desde los centavos capturados. Ubicación real, video excluido y tres pasos conservan las excepciones acordadas. El renderer de adopción compartido y los estados de scroll del capturador se verifican en el frente central.

`dart format` y `git diff --check` aprobaron el lote editado. Pendiente: análisis/pruebas centrales y recaptura dirigida de estos seis grupos; no se acredita cierre visual hasta esa comparación.

### Resultado de la recaptura C6

Las PNG renovadas a las00:17 del2026-10-05 cierran los seis grupos en viewport normal: elección vacía/seleccionada, perfil de adopción/caso, salud/convivencia/personalidad, preview y filas de gastos/encabezado de Mis Casos. La regresión central `.tools/update889-regression-affected.log` pasó113/113, incluidos los recorridos actuales e históricos del lote. No se reabren diferencias imperceptibles de4px ni variantes de glifos entre renderizadores.

El CTA normal Source usa `--purple: #7841f2`. El color más oscuro de algunas capturas procede de `.purple-button:hover { background: #6d28d9; }`, fuera del alcance móvil acordado; no se cambió el color correcto para reproducir hover. La elección de adopción muestra casa outline en Source01/02 y ahora usa el asset existente correspondiente.

Restan dos evidencias dirigidas de preview al200%: desplazar el scroll exterior hacia el marco y verificar también el hero de adopción a32vh (204.8px al320×640), que pertenece al renderer compartido del frente central. Caso ya utiliza ese alto. El capturador debe completar asimismo la galería adicional plegada de caso; los fallos de toque registrados corresponden al estado previo de scroll del fixture. La pasada nativa final continúa pendiente en el tablero central.

### Header del preview al200%

La recaptura adaptativa confirmó hero32vh y footer accesible, pero detectó una diferencia real: el marco enviaba el header al scroll sólo por texto ampliado. Source10 conserva Back/título fijos; no se trató como excepción de accesibilidad aceptada. Se retiró esa condición. El header sólo pasa al scroll con teclado abierto o viewport de menos500px, conservando el fallback nativo y el estado del formulario. La prueba de preview100/200 exige ahora Back/título visibles también tras desplazar el cuerpo hacia el aviso inferior. Dartformat/diffcheck limpios; la cola central verifica esta corrección antes del cierre al200%.

### Cierre de desarrollo C6 · 2026-10-05

La comprobación final de header fijo pasó9/9 en `.tools/update889-preview-pinned-tests2.log`. La prueba carga Inter empaquetada y conserva las exigencias de aviso alcanzable, título/Back visibles tras scroll profundo y footer operable al100/200%; no se retiraron aserciones de legibilidad. `.tools/update889-capture-preview-pinned.log` pasó1/1 y regeneró los dos previews al200%.

Las capturas finales conservan Back/«Valida tu caso», marco/hero32vh y controles inferiores fijos conforme a Source10. Ubicación e identidad reales permanecen completas mediante envoltura/desplazamiento interno, sin sustituir datos para imitar el recorte del prototipo. La galería adicional de caso completó asimismo su recaptura con estado del acordeón correctamente asentado.

Los seis grupos perceptibles de REF11/14–18 quedan cerrados en desarrollo, normal y200%. No quedan defectos comprobados de este lote. Este cierre no sustituye la regresión sobre el SHA candidato final, Codemagic/Play ni la aceptación nativa Android, que permanecen en el tablero central.
