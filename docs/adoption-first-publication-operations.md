# Seguimiento de la primera publicación de adopción

En **Admin → Pendientes de revisión → Primera publicación de adopción**,
la tarjeta resume las cuentas creadas en los últimos siete días. Los conteos
muestran cuentas que conservaron una publicación, tienen foto guardada,
registraron un envío y llegaron a publicar. La cola de primeras revisiones
abarca todo Dopmi y muestra la edad de la más antigua. Usa **Actualizar
pendientes** para volver a consultar. Si falla la consulta, la tarjeta muestra
que los datos están indisponibles.

El aviso de cámara y galería aparece si cinco o más cuentas del periodo
conservan un borrador de al menos 24 horas, sin foto ni envío registrado.
Es un criterio provisional
para investigar con una muestra pequeña. Si aparece, revisar el flujo de
fotos con una cuenta de prueba y comparar los resultados de selección,
procesamiento, subida y guardado. Si aumenta la antigüedad de la cola, abrir
la revisión de adopciones desde la tarjeta.

En la [exploración de GA4 Producción](https://analytics.google.com/analytics/web/#/analysis/a273408500p561295536/edit/oKrPe-LmQQO0_c3Hgr051w),
abre **DopMi · Actividad y adopciones**, compartida con quienes ya tienen
acceso a la propiedad. La pestaña de **actividad medida (no cuentas)** cruza
**App version** y **Platform** con seis métricas de actividad. Las pestañas
de pasos y errores de publicación conservan sus nombres de eventos y las
métricas configuradas, incluida **Total users**. La tabla siguiente mantiene
el mapa de señales del formulario.

**Clientes corregidos · 2.3.10** conserva esas seis métricas con filtro exacto
**App version = 2.3.10**. Separa las instalaciones corregidas del histórico
afectado. El rango relativo original termina el día anterior; al crear la vista
25/oct–21/nov aún no podía contener esta versión del22/nov. «Sin datos» describe
esa combinación de versión/fechas, no la actividad de todo Dopmi. Los días
completos se comparan después de su procesamiento; la disponibilidad de la build
y una llamada al SDK no acreditan recepción en los informes.

Las cuentas de Auth son registros del producto; los usuarios activos de GA
describen actividad medida en una ventana concreta. **Total users** tampoco
es un conteo de cuentas ni garantiza personas únicas o deduplicación entre
dispositivos. Los eventos pueden repetirse en un mismo recorrido y una
misma **App version** puede agrupar varios builds. Comparar siempre periodo,
plataforma y versión, sin forzar igualdad con las altas del backend.

La pestaña de **valor confirmado** filtra exclusivamente
`adoption_contact_created`, `rescuer_first_reply` y
`adoption_marked_adopted`. Al corte del 22 de noviembre todavía no hay
eventos entrantes de estos tres nombres. La configuración del informe no
acredita recepción de eventos ni distribución del código nuevo.

| Paso | Eventos para revisar |
| --- | --- |
| Apertura | `adoption_form_opened`, `adoption_draft_resumed` |
| Foto principal | `adoption_main_photo_camera`, `adoption_main_photo_gallery`, `adoption_photo_attached` |
| Dónde se detuvo una foto | `adoption_photo_prep_failed`, `adoption_photo_picker_cancelled`, `adoption_photo_picker_denied`, `adoption_photo_picker_failed`, `adoption_photo_read_failed`, `adoption_photo_process_failed`, `adoption_photo_upload_failed`, `adoption_photo_attach_save_failed` |
| Avance | `adoption_details_reached`, `adoption_preview_reached` |
| Envío | `adoption_submit_attempted`, `adoption_submit_validation_failed`, `adoption_submit_save_failed`, `adoption_submit_transition_failed`, `adoption_submit_accepted` |

Una visita puede tener varios intentos. Los inicios distinguen cámara y
galería, y los conteos de resultados agrupan ambas fuentes. Una cancelación
se registra cuando el selector devuelve un resultado vacío. Los errores de
permiso requieren un código explícito del sistema. En la 383, el primer
**Continuar** se habilita al completar todos los requisitos. En el candidato
siguiente, tocar **Continuar** muestra el primer requisito pendiente y lleva
al campo correspondiente. Si hay foto pero el paso no avanza, los eventos
ubican la caída en ese paso. Hace falta observar el recorrido para identificar
el requisito concreto. Una foto se registra como adjunta cuando su
referencia ya se guardó. El envío aceptado requiere respuesta del servidor
con estado en revisión. Todos los eventos son nombres fijos.

## Corte del 22 de noviembre de 2026

La lectura actual del backend registra **393 cuentas Auth**. Sus preferencias
vigentes son **31 ON, 297 OFF y 65 sin elección registrada**. Este corte
describe el estado actual del consentimiento, no su cobertura histórica ni
cuántas personas estuvieron activas en GA durante otro periodo.

Para el 25 de octubre al 21 de noviembre, GA mostró **40 usuarios activos,
40 sesiones y 0 usuarios recurrentes**. Esas cifras no son una base fiable
para inferir personas únicas, regreso o retención: una consulta de
consentimiento fallida podía borrar la identidad de Analytics incluso al
reanudar la misma cuenta con ON previo. La corrección está **verificada en CI y
distribuida como Android437/iOS438 (2.3.10)**, con Android probado físicamente y
las dos tiendas en revisión pública. La incertidumbre pausa la colección y
conserva sólo la identidad del mismo propietario y entorno; un OFF explícito
o confirmado, el cambio de propietario o la salida real siguen borrándola.
No se unen cuentas ni se envía el identificador de la cuenta a Firebase.

La identidad de informes de GA quedó en **Observed**; el modelado no está
disponible. Este ajuste no reconstruye identificadores, no recupera eventos
omitidos y no repara los conteos históricos. Tampoco convierte los usuarios
medidos en una deduplicación de personas entre dispositivos.

| Señal nueva | Resultado confirmado que representa |
| --- | --- |
| `adoption_contact_created` | El servidor creó un contacto nuevo y su conversación. Reabrir una conversación existente no cuenta como otro contacto. |
| `rescuer_first_reply` | El servidor guardó la primera respuesta del rescatista a un contacto previo en esa conversación. Un saludo automático o un reintento del mismo mensaje no acredita otra respuesta. |
| `adoption_marked_adopted` | El servidor guardó por primera vez el cierre declarado como adopción realizada. No acredita que Dopmi causó la adopción ni que la familia se encontró por la app. |

Los tres nombres requieren éxito del servidor y consentimiento ON vigente
antes del despacho y al aceptar la respuesta, para el mismo propietario,
entorno y revisión. Sólo se envía el nombre, sin payload. Una respuesta sin
señal, un contrato legado o una elección ON posterior no reconstruyen una
conversión. `contact_started` conserva su función auxiliar histórica y no
equivale a un contacto nuevo confirmado.

Contacto y respuesta pertenecen a actores distintos. Esta tabla no es un embudo
de una sola persona: dividir respuestas de un periodo entre contactos del mismo
periodo puede mezclar conversaciones y tiempos distintos. Una tasa de respuesta
requiere una cohorte de conversaciones y su ventana de seguimiento en el backend.
Los conteos GA son los resultados recibidos con medición consentida; una respuesta
perdida o una entrega fallida al SDK puede omitir una señal. No son un censo de todas
las operaciones guardadas.

Al corte, la validación local reúne **180 pruebas Flutter**, análisis sin
incidencias y **23 pruebas en PostgreSQL real**; la revisión independiente
cerró sin P1/P2. CI todavía no se ha iniciado. Esta evidencia local no
acredita distribución, aplicación remota del contrato ni llegada de las
señales nuevas a GA.

## Corte del lanzamiento

El 12 de noviembre de 2026 a las 19:22 de Ciudad de México, las altas
desde el 11 sumaban 40 cuentas, de las cuales 12 estaban en modo Rescatista
al consultar. Había siete borradores activos, seis de cuentas en ese modo,
sin foto adjunta ni objeto de foto guardado en su ruta de Storage. Al
aplicar a los campos guardados las reglas del servidor, a dos borradores
sólo les faltaba foto y a los otros cinco también les faltaba historia.
Cero envíos registrados y cero primeras revisiones pendientes. Los
borradores archivados quedan fuera de este corte.

La 381 interna cargó fotos desde cámara y galería en un Samsung. La 383
interna confirmó en DebugView apertura, selección de fuente, cancelación,
adjunto guardado y reapertura. La vista compartida de GA4 todavía no
mostraba actividad del formulario al consultar el 12 de noviembre.
La evidencia ubica la caída antes de guardar una foto para los siete
borradores activos. El motivo de cada abandono requiere eventos de uso
real o una sesión observada.

A las 19:34 de Ciudad de México, la preferencia de analítica sincronizada
figuraba activa para los siete autores con borrador, para siete de las
doce cuentas en modo Rescatista y para nueve de las cuarenta altas. Es
una lectura de la preferencia actual. Los eventos dependen de la versión
y de la configuración del dispositivo en el momento de la acción.

## Cómo convertir señales en cambios

| Señal repetida | Qué comprobar y qué cambiar |
| --- | --- |
| Personas rescatistas sin apertura registrada | Observar si encuentran **Publicar** y si llegan al formulario. La medición actual comienza al abrir el formulario. |
| Aperturas sin elegir cámara o galería | Observar si se encuentra el control de foto y si la persona tiene una imagen preparada. Probar una entrada de foto más clara si el control pasa inadvertido. |
| Selecciones que terminan en cancelación | Ver cómo se entiende la confirmación del selector y si queda claro cómo volver a intentar. Cambiar la indicación sólo si se observa confusión. |
| Fallos repetidos de procesamiento, subida o guardado | Reproducir la etapa con el mismo sistema y tipo de archivo. Corregir la falla antes de cambiar requisitos. |
| Fotos guardadas con poco avance al segundo paso | Revisar qué requisito detiene el botón y si la persona encuentra cómo completarlo. |
| Envíos aceptados con una cola creciente | Revisar el tiempo hasta la primera respuesta de moderación. |

Usa la primera ficha enviada dentro de siete días del alta como resultado
de producto cuando se comparen cohortes con siete días completos. Mientras
la muestra sea pequeña, reporta conteos junto con la ventana y las pruebas
observadas. Guardar un cambio por hipótesis y volver a medir ese paso.
Las pruebas internas de DebugView sirven para comprobar la instrumentación.
Conviene comprobar el filtro de tráfico de desarrollo antes de usar datos
de GA4 como evidencia de usuarios.

### Sesión observada de diez minutos

Invita a dos personas que tengan una mascota lista para adopción y que
acepten que observes el recorrido en su propio teléfono. Pide a una que
retome su borrador y a la otra que encuentre **Publicar** por su cuenta.
Si alguien se detiene, pregunta «¿Qué esperabas que pasara?» y «¿Qué harías
ahora?». Anota el dispositivo, la versión, el último paso completado y la
dificultad en tus propias palabras. Registra sólo la dificultad y el paso,
omitiendo nombres, fotos, direcciones y texto de la ficha. Si el obstáculo
es una foto, anota si abrió el selector, encontró una imagen y volvió al
formulario con ella. Pide que avise antes de enviar a revisión para
confirmar que la ficha se debe publicar. Una sesión ayuda a formular una
corrección. Volver a probar el paso con otra persona ayuda a ver si la
corrección resuelve el mismo problema.

Para un piloto de analítica de producto, PostHog permite
[embudos](https://posthog.com/docs/product-analytics/funnels),
[alertas](https://posthog.com/docs/alerts),
[suscripciones a reportes](https://posthog.com/docs/product-analytics/subscriptions)
y [grabación para Flutter](https://posthog.com/docs/session-replay/installation/flutter).
Codex puede consultar los reportes con el
[conector de PostHog](https://posthog.com/docs/model-context-protocol/codex)
y [acceso acotado de lectura](https://posthog.com/docs/api/scopes).
Su [plan gratuito](https://posthog.com/pricing) incluye un millón de
eventos y cinco mil grabaciones al mes. El piloto recomendado empezaría
con eventos explícitos y grabación apagada, una vez aprobados el proveedor
y el alcance del consentimiento. La prueba de grabación, si se necesita,
usaría cuentas y datos sintéticos antes de exponerla a usuarios.

**Comprobación de la siguiente versión.** En DebugView de Firebase para DEV,
con una cuenta controlada que activó medición, abre Publicar, cancela cámara,
selecciona una foto en galería y verifica el adjunto al reabrir el borrador.
Completa los campos, llega a la vista previa y envía a revisión en DEV.
Comprueba los eventos correspondientes y repite con la medición apagada
para confirmar su ausencia. En Admin, actualiza la tarjeta y comprueba que
la consulta del servidor incluye el envío aun cuando la medición esté apagada.
