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

En **Firebase Analytics → Eventos**, filtra por plataforma y por la versión
que incluya esta medición. Las señales describen las visitas y los intentos de
personas con medición activada. La inicialización actual de Analytics puede
reiniciar el identificador del dispositivo. Usa conteos de eventos para
diagnóstico y evita usar usuarios únicos entre arranques como denominador.

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
permiso requieren un código explícito del sistema. El primer **Continuar**
se habilita al completar todos los requisitos. Si hay foto pero el paso no
avanza, los eventos ubican la caída en ese paso. Hace falta observar el
recorrido para identificar el requisito concreto. Una foto se registra como adjunta cuando su
referencia ya se guardó. El envío aceptado requiere respuesta del servidor
con estado en revisión. Todos los eventos son nombres fijos.

**Corte de prueba del reporte en Producción.** El 12 de noviembre de 2026 a
las 17:30 de Ciudad de México, el cálculo agregado de siete días devolvió
35 altas, 9 autores con una publicación guardada, 1 autor con foto, cero
envíos y cero primeras revisiones en cola. El cálculo se ejecutó como una
consulta de solo lectura. Storage confirmó dos cargas de fotos con HTTP 200
entre las 17:16 y las 17:39. Los registros de Storage carecen del origen
cámara o galería. La tarjeta requiere publicar el panel y su
función administrativa para consultar esos datos desde Admin.

**Comprobación de la siguiente versión.** En DebugView de Firebase para DEV,
con una cuenta controlada que activó medición, abre Publicar, cancela cámara,
selecciona una foto en galería y verifica el adjunto al reabrir el borrador.
Completa los campos, llega a la vista previa y envía a revisión en DEV.
Comprueba los eventos correspondientes y repite con la medición apagada
para confirmar su ausencia. En Admin, actualiza la tarjeta y comprueba que
la consulta del servidor incluye el envío aun cuando la medición esté apagada.
