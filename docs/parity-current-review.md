# Corte de evidencia de paridad — 2/10/2026

Referencia: `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.
Corte productivo: `4a206db` (loop257); CI integral aprobado para
`9e1c27d82aba6825e0d59391e0ffaae709e94141`, run37053996279 #428.
El CI precede la corrección del mazo257 y las capturas de teclado258.
Este inventario organiza revisión pendiente y evidencia técnica; no acredita
aceptación global ni instalada. Entradas históricas debajo están fechadas.

## Capturas reproducibles actuales

Actualización loop260: recorrido Perfil rescatista → Configuración → regreso
contrastado en mockup ejecutado y router productivo. Regreso conserva posición,
nombre y experiencia a tamaño normal y200%;29pruebas dirigidas aprobadas.
Paleta efectiva y recorte de biografía ya coincidían: no modificación visual
sin evidencia. Capturas normal/large en `design-reviews/parity-loop260`.
Datos Connect/verificación/revisión reales conservados. CI432 aún ejecutándose;
esto no acredita aceptación en Samsung ni paridad completa.

`apps/mobile/tool/capture_profile_test.dart` contiene **256 estados en 29 URLs**,
recontados desde todas las tuplas, incluidas las multilínea, en loop259.
Incluye conversación con300px de teclado simulado y cuatro nuevos estados de
galería/selector de monto del caso, normal/200%.
El último CI integral aprobado capturó250 estados; los dos nuevos aprobaron
localmente junto a las pruebas de comunidad. No son252 pantallas aceptadas,
ni29 pantallas que haya que implementar desde cero. Los widgets productivos
usan fixtures de prueba: no acreditan sesión, Storage ni pagos reales.

| URL del capturador | Estados |
| --- | ---: |
| `/adoptions` | 13 |
| `/adoptions/post` | 2 |
| `/messages` | 18 |
| `/messages/thread-one` | 7 |
| `/rescuer` | 10 |
| `/rescue/case-one` | 36 |
| `/my-cases` | 6 |
| `/rescue-cases` | 18 |
| `/notifications` | 7 |
| `/rescue-cases/case-one` | 16 |
| `/contribute/Cirugía?case=case-one&amount_cents=10000` | 7 |
| `/guardian` | 16 |
| `/impact?history=1` | 4 |
| `/impact` | 2 |
| `/impact/guardian` | 6 |
| `/payments` | 3 |
| `/contribute/Cirugía?case=case-one` | 2 |
| `/profile` | 18 |
| `/settings` | 8 |
| `/people/owner` | 12 |
| `/about` | 2 |
| `/transparency` | 2 |
| `/publish` | 2 |
| `/my-adoptions/new` | 2 |
| `/my-adoptions/post` | 8 |
| `/rescue/expense-one` | 17 |
| `/rescue/new?kind=case` | 4 |
| `/rescue/new?kind=verification` | 4 |
| `/rescue/verification-id` | 4 |

Acceso y galería de componentes tienen otro capturador,
`tool/capture_design_test.dart`; no están incluidos en este total. Tampoco son
una auditoría completa de todas las rutas declaradas por el router. Los nombres
`large`, `focus`, `empty`, `review`, etc. identifican estados, no aceptación.

## Revisión que debe cerrar cada recorrido

1. Consultar SHA vigente y recuperar la comparación histórica de ese recorrido
   en `parity-loops.md`. Muchos loops ya usan a3c969; no clasificarlos como
   evidencia antigua sólo por su fecha.
2. Contrastar el PNG actual con la referencia renderizada y condiciones iguales
   de viewport, estado y texto. Las fotos, identidades e importes fixture pueden
   diferir: medir composición sin inventar datos para aparentar igualdad.
3. Verificar acciones, regreso, scroll, teclado, duración y curvas de animación.
   Un PNG estático no acredita ese movimiento. Registrar diferencia concreta y
   corregirla antes de volver a capturar, evitando repetir gates sin cambios.
4. Repetir el recorrido correspondiente en el candidato instalado con servicios
   de prueba. Registrar versión, SHA y resultado; separar esta evidencia de CI.

Primer bloque de revisión: descubrimiento de adopción y apoyo (arrastre parcial,
umbral, retorno y salida), seguido de galerías pública/propia y mensajes con
teclado. Después perfiles/ajustes, publicación/evidencia/verificación y
aportación/Guardian/impacto. Las comparaciones previas son puntos de partida,
no una razón para reconstruir funciones aceptadas.

## Diagnóstico histórico PUBLIC — loop235, supersedido por236–255

`/people/:id` no está cubierto por el capturador anterior. La lectura actual de
`catalog_screens.dart` confirma presentación genérica: avatar88, Heading con
eyebrow, chips Material, contador de adopciones en Notice, SegmentedButton y
ListTile. La referencia `PublicRescuerProfile` usa TopBar sin título, avatar96,
identidad centrada, verificación explícita, casos publicados, redes con botones
propios, pestañas subrayadas y numeralia. Tener la operación funcional no prueba
esa composición. Esta pantalla requiere implementación visual completa.

Trabajo inmediato: marco, identidad aprobada y pestañas; después numeralia,
tarjetas de adopción/casos, vacío/error y comparación renderizada normal/grande.
Conservar favorito, compartir, reporte persistido y contacto confirmado reales.
No sustituir `activity` por métricas inventadas: los avances públicos existentes
siguen siendo información real que debe quedar accesible.

El SQL local vigente de `dopmi_rescuer_public` devuelve nombre/bio/ciudad/región,
avatar/redes aprobados, verified/saved, adopted_count y listas completas de
adopciones públicas, casos visibles y avances publicados. No devuelve el conjunto
de agregados que presenta el mock (recaudación, necesidades cubiertas y otros).
No estimar historia publicada desde las listas visibles ni usar el dashboard
privado de otro propietario. Revisar/implementar un contrato de agregados públicos
autorizados antes de mostrar esos valores. Esta inspección es de SQL del
repositorio; no es una nueva verificación del servidor remoto.

## Android y entrega

Samsung SM-S938B conectado y autorizado, comprobado en loop223. Tiene
`com.mycompany.dopmi` 2.3.3 (285), anterior a este corte. Esa instalación conserva
valor para regresión histórica, pero no acredita los cambios nuevos.

Entrega final autorizada: `android-guardian-internal` → Google Play internal.
Conservar firma e identidad y verificar compilación y publicación por separado.
El APK debug con configuración de ejemplo de GitHub Actions no es ese candidato.
Dinero continúa en test; no copiar tienda, fondo, bonos, cashback o simulaciones.

## Actualización PUBLIC — loops236–239

El estado genérico descrito en loop235 quedó reemplazado por marco blanco con encabezado difuminado, identidad centrada/avatar96, redes con SVG, pestañas subrayadas y tarjetas públicas de adopción y casos. Guardado, reporte y contacto siguen reales. El capturador añade seis estados de /people/owner (normal/grande, adopciones y casos): 244 estados en 29 URLs. Se capturaron por grupos en loops237–239. Numeralia pública, comparación completa con runtime Source y dispositivo siguen pendientes; las capturas fixture no prueban sesión ni pagos reales.

CI68c098424a3688e7dc89b36df10897c3a7738239, run37039192375 #418, fue confirmado completed/success en loop237. Cubre el corte hasta234, no los cambios PUBLIC nuevos. No se ha enviado el candidato final a Codemagic.


Loop242 añade cuatro estados de numeralia pública normal/grande y vista de estadísticas: 248 estados en29URLs. CI37043766184/420 confirmado completed/success para6f81976; no cubre241–242. Numeralia tiene contrato real aplicado enDEV e integración cliente con pruebas de revocación; falta comparación completa del runtime Source y dispositivo.


Loop243 compara el perfil público con el runtime Source /rescuer-profile/luna en IAB377×852 y captura la app con los mismos textos de identidad para comparar composición. Guardado/contacto/conteo realizado se conservan al final; encabezado, identidad, redes y pestañas ya siguen el orden Source. Se corrigieron alturas y espaciados medidos (incluido margen automático bilateral de Reportar). Añade dos estados de identidad de referencia normal/grande:250estados29URLs. No acredita datos del servidor ni dispositivo; los totales fixture difieren del mock y el brillo radial sigue pendiente.


Loops244–246 complete bottom-aligned public hero content, elliptical radial highlight and Reportar keyboard outline. Counts remain250states29URLs. Local captures/tests verified; CI422 for3dcc568 is in progress, device/full visual acceptance remains pending.


Loop253: corte83e081f557a4c9ebb3a058cba23c24b5a3563cd5,419pruebas móviles completas y12configuración aprobadas. Swipe ya no espera red entre tarjetas; favorito fallido tiene reintento para mascota original. Avatar público renueva al reanudar. Pestañas públicas contrastadas con Source renderizado, tipografía/botones/progreso corregidos. Referencia a3c969 sin cambios. CI424 aprobado b38acd8; nuevo426queued para corte actual. Criterio móvil excluye hover; capturas250estados29URLs no son aceptación instalada. Codemagic final pendiente.


Loop256: complete Adoptar → detalle → confirmación → regreso contrastado en Source377x852; arrastre60 retorna y150 sale, parámetros coinciden con producción. Capturas nativas normal/200% retenidas, mazo fixture alineado a Rocky/foto aprobada. Diferencias de datos (ubicación no elegida, distancia real y guardado) documentadas. 424 pruebas móviles completas aprobadas sobre9e1c27d; CI428 en curso. No equivale a gesto en Samsung ni a cierre de las demás rutas. Próximo bloque: mensajes con teclado/galerías/regreso, seguido de cierre de estados por grupo.

Loop257 supersedes deck distance difference256: extra distance row removed to match Source card; actual computed distance still reaches detail and filters. Location SVG and text/tag lineboxes corrected; same Rocky fixture/photo normal/large captured and inspected. Motion/detail/community38pass; final motion/detail/capture12pass and analyze7.6s clean. Installed motion remains separate. Continue with whole message/keyboard/back path, not hover.


Loop259: Apoyar → caso → selección de foto → galería → monto comparado con Source renderizado377x852. Galería real sólo muestra fotos aprobadas; Source repite imágenes hasta6, no se inventan copias. Selector real conserva mínimo10/centavos y descuento real de costos en vez del checkbox simulado0. Se corrigen lineboxes/campo52 y se añaden4capturas normal/large. Último CI430: análisis, pruebas, ambos capturadores, iOS y backend exitosos; Android falló por Maven403 al descargar Kotlin. No es gate completo aprobado. Próximo cierre: comparar perfil/ajustes y panel/formularios rescatista completos, después recorridos de Guardian/pago test y candidato instalado.
