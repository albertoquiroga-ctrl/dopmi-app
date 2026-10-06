# Swipe: pila natural y contenido unido

## Candidato — 5 de octubre de 2026

Continuación de `codex/design-foundation`, base `c02e5e00a64447f31ca822223ffdcf899d1ce5b7`. Referencia visual de Irlanda: `irlanda/apoyar-detalle-perfil`, SHA `889c096ade9479b348530db7ba169f023b472ab9`.

La tarjeta siguiente ahora permanece completa y centrada detrás: foto, gradiente, texto y controles pertenecen al mismo registro. Las claves tipadas conservan su árbol y proveedor de imagen al pasar al frente. El fondo queda excluido de gestos, foco y semántica.

La saliente mantiene opacidad y termina fuera del viewport con margen de 16 px, sin disminuir el desplazamiento alcanzado. Se conservan reconocimiento de 8 px, umbral de 110 px, salida de 280 ms y retorno de 250 ms. La promoción depende del fin real de animación, con identidad y generación capturadas; favoritos y paginación no bloquean la nueva frontal. Movimiento reducido promueve inmediatamente.

La vista previa sólo observa frames ya decodificados y autorizados. No inicia cargas ni reintentos. Al promoverse conserva el proveedor o comparte la solicitud pendiente; siguen vigentes los dos trabajos anticipados, caché y presupuestos de recuperación del servicio compartido.

## Verificación acotada

Subagentes separados para observación de fotos, pruebas y auditoría independiente. Auditoría inicial del cambio: sin hallazgos materiales; no requirió pasadas adicionales de corrección. Pruebas con JPEGs distintos realmente decodificados cubren adopción→adopción→apoyo→adopción, preservación de State/proveedor, frames intermedios, arrastre largo en ambos sentidos, paginación pendiente, texto ampliado, movimiento reducido y promoción de precarga lista/pendiente sin descarga duplicada.

Los tests observan el primer timestamp posterior a los 280 ms porque Flutter informa finalización cuando el tiempo supera la duración. Esto no añade demora al producto. Los selectores de controles se limitan a la frontal interactiva; la tarjeta de apoyo avanza por gesto.

Gate final, publicación y aceptación instalada pendientes de registrar. No se modifican esquema, permisos, compresión ni pagos. La pantalla independiente de Apoyar permanece fuera del alcance.
