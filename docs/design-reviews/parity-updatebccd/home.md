# Inicio Rescatista — Source bccd

Fuente fijada: `bccd040d3a4b1c391bc6ab9eeccc479198868a7f`; base `889c096ade9479b348530db7ba169f023b472ab9`. App de partida `ed4b788bd4117eb8949bb633483e94d8d4b36010` / Play 295. Una pasada Source completa, diez estados, fuentes Inter/Fraunces cargadas, 0 errores de consola, 0 imágenes rotas y 0 overlays Vite. Evidencia local reutilizable: `C:/Users/betoq/AppData/Local/Temp/dopmi-plan-bccd040/capture-home/manifest.json`.

## Lista finita: ocho grupos

| Grupo | Diferencia perceptible implementada | Prueba de cierre requerida |
|---|---|---|
| H01 Cabecera | Wordmark y campana morada, saludo sin subtítulo/wallet, identidad real aislada por cuenta. | Comparación 377×852 + regreso desde notificaciones. |
| H02 Métricas de adopción | Carrusel Adoptar/Mis match/Mensajes con tres superficies, cifra y texto; desplazamiento horizontal con snap. | Source 01; agregado real de vistas consentidas desde activación, mascotas guardadas y conversaciones sin respuesta; swipe sin navegar. |
| H03 Evidencias de apoyo | Carrusel informativo de evidencias propias, urgencia y avance calculado por formulario. | Source 02; pendientes reales, 200% sin recorte de información; aprobado no editable. |
| H04 Mis pendientes | Cuatro accesos, badges 9+, selección, mensajes con destino real. | Source 01–04; contadores reales y mensajes; texto 200%. |
| H05 Resúmenes | Cuatro estados en cada programa, contador y filtro exacto a Mis casos. | Source 03–04; ocho destinos programa/estado y Back. |
| H06 Pagos | Actividad recibida real con foto/importe neto/fecha; historial paginado propio, deduplicación; reconocimiento sólo con cursor presentado. | Source 05–06; error/reintento conserva badge, paginación y actividad de casos cerrados. |
| H07 Estados | Vacío, verificación pendiente/correcciones, loading/error/reintento y cambio de identidad. | Source 07–10; sin simulaciones ni ceros inventados y operaciones permitidas disponibles. |
| H08 Tips | Banner negro/estrella y presión 120 ms/.99; recomendaciones reales con Back. | Toque, recomendaciones y regreso a Inicio; hover excluido. |

Estado del lote: implementación guardada; verificaciones Flutter, comparación final y Android pendientes de la cola central. No se acredita cierre mediante capturas Source solamente. Archivos exclusivos: `rescuer_home_screen.dart`, `rescuer_home_screen_test.dart`, esta ficha.

## Contratos y excepciones funcionales

Dashboard V2 real: conteos de adopción/apoyo por estado; métricas de vistas únicas consentidas desde activación y mascotas guardadas; conversaciones sin respuesta; evidencias propias con `progress_percent` según campos requeridos; actividad asignada real (`net_cents`, `expense_title`, foto, fecha, origen y estado de transferencia). Ausencia de un valor se muestra como no disponible, no como cero. Dinero exclusivamente en prueba; no cambios de reglas financieras.

La selección de Pagos reconoce `payments_cursor` después de presentar el panel y refresca el contador del servidor. El historial reconoce exclusivamente `DataPage.cursor` de la página presentada, conserva errores recuperables y vacía datos ante errores de lectura/cambio de actor. No se utiliza la facturación del donante como historial del rescatista. No se inventan nombres/número de donantes, pagos semanales ni porcentajes de progreso.

Las tarjetas de los carruseles son informativas en Source; los expedientes continúan accesibles por los resúmenes/Mis casos. La falta de verificación financiera no bloquea borradores, adopciones propias, conversaciones ni historial ya existente. Source enlaza Tips a `/impact/support` (App.tsx 4947–4955), ruta inexistente y sin recomendaciones; decisión root autorizada: `/rescuer/photo-tips` mínima con luz natural, sin flash/filtros, altura de mascota, enfoque/fondo y Back. Croquetas, bono de verificación y Simular verificación quedan excluidos.

Accesibilidad: 320px/200% aumenta ancho/alto natural de tarjetas, coloca cantidades debajo del texto y conserva desplazamiento/lectura; no copia los recortes de Source. No cambios a fotos, caché o swipe aceptados de Play 295.

## Evidencia y siguiente pasada

Source: adopción/apoyo, resumen de ambos, pagos superior/inferior, vacío verificado, vacío sin verificar, revisión y adopción a 200%. Runtime compartido `4192`, sesión aislada `bccd-home`; extracción exacta y fuentes locales. El primer Vite tenía cwd incorrecto; se descartó antes de capturar y se verificó el módulo bccd en el servidor corregido. No se abrió un segundo servidor.

Pruebas propias preparadas (sin ejecución por agente): carrusel y filtros normal/200%, reconocimiento con fallo/reintento y destino historial, páginas deduplicadas/cursor, carga fallida sin cero inventado, adopción usable con verificación pendiente, Tips/Back y aislamiento de respuestas tardías/historial. Pruebas antiguas de Home deben reflejar las tarjetas informativas actuales, sin restaurar wallet/CTA retirados por Source.

Pasada Android mínima, en la cola root: abrir Inicio con cuenta QA real y estado de verificación; arrastrar carrusel horizontal sin navegación y desplazar página vertical; seleccionar ambos resúmenes y regresar de filtro; Mensajes/Back; Pagos/historial/página siguiente y contador; Tips/Back; texto ampliado. Fixtures controladas con vista consentida desde otro actor, guardado, conversación pendiente, evidencia incompleta y asignación Stripe test existente; no crear dinero ni publicar/verificar a usuarios reales para reproducir cifras Source.


## Pasada conjunta visual 1 y corrección agrupada

Comparadas las once capturas Flutter contra los diez estados Source, con el mismo tamaño normal377×852, 320×640/200% y variante de texto115% para Samsung en el harness (no acredita dispositivo físico). Se descartaron las primeras capturas de acciones porque no habían tocado los selectores; la tanda corregida sí mostró evidencia, ambos resúmenes y Pagos. Las primeras fotos sintéticas de Pagos fallaban por la precarga del capturador; la tanda final con PhotoRuntime preparado muestra Nina/Milo correctas, sin cambiar producto/caché.

Source06 se corrigió únicamente en su evidencia Temp: scroll real300 sobre `.screen-scroll`, PNG y entrada del mismo manifest actualizados, 0 imágenes rotas/0 overlay. La primera Source06 había desplazado window y repetía la captura superior; no era un defecto de app.

Lista finita de diferencias perceptibles: **3 cambios en 2 grupos**. H04: los iconos del acceso seleccionado debían tornarse morados; a115% Adopción/Mensajes se partían por la última letra. H03: Milo draft no urgente debía decir Evidencia pendiente. Corrección única guardada: color seleccionado, fuente12/gap10 de Source, medición de etiquetas y reflujo4/2/1 columnas sólo cuando hace falta (sin partir palabras); copia draft urgente/Incompleta y draft no urgente/Evidencia pendiente. Se prepararon dos pruebas adicionales: palabras completas/cuatro columnas con Inter real a115% y ambas presentaciones de evidencia; las pruebas existentes también verifican el icono seleccionado.

H01/H02/H05/H06/H08 no mostraron otras diferencias que ameriten reabrir implementación. En H06 se conservan títulos/fechas reales y la altura natural que deriva de esos datos; no se inventan Luis/Sofía/número de donantes/Esta semana. H07 conserva el bloque de verificación y sus botones accesibles previamente aceptados, con estado real/privacidad y Ver estado; no se reabre su estilo ni se copia Simular verificación/bonos/afirmación de que se desbloquean todas las funciones. A200% se acepta reflujo legible frente a los recortes Source, incluido saludo y navegación.

Pendiente: segunda y última comparación de H03/H04 afectados y validación central de las once pruebas propias; operaciones backend/Android/entrega siguen en la cola root. No se ejecutó Flutter ni backend desde este agente.

## Cierre de desarrollo6/10

Primera comparación conjunta completada (10Source/11Flutter): H03/H04 reunieron tres diferencias perceptibles — evidencia pendiente no urgente, icono seleccionado morado y etiquetas completas115%. Corregidas juntas en una sola pasada. Diez dirigidos aprobaron inicialmente y el check nuevo115% pasó al limitar el finder al acceso correspondiente, completando11/11. Recaptura exclusivamente afectada aprobada conCAPTURE_FILTER y contraste central normal/115/200. Fotos de actividad Nina/Milo verificadas; decode del harness preparado conrunAsync sin modificar cache/transporte295. Source06 se corrigió para desplazar el contenedor real300px, no window.

Conteos/métricas/pendiente de respuesta y progreso real acreditados por SQL del delta y Auth/RPC DEV, incluidas vistas concurrentes/reintentadas y lectura frente a respuesta. Actividad con Guardian/individuales/casos cerrados y reconocimiento exacto cubierta por SQL transaccional. Sin defectos perceptibles conocidos de los ocho grupos tras la primera pasada. Pendientes transversales: auditoría independiente, gate final, emulador y Samsung instalado.


## Entrega instalada6/10

Candidato Androidf3808f1 publicado una sola vez por Codemagic6ac512ac762af530b028e23f; Playinternal/completed296 comprobado aparte. Samsung2.3.3(296)/Android16/115% aprobado: Inicio/carruseles, casos/filtros/Archivo, inbox/selección/Sin leer/Historial/Back/refresh, teclado, FAB/cancelación, galería6 y swipe corto/largo. Sesión y modo Adoptante conservados; no se escribieron borradores ni mensajes personales. Cierres/reactivación se acreditan por21checks controlados del emulador. Gate móvil476/f380913tests y bloques equivalentes474/f362 aprobados. Cero defectos perceptibles conocidos. Sólo cleanup administrativo del único archivo QA cerrado pendiente; detalle vigente en tablero.


Cierre final6/10: entrega instalada y limpieza exacta aprobadas. Postflight DEV19conteos QA cero; singleton de activación conservado. No quedan puertas pendientes de este lote/corte; ver tablero vigente.
