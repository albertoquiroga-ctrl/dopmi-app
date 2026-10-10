# Actualización889 — Adoptar

Referencia fija `irlanda/apoyar-detalle-perfil@889c096ade9479b348530db7ba169f023b472ab9`.
Base app `8785f6674c676ac6eb55fa716a75e0cb21d01388`.
Ficha del lote REF-01–05 y REF-19; no reabre las 25 familias anteriores.

Estado: los seis grupos de este lote cierran implementación y comparación
visual perceptual en Source889. El conteo de desarrollo baja de 19 a 13
grupos pendientes. Sigue pendiente la aceptación nativa, la puerta integral
del candidato y la entrega; no representa cierre final de 19/19.

Implementación agrupada: wordmark con selección real de ubicación accesible;
fin del mazo con hasta cuatro publicaciones únicas y primera foto de cada una;
filtros Sexo/tamaños rotulados/nueve personalidades con selección única y ancho
medido con fuente/escalado reales; detalle con edad, personalidad,
convivencia explícita y salud, preservando distancia real y datos históricos;
galería sin puntos para una foto y puntos operables para varias; CTA
«Quiero saber más» y confirmación «Conectar con {nombre}». La barra fija
del detalle llega al borde inferior con margen14 y zona segura nativa,
conforme a la corrección de especificidad CSS en Source889.

El diálogo explica que la confirmación envía un saludo inicial sólo en una
conversación nueva. Su envío y deduplicación pertenecen al contrato integrado
por el coordinador; esta ficha no atribuye esa operación por mostrar el diálogo.
No se deduce género del nombre de la persona rescatista.

El detalle ofrece `preview:true` al formulario: hero240, scroll y galería
reutilizados, identidad/share/reporte estáticos y ningún destino ni CTA de
contacto/guardado. Datos y fotos del borrador siguen siendo privados.

Pruebas dirigidas cubren: nueve etiquetas sin desbordamiento en Samsung115%,
reemplazo y deselección de personalidad con consulta real, cancelación/limpiar y
resultados tardíos conservados; mosaico sin repetir fotos de una publicación;
una foto sin controles; swipe y punto sincronizados; reinicio al cambiar
publicación; preview sin acciones y con rasgos reales; confirmación personalizada
y scroll200%. Se mantienen tests de pulsación/cancelación y CTA fija.

Auxiliar Source: doce estados aislados en Temp, viewport377×852 y320×640
al200%, Inter/Fraunces cargadas, cero imágenes rotas y cero errores del
navegador. Incluye fin de cuatro publicaciones y fin filtrado a una; sus
datos deben coincidir antes de comparar con Flutter. Capturas por sí solas
no acreditan operaciones reales.

El primer dirigido detectó un desborde real del reporte estático del preview,
corregido al permitir envolver el texto; y un fixture de semántica/swipe
corregido al activar semántica antes del pump y fijar el viewport móvil.
Dirigidos aprobados por la cola única del coordinador: 46/46, registro
`.tools/update889-flutter-adopt-final.log`, incluyendo preview/galería,
barra fija y foto única sin controles. No incluye aceptación visual por sí solo.
Capturas Flutter afectadas y comparación perceptual completadas; quedan
puerta integral del candidato y aceptación nativa.
Este agente no ejecutó Flutter, dispositivo, builds ni commits.
Comparación de los PNG nuevos contra Source889: wordmark, fin de cuatro,
detalle y confirmación normales conservan composición, datos equivalentes y
CTA. La diferencia de 3 px en el fin se acepta como imperceptible; sombras
usan los mismos valores. Distancia real, expansión de salud histórica y el
aviso del saludo explican los elementos adicionales del app.

Se encontraron dos grupos perceptibles: filtros con título18/radio16 y tamaños
de altura desigual frente título22/radio24/fila uniforme de Source; y acciones
al200% apretadas en altura fija por el padding heredado. Ambos corregidos juntos
en los dos componentes propios: fila uniforme de tamaños, título/radio y
padding11×18 con crecimiento natural de acciones. Las pruebas existentes
comprueban alineación y espacio vertical del texto ampliado, sin repetir
operaciones backend. Dirigidos de esa corrección: 21/21 aprobados por la cola
central (`.tools/update889-adopt-visual-fix-tests.log`). Recaptura aprobada:
normal y200% muestran título/radio/tamaños y
acciones con altura natural. Se centró además el texto que envuelve en acciones,
como Source. Comprobación final visual del 2026-10-05: PNG
`adoption-filters-large.png` y `adoption-detail-contact-large.png` de 00:17:30,
en el directorio auxiliar Temp de capturas, confirman las dos líneas centradas
y el espacio vertical al200%; se cierran los dos defectos perceptibles.
La regresión dirigida de componentes afectados también pasó 113/113
(`.tools/update889-regression-affected.log`), incluidos reflow y límites de
toque/drag, sin debilitar destinatario, lectura ni semántica.
No se acredita operación real ni cierre integral por capturas. La evidencia
de operaciones reales y la pasada Android pertenecen a la integración del
coordinador; este cierre conserva sus pendientes.
