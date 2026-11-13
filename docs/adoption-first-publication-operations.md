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

Pide a una persona que ya tenga una mascota lista para adopción que use su
propio teléfono y publique como lo haría normalmente. Deja que encuentre
**Publicar** por su cuenta. Si se detiene, pregunta «¿Qué esperabas que
pasara?» y «¿Qué harías ahora?». Anota el dispositivo y la versión, el
último paso completado y la respuesta en tus propias palabras. Si el
obstáculo es una foto, anota si llegó a abrir el selector, si encontró
una imagen y si volvió al formulario con ella. Pide que avise antes de
enviar a revisión, para confirmar que la ficha se debe publicar. Una
sesión ayuda a formular una corrección. Volver a probar el paso con
otra persona ayuda a ver si la corrección resuelve el mismo problema.

Para un piloto de analítica de producto con alertas y reportes recurrentes,
[PostHog](https://posthog.com/docs/product-analytics/funnels) permite
embudos, [suscripciones a reportes](https://posthog.com/docs/product-analytics/subscriptions)
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
