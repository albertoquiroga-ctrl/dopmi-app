# Corte de evidencia de paridad — 2/10/2026

Referencia: `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.
Implementación/capturador/CI: `64fd0568cc989a06173f0d9c4ea78ebf860f7128`.
Este inventario organiza la revisión pendiente; no sustituye las comparaciones
registradas en `parity-loops.md` ni acredita aceptación global.

## Capturas reproducibles actuales

`apps/mobile/tool/capture_profile_test.dart` contiene **236 estados en 28 URLs**.
El conteo incluye las siete tuplas multilínea de aportación que la búsqueda del
loop227 no incluyó en sus 229 tuplas de una línea. No son 236 rutas distintas.
Los 236 PNG existen tras el pase completo local del loop227 (108s, exit0).
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
| `/rescue-cases/case-one` | 10 |
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

## Android y entrega

Samsung SM-S938B conectado y autorizado, comprobado en loop223. Tiene
`com.mycompany.dopmi` 2.3.3 (285), anterior a este corte. Esa instalación conserva
valor para regresión histórica, pero no acredita los cambios nuevos.

Entrega final autorizada: `android-guardian-internal` → Google Play internal.
Conservar firma e identidad y verificar compilación y publicación por separado.
El APK debug con configuración de ejemplo de GitHub Actions no es ese candidato.
Dinero continúa en test; no copiar tienda, fondo, bonos, cashback o simulaciones.
