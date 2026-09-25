# Escritura de monto incierta al cruzar aniversario

Instrumento de aceptación, no importado por runtime ni desplegado por defecto.
`guardian-change-loss-fetch.mjs` deja pasar el POST real de cambio de monto y consume
su respuesta antes del SDK. También oculta las lecturas posteriores de esa misma
suscripción cuando ya muestran el monto nuevo, incluso en otras instancias. No
modifica solicitudes, fechas, respuestas Stripe ni registros financieros.

El target debe identificar suscripción, cliente, item, monto nuevo y vencimiento
de hasta 30 minutos. Autorización test exacta, sin Stripe-Account. Sólo POST con key
de cambio Guardián y cinco campos esperados, o GET exacto de la suscripción.
Respuestas ajenas, antiguas, inválidas, no exitosas o mayores de 256 KiB pasan sin
alteración. Los logs sólo registran identificadores técnicos y monto; no objetos
completos, claves ni secretos de cliente.

Antes de desplegar: revisión independiente; confirmar plan test, reloj ready,
monto previo distinto, consentimiento y capacidad del escenario. Conservar los
bundles originales. Integración debe usar fetch normal si target ya venció (no
construir wrapper vencido). Instrumentar todos los consumidores relevantes para
evitar que un worker distinto confirme antes de cruzar el aniversario.

Secuencia pendiente de ejecución real:

1. Preparar reloj antes del próximo aniversario con margen mayor a 120 segundos.
2. Instalar instrumentación temporal y solicitar cambio desde el dispositivo.
3. Comprobar log de POST real consumido, precio nuevo Stripe y solicitud pendiente
   en base con evidencia de mutación; no reescribir estado ni liberar capacidad.
4. Avanzar reloj a través del aniversario, conservando ocultación de confirmación.
5. Retirar instrumentación y comparar bundles. Dejar conciliación normal verificar
   factura del período original, fecha efectiva y monto; comprobar no duplicados.
6. Validar estado/historial móvil. Documentar si el período se omitió por revisión.

Los tests locales comprueban el transporte y su aislamiento. No acreditan pérdida
real, cruce de aniversario ni aceptación integrada. No reutilizar el target para
otra prueba ni dejar el instrumento instalado después de la ejecución.
