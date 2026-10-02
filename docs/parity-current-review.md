# Corte de evidencia de paridad — 2/10/2026

Referencia: `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.
Implementación/capturador/CI: `64fd0568cc989a06173f0d9c4ea78ebf860f7128`.
Este inventario organiza la revisión pendiente; no sustituye las comparaciones
registradas en `parity-loops.md` ni acredita aceptación global.

## Capturas reproducibles actuales

`apps/mobile/tool/capture_profile_test.dart` contiene **238 estados en 28 URLs**
tras los dos estados de foco de galería pública añadidos en loop233. El corte
229 tenía 236 estados. Ese conteo incluye las siete tuplas multilínea de aportación que la búsqueda del
loop227 no incluyó en sus 229 tuplas de una línea. No son 236 rutas distintas.
Los 236 PNG iniciales existen tras el pase completo local del loop227 (108s, exit0).
Los dos estados nuevos se capturaron y revisaron por separado en loop233 (3s,
exit0); el corte CI indicado debajo precede esa ampliación.
El CI [37034721943](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/37034721943)
aprobó ambas etapas de captura y la carga del artefacto al consultar en loop229;
el APK de desarrollo seguía compilando. Las capturas usan repositorios fixture
y widgets de producción; no prueban sesión, almacenamiento ni pagos reales.

| URL del capturador | Estados |
| --- | ---: |
| `/adoptions` | 13 |
| `/adoptions/post` | 2 |
| `/messages` | 18 |
| `/messages/thread-one` | 5 |
| `/rescuer` | 10 |
| `/my-cases` | 6 |
| `/rescue/case-one` | 36 |
| `/rescue-cases` | 18 |
| `/rescue-cases/case-one` | 12 |
| `/notifications` | 7 |
| `/contribute/Cirugía?case=case-one` | 2 |
| `/contribute/Cirugía?case=case-one&amount_cents=10000` | 7 |
| `/guardian` | 16 |
| `/impact` | 2 |
| `/impact?history=1` | 4 |
| `/impact/guardian` | 6 |
| `/payments` | 3 |
| `/profile` | 18 |
| `/settings` | 8 |
| `/about` | 2 |
| `/transparency` | 2 |
| `/publish` | 2 |
| `/my-adoptions/new` | 2 |
| `/my-adoptions/post` | 8 |
| `/rescue/new?kind=case` | 4 |
| `/rescue/expense-one` | 17 |
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

## Prioridad PUBLIC identificada en loop235

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

