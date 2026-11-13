# Piloto de adquisición de rescatistas en Facebook

Decisión del titular del 12 de noviembre de 2026. La atribución debe funcionar automáticamente donde la plataforma lo permita, sin pedir códigos al rescatista. La configuración de **Analítica de uso** sigue siendo voluntaria. Usar la variante en los datos internos y reportar resultados agregados.

## Qué queremos aprender

Comparar dos maneras de invitar a alguien que ya está dando una mascota en adopción en Monterrey o su área metropolitana. Medir primeras fichas enviadas a revisión por cuentas nuevas atribuidas a cada combinación y compararlas por comentario publicado. Reportar también las asignaciones, los primeros envíos observables de cuentas existentes y la aprobación de cada primera ficha atribuida.

Los primeros 12 comentarios (6 del perfil personal y 6 de DopMi) se publicaron antes del diseño del piloto. Sirven para revisar el tono y las respuestas. No tenían enlaces de campaña ni asignación aleatoria.

## Mensajes

- **A · Otro lugar para encontrar familia.** «Hola, [nombre]. Si [mascota] sigue en adopción, en DopMi puedes compartir su ficha en otro lugar donde la gente busca adoptar».
- **B · Aprovechar lo que ya preparaste.** «Hola, [nombre]. Si [mascota] sigue en adopción, puedes usar las fotos y la descripción que ya tienes para armar su ficha en DopMi».
- **Mismo cierre.** «Abre [enlace] para instalar DopMi. En modo Rescatista, ve a Publicar → Dar en adopción y envía la ficha a revisión».

| Perfil | A | B |
| --- | --- | --- |
| Personal | https://www.dopmi.org/descargar/personal-a | https://www.dopmi.org/descargar/personal-b |
| DopMi | https://www.dopmi.org/descargar/pagina-a | https://www.dopmi.org/descargar/pagina-b |

## Asignación

1. Elegir casos públicos, recientes y todavía vigentes. Buscar variedad de colonias, perros y gatos. Agrupar cuatro publicaciones parecidas por grupo o zona y momento del día. Verificar que ambos perfiles puedan participar antes de asignar.
2. Sortear las cuatro combinaciones dentro de cada bloque. Dejar un solo comentario por caso y autor. Si Facebook impide publicar, registrar el impedimento con la combinación asignada.
3. Buscar 24 publicaciones elegibles en la primera ronda, seis por combinación. Mantener el texto y enlace de cada comentario. Registrar fecha, combinación, asignación, envío, retiro y respuestas en una bitácora privada. Leer las respuestas visibles a los 14 días de cada comentario.
4. Contar envíos que ocurrieron en los 14 días posteriores al clic y comparar cohortes que ya completaron esa ventana. Revisar también qué fichas fueron aprobadas. En la siguiente ronda, conservar una variante como control, cambiar un elemento y usar enlaces de una campaña nueva para distinguirla de la anterior. La muestra inicial sirve para verificar la medición y observar señales con los conteos y denominadores visibles.

## Qué podemos atribuir

- **Android.** El enlace envía la variante por Google Play Install Referrer. La versión de Android con esta integración captura la variante y la fecha del clic cuando la cuenta eligió **Analítica de uso**. El servidor registra una sola fuente y mide el primer envío con evidencia de la adopción. Si una cuenta existente retiró y editó una ficha antes de recibir revisión, su estado actual puede carecer de ese antecedente. Las instalaciones de una versión anterior, cuentas sin consentimiento y referencias perdidas quedan sin atribución.
- **iPhone.** El enlace abre la ficha de App Store. Un enlace de campaña válido de App Store Connect permite descargas agregadas por variante una vez alcanzado el umbral de Apple. La App Store no entrega la variante a la cuenta de DopMi. Hasta obtener el token de proveedor, las cuatro rutas de iPhone abren la misma ficha.
- **Lectura del resultado.** La variante identifica la combinación del perfil y el mensaje. Una persona que leyó o recibió el enlace también puede usarlo. La medición no identifica al autor de Facebook ni un comentario individual. No guardar URL de Facebook, nombre, IP, identificadores de dispositivo o contenido de la ficha en la atribución. Los clics al botón de la ficha de Play y las instalaciones son métricas distintas.

## Antes de abrir la ronda

Verificar en producción que cada enlace abre la tienda correspondiente. Probar con una instalación real desde Google Play, con y sin consentimiento, hasta el primer envío a revisión. Conservar el resultado de la prueba aparte del conteo del piloto.

[Google Play Install Referrer](https://developer.android.com/google/play/installreferrer) · [Campañas de App Store Connect](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links)

## Estado de entrega del 12/11/2026

La [ruta de descarga](https://www.dopmi.org/descargar) está publicada en Vercel desde el SHA `e56a6020caad69b3244cb8b55fc6ee37f8b90f09` de la landing. El despliegue `dpl_DP5X7KVS4A8BdDnoYmQxT1KipoAE` está READY. Dieciséis comprobaciones HTTP en el dominio público validaron el salto a cada tienda, las cuatro variantes Android, el selector de escritorio, las vistas previas de Facebook y las rutas existentes. El [PR de la landing](https://github.com/albertoquiroga-ctrl/dopmi-landing-mockup/pull/1) tiene el diff.

La integración de Android parte de la versión pública 2.3.3 (368), fuente `fc1da17a`. El [reporte agregado](../tools/verification/android-rescuer-acquisition.sql) lee variantes, primeras fichas y aprobaciones sin devolver cuentas ni fichas individuales. La migración está aplicada en Supabase DEV. El candidato interno Android 2.3.3 (382) se publicó el 12 de noviembre a las 18:33 de Monterrey, con fuente 3fa7de1d y [CI aprobada](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/43334879392). Google Play Console confirmó el número 382 y que está disponible para testers internos. El recorrido en el teléfono y el token de campaña de App Store Connect siguen pendientes.

Para la aceptación interna, abrir el enlace de una variante en Android → instalar el candidato desde Google Play → crear una cuenta de prueba y activar Analítica de uso → enviar la primera ficha a revisión → comprobar una fila agregada en la variante correcta. Repetir con analítica desactivada, y comprobar que una corrección o reenvío de la ficha original conserva un solo primer envío. Si falta una señal, revisar primero la variante de Play y el consentimiento sincronizado.

El candidato 386 reemplazó al 382 para esta prueba. Integra la rama de Tienda y la medición del formulario en `a4f1bc34`, usa Supabase DEV y está disponible en [Play Internal Testing](https://play.google.com/console/u/0/developers/6135505245902279362/app/4973415797410678796/tracks/4701490604660624893/releases/210/details) desde el 12 de noviembre a las 19:39 de Monterrey. Para medir la ronda pública, Play México debe servir una versión de producción con atribución y Supabase de producción debe tener la migración correspondiente.
