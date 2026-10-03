# Perfil público — loop 485

Referencia reconsultada: `irlanda/apoyar-detalle-perfil`,
`a3c969cd9103fd46dc5cd886999912526ce75efb`.
Producción inicial: `b3bbd7b`; Edge a 377 × 852, ruta
`/rescuer-profile/luna`, pestañas seleccionadas mediante sus botones reales.

Medidas DOM de referencia:

| Elemento | Ancho | Alto |
| --- | ---: | ---: |
| Tarjeta de adopción | 345 | 336 |
| Foto dentro del borde | 343 | 258 |
| Acciones de adopción | 343 | 76 |
| Guardar | 44 | 44 |
| Historia | 259 | 44 |
| Tarjeta de caso | 345 | 378 |
| Resumen de necesidad | 343 | 118 |
| Ver caso / Donar | 151.5 | 38 |
| Diálogo de reporte | 345 | 426.65625 |
| Campo del reporte | 297 | 112 |

La captura Flutter anterior mostraba el botón de historia ajustado a su texto,
dejando espacio libre a la derecha. Se obliga al botón a ocupar el ancho
disponible y se reserva el borde de la tarjeta mediante `Container`, como en
CSS. Se conservan favoritos reales, reversión de errores y navegación.

Los datos sintéticos de ambas versiones son distintos: las fotos grises del
fixture no representan fotos ausentes en el servicio real; edades, distancias,
conteos y necesidades no se sustituyen por los valores simulados del mockup.
Las medidas anteriores son de Source; no se atribuye igualdad de píxeles de
Flutter ni aceptación física del teléfono.

Antes del cambio, la pasada completa del capturador terminó con un test verde
en 3m13s sobre las 401 especificaciones únicas del inventario del loop484.
Incluye las comprobaciones de navegación y recuperación del capturador;
no representa 401 pantallas aceptadas visualmente. Log local:
`C:/Users/betoq/AppData/Local/Temp/dopmi-loop485-all-captures.log`.

ADB siguió vacío. Browser cerrado y Vite detenido. Codemagic se reserva para
el objetivo completo por instrucción vigente del titular.

Después del cambio: ejecución38676 exit0, 3/3 en 11s (dos pruebas de
favoritos y un capturador con dos estados normal/200%). Capturas finales
inspeccionadas: el botón alcanza el borde derecho de su columna; el texto
ampliado conserva todas sus palabras en varias líneas. Analyzer9033 exit0.
Logs `dopmi-loop485-adoption-final.log` y `dopmi-loop485-analyze.log` en
el mismo directorio temporal. La pasada401 anterior no cubre este cambio;
el último full de tests móviles sigue siendo el checkpoint479.
