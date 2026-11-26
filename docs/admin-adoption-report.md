# Reporte administrativo de adopciones — 25/11/2026

Solicitud y decisiones del titular en esta conversación: tabla de todas las mascotas actualmente publicadas en adopción, perros y gatos; **una persona única por mascota** que entra al detalle, favoritos que siguen guardados, personas que contactaron y conversaciones con una primera respuesta de su rescatista. Sólo adopciones en este alcance. No incluye casos de apoyo ni denuncias de moderación.

26/11/2026: el titular confirmó que el contador funciona y cerró su revisión.
La consulta posterior sobre privacidad se resolvió como investigación separada:
[datos reales y requisitos de Apple/Google](adoption-report-consent-review-20261126.md).
No se cambió consentimiento, recopilación o producto por esa consulta.

## Comportamiento y aceptación

- Sección **Reportes**, accesible desde la navegación administrativa existente. Buscar por mascota/rescatista, filtrar especie y paginar en servidor de20en20. Muestra todas las publicaciones vigentes de cuentas activas, incluyendo las que tienen cero actividad.
- Detalle: identidad de la cuenta y publicación, deduplicados en PostgreSQL entre dispositivos/reintentos. Sólo después de mostrar el detalle real, con consentimiento vigente. No cuentan tarjetas, precargas, preview, propietario ni visitantes sin cuenta. Un contador nuevo con fecha de inicio explícita, sin rellenar históricos desde impresiones. Revocar elimina las observaciones propias.
- Favoritos: filas actuales de otras personas; quitar un favorito baja el contador. No es acumulado de pulsaciones.
- Contactos: personas con al menos un mensaje por esa publicación, incluido el saludo transaccional que confirma la acción de contacto. Crear un hilo vacío no cuenta. Hilos cerrados conservan su contribución.
- Primeras respuestas: una por conversación con al menos una respuesta humana del responsable posterior al contacto. Leer no cuenta, ni respuestas posteriores/reintentos. La clasificación servidor actual se respeta; para registros anteriores sin clasificación se usa remitente, origen y existencia de un contacto previo, sin publicar mensajes ni producir eventos publicitarios retrospectivos.
- RPC exclusivamente administrativa para agregados, con verificación de membresía activa en cada llamada y registro de consulta. No concede permisos de lectura de conversaciones. Tablas nuevas privadas con RLS y sin acceso directo del cliente. Falla/carga/ausencia de conexión no se representan como ceros.

Ejemplo sintético de aceptación: Luna con12personas que abrieron detalle,4favoritos actuales y3personas que escribieron, de las cuales2recibieron respuesta, muestra **12 / 4 / 3 / 2**. Si una de esas personas abre el detalle otras cinco veces y recibe otras tres respuestas, las cifras permanecen iguales. Si quita su favorito, favoritos pasa a3.

## Base y límites operativos

Rama aislada codex/adoption-metrics-20261125 desde61fa88d40f0088b84a37c7369da7fb4950b18ef6, conservando las fuentes posteriores conciliadas por la exploración de base. El checkout original1094e29c con cambios ajenos se preserva. Referencia Irlanda observada d9f9aa430ffc4b1d9df76e49e7efbe9f0e5cae1c; el reporte usa el patrón del panel actual, sin absorber nuevos alcances del mock. Paquete separado codex/admin-report-context-20261122 trata moderación y no se activa aquí.

El titular autorizó la activación y la versión interna con «Dale». El esquema y el panel ya están publicados y verificados; el cliente anterior no envía observaciones del detalle. Estado del candidato móvil y resultados finales en progress.md.

## Demostración y activación

PROD: migración remota **20261126030428 / adoption_detail_reports_20261125**, correspondiente al archivo20261125222901, aplicada una sola vez. Postflight independiente: historia76→77 con prefijo y funciones anteriores intactos, SQL exacto, RLS/ACL y estado inicial correctos. [Auditoría](migration-history-audit.md#25112026-cdmx--reportes-de-adopción-en-prod). No repetir SQL ni reparar timestamps.

Panel [dopmi-app.vercel.app](https://dopmi-app.vercel.app), deploy **dpl_F9K8wePuPjZp7hpGgmos67wdLHr3** desde **a8601c257a133a96dd2053a34eb182ea4ddd1e8b**, READY y alias confirmado. HTTP200/bundle PROD comprobados. Demo real con sesión administrativa:21adopciones, paginación20+1, filtro Gatos4 y búsqueda de una publicación con cifras0/9/4/2; sin leer mensajes privados ni crear actividad de prueba. Captura privada `.tools/report-activation/production-report.jpg`.

Cliente móvil integrado **280b3186d15db26d5641847cff9acdc694614602**, tag **codex/adoption-report-20261125-v1**, CI45746827546 cuatroSUCCESS. **Android2.3.12(448) disponible en Google Play interno**, comprobado en Console (release238) y log Publishing internal/completed; Codemagic6b07a763e4b8406fd5893ddc terminó14SUCCESS. AAB/firma registrada/configuración y marcador del nuevo RPC verificados. Conserva los cuatro archivos exactos de la entrega de tienda Rescatista36f8e47f y usa el perfil Android446, con Meta lifecycle opcional explícitamenteOFF y finanzasOFF. No se envió iOS ni se promovió a producción pública. El cliente público anterior aún no envía estas vistas.

Demo ejecutada en navegador con el React real y datos ficticios: Reportes → página2/2 → filtro Gatos11 → búsqueda Luna1 → cifras12/4/3/2. A390px la tabla permite llegar por teclado a las últimas columnas sin desbordar la página. Capturas privadas en `.tools/report-desktop.jpg` y `.tools/report-narrow.jpg`; no son datos remotos ni aceptación del titular.

Recorrido propuesto tras la publicación: abrir **Reportes** con una cuenta administrativa → localizar una adopción publicada → contrastar los cuatro agregados. Con una cuenta controlada y cliente actualizado, abrir dos veces el detalle debe sumar una persona; guardar/quitar debe subir/bajar favoritos; contactar debe sumar una persona; leer no debe sumar respuesta y responder varias veces debe sumar una primera respuesta. Retirar consentimiento debe eliminar la observación del detalle. Estas acciones de QA instalada aún no se han ejecutado ni se han creado fixtures para ellas.

Señales de problema durante ese recorrido: recargar el detalle aumenta el contador, un favorito retirado sigue contado, o leer/responder otra vez suma una nueva primera respuesta. La demo web descrita arriba sí fue ejecutada; este recorrido instalado sigue propuesto.

Pendiente de aceptación instalada: cliente actualizado → abrir una ficha dos veces → una persona en detalle; retirar consentimiento → se elimina su observación. El teléfono no está conectado al comprobar ADB. La publicación móvil, la moderación pendiente y la configuración financiera conservan sus propios gates.
