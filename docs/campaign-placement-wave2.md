# Segunda ola de comentarios MTY — registro prospectivo

22/11/2026, CDMX. El titular pidió ampliar la prueba después de los60 envíos
del [piloto original](campaign-placement-pilot.md). Se fija una segunda ola de
**24 contactos nuevos** antes de enviarlos:6 por cada brazo y12 publicaciones
de gatos/12 de perros. La meta es ampliar evidencia operativa y variación de
contexto;24 contactos adicionales no garantizan significancia estadística.
El diseño siguiente se fijó antes del envío; el cierre operativo y el corte de
resultados comprobados están al final. Enviar comentarios no acredita la QA
física de atribución pendiente.

## Asignación y versiones congeladas

Manifiesto `tools/campaigns/rescuer-wave2-24-v1.json`, SHA256
`c9ae0a81c466d9301a6aaeb6a0a109c5b974f3b9329b345eb03931bd0b1b71a7`.
Experimento servidor `resc_mty_20261122_wave2_v1`; los60 originales conservan
sus tokens, asignaciones, manifiesto y denominadores. No sustituir su comentario
pendiente por otro visible ni reenviar a sus autoras.

| Brazo | Identidad | Texto v1 conservado | Contactos previstos |
| --- | --- | --- | --- |
| R1 | Perfil personal | Beneficio de difusión | 6:3 gatos/3 perros |
| R2 | Perfil personal | Facilidad/gratuidad | 6:3 gatos/3 perros |
| R3 | Página DopMi | Beneficio de difusión | 6:3 gatos/3 perros |
| R4 | Página DopMi | Facilidad/gratuidad | 6:3 gatos/3 perros |

Se conservan las dos plantillas v1 del piloto, la afiliación «Soy parte de
DopMi», oferta gratuita, CTA, descarga directa y formato canónico del enlace.
Sólo se adapta la referencia real a la mascota y la concordancia del plural.
No añadir promesas de adopción, códigos ni acceso previo para descargar.

Semilla22112026, Mulberry32 y Fisher–Yates fijaron el orden de brazos en seis
bloques de cuatro. Cada bloque contiene R1–R4 una vez: bloques1/3/5 gatos y
2/4/6 perros. La especie es un estrato observado, no un tratamiento aleatorio.
No cambiar orden, tokens o texto según respuestas tempranas.

## Selección previa al enlace con el brazo

Buscar publicaciones activas de adopción de MTY/metrópoli de hasta14d al
seleccionar; preferir hasta7d. Aplicar la misma regla de antigüedad a todos
los brazos y guardar fecha original/republicación cuando ambas sean visibles.
Priorizar rescate independiente declarado; mantener separado el particular
que reubica una mascota. Organización, difusión de tercero y autoría desconocida
se registran como tales, sin llamarlas automáticamente rescatistas independientes.
Excluir avisos resueltos, mascotas perdidas sin oferta de adopción, colectas y
casos cuya invitación no corresponda al texto real.

Guardar municipio declarado en el post. Un grupo local, lada o nombre no
confirma ubicación: conservar «desconocido» aparte y excluir ubicaciones
explícitamente ajenas a MTY/alrededores. Respetar reglas, comentarios cerrados,
peticiones de no contacto y límites de participación de Facebook. Para comparar
identidades, ambas deben estar permitidas en el grupo seleccionado.

Antes de enlazar un bloque con sus cuatro brazos, congelar sus candidatas
elegibles en orden de descubrimiento y registrar hora, orden y motivos de
exclusión. Después enlazar ese orden al del manifiesto correspondiente a su
especie. Deduplicar autora y publicación contra los60 anteriores, contactos
históricos y esta ola. Una autora recibe un solo contacto en todo el experimento,
aunque publique en varios grupos. No reemplazar posteriormente asignaciones
malas, comentarios ocultos, rechazados o pendientes.

El operador ya tuvo acceso al manifiesto; **no se acredita ocultamiento de la
asignación ni selección ciega**. Congelar candidatas antes de asociarlas limita
decisiones posteriores, pero no elimina posible sesgo de selección. Registrar
también grupo, tipo de post, especie, fecha, horario, visibilidad y tiempo total
de búsqueda/lectura/envío/seguimiento, sin publicar datos personales en Git.

## Transporte y observabilidad

Cada comentario tiene un token nuevo de32hex y ruta
`https://www.dopmi.org/descargar/piloto/{token}`. El registro privado deriva
experimento, brazo y variante. Para conservar compatibilidad con el cliente
Android público, el transporte mantiene exactamente cuatroUTM:
`facebook`/`organic_comment`/`dopmi_rescatistas_mty_p60_v1`/token.
Ese nombre de transporte compartido no convierte esta ola en los60 originales:
los informes separan por `experiment_id` del registro, nunca sólo por UTM.

iOS usa `ct=resc_mty_wave2_v1_r1`–`r4` con el proveedor público de Apple y
descarga directa; son campañas **agregadas**, sin atribución individual
postinstalación de este token a ficha o mensajes acreditada. No extrapolar
la prueba histórica de personal-a en TestFlight a esta nueva ola. La QA manual
p60 de instalación limpia/cuenta elegible/primera ficha válida sigue pendiente;
pruebas técnicas y HTTP no la sustituyen. No fabricar fuentes o hitos por SQL.

Antes de comentar: comprobar el despliegue público, rutas nuevas Android/iOS,
preservación de rutas anteriores y registro habilitado exacto de los24 tokens.
No reutilizar tokens QA, contactos originales ni enlaces de esta ola como
campañas pagadas. Meta/Google requieren cohortes/origen propios y gasto aparte.

## Resultados y análisis

Conservar todos los envíos/asignaciones y distinguir comentarios visibles,
pendientes, ocultos y eliminados. Resultado principal: cuentas elegibles con
primera ficha original enviada a revisión por token; fichas adicionales,
aprobación, saludo automático, primer mensaje escrito y primera respuesta
propia del rescatista son resultados separados. Un token compartido también
puede captar lectores; no identifica automáticamente a la autora de Facebook.

Reportar las dos olas por separado y, si se agrupan descriptivamente, conservar
ola, especie, grupo, antigüedad y horario. Los primeros60 tuvieron reclutamiento
por especie en momentos distintos; no ignorar esa diferencia. No convertir
tasas por especie del outreach en tendencia natural de la app.

Mantener observabilidad Android consentida aparte de iOS agregado y fuentes
desconocidas. Cero eventos no significa cero clics/descargas ni prueba de fallo.
Respetar336h desde cada clic y bajas de consentimiento; no declarar madura toda
la muestra sólo porque pasaron14d desde el comentario. Los cortes tempranos
sirven para seguimiento, no para elegir ganadores y ampliar sólo el brazo que
parezca funcionar. El piloto ampliado no es un ensayo confirmatorio con
potencia calculada ni prueba concluida contra anuncios pagados.

## Entrega técnica comprobada — 22/11/2026

Landing publicada desde
`9f8cf94430b2f3ed505c5cce2f0ee8cc5fb5c7bb`, despliegue Vercel
`dpl_8qGe9jQLCRFJPgr6vj9pMq4Q8jZw` READY/production. El integrador repitió
la suite completa de landing:47/47PASS. El cambio incorpora el registro nuevo
de forma aditiva; el manifiesto original permanece intacto. Esta ampliación no
modificó código móvil ni produjo otro build.

Baseline HTTP22:34:19UTC y postflight22:35:05UTC conservaron los hashes,
estados y encabezados estables de13 rutas: descarga simple, cuatro variantes
históricas, privacidad/términos/eliminación/soporte y cuatro tokens originales,
uno por brazo. Los24 tokens nuevos pasaron Android con intent y fallback HTTPS
con los cuatroUTM exactos, escritorio200/canonical, iOS302 con `ct` distinto y
proveedor público de Apple, y token desconocido404. Se excluyeron de la
comparación encabezados dinámicos como fecha e identificadores de solicitud.
Evidencia privada en `wave2-20261122/http-baseline.private.json` y
`http-postflight-1795386908712.private.json` dentro del directorio del piloto.

El SQL revisado se ejecutó una vez; readback22:35:30UTC confirma24 etiquetas
nuevas habilitadas,6 por cada brazo y0QA. Guardas dentro de la transacción
cotejaron registro previo y conteos/digests de fuentes, eventos, recibos,
historial y funciones. No se aplicó DDL persistente ni se fabricaron cuentas,
consentimientos, fuentes o conversiones. La comparación bajo snapshot acredita
la conservación por esta transacción; no afirma ausencia de actividad concurrente
de usuarios. Recibos privados: `activation-result.private.json` y
`activation-readback.private.json` en la misma carpeta.

El reporte de lectura es
[`android-campaign-wave2.sql`](../tools/verification/android-campaign-wave2.sql).
Sus24 filas representan etiquetas registradas; por sí solas **no acreditan
comentarios enviados ni exposiciones visibles**. Unir el resultado con el ledger
privado para los denominadores efectivos de asignación, envío y visibilidad.
El cierre de contactos y el corte de resultados están abajo; esta evidencia
técnica no cierra la QA física p60 o la limitación agregada de iOS.

El `operationStartedAt` del ledger es22:35:51UTC, hora de su creación, mientras
que la preparación ya estaba en curso al menos a22:25:30UTC. No usarlo como
inicio completo del trabajo. El intervalo de selección a comprobante puede
incluir esperas de acceso/conexión y no equivale a minutos de labor activa.
Conservar tiempos y límites por separado; no derivar un CAC total o costo de
operación preciso sólo de esos intervalos.

## Cierre de contactos — 22/11/2026 CDMX

Último envío23nov00:57:27UTC, equivalente a22nov18:57:27CDMX.
**24 enviados,22 visibles y2 pendientes**, sin sustituir los pendientes:

| Brazo | Enviados | Visibles | Pendientes | Gatos/perros |
| --- | ---: | ---: | ---: | --- |
| R1, personal-a | 6 | 6 | 0 | 3/3 |
| R2, personal-b | 6 | 6 | 0 | 3/3 |
| R3, pagina-a | 6 | 5 | 1 | 3/3 |
| R4, pagina-b | 6 | 5 | 1 | 3/3 |

Son12 contactos por identidad y12 por especie. Sumados a los60 originales,
hay84 envíos:42 por identidad,21 por brazo y44 publicaciones de gatos/40 de
perros. Esta suma conserva dos cohortes distintas; no es un nuevo ensayo de84
seleccionados bajo un único procedimiento. La visibilidad de cada ola corresponde
a su propio corte, sin afirmar una revisión simultánea de los84.

Auditoría final local23nov01:06:47UTC:24 autores públicos, posts y tokens
distintos contra los índices disponibles; textos, bloques e identidades
conformes,0 discrepancias. No acredita identidad humana entre cuentas diferentes.
Hay14 casos con municipio declarado y10 sin municipio confirmado; estos últimos
no se cuentan como MTY confirmado. La muestra incluye rescate declarado,
particulares que reubican y páginas/equipos con estatus no verificado; no llamarla
«24 rescatistas independientes verificadas». Las fechas de Facebook corresponden
a0–13 días de calendario aproximados; sus horas/zona no están verificadas.
Conservar análisis de sensibilidad por antigüedad y geografía conocida.

Se respetaron cierres de comentarios y reglas contra autopromoción. Los dos
grupos con nuevos pendientes quedaron retenidos para más reclutamiento con
ambas identidades. En uno apareció revisión de participación: se cerró sin
responder preguntas ni unirse. No repetir el comentario ni usar otro perfil
para evitar esa revisión. Un posible caso repetido se excluyó antes de asignar,
sin afirmar que la similitud de fotos demostrara identidad.

Las primeras capturas de seis envíos conservaron «Publicando…» aunque ya había
ID numérico aceptado. Se revisitaron sus URLs sin reenviar, se confirmó mismo
token/ID y se repusieron comprobantes asentados; revisión final01:06:33UTC.
Facebook presentó variación visual pese a conservar el formato de URL: dos de
esas capturas muestran URL completa sin tarjeta y otras cuatro, tarjeta con
miniatura. No declarar presentación idéntica ni tratar esa diferencia observada
como un tratamiento aleatorio de enlace o evidencia de clic.

Ledger privado final SHA256
`9e680926903131479ff8fc11fa282f29c41f069bc7d699c9249543a6be172025`;
el ledger original60 conserva
`d600c33786a6deca699187c5acdde0792f9a72cf14218365d9d4e6690a4510c6`.
Hay24 capturas y un respaldo local fuera de Git en
`C:/Users/betoq/.codex/visualizations/2026/11/12/01a1d1f7-7105-7a10-876f-7fbf39340eea/wave2-20261122-private`.
Se verificaron por hash45 archivos de la carpeta operativa; el manifiesto de
respaldo tiene SHA256
`77b58c90ed4aa9df5bb26bde05acdefeb91fb729984fb34a6d9b49dd56e0ca20`.
Nombres, URLs sociales, IDs y capturas reales permanecen fuera de Git.

## Corte de atribución y siguiente observación

LecturaPROD23nov00:58:58UTC,22nov18:58:58CDMX, separada por experimento y
brazo, conQA aparte: las dos olas tienen0 cuentas Android consentidas retenidas
con colocación,0 primeras fichas,0 aprobaciones,0 recibos de otras mascotas y0
saludos/primeros textos/respuestas propias atribuidos;0 cuentas maduras336h.
Los24 tokens nuevos siguen habilitados,6 por brazo; los60 originales conservan
15 por brazo yQA separada. Recibo de sólo lectura y auditoría en el respaldo
privado. No hubo DML de fuentes/hitos ni DDL para obtener este resultado.

Es ausencia de eventos observables en ese corte, **no cero descargas/clics,
fallo probado ni equivalencia entre variantes**. AnalíticaOFF y cobertura iOS
agregada no se convierten en cero. La QA física p60 permanece pendiente y debe
informar la interpretación de esta ausencia. No se declara significancia,
ganador ni superioridad frente a Meta/Google pagados.

Continuar los cortes previstos23nov/29nov/6dic con madurez individual336h desde
cada clic, moderación y exclusiónQA. No se creó una automatización ni una cuota
diaria. Reportar tanto cuentas únicas con primera ficha como tokens con al menos
una primera ficha, conservando asignados/enviados/visibles como denominadores
distintos. Un comentario puede convertir a varios lectores: cuentas por
comentario es rendimiento, no probabilidad verificada de conversión de la
rescatista contactada; no tratar lectores como contactos aleatorizados nuevos.
Las diferencias por especie, grupo o presentación observada son exploratorias.
