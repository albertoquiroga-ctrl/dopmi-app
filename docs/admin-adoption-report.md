# Reporte administrativo de adopciones — 25/11/2026

Solicitud y decisiones del titular en esta conversación: tabla de todas las mascotas actualmente publicadas en adopción, perros y gatos; **una persona única por mascota** que entra al detalle, favoritos que siguen guardados, personas que contactaron y conversaciones con una primera respuesta de su rescatista. Sólo adopciones en este alcance. No incluye casos de apoyo ni denuncias de moderación.

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

La implementación local no aplica SQL remoto ni publica el panel ni un binario. Publicación y recorrido instalado requieren su evidencia y autorización vigente. La app instalada anterior no envía observaciones del detalle. Estado y resultados finales se registran en progress.md.
