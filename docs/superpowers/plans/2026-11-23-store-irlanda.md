# Tienda de Irlanda en Dopmi — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Una sola cola Flutter, controlada por root.

**Goal:** Igualar las tres pantallas de Tienda al mock solicitado, conservando el catálogo y la salida Amazon reales.

**Architecture:** Cambios de presentación y filtros locales en StoreScreen. Mantener repositorios, catálogo/ASIN, autorización, overlays y navegador externo actuales. La aplicación conserva estados reales ausentes en la simulación.

**Tech Stack:** Flutter/Riverpod; referencia React/CSS existente, sin SDK/dependencias nuevos.

**Spec:** Solicitud del titular23nov y Tienda en `dopmi-functional-mockup`, `irlanda/apoyar-detalle-perfil@d9f9aa430ffc4b1d9df76e49e7efbe9f0e5cae1c`, `src/App.tsx:6719–7105`, `src/styles.css:3394–4067`, paleta warm-trust. Éste es un delta sólo de Tienda; no actualiza la referencia globalf693 para otras secciones. Inventario en el tablero único `docs/parity-current-review.md`.

## Restricciones

- Base vigente fe378773/b471bdaf (Android439), rama aislada existente `codex/store-irlanda-current-20261123`. PR6/7 abiertos comprobados; no merge ni reset. Se cambió de base antes de congelar para conservar el cliente Android439; la primera inspección usó992e430a. Admin preparado en ca9fff2c permanece en su rama sin activación y no se incorpora a este binario.
- Español mexicano; fuentes/activos y navegación accesible existentes. Contenido normal, Samsung115% y320px/200%, sin superposición de navbar/acciones.
- Catálogo completo, imágenes y ASIN por presentación, código afiliado, aviso de comisión y confirmación previa a Amazon conservados. El mock tiene botones simulados y fotos genéricas; no sustituir datos reales ni copiar simulación.
- No precios/stock/descuentos inventados, donación garantizada, cashback, carrito o checkout propios. Cada artículo del kit se compra por separado.
- No cambios SQL, credenciales, flags, servicios, consentimiento, Stripe ni publicación pública por inferencia. Distribución QA conserva ruta vigente y ventana5min si se envía un binario.

## Revisión enfocada

- Filtro de varios sabores/presentaciones: cada resultado debe corresponder a una variante real que satisfaga ambos; no mezclar combinaciones inexistentes.
- Especie/edad/tamaño/marca cambian opciones disponibles; no dejar seleccionada una opción oculta que bloquee resultados sin explicación.
- Carga/error/revocación con filtro/detalle/handoff abierto: conservar las guardas existentes y cerrar datos del actor anterior.
- Volver del comercio o detalle conserva búsqueda/filtros/orden/scroll de la misma cuenta; nunca abrir sin confirmar ni usar enlace de otra presentación.
- Texto200% y320px: botones, chips y cierre accesibles por scroll, imagen sin recorte del empaque y navbar separada.

## Tarea1 — Pantallas y filtros (UIagent, root ejecuta Flutter)

Files: `apps/mobile/lib/features/store/store_screen.dart`, `apps/mobile/test/store_screen_test.dart`.

- [x] Escribir negativos de multiselección/opciones contextuales y recuperación; root ejecuta RED antes de producto.
- [x] Home: logo/notificación, título separado, banner compacto con foto42%, especie naranja, buscador+filtro48, kitceleste, encabezado con orden y grid de tarjetas.
- [x] Filtros: estado borrador, multiselección de marcas/sabores/presentaciones derivadas del catálogo real; aplicar/limpiar conservados.
- [x] Kit: tarjetas horizontales con imagen, especificación y CTA; detalle con marca/título/foto contain y chips como referencia. Mantener CTA seguro y aviso afiliado.
- [x] Root: pruebas dirigidas, analyze y suite móvil consolidada; resolver únicamente regresiones de este delta.

## Tarea2 — Contraste e integración (root + revisión independiente)

Files: `apps/mobile/tool/capture_store_test.dart` si requiere ampliar cobertura; continuidad en el tablero/cola/ledger existentes.

- [x] Ejecutar referencia congelada; contrastar DOM/CSS de inicio, filtros, kit y detalle con capturas Flutter. Excepciones y dimensiones registradas; captura gráfica del mock bloqueada, sin comparación de imágenes atribuida.
- [x] Reutilizar capturadores Flutter: normal, Samsung115% y320px/200%, datos controlados y sin escrituras productivas.
- [x] Revisión independiente acotada UI/UX/código/seguridad; cotejar diff con superficie prevista y corregir hallazgos materiales.
- [x] Congelar SHA de producto, ejecutar gates y registrar resultados por SHA. No repetir suites válidas por documentación.
- [ ] Si se distribuye: ventana5min, una cola Codemagic, verificar publicación y versión instalada antes de afirmar QA del teléfono. Aceptación humana permanece separada.

## Inventario y límites iniciales

Seis grupos finitos: cabecera/banner, especie/búsqueda/orden, filtros, tarjetas, kit y detalle. Handoff real y catálogo se conservan. Inventarios independientes de mock y app completados sin Flutter ni escrituras remotas. La carpeta histórica llamada dopmi-functional-mockup apunta a dopmi-app; se clonó el repositorio correcto en .tools/store-irlanda-20261123 con SHA exacto, sin alterar ese directorio histórico. El lock del mock omite xlsx; la instalación para lectura visual usa package-lock=false en el clon ignorado y no altera el lock de producto.

Preflight de distribución descubrió439/b471 posterior a437 y se conservó ese producto
íntegro mediante fe378773, que sólo agrega nueve MD. El lote Meta existente tiene
gate de entregaOFF; no lo activa Tienda. iOS no captura IDFA/ATT ni activa el permiso
desde esta integración. Revisión acotada encontró una marca oculta incompatible al
cambiar especie/edad; negativo RED y normalización local, sin modificar contratos.

Producto97af3893/tagcodex/store-irlanda-97af3893, CI45262749872 cuatro SUCCESS;
analyze limpio, 2125 Flutter PASS/4 SKIP y 39 dirigidas PASS. Revisión independiente
y capturas cerradas, salvo screenshot de referencia bloqueado por control gráfico.
Android440/CM6b04ab73d21ef35dc1e45a9a:14 SUCCESS, AAB/firma/configuración y log
Publishing internal/completed verificados. iOS441/CM6b04b236418a2b03a8c9e893:
15 SUCCESS, IPA/configuración y carga verificados; posproceso Apple finished sin
error22:00UTC. Ventanas de5min y un POST por plataforma; cola secuencial sin replay.
Disponibilidad de canales, instalación y aceptación siguen pendientes y separadas.
El mock permanece d9f9aa43 al cierre. Root probará Samsung cuando vuelva ADB; titular
recibió solicitud TestFlight441. No cambios públicos, SQL, flags ni servicios.


## Correctivo acotado24/nov tras feedback de Irlanda

El titular señala el bloque adicional de portada y el beige de las tarjetas.
Referencia d9f9aa43 reconsultada sin cambios. Corregir esos dos puntos, reutilizar
el test de salida segura y las capturas existentes, conservar detalle blanco y
aviso antes de Amazon. No nuevo plan, tablero, dependencias, SQL o cambio público.
El capturador permite salida distinta para conservar la evidencia de440/441.
Fuente dbac483b/tagcodex/store-irlanda-correction-20261124, CI45438832854 cuatro
SUCCESS. Android442 publicado interno y verificado; iOS443 cargado/verificado y
posproceso Apple terminado sin error18:11UTC. Un envío por plataforma; capturas
nuevas y revisión cerradas. QA instalada y aceptación permanecen pendientes.
