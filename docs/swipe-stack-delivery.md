# Swipe: pila natural y contenido unido

## Candidato — 5 de octubre de 2026

Continuación de `codex/design-foundation`, base `c02e5e00a64447f31ca822223ffdcf899d1ce5b7`. Referencia visual de Irlanda: `irlanda/apoyar-detalle-perfil`, SHA `889c096ade9479b348530db7ba169f023b472ab9`.

La tarjeta siguiente ahora permanece completa y centrada detrás: foto, gradiente, texto y controles pertenecen al mismo registro. Las claves tipadas conservan su árbol y proveedor de imagen al pasar al frente. El fondo queda excluido de gestos, foco y semántica.

La saliente mantiene opacidad y termina fuera del viewport con margen de 16 px, sin disminuir el desplazamiento alcanzado. Se conservan reconocimiento de 8 px, umbral de 110 px, salida de 280 ms y retorno de 250 ms. La promoción depende del fin real de animación, con identidad y generación capturadas; favoritos y paginación no bloquean la nueva frontal. Movimiento reducido promueve inmediatamente.

La vista previa sólo observa frames ya decodificados y autorizados. No inicia cargas ni reintentos. Al promoverse conserva el proveedor o comparte la solicitud pendiente; siguen vigentes los dos trabajos anticipados, caché y presupuestos de recuperación del servicio compartido.

## Verificación acotada

Subagentes separados para observación de fotos, pruebas y auditoría independiente. Auditoría inicial del cambio: sin hallazgos materiales; no requirió pasadas adicionales de corrección. Pruebas con JPEGs distintos realmente decodificados cubren adopción→adopción→apoyo→adopción, preservación de State/proveedor, frames intermedios, arrastre largo en ambos sentidos, paginación pendiente, texto ampliado, movimiento reducido y promoción de precarga lista/pendiente sin descarga duplicada.

Los tests observan el primer timestamp posterior a los 280 ms porque Flutter informa finalización cuando el tiempo supera la duración. Esto no añade demora al producto. Los selectores de controles se limitan a la frontal interactiva; la tarjeta de apoyo avanza por gesto.

La suite completa del candidato `7cf8202d2a64c0fb9d4eb387dc987c512f2c62b7` pasó en Codemagic: **877 pruebas**, análisis limpio. El intento previo `6ac46136fcdf2ca4f34d2906` fue cancelado antes de publicación tras detectar un selector antiguo ambiguo; el único candidato publicable es `6ac462432a09979c7fc17bef`.

El gate completo `37405575748` acreditó configuración, web/admin, PostgreSQL, permisos, concurrencia y backend integrado. Su fallo móvil fue exclusivamente el selector antiguo del test de cierre; la suite corregida tiene siete pruebas aprobadas. Las capturas requirieron el mismo ajuste para controles frontales. Las dos correcciones acotadas fueron auditadas sin hallazgos, sin cambiar el código móvil. `41c5a37e0f84fc0b432747b992d4950552663a50` sólo cambia la herramienta de captura y la separación de concurrencia CI; gate móvil `37406799890`, con pruebas y capturas aprobadas y compilación pendiente. iOS se recupera de la cancelación de concurrencia mediante su check aislado del gate inicial.

## Cierre verificado

- **Play:** Codemagic `6ac462432a09979c7fc17bef` terminó el 5/10/2026 a las 21:08 de México. Publicó únicamente **2.3.3 (295)**, `com.mycompany.dopmi`, Guardian test habilitado. La consulta separada `google-play tracks get` confirmó `internal`, `completed`, código 295. AAB SHA256: `74dc8f40372014a1058032220f9b5503578884ec0128b963a9354bcc4252970f`.
- **Build:** `guardian-build-info.txt` del artefacto confirma commit `7cf8202d2a64c0fb9d4eb387dc987c512f2c62b7`, versión 295 y distribución interna. `lib/`, pubspec y lockfile son idénticos entre ese candidato, `fcc2ce7` auditado y `41c5a37` de herramientas.
- **CI:** bloque móvil `37406799890` aprobado sobre `41c5a37`: análisis, 121 pruebas afectadas, dos suites de capturas y APK de desarrollo. iOS recuperado mediante job `112085464286` del run `37405575748`: aprobado. Web/admin/configuración/PG/backend del gate inicial siguen válidos; sus ejecuciones exitosas no se repitieron. El run inicial conserva el fallo histórico de selector; no se presenta como un run completo verde.
- **Samsung:** SM-S938B, serial R5CY51260VK, actualizado **desde Play** y código 295 comprobado por ADB. Diez avances efectivos, repitiendo el catálogo disponible en tres recorridos (4+4+2), con adopción→adopción, adopción→apoyo y apoyo→adopción. Arrastre corto vuelve; largo y rápido salen sin regresar. Reanudación mantiene el registro visible. Cambio Perros→Gatos→Perros restaura el feed; sesión conservada. No se generaron favoritos, conversaciones, fixtures remotos ni pagos.
- **Video:** referencia 293 `swipe-motion-review.mp4` frente a candidato `swipe-final-review.mp4`. Inspección de cuadros intermedios confirma la siguiente tarjeta completa, centrada y sin nueva entrada lateral. El video anterior muestra foto aislada y posterior entrada con texto. Evidencia privada en `.tools/photo-loop/`, incluyendo contactos `swipe-adoption-verified-contact.png`, `swipe-into-support-verified-contact.png` y `swipe-support-verified-contact.png`; no se versionan imágenes/datos reales. La nueva grabación cubre las transiciones mixtas; los avances repetidos adicionales están respaldados por capturas.

Se conserva salida de 280 ms y retorno de 250 ms; desaparece la entrada lateral adicional de 250 ms. Esto describe las duraciones del código, no un benchmark de red o una ganancia de FPS. Recuperación y caché de la entrega anterior permanecen acreditadas; este loop cierra el defecto visual.

No se modifican esquema, permisos, compresión ni pagos. La pantalla independiente de Apoyar permanece fuera del alcance. Auditoría cerrada con las dos correcciones de verificación previstas; no quedan hallazgos ni otra ronda abierta.
