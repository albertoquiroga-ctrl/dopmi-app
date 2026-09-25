# Pérdida de respuesta en transporte — instrumento local

`guardian-response-loss-proxy.mjs` prepara el caso pendiente de H5. No se importa
en funciones desplegadas ni se expone al cliente público. Sus pruebas utilizan
dos servidores TCP de loopback; **no acreditan todavía una escritura Stripe real**.

El instrumento escucha exclusivamente en 127.0.0.1 y un puerto efímero. Su
upstream real está fijado a HTTPS api.stripe.com; la única alternativa admitida
es HTTP 127.0.0.1 para fixtures locales. Exige una clave test exacta y permite un
solo POST con ruta e idempotency key predeterminadas. Al consumir una respuesta
2xx completa del upstream destruye la conexión del cliente antes de enviarle
bytes de respuesta. Las respuestas de error se entregan normalmente. Desde el
primer POST bloquea cualquier segundo POST, incluso concurrente: no autoriza
reintentos financieros. Sólo las rutas GET explícitas pueden usarse para leer
la evidencia de recuperación. No sigue redirecciones.

La evidencia conserva únicamente método, ruta, status, Request-Id, ID del objeto,
hora y señal de descarte. No imprime ni guarda la clave, cuerpos, datos de tarjeta
o respuestas completas. El proceso tiene credenciales en memoria: no publicar
el puerto, no registrar tráfico y cerrar el instrumento al terminar.
El plazo absoluto por petición es de 20 segundos como máximo, también para un
upstream que siga enviando bytes. El cierre destruye las conexiones activas en
ambas direcciones. Las consultas GET con filtros o expansiones deben figurar con
su query exacta en la lista permitida; no se autorizan variantes implícitas.

## Ejecución local comprobada

Desde la raíz:

```sh
node --test tools/verification/guardian-response-loss-proxy.test.mjs
```

Comprueba pérdida TCP después de aplicar una escritura en el fixture, recuperación
por lectura, exclusión de escrituras concurrentes/repetidas, rechazo de rutas y
credenciales no autorizadas y ausencia de evidencia falsa ante errores upstream.
También forma parte de `npm test` de tools/verification.

## Requisitos para la aceptación Stripe pendiente

1. Preparar un escenario aislado y legítimo, con consentimiento y RPC reales.
   No usar el ciclo de expiración natural en curso ni desactivar Cron/webhooks
   compartidos. La escritura incierta al cruzar aniversario requiere exclusión
   del escenario frente a otros procesadores; aún no está preparada.
2. Obtener credenciales test por el mecanismo seguro del ejecutor, nunca por chat
   ni argumentos de shell. No usar la clave de producción. El conector Stripe
   ejecuta sus propias peticiones: no permite interceptar el SDK del servicio.
3. Configurar el cliente Stripe del ejecutor local para este puerto y desactivar
   sus reintentos automáticos, conservando la versión API del runtime. Validar
   esta configuración contra la versión instalada antes de ejecutar. Inyectar
   ese cliente en el módulo de servicio de producción, sin modificar dicho módulo.
4. Fijar POST/ruta/idempotency key del objeto acordado y GETs de recuperación.
   No disparar una operación de escritura adicional desde el proxy.
5. Ejecutar una vez, guardar el fallo observado por el servicio y la evidencia
   limitada del proxy. Consultar Stripe independientemente por Request-Id/objeto.
6. Reanudar la conciliación normal con referencias persistidas, acreditar un solo
   efecto, importes, autorizaciones, fechas y ausencia de duplicados. No editar
   estados, leases o contadores para fabricar incertidumbre.

La pérdida móvil→Edge y la pérdida Edge→Stripe son alcances diferentes. Este
instrumento prepara la segunda frontera. Un test local verde, una excepción
simulada o un reenvío de webhook no cierran ese recorrido integrado.
