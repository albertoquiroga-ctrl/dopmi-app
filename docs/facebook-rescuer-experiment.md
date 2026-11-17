# Experimento de adquisición de rescatistas en Facebook

Comparamos dos invitaciones para personas que ya dan una mascota en adopción en Monterrey y su área metropolitana. La medida principal son las primeras fichas enviadas a revisión por cuentas nuevas de Android atribuidas a la campaña por cada 100 comentarios asignados. La atribución es automática y requiere que la persona elija **Analítica de uso**. El reporte devuelve agregados.

Los comentarios anteriores se publicaron con el enlace general, en días distintos y con diferentes grupos. Sirven para revisar el tono y la moderación de Facebook. Su efecto sobre la primera ficha queda sin medir.

## Mensajes y perfiles

- **A · Alcance.** «Hola, [nombre]. Si [mascota] sigue en adopción, en DopMi puedes publicar su ficha para que la vean personas que están buscando adoptar».
- **B · Aprovechar el aviso.** «Hola, [nombre]. Si [mascota] sigue en adopción, en DopMi puedes armar su ficha con las fotos y la descripción que ya preparaste».
- **Cierre común.** «Abre [enlace] para instalar DopMi. En modo Rescatista, ve a Publicar → Dar en adopción y envía la ficha a revisión».

Personalizar el nombre, el rasgo de la mascota y la concordancia. Mantener la misma invitación, pasos y formato dentro de cada variante.

| Perfil | Mensaje A | Mensaje B |
| --- | --- | --- |
| Personal | [Descarga](https://www.dopmi.org/descargar/personal-a) | [Descarga](https://www.dopmi.org/descargar/personal-b) |
| DopMi | [Descarga](https://www.dopmi.org/descargar/pagina-a) | [Descarga](https://www.dopmi.org/descargar/pagina-b) |

## Primera ronda

1. Seleccionar avisos públicos, recientes y vigentes, de grupos donde puedan participar ambos perfiles. Elegir casos antes de ver la asignación. Confirmar que cada mascota y autor tengan una sola entrada aunque aparezcan en más de un grupo.
2. Formar un grupo completo de cuatro casos comparables antes de sortear. Elegirlos de un mismo grupo de Facebook y franja horaria. Emparejar por especie cuando sea posible. Sortear las cuatro combinaciones y registrar la asignación antes de publicar.
3. Cerrar el reclutamiento al asignar el caso 24 o al cumplirse 14 días, lo que ocurra primero. Registrar hora prevista, combinación, estado de publicación, moderación y retiro. Mantener cada asignación en el denominador, incluso si Facebook bloquea el envío, lo deja pendiente o vence el plazo. Mostrar también el rendimiento por comentario publicado.
4. Fijar la apertura y el cierre de clics antes de publicar, con hora local y su equivalente UTC. Excluir las pruebas del equipo. Contar las fichas enviadas dentro de los 14 días posteriores a cada clic elegible y leer el corte 14 días después de cerrar la ventana de clics. Medir aparte las respuestas de autores por cada 100 asignaciones dentro de los 14 días desde la hora prevista. Cada autor cuenta una vez si expresa interés en DopMi o solicita ayuda para publicar. Registrar también aprobaciones, cuentas atribuidas e interacciones con la ficha de Play cuando estén disponibles.
5. Usar esta ronda para validar la medición, estimar el volumen inicial y registrar el tiempo de moderación. Conservar los avisos y las respuestas en la bitácora privada. Cada variante en los datos agregados representa un perfil y un mensaje. Un enlace compartido puede traer varias cuentas.

## Comparación confirmatoria

Antes de abrir una ronda confirmatoria, habilitar un identificador opaco por aviso en el enlace, con la misma apariencia y comportamiento en las cuatro combinaciones. El identificador viaja automáticamente. La bitácora privada lo relaciona con el bloque aleatorio y la asignación. Evitar guardar URL de Facebook, nombre, IP, identificadores de dispositivo o contenido de la ficha en la atribución. Una nueva ronda usa identificadores propios porque los enlaces previos siguen circulando. Si una persona ve varios comentarios, su cuenta puede quedar atribuida a uno de esos enlaces. Registrar esa limitación al interpretar los resultados.

Fijar de antemano el mínimo efecto que justificaría cambiar el mensaje o el perfil y calcular la muestra con el nivel observado en el piloto. Comparar dos efectos principales, A frente a B promediando ambos perfiles, y perfil personal frente a DopMi promediando ambos mensajes. Usar una prueba bilateral que respete el sorteo por bloque, con corrección de Holm para las dos comparaciones y un nivel familiar de 5 %. Mostrar diferencia por cada 100 asignaciones, intervalo de confianza y números absolutos. Examinar la interacción mensaje y perfil como exploratoria. La conclusión estima el efecto de asignar un mensaje o perfil sobre las fichas atribuibles en Android en los grupos y el público medible de la ronda.

Para dimensionar la prueba, una comparación de 2 frente a 5 primeras fichas por cada 100 asignaciones requiere aproximadamente 740 asignaciones por lado, 1,480 en total con reparto equilibrado. Es un ejemplo de planeación bajo conteos Poisson independientes, potencia del 80 % y alfa bilateral de 2.5 % por comparación. La muestra real puede cambiar por la dispersión y el parecido de casos dentro de los grupos. Como referencia para la respuesta del autor, un aumento de 10 % a 25 % requiere alrededor de 244 asignaciones totales bajo independencia y los mismos parámetros. La respuesta del autor y la primera ficha son resultados distintos.

Hacer una lectura confirmatoria al completar la muestra y la ventana fijadas. Declarar una ventaja accionable si el intervalo ajustado por las dos comparaciones queda por completo más allá del mínimo útil en la dirección observada. Declarar equivalencia práctica si queda por completo dentro de los límites de ese mínimo. Los demás resultados son inconclusos. Calcular la muestra confirmatoria con el criterio de decisión elegido. Si se prueba otro mensaje, conservar un control y cambiar un elemento en la siguiente ronda.

[Diseño aleatorio por bloques de NIST](https://www.itl.nist.gov/div898/handbook/pri/section3/pri332.htm)

## Atribución y puesta en marcha

- **Android.** Google Play Install Referrer entrega la variante y la fecha del clic. El servidor registra una sola fuente por cuenta con consentimiento y mide el primer envío. Las cuentas sin consentimiento, instalaciones de versiones anteriores y referencias perdidas quedan fuera de la medición automática.
- **iPhone.** Los cuatro enlaces abren la ficha mexicana de App Store. Un enlace de campaña de App Store Connect permitiría ver descargas agregadas. La primera ficha se mide en Android.
- **Play Console.** La ficha de la tienda distingue campañas Android por UTM. Sus interacciones son una señal del interés por instalar. La atribución de la primera ficha se lee en DopMi.

El [reporte interno](../tools/verification/android-rescuer-acquisition.sql) acumula todas las fechas. Para el piloto, filtrar `source.clicked_at >= apertura` y `source.clicked_at < cierre` en el CTE `eligible` con límites explícitos en UTC. Leer después de que madure toda la ventana. El reporte refleja el consentimiento registrado en el servidor al momento de la consulta. Las primeras fichas observables de cuentas existentes se muestran aparte.

Al 16 de noviembre, las ocho comprobaciones HTTP de los cuatro enlaces con Android y iPhone devolvieron la tienda esperada. Android conserva las cuatro variantes. El build 389 se publicó en Play interno con DEV y quedó pendiente de una prueba instalada con una cuenta nueva. El Samsung conectado muestra el build 395 instalado desde Google Play. Los builds 393 y 395 carecen de la integración. El último estado registrado de Play mostró 393 pública y 395 en revisión de Producción. La validación instalada requiere un candidato DEV vigente y una instalación nueva desde cada escenario de prueba. Comprobar consentimiento activado y desactivado y un solo primer envío después de corregir y reenviar. Para abrir la ronda de fichas, comprobar el mismo recorrido en una versión disponible al público y verificar el contrato de producción.

[Google Play Install Referrer](https://developer.android.com/google/play/installreferrer) · [Métricas de Play Console](https://support.google.com/googleplay/android-developer/answer/9859173) · [Campañas de App Store Connect](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links) · [Registro del build 389](https://github.com/albertoquiroga-ctrl/dopmi-app/commit/cb812ae5) · [Último corte de Play](https://github.com/albertoquiroga-ctrl/dopmi-app/blob/82123869dc054015f78bd3bbf9f3c0041c343794/docs/progress.md)
