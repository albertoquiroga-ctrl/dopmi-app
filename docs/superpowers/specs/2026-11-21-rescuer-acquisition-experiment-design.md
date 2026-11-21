# Experimento de adquisición de rescatistas: comentarios frente a anuncios

Diseño21/11/2026, CDMX. Estado: **protocolo preparado; ensayo confirmatorio no iniciado**.
Contrato técnico y entrega al chat de campañas: [handoff](../../campaign-attribution-handoff.md).
Decisiones operativas propuestas por Codex se identifican como tales; no son
resultados ni aprobaciones de gasto. Este documento no implementa nuevos trackers.

## Objetivo e hipótesis

Hipótesis del usuario: las rescatistas independientes que ya publican adopciones
en grupos que sigue en MTY tienen intención y disposición para publicar gratis
en otra plataforma; un comentario útil puede captar más publicadores que los
anuncios actuales. El comparador principal confirmado es **Meta/Google pagados**.

Decisión propuesta: evaluar adquisición por **cuentas elegibles que envían una
primera ficha original a revisión**. Una cuenta con varias mascotas cuenta una
vez en el resultado principal. Después medir calidad/aprobación y repetición,
sin confundir cuentas con personas únicas ni afirmar que toda cuenta es una
rescatista independiente por haber publicado.

Preguntas separadas:

1. ¿Cuál política obtiene más primeras fichas observables por costo total,
   contando tiempo de operación y anuncios?
2. Dentro de comentarios a independientes, ¿qué mensaje e identidad mejoran
   ese rendimiento bajo la misma oferta y acceso?
3. ¿Cambian los resultados por tipo de post, plataforma, enlace y fricción?

No está probado que los tres hitos de mensajes funcionen en dispositivo:
saludo y primer mensaje sí pasaron en iPad421; respuesta propia como dueño y
aprobación siguen pendientes. Un test técnico de transporte no prueba eficacia
comercial ni permite extrapolar una tasa de conversión.

## Qué se puede medir y qué falta

Android ya permite atribución consentida por cuatro variantes y primer envío;
iOS tiene sólo personal-a técnico validado en TestFlight/Safari, sin CPP pública
activada o instalación desde App Store validada. No mezclar ambos denominadores.
Los reportes actuales agrupan por variante, no por comentario/autora/segmento.
Una cuenta puede aparecer en Android y en iOS: la unión entre métodos debe
deduplicar cuentas autorizadas dentro del reporte, nunca sumar personas supuestas.
OFF/eliminación retiran fuentes e hitos y pueden cambiar los denominadores entre
cortes. Documentar la población todavía observable/consentida, excluir QA tanto
del numerador como del denominador y no reconstruir atribución retirada. Distinta
cobertura de consentimiento entre brazos puede parecer un efecto del mensaje.

El enlace público puede convertir a la autora, a lectores o a alguien que lo
recibió compartido. Sin una correspondencia autorizada y validada entre autora
y cuenta DopMi, el resultado es **primeras fichas atribuidas por cada100 contactos**,
no «porcentaje de autoras contactadas que publicaron». No unir por nombre, hora,
fotos o similitudes. El usuario mantiene descarga directa sin códigos/login previo.

Registrar un segmento en una hoja no basta para calcular publicaciones de ese
segmento: también debe existir atribución conservada hasta ese segmento. Tampoco
se puede comparar ausencia de eventos entre brazos con distinta observabilidad.

## Resultados y costos predefinidos

| Nivel | Medida | Interpretación |
| --- | --- | --- |
| Principal comercial | Cuenta única con primera ficha enviada a revisión. | Adquisición observable; no borradores, clics o descargas. |
| Calidad | Aprobación de esa primera ficha, proporción aprobada a un plazo común y tiempo de revisión. | Evita premiar fichas inadecuadas; reportar aún pendientes por separado. |
| Rendimiento orgánico | Primeros envíos atribuidos/100 contactos únicos asignados; también por100 comentarios efectivamente visibles. | Conteo de rendimiento, puede incluir lectores; el segundo denominador es descriptivo, no sustituye asignación. |
| Eficiencia | Costo total/primer envío y primer envío/hora de trabajo. | Incluir tiempo de buscar, leer, comentar, responder y registrar. |
| Retención exploratoria | Segunda ficha real a30d y seguimiento a60d. | Instrumentación nueva pendiente; el reporte actual de primera ficha no lo entrega. |
| Diagnóstico | Respuesta a comentario, clics filtrados, inscripción atribuida, saludo, primer mensaje, respuesta propia. | No son sustitutos del objetivo de publicadores. |
| Experiencia | Comentarios ocultos/eliminados, rechazos, petición de no contacto y fallas del flujo. | Conservarlos en el análisis por asignación; nunca retirar sólo los casos malos. |

Costos en MXN: `CPA_total = (gasto incremental + horas × V_hora + costos operativos asignados) / primeras fichas`.
Fijar V_hora y amortización antes del cierre; mientras falte, publicar horas y
un análisis de sensibilidad por valor/hora, sin llamar gratis al trabajo.
Con cero conversiones el CPA no es0 ni un ganador: informar costo y cero casos.

Para comparar Meta y Google, reportar cada canal y, si se evalúan juntos, congelar
su mezcla presupuestaria. No sumar conversiones que ambos proveedores reclaman.
El servidor deduplica cuentas conforme al contrato; los paneles publicitarios
con distintas ventanas/view-through permanecen como diagnóstico independiente.

## Población y muestreo orgánico

Propuesta inicial: publicaciones activas de adopción en MTY/metrópoli, de hasta
7d de antigüedad al seleccionar. Municipio declarado en la publicación, sin
deducir domicilio de la persona. Congelar una lista de grupos y definición de
alrededores antes de reclutar; no seleccionar a mano sólo los posts que parecen
fáciles para un brazo. Recorrer inventario en orden cronológico reproducible.

Clasificar con evidencia visible: independiente declarada, particular que
reubica una mascota, organización, republicación de tercero o desconocido.
La primera prueba se concentra en las dos primeras clases; no atribuir el efecto
de ese segmento frente a organizaciones como si hubiese sido aleatorizado.
Excluir solicitudes de búsqueda de mascota perdida, colectas o publicaciones
que ya no ofrecen adopción. Respetar reglas del grupo y no usar elegibilidad
posterior al resultado para borrar observaciones.

Una autora recibe un solo contacto durante el experimento aunque tenga muchos
posts/grupos. El registro privado deduplica su perfil público con una clave
pseudónima de alcance limitado; sigue siendo dato personal y no se guarda en Git
ni se envía al backend de atribución. No deducir identidad entre plataformas.
Conservar exclusiones/duplicados y exposiciones previas conocidas. No enviar
mensajes privados o seguimientos no solicitados por ser un brazo experimental.

## Variables candidatas y orden de prueba

| Variable | Niveles propuestos | Tipo y fase |
| --- | --- | --- |
| Enfoque del mensaje | Encontrar/difundir hacia adoptantes vs facilidad de crear la ficha gratis. | Aleatorio, primer factorial. |
| Identidad que comenta | Perfil personal con afiliación transparente vs página DopMi. | Aleatorio donde ambas identidades estén permitidas, primer factorial. |
| Personalización | Mención de la mascota/dato pertinente vs texto general respetuoso. | Aleatorio en ola posterior; mantener constante inicialmente. |
| Longitud | Invitación breve vs pasos explícitos de publicación. | Aleatorio posterior. |
| CTA | «Publica su ficha» vs «Descarga DopMi y publica». | Aleatorio posterior. |
| Ubicación del enlace | Después de la invitación vs al final del comentario. | Aleatorio posterior con mismo transporte. |
| Apariencia del enlace | URL de marca legible vs alias de marca corto con igual destino/payload. | Aleatorio sólo tras implementar/probar aliases; no hay URL nueva entregada aquí. |
| Tarjeta/preview | Texto/título/imagen reales de preview, si esa superficie los muestra. | Aleatorio posterior; registrar preview observado, no asumir que Facebook lo renderiza. |
| Acceso | Enlace directo vs enlace del perfil/bio vs búsqueda en tienda sin enlace. | Diferir hasta medición comparable independiente del enlace. |
| Prueba social | Afirmación verificable concreta vs ausencia de esa afirmación. | Aleatorio posterior; nunca inventar adopciones, usuarios o alcance. |
| Idioma/oferta local | Mención de MTY y adopción local vs invitación general. | Aleatorio posterior. |
| Superficie | Grupo, perfil de la rescatista, página, Instagram post/Reel. | Inicialmente observacional; después aleatorizar políticas de prospección si hay medición comparable. |
| Autora | Independiente, particular, organización, tercero, desconocido. | Observado antes de asignar; no causal por comparar tasas. |
| Formato/origen | Original o compartido; foto, varias fotos, video/Reel. | Observado; clasificación desconocida si no se puede verificar. |
| Solicitud visible | Pide difusión explícita, urgencia declarada, no declara urgencia. | Observado; no inferir vulnerabilidad ni manipular urgencia. |
| Mascota | Gato/perro, una o varias mascotas, edad declarada. | Observado/posible bloqueo; no hacer conclusiones con celdas diminutas. |
| Contexto | Municipio, antigüedad del post, actividad previa, grupo y día/franja horaria. | Bloqueo/covariable previa; sólo tiempos asignados al azar permiten inferir efecto horario. |
| Seguimiento | Respuesta útil sólo si la autora pregunta. | Mantener política común inicialmente, registrar tiempo; no perseguir a quien no responde. |

Estas variables son hipótesis a contrastar, no una lista de efectos significativos.
Prioridad propuesta: mensaje e identidad → personalización/CTA → presentación
del enlace → acceso/bio y expansión de superficie. No cambiar todo en cada comentario.

## Etapa0: medición, registro y piloto operativo

Antes del confirmatorio:

- Crear un namespace nuevo de experimento/ola/brazo que no recicle los cuatro
  enlaces históricos. Si se necesita segmentar resultados, conservar además
  un token opaco de colocación; un mismo token corresponde a un comentario
  planificado y su contexto privado, sin identidad social en el token/backend.
- Transportar y verificar ese registro hasta la fuente consentida, primer envío
  y reporte. Esto **requiere ampliación técnica** de landing, allowlists, cliente,
  servidor y reporte; UTM añadida a las URLs actuales no lo resuelve.
- Preservar primera fuente elegible, propietario, revisión de consentimiento,
  ventanas, deduplicación, opt-out, identidad de distribución y arreglos recientes.
  Validar Android real. No generalizar el piloto iOS personal-a a otras variantes.
- Aislar namespace de orgánico, Meta pagado y Google pagado. Preparar el puente
  publicitario por separado; un SDK de Meta no prueba atribución orgánica, ni al revés.
- Decisión propuesta: piloto de60 autoras únicas, distribuido entre los cuatro
  brazos, para revisar inventario, visibilidad, asignación y medición. No buscar
  significancia con esos60. Con instrumento nuevo primero comprobar el flujo;
  si usa enlaces históricos, etiquetarlo piloto contaminable, nunca confirmatorio.
- Cerrar fallas y congelar versión. Datos de piloto no pasan al confirmatorio
  si cambian mensajes, selección o instrumentación.

Se puede observar el comportamiento de los enlaces existentes desde ahora, pero
no presentar las capacidades pendientes como disponibles ni lanzar múltiples
brazos nuevos imposibles de distinguir. El benchmark pagado también espera
resultados de primera ficha comparables, no sólo instalaciones baratas.

## Etapa1: factorial de mensajes e identidad

Propuesta2×2, enlace directo constante. Estos IDs son **simbólicos, no URLs activas**:

| Brazo | Mensaje | Identidad |
| --- | --- | --- |
| R1 | Beneficio de difusión | Personal |
| R2 | Facilidad/gratuidad | Personal |
| R3 | Beneficio de difusión | Página DopMi |
| R4 | Facilidad/gratuidad | Página DopMi |

Ejemplos para congelar tras cotejar que publicar no tiene costo:

- Base beneficio: «También puedes publicar a [mascota] en DopMi para que personas
  que buscan adoptar puedan conocer su historia. Publicar la ficha es gratis.
  Soy parte de DopMi. Descarga la app y elige “Publicar una adopción”: [enlace]».
- Base facilidad: «Puedes crear gratis la ficha de [mascota] en DopMi con sus
  fotos, historia y ubicación. Soy parte de DopMi. Descarga la app y elige
  “Publicar una adopción”: [enlace]».

Mantener igual personalización, CTA, oferta, enlace y política de respuesta;
ajustar sólo concordancia real de mascota/plural. No prometer que habrá adoptante.
La afiliación es visible también desde el perfil personal. No improvisar textos
fuera de la versión asignada; una variación sustancial es otro brazo/ola.

Asignar aleatoriamente1:1:1:1 con semilla guardada antes de comentar y bloques
predefinidos por grupo×semana; especie sólo si no fragmenta el inventario.
Mantener el brazo de una autora al encontrar duplicados. En grupos que no admiten
páginas, hacer sólo una cohorte de mensajes desde perfil personal; no usarla para
estimar el efecto de identidad. No asignar la página a grupos que ya sabemos que
la van a rechazar y luego quitar sus fallos del denominador.

Unidad de asignación: autora/contacto único. Unidad observable de resultado:
cuentas con primera ficha por token de colocación, que pueden incluir lectores.
Retener esa relación colocación→brazo→bloque permite analizar conteos con offset
de contactos y dependencia por grupo. Con interferencia fuerte, asignar comunidades
enteras al mismo brazo y recalcular potencia; muchos comentarios en dos grupos
no equivalen a muchos grupos independientes. Registrar cruces de brazos conocidos.

Efectos principales de mensaje e identidad: familia confirmatoria de dos
contrastes, control de error familiar5% (Holm). Interacción mensaje×identidad
exploratoria salvo muestra específica. Elegir un mensaje ganador en exploración
requiere confirmación posterior contra el control con autores/bloques nuevos.
Un factorial de dos factores tiene cuatro combinaciones; no probar todas las
combinaciones de18 variables. [NIST, factoriales](https://www.itl.nist.gov/div898/handbook/pri/section3/pri333.htm).

## Etapa2: enlace, bio e Instagram

Probar primero cambios medibles manteniendo transporte y destino equivalentes:
ubicación del enlace, CTA, alias de marca validado y preview realmente visible.
Los aliases nuevos deben llegar al mismo registro de experimento sin sobrescribir
el primer contexto. No imprimir una URL de ejemplo en Facebook antes de probarla.

Un brazo sin enlace o con bio común pierde la etiqueta de origen. No registrarlo
como cero fichas y compararlo contra enlaces instrumentados. Alternativas válidas:
medición agregada independiente del enlace con asignación por comunidades/mercados,
o un mecanismo que mantenga la asignación sin añadir pasos prohibidos y que pase
prueba real. Cambiar la bio cada día no identifica visitas tardías. Si ninguna
opción funciona, limitar ese ensayo a respuestas/fricción observable y declarar
que no resuelve publicaciones. No usar códigos ni login web como atajo.

Instagram se valida como recorrido separado, incluida posibilidad real de tocar
el enlace en esa superficie. Misma oferta no significa misma exposición ni misma
audiencia. Comparar Facebook e Instagram sin asignación compatible es descriptivo.

## Etapa3: comprobar comentarios frente a Meta/Google

### Benchmark concurrente, disponible antes del estudio causal

Registrar las políticas vigentes durante las mismas fechas: alcance geográfico,
objetivo de anuncios, mezcla Meta/Google, gasto, trabajo, costo y primeras fichas
observables separadas por SO y cobertura. Comparar CPA/hora/calidad con incertidumbre.
No cambiar ni apagar anuncios para redactar este plan. Si los anuncios buscan
instalaciones/adoptantes y los comentarios publicadores, mostrarlo como comparación
de estrategias actuales, no como prueba aislada de que un canal es mejor.

No dividir fichas por cuentas atribuidas para juzgar el canal: la atribución es
posterior al tratamiento. Tampoco comparar CPA Android pagado dirigido a Android
con rendimiento orgánico total como si la cobertura de dispositivos fuera igual.
Si orgánico sólo observa conversiones Android, denominarlo así; la ausencia de
atribución iOS es desconocida. El resultado primario global espera medición común.

### Confirmación de incremento: diseño propuesto, todavía condicionado

Una comparación causal requiere contrafactual. Propuesta: mercados no solapados,
emparejados por resultados previos y asignados al azar a políticas estables:

| Política | Tratamiento |
| --- | --- |
| C0 | Operación/campañas habituales predefinidas, sin acción adicional del experimento. |
| C1 | Esa misma base + comentarios orgánicos con dosis/tiempo predefinidos. |
| C2 | Esa misma base + pauta incremental Meta/Google con mezcla y recursos predefinidos. |

C1−C0 y C2−C0 estiman incrementos de esas políticas a esos recursos; C1−C2 los
compara. Ajustar sus tres contrastes como familia. Una política Meta+Google fija
evalúa el conjunto; separarlos requiere más brazos y potencia. No se demuestra
superioridad universal de un canal ni equivalencia de dosis por gastar lo mismo.

Medir primeras fichas únicas por mercado con una métrica común **independiente
del enlace de adquisición**, bajo el consentimiento aplicable y sin resetearlo.
Definir cómo se asigna una cuenta/ficha al mercado antes de reclutar. El grupo de
Facebook o la ciudad de la mascota no prueban residencia: si se usa municipio de
la primera ficha como unidad, validar ese proxy y llamar al estimando por esa
ubicación, no por domicilio humano. Casos fuera de zona/multizona van separados.

Cuatro semanas previas es un punto de partida propuesto para estudiar estabilidad,
volumen, estacionalidad y medición; ampliar si no bastan. Determinar número de
mercados/duración con simulación de su variación y correlación reales, no con la
tabla binomial inferior. Semanas repetidas en el mismo mercado no crean nuevas
unidades independientes. Retargeting, grupos multizona y exposición cruzada pueden
invalidar la separación; si no se pueden controlar, no declarar causalidad.
Con pocas zonas/eventos en MTY, el resultado puede ser sólo factibilidad o
inconcluso. Referencia: [experimentos geográficos, Google Research](https://research.google/pubs/measuring-ad-effectiveness-using-geo-experiments/).

Preparar antes de ejecutar el mapa/asignación, medición común, dosis y cambio
concreto de pauta dentro de límites autorizados. No reservar ni aumentar gasto
con este documento. Si no existen recursos para pauta incremental, rediseñar una
redistribución dentro del presupuesto vigente y documentar el estimando nuevo;
no llamar al brazo C2 incremental sin serlo.

## Ventanas, potencia y decisiones

Congelar antes de reclutar: N o número de clusters, fechas, comparaciones, métrica,
MDE relevante para el negocio, versión, exclusiones y análisis. Propuesta de
objetivo de potencia80% y error familiar5%; son decisiones de diseño, no garantías.
Esperar cohortes completas. No parar al primer p<0.05 ni cambiar brazos por un
ranking diario. Si se decide un método secuencial, preregistrar su regla primero.

Hay tres relojes distintos: comentario/exposición, clic/inscripción y evento.
Fijar una ventana de adquisición del experimento; en Android, conservar los
clics de esa ventana y esperar336h después del último clic elegible. En iOS,
cohortes desde inscripción servidor, separadas. Mantener asignaciones/enlaces
inmutables y registrar clics tardíos en otra cohorte; no desactivar descargas
para limpiar datos. Sin token de colocación no se conoce el retraso por post.

Ejemplos orientativos para **proporciones binarias independientes identificadas**,
alpha bilateral0.05/potencia80%, dos brazos iguales, aproximación normal propia:

| Cambio hipotético | N por brazo | Total |
| --- | ---: | ---: |
|2%→4%|1,141|2,282|
|5%→10%|435|870|
|2%→3%|3,826|7,652|
|5%→7.5%|1,471|2,942|

Fórmula reproducible: `ceil((1.9599639845*sqrt(2*pbar*(1-pbar)) + 0.8416212336*sqrt(p0*(1-p0)+p1*(1-p1)))^2 / (p1-p0)^2)`.
No son tamaños calculados para el rendimiento agregado de comentarios, mercados
ni18 variables; tampoco cuatro muestras por brazo de un factorial. No incluyen
multiplicidad, agrupación, pérdidas ni contaminación. Para los dos contrastes,
planificar conservadoramente con alpha0.025 o simular Holm. Ejemplo2%→4%:
1,382 por nivel en el caso binario simple, antes de los demás ajustes.
Método de referencia: [potencia de dos proporciones, Minitab](https://support.minitab.com/en-us/minitab/help-and-how-to/statistics/power-and-sample-size/how-to/hypothesis-tests/power-and-sample-size-for-2-proportions/methods-and-formulas/methods-and-formulas/).

En el ensayo real usar conteos por colocación/bloque y un modelo apropiado
Poisson/negativo binomial según sobredispersión, con offset de contactos asignados
y dependencia por grupo, o inferencia de aleatorización en la unidad asignada
cuando los datos permitan reconstruirla. No aplicar Fisher/proporciones a fichas
de lectores divididas entre autoras distintas. Pocos clusters invalidan la
confianza asintótica habitual; elegir análisis/muestra antes de abrir resultados.

Informar efecto absoluto, relativo, intervalos95% y costo/tiempo/calidad, con
ajuste para contrastes confirmatorios. Separar observación de inferencia causal.
Una diferencia estadística minúscula no basta para preferir un método; exigir
la mejora práctica predefinida. Si falta potencia, el cierre correcto es
**inconcluso**, no empate ni «funcionan igual». Cien comentarios no garantizan nada.
Bloques y multiplicidad: [NIST](https://www.itl.nist.gov/div898/handbook/pri/section3/pri332.htm),
[comparaciones múltiples](https://www.itl.nist.gov/div898/handbook/prc/section4/prc47.htm).

## Registro privado y reporte

Registro de asignación antes de publicar: experiment_id, versión/huella del
protocolo, semilla, unidad asignada, arm_id, block_id, placement_id y estado de
instrumentación. Relación privada de autora pseudónima, URL de post/comentario,
grupo, plataforma, segmento previo, fecha/asignación y texto exacto publicado.
Guardar minutos/costo, visibilidad y motivos de no entrega; no datos en Git.

Registro automático propuesto de adquisición: IDs de experimento/brazo/colocación
validados y sin PII, SO/método, reloj del origen, revisión de consentimiento,
resultado único y fecha. La ampliación técnica debe definir integridad, retención,
opt-out y publicación del reporte antes de implementarla. No enviar a proveedores
los IDs sociales del ledger ni contenido de chats/mascotas.

Reporte por corte: asignados/elegibles/entregados, minutos/gasto, cobertura de
medición por SO y proveedor, cohortes maduras/no maduras, cuentas atribuibles,
primeros envíos/aprobaciones/pendientes, eventos separados y desconocidos.
Desglosar QA, duplicados y contaminación. No fabricar denominadores de impresiones
de comentarios o clics humanos si sólo hay solicitudes HTTP/crawlers.

## Orden de ejecución y responsabilidades

1. Chat de campañas: leer handoff y auditar señal actual Meta/Google/objetivos
   sin tocar presupuesto; registrar baseline y carencias de recepción real.
2. Integrador: inventariar último producto, preparar namespace/colocaciones y
   medición comparable, gates y QA real; conservar favoritos/visor/compartir y
   SDK/consentimientos de ramas ajenas. Una cola Flutter; nada de construir rama vieja.
3. Operador orgánico: inventario, deduplicación, piloto60 y propuesta de textos;
   validar visibilidad y atribución antes de congelar confirmatorio.
4. Analista: cerrar cálculo de potencia a partir del piloto/baseline; preregistrar
   tamaño, calendario, asignación y pruebas. No prometer un plazo de significancia.
5. Operador: ejecutar sólo brazos medibles y congelados, un contacto pertinente
   por autora; detener una acción ante bloqueo/rechazo en vez de evadirlo.
6. Analista: cortes operativos sin declarar ganadores; análisis maduro final,
   confirmación independiente y sólo después siguiente ola.

El usuario pidió documentación/diseño y definió el comparador. Este corte no
publica comentarios nuevos, modifica anuncios, crea automatizaciones, despliega
trackers ni habilita iOS CPP. Deja acciones concretas para preparar el experimento
sin fingir que sus requisitos técnicos o la significancia ya existen.
