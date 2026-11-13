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
abre **Primera publicación**. La vista compartida con quienes ya tienen
acceso a la propiedad muestra conteos de eventos por plataforma. Las señales
describen las visitas y los intentos de personas con medición activada.
Android reutiliza el nombre 2.3.3 para varios builds. El primer corte con
tráfico de clientes debe tomar como referencia la fecha de disponibilidad
pública de la 383. La inicialización actual de Analytics puede reiniciar
el identificador del dispositivo. Usa los conteos para diagnóstico y
evita usar usuarios únicos entre arranques como denominador.

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

## PostHog

La configuración remota queda pendiente de acceso al proyecto de Dopmi.
En el proyecto, desactiva **Session Replay**, **Autocapture** y la
transformación **GeoIP**. En **Settings → Project → General**, configura
**IP data capture** para descartar las IP. El cliente usa captura directa,
envía eventos explícitos con `platform` y `environment`, y pide a
PostHog omitir perfiles de persona y enriquecimiento geográfico.
En **Cuenta y privacidad**, **Medición de publicaciones con PostHog**
empieza apagada y tiene consentimiento propio. El identificador aleatorio
agrupa eventos de un intento en el editor. [Privacidad en PostHog](https://posthog.com/docs/privacy/data-collection)

### Embudo guardado

Guarda **Dopmi · Primera publicación de adopción** en Product Analytics,
con pasos ordenados, últimos 30 días y ventana de conversión de siete días.
Aplica el filtro de evento `environment = production` y desglosa por
`platform` cuando compares Android e iOS.

| Paso | Evento |
| --- | --- |
| Abre o retoma el editor | `adoption_editor_started` |
| Tiene foto principal guardada | `adoption_photo_ready` |
| Avanza a detalles | `adoption_details_reached` |
| Llega a la vista previa | `adoption_preview_reached` |
| El servidor acepta el envío a revisión | `adoption_submit_accepted` |

El embudo cuenta intentos con consentimiento. Una nueva apertura crea otro
intento y retomar un borrador con foto ya guardada cuenta como foto lista.
Usa Admin para las cifras por cuenta y la cola de revisión. [Embudos de PostHog](https://posthog.com/docs/product-analytics/funnels)

### Alertas diarias

Guarda cada consulta como un insight SQL (HogQL). En **Monitor → Alerts**,
selecciona la columna `incidencias`, la última fila y **Has value**.
Suscribe al operador responsable que ya tenga acceso al proyecto. Revisa
el valor calculado y la próxima comprobación desde la alerta.
[Alertas en PostHog](https://posthog.com/docs/alerts)

**Foto principal con fallos sin resolver.** Avisa si `incidencias > 2`.
Cuenta tres o más intentos distintos en las últimas 24 horas con un fallo
de foto y sin foto lista en ese intento. Revisa el evento de fallo y la
plataforma antes de reproducirlo.

```sql
SELECT count() AS incidencias
FROM (
  SELECT distinct_id
  FROM events
  WHERE timestamp >= now() - INTERVAL 24 HOUR
    AND properties.environment = 'production'
    AND event IN (
      'adoption_photo_prep_failed',
      'adoption_photo_picker_denied',
      'adoption_photo_picker_failed',
      'adoption_photo_read_failed',
      'adoption_photo_process_failed',
      'adoption_photo_upload_failed',
      'adoption_photo_attach_save_failed',
      'adoption_photo_ready'
    )
  GROUP BY distinct_id
  HAVING countIf(event = 'adoption_photo_ready') = 0
)
```

**Editor sin envíos aceptados.** Avisa si `incidencias > 0`. Se activa
cuando cinco o más intentos empezaron en los últimos siete días y tuvieron
al menos 24 horas para avanzar, y ninguno de esos intentos llegó a envío.
Revisa el paso con menor avance y compáralo con Admin.

```sql
SELECT if(
  countIf(aperturas > 0) >= 5
  AND countIf(aperturas > 0 AND envios > 0) = 0,
  1,
  0
) AS incidencias
FROM (
  SELECT
    countIf(
      event = 'adoption_editor_started'
      AND timestamp <= now() - INTERVAL 24 HOUR
    ) AS aperturas,
    countIf(event = 'adoption_submit_accepted') AS envios
  FROM events
  WHERE timestamp >= now() - INTERVAL 7 DAY
    AND properties.environment = 'production'
    AND event IN ('adoption_editor_started', 'adoption_submit_accepted')
  GROUP BY distinct_id
)
```

El script [configure-posthog-adoption.py](../scripts/configure-posthog-adoption.py)
muestra la configuración sin red con `python3 scripts/configure-posthog-adoption.py`.
Desde una terminal con `POSTHOG_PERSONAL_API_KEY` en el entorno y acotada
al proyecto, agrega `--apply --region us --project-id ID` para crear el
tablero, el embudo, las consultas y las alertas. Usa `eu` si el proyecto
está en esa región. La clave necesita `dashboard:write`, `insight:write`,
`alert:write` y `user:read`. Las alertas suscriben al titular de la clave.
El script verifica los recursos por nombre y se detiene ante diferencias
o duplicados. Ejecuta una sola instancia por proyecto. Si se interrumpe,
vuelve a ejecutarlo para leer el estado antes de crear lo que falte.
Los ajustes de privacidad se configuran en PostHog.

Para consultar desde Codex,
limita el acceso al proyecto con `insight:read`, `alert:read` y
`query:read`. Agrega `dashboard:read` si se comparte un tablero.
[Conector de PostHog](https://posthog.com/docs/model-context-protocol/codex) · [Permisos de API](https://posthog.com/docs/api/scopes)

### Comprobación de PostHog

1. Con una cuenta controlada en DEV y PostHog apagado, abre **Publicar** y
   toca **Continuar** sin foto. Comprueba que se muestra la indicación y
   que esos pasos no aparecen en la actividad de PostHog.
2. Activa la opción de PostHog y abre el editor de nuevo. Cancela el selector
   de cámara, toca **Continuar**, adjunta una foto de galería, completa la
   ficha y envíala a revisión en DEV. Comprueba los cinco eventos del
   embudo y los eventos de diagnóstico. Deben compartir el mismo código
   aleatorio y estar etiquetados `environment = test`.
3. Retoma el borrador con foto en una prueba separada. Comprueba el nuevo
   código de intento y el paso de foto lista. Apaga la opción antes de
   repetir una acción y verifica que no aparezcan eventos nuevos.
4. Comprueba que la actividad contiene sólo los eventos esperados y los
   metadatos previstos. Verifica que la grabación siga apagada. Ejecuta
   ambas consultas, comprueba sus valores y verifica que el embudo y las
   alertas de producción excluyen los eventos de DEV.

La recepción de eventos y la evaluación de alertas requieren acceso
al proyecto y una compilación configurada. Una carga aceptada por el
endpoint no acredita que el evento ya sea consultable.

**Comprobación de Firebase y Admin.** En DebugView de Firebase para DEV,
con una cuenta controlada que activó medición, abre Publicar, cancela cámara,
selecciona una foto en galería y verifica el adjunto al reabrir el borrador.
Completa los campos, llega a la vista previa y envía a revisión en DEV.
Comprueba los eventos correspondientes y repite con la medición apagada
para confirmar su ausencia. En Admin, actualiza la tarjeta y comprueba que
la consulta del servidor incluye el envío aun cuando la medición esté apagada.
