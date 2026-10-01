# Paridad con el mockup vigente

## Objetivo autorizado — 30/9/2026 (México)

El titular solicita loops hasta que la app real se vea y se sienta igual al
mockup, incluidas animaciones y gestos. Esta instrucción supersede el aplazamiento
visual del 27/9. Conservar datos y operaciones reales, autorización, privacidad,
accesibilidad y decisiones económicas. No copiar tienda, fondo, bonos, cashback
ni resultados simulados. No autoriza dinero real.

Referencia viva: `irlanda/apoyar-detalle-perfil`. Registrar SHA al inicio y cierre
de cada loop; las capturas anteriores no prueban fidelidad a un commit nuevo.
Implementación: `codex/design-foundation`; preservar cambios locales del titular.

Entrega autorizada por el titular: al terminar los loops y gates técnicos,
enviar el candidato a Codemagic usando `android-guardian-internal` en la rama
de continuación y publicar en Google Play interno para pruebas. Verificar acceso
API al momento de ejecutar, SHA fuente, versión/build, compilación y publicación
Play por separado. Esta autorización persiste; no solicitarla otra vez. La
publicación no acredita instalación ni aceptación visual y no autoriza dinero real.

## Loop 1 — Perfil adoptante, primera pasada

- Base `cae3c3caf941e3079623166fb2f195e219725d33`; remoto y PR6 abierto comprobados.
  Referencia `a3c969cd9103fd46dc5cd886999912526ce75efb`, posterior a `a246fa6`:
  cinco archivos cambiados, 4700 inserciones/1672 eliminaciones. Se consultó código
  y perfil ejecutado en navegador a 377×852; cambio/cancelación del diálogo observados.
- Implementación local: tarjeta personal blanca con nombre/ciudad reales, tarjeta
  Guardián consultada al servidor cuando el build lo habilita, accesos Preferencias
  y Pagos, confirmación antes de persistir experiencia, cierre de sesión real.
  Se conservan configuración, impacto y rescatistas guardados mientras se igualan
  sus accesos globales. SVG reutilizados de la referencia, sin nuevas dependencias.
- Pulsación de tarjetas: escala 0.99/120ms/ease, recuperación al cancelar y
  reducción de animaciones según preferencia del sistema. Pruebas cubren gesto
  cancelado, activación única, reducción, cancelar modo y guardar/fallar sin
  modificar datos personales. No representa la auditoría completa de gestos.
- Comparación inicial identifica pendientes concretos: barra flotante de cuatro
  destinos, márgenes verticales, sombreado de tarjeta Guardián, iconos restantes,
  diálogo de cambio y accesos Sobre Nosotros/configuración/guardados. No se acepta
  paridad por esta primera pasada. Datos de captura son fixtures, no cuentas reales.
- Captura Flutter: `docs/design-reviews/parity-loop-01/profile-overview.png`;
  referencia: `reference-profile.png`. Fuente: base anterior más diff local de
  `profile_overview.dart`, assets/profile, pubspec, pruebas y herramienta de captura;
  no hay nuevo commit, CI ni candidato instalado de esta pasada.
- Verificación: Flutter analyze sin incidencias y 104 pruebas Flutter aprobadas;
  generación de cuatro capturas y 12 pruebas de configuración móvil aprobadas;
  `git diff --check` sin errores. OneDrive impidió regenerar
  `build/unit_test_assets`; se verificó copia de lib/assets/test/tool y manifiestos
  en `C:/Users/betoq/AppData/Local/Temp/dopmi-parity-20260930/mobile`.
  No se borraron carpetas bloqueadas. Se precarga el SVG en la captura para impedir
  que una imagen aún sin cargar se interprete como evidencia de fidelidad.

## Continuación y criterio de cierre

### Loop 2 — barra flotante y estados de Perfil

- Inicio/cierre de referencia `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin
  cambios. PR6 remoto sigue abierto en `cae3c3c` contra `ba9f897`; rama de
  continuación conservada. Primera pasada anterior fue progreso concreto;
  esta continuación añade implementación y evidencia, sin esperar aceptación.
- Donante: cuatro accesos sin texto, cápsula negra240×68, círculos48×48,
  gap8, relleno12/10, sombra doble y selección amarilla. Favoritos abre
  `/messages`, como la referencia, mediante el navegador real ya existente.
  Perfil permite contenido bajo la barra y agrega espacio final para desplazar
  todos los controles; accesibilidad conserva etiquetas/selección/área48.
  Los cinco destinos rescatista y los navegadores conservados no se sustituyen.
- Diálogo de modo: composición, cuatro pasos, badge, iconos originales,
  cancelar/cerrar y confirmación antes de persistir; scroll comprobado a320px
  con texto200%. Barrera48% del color ink; referencia no define animación de
  aparición, por lo que este diálogo no añade transición. Ajustes de márgenes,
  alturas de línea/gaps y sombras de Perfil contrastados en las capturas.
- Guardián consulta estado real: carga sin afirmar membresía, fallo con
  reintento, estado activo y nueva lectura al regresar desde gestión. Pruebas
  detectaron y corrigieron un setState que devolvía Future durante reintento.
  No se cambió backend, monto, idempotencia, flags ni lógica de pagos.
- Gate:108 pruebas Flutter completas aprobadas; luego19 pruebas dirigidas
  (incluida generación de siete capturas) tras el ajuste final de geometría;
  analyze lib/test/tool sin incidencias; configuración móvil12 aprobadas.
  Copia temporal fuera de OneDrive comparada por SHA256 de lib/assets/test/tool
  con el checkout. Se regeneró únicamente su build temporal, que retenía el
  manifiesto viejo. La herramienta precarga todos los SVG usados y falla si
  faltan; imágenes del diálogo/estrella/corazón ya están presentes y revisadas.
- Capturas: `docs/design-reviews/parity-loop-02/`; perfil inactivo/activo y
  diálogo377×852, perfil320×640/texto200%. Referencia sigue en loop01.
  Son widgets reales con fixtures, no instalación ni aceptación externa.
- Pendientes antes de cerrar PAR.1: acceso Sobre Nosotros/Transparencia y
  estructura final de enlaces de Perfil, encabezado/notificaciones y selección
  de destino al entrar a vistas subordinadas; barra superpuesta en otros
  recorridos se revisa con su pantalla completa. No declarar paridad global.

## Loop 03 · Información y enlaces de Perfil · 2026-09-30

- Referencia al inicio/cierre: `irlanda/apoyar-detalle-perfil`, SHA
  `a3c969cd9103fd46dc5cd886999912526ce75efb`, comprobado con ls-remote.
- Perfil adoptante usa sólo campana original en el encabezado y las tres
  filas del mockup: Sobre Nosotros, Centro de ayuda, Cerrar sesión. Iconos,
  círculos40, radio18, padding12/14 y sombras de la referencia. Configuración,
  impacto y rescatistas guardados se conservan desde Mi cuenta. Favoritos
  conserva el acceso a Guardados en mensajes; no se retiraron operaciones.
- Rutas reales /about y /transparency; se corrigió la lista de navegación
  autenticada, que inicialmente desviaba estas rutas a Adoptar. Regresar
  restaura la pantalla anterior y tiene fallback cuando se abre directamente.
- Páginas informativas replican encabezado68, borde, márgenes16/20,
  secciones28, tipografía y tarjetas/criterios. Se eliminó el espaciado de
  letras heredado de Material que alteraba los saltos de línea. Quedan ajustes
  menores de métricas verticales y la composición final de listas/footer;
  las capturas no justifican todavía declarar paridad exacta de esas páginas.
- Contenido de Transparencia explica gastos pagados/aprobados, conciliación,
  devolución íntegra y cobro mensual condicionado. No copia reparto93/5/2,
  fondo comunitario, reasignación arbitraria ni exposición de comprobantes.
  Contacto abre un borrador a soporte@dopmi.org; privacidad abre el destino
  oficial establecido y ambos reportan fallo de apertura. No envía mensajes.
- Validación:111 pruebas Flutter completas; después10 dirigidas incluyendo
  captura tras último ajuste tipográfico. Analyze lib/test/tool limpio también
  después del ajuste; configuración12 aprobadas. Copia fuera de OneDrive con
  SHA256 idéntico para lib/assets/test/tool. Capturas12 generadas sin errores,
  incluyendo /about320×640/texto200%, criterios expandibles y perfil inferior.
  Evidencia seleccionada en docs/design-reviews/parity-loop-03; referencia
  ejecutada en Vite y capturada en navegador377×852. No instalación/dispositivo,
  aceptación de Irlanda, CI remoto ni publicación Codemagic en este loop.
- Próximo: terminar composición informativa y encabezado/badge con datos reales;
  luego comparar Adoptar, detalle, filtros y gestos contra la misma referencia.

## Loop 04 · Adoptar: tarjeta y movimiento · 2026-09-30

- Referencia inicio/cierre: `a3c969cd9103fd46dc5cd886999912526ce75efb`
  en `irlanda/apoyar-detalle-perfil`; remoto reconsultado en ambos extremos.
  PR6 abierto/draft, head remoto cae3c3c/base ba9f897 comprobados por GitHub
  y git ls-remote. Se continúa el checkout local sin incluir cambios del titular.
- Adoptar: encabezado con logo/campana originales, categorías tipográficas,
  tarjeta radio32/media22, padding12, degradado, etiquetas oscuras, sombras
  y controles58/64 con SVG de la referencia. Barra superpuesta; acciones de
  mensajes/favoritos conservadas en Favoritos. La ubicación exige selección
  real y no afirma Monterrey cuando no existe un filtro del usuario.
- Gesto: seguimiento inmediato, rotación delta/28 grados, umbral estricto
  ±110px, retorno250ms y salida280ms/cubic(.22,1,.36,1), ±420px/±18grados,
  opacidad.35. Control caliente desde±12px, escala1.14/180ms. Cancelar vuelve
  sin persistir; reducción de movimiento omite tiempos. La tarjeta siguiente
  aparece detrás sin botones ni semántica interactiva; entra centrada.
- Guardar espera confirmación real antes de salir, bloquea duplicados y
  conserva tarjeta/error si falla. Texto200% aumenta altura de media para
  evitar recortar nombre; categorías envuelven y la lista permite alcanzar
  controles. No se cambió repositorio, backend ni autorización.
- Gate:115 pruebas Flutter completas aprobadas después de corregir la
  prueba que aún buscaba el acceso viejo Mis match. Incluyen arrastre inmediato,
  umbral, cancelación, duración, tarjeta siguiente, guardado pendiente/fallo,
  texto ampliado y reducción de movimiento. Configuración12 aprobadas;
  capturador14 estados aprobado. Analyze final lib/test/tool sin incidencias.
  Copia temporal fuera de OneDrive: lib/assets/test/tool idénticos por SHA256.
- Evidencia: reference-adoption y adoption-swipe/drag/large en
  `docs/design-reviews/parity-loop-04`,377×852 y320×640/texto200%.
  Referencia ejecutada en navegador; se compara composición, no la fotografía
  ficticia de Rocky con la fixture sin foto de Luna. Vite/tab temporales cerrados.
- Pendientes de este recorrido: filtro/ubicación y sus hojas, confirmación de
  contacto, detalle, vacíos/fin, badge de notificaciones con datos reales,
  tarjeta de apoyo intercalada (todavía usa composición anterior y sin gesto),
  capa siguiente cuando es apoyo, y verificación instalada. No paridad global,
  aceptación visual, CI remoto ni Codemagic atribuidos a este checkpoint.

## Loop 05 · Filtros de Adoptar · 2026-09-30

- Referencia inicio/cierre `irlanda/apoyar-detalle-perfil` en
  `a3c969cd9103fd46dc5cd886999912526ce75efb`, reconsultada con ls-remote.
- Filtros cambia de hoja inferior a diálogo centrado, barrera ink48%, sin
  animación añadida, panel blanco/radio24 y máximo88vh/720. Geometría/título
  final contrastados con captura, incluyendo reglas CSS posteriores que
  sobreescriben radio16/font18 en la fuente. Género en cápsula, iconos de tamaño
  del SVG original (trazo/relleno según selección), chips de tonos y controles
  de aplicar/limpiar con borde y tipografía de referencia. Botón de filtro usa
  los dos deslizadores originales y cambia de color cuando hay filtros activos.
- Datos reales: cerrar descarta borrador sin consulta; aplicar conserva especie
  y utiliza sex/size/personality; reabrir conserva selección; limpiar retira sólo
  esas tres claves. Versionado de cargas impide que una consulta antigua cambie
  resultados o error/loading de la selección más reciente. No se cambió SQL.
- Diferencia explícita aún pendiente: mockup ofrece12 rasgos emocionales; SQL
  sólo admite6 rasgos existentes. Este loop conserva claves y etiquetas reales,
  sin renombrarlas arbitrariamente ni mostrar filtros que el servidor rechaza.
  La ampliación necesita revisión de migraciones/contrato/publicación y pruebas
  de descubrimiento antes de cerrar esta paridad. Panel usa controles48px y
  chips3 columnas para6 opciones; referencia usa4 columnas/12 y min34px.
- Texto200%: panel desplazable, categorías/género se envuelven sin cortar palabras,
  aplicar alcanzable y cerrar fijo. Captura ampliada conserva diferencias de
  composición y requiere revisar pintura/etiqueta Género antes de aceptación
  visual completa; una prueba de ausencia de overflow no demuestra esa aceptación.
- Gate:119 pruebas Flutter completas; capturador16 estados aprobado;
  configuración12 aprobadas; analyze lib/test/tool limpio tras corrección de
  llaves en prueba. Lib/assets/test/tool idénticos por SHA256 en copia temporal
  fuera de OneDrive. Evidencia seleccionada: docs/design-reviews/parity-loop-05.
  Fuente ejecutada en Vite/navegador377×852; procesos/tab temporales cerrados.
- Próximo: resolver contrato de personalidad y revisar etiqueta ampliada;
  ubicación, confirmación, detalle/vacíos, apoyo intercalado, restantes rutas y
  verificación instalada siguen abiertos. No nuevo CI remoto/Codemagic ni
  aceptación atribuida. Objetivo activo; entrega final autorizada permanece.

## Loop 06 · Doce rasgos con datos reales · 2026-09-30

- Referencia inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`,
  consultada en la rama Irlanda. Los doce nombres, orden y tonos pasan al
  selector real. Cuatro columnas y chips34px en escala normal; texto200% usa
  una columna desplazable para conservar palabras completas. Género vuelve a
  aparecer en la captura ampliada. Acciones42px y composición contrastadas con
  reference-filters.png; persisten pequeñas diferencias de tipografía/espaciado.
- Publicación carga/conserva personalidad, permite seleccionar rasgos nuevos
  y envía el payload real. Los rasgos anteriores se conservan literalmente;
  se muestran en el editor si ya estaban seleccionados, sin equivalencias
  emocionales inventadas. Filtros usa las doce claves nuevas, no etiquetas que
  el servidor rechaza.
- Migración nueva local20261001042203/remota20261001042909 aplicada sólo en
  desarrollo. Correspondencia de cuerpos y ACL verificada antes/después en
  migration-history-audit.md; consulta remota de doce rasgos aceptada.
  Guardado conserva propietario/versionado, bloquea edición enviada y devuelve
  las publicaciones editadas a borrador. Exposición exige revisión vigente.
- Backend410 pruebas; cinco pruebas nuevas comprueban filtro legado/nuevo,
  conservación/limpieza, retiro público, envío/aprobación y entradas inválidas.
  Capturador16 estados y cuatro pruebas de filtro pasan. Nueva prueba de editor
  comprueba conservación legado y selección/payload nuevo. Configuración12.
  Gate final Flutter120 y analyze lib/test/tool limpio; archivos lib/test de
  la copia ejecutada coinciden byte a byte con el checkout.
  Evidencia PNG en docs/design-reviews/parity-loop-06. pgTAP pendiente porque
  Docker no está disponible; no se atribuye aceptación instalada/visual general.
- Próximo: ubicación, confirmación, detalle/vacíos y apoyo intercalado de
  Adoptar, luego restantes recorridos. Objetivo y entrega Codemagic final siguen
  activos; este checkpoint no completa la paridad integral.

## Loop 07 · Confirmación de contacto · 2026-09-30

- Referencia inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`.
  Vite/navegador377×852 comprobados; PNG reference-contact guardado. El mockup
  muestra ciudad del perfil como texto estático: no hay selector de ubicación
  que copiar. Se conserva el selector real existente, cuya persistencia de
  coordenadas/radio al reabrir necesita un ciclo propio.
- Adoptar y detalle reutilizan AdoptStartDialog: texto de referencia, blanco,
  radio24, barrera ink48%, sin animación de entrada, padding28/22/22, título22
  Inter700, cuerpo14/1.45 y acciones apiladas48px. Captura normal reproduce
  panel y posición contra referencia. Texto200% elimina padding del título
  para conservar palabras completas; scroll y cerrar fijo.
- Confirmar sigue llamando startThread real y mide contact_started sólo cuando
  resulta; cancelar/cerrar no crea conversaciones. Error conserva tarjeta y
  permite nuevo intento. Se impide contacto mientras otra acción de tarjeta
  está pendiente. El diálogo de contacto desde perfil público conserva su
  semántica actual para revisarlo con esa ruta, no se reemplaza a ciegas.
- Tres pruebas nuevas: cancelar/cerrar, fallo y reintento real, texto ampliado
  con confirmación desplazable y cierre visible. Pruebas existentes del detalle
  y medición conservadas. Capturador incorpora dos estados nuevos de contacto.
  Gate final: Flutter123 completos, analyze lib/test/tool limpio, configuración12
  y captura18 estados aprobados; lib/test/tool ejecutados idénticos al checkout.
- Diferencias abiertas: tarjeta de fondo usa fixture sin foto y ubicación aún
  difiere; referencia tiene foto Rocky/datos de prueba. No aceptación instalada
  ni paridad integral atribuida. Próximo: detalle/galería, vacíos y apoyo
  intercalado. Entrega final Codemagic sigue pendiente, objetivo activo.

## Loop 08 · Detalle y galería de adopción · 2026-09-30

- Referencia inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`.
  Navegador377×852 en adoption/rocky, medidas de hero340, sheet318 y barra671/752.
  Se reproduce incluso la banda blanca100px que produce la cascada real de
  ScreenShell; no se usa el CSS aislado como prueba del resultado.
- Detalle pasa a foto de ancho completo, botón volver40 con transparencia/blur,
  enlace al publicador en cápsula, ficha blanca superpuesta22/radio28,
  nombre/ubicación/verificación, estadísticas3 columnas y acciones fijas52.
  SVG originales de volver/ubicación/compartir/reporte/verificación y corazón
  original de guardado. Texto200% usa estadísticas apiladas y barra adaptable.
- Galería usa sólo fotos aprobadas devueltas por detalle, dots según cantidad
  real y PageView con índice accesible; cambio de lista aprobada restablece
  página. No se agregan fotos/dots simulados ni zoom inexistente en la referencia.
- Insignia depende de dopmi_rescuer_public/publicProfile con verified=true,
  consulta renovada por LiveSection; errores/null no producen verificación.
  Distancia calculada por discovery pasa por la ruta; entrada directa sin ese
  dato muestra raya, sin kilómetros inventados. Datos clínicos/edad/raza siguen
  accesibles en expansión; cuidados especiales permanecen visibles.
- Guardar/contactar/reporte/compartir/perfil y administrar publicación propia
  conservan operaciones reales. Se encontró fallo de reintento de AdoptionPhoto:
  setState devolvía Future y el fallo post-frame podía quedar sin observador.
  Callback ahora es void y Future se observa inmediatamente sin ocultar el error
  a FutureBuilder. Pruebas de firmas fallidas/reintento y swipe pasan.
- Cuatro pruebas nuevas cubren distancia trasladada desde discovery, verificación
  obligatoria/cuidados accesibles, pager/reintento y acciones a texto200%.
  Captura usa Rocky y datos equivalentes de referencia mediante HTTP sólo local
  en tool, sin sockets ni cambios al cliente productivo; PNG fixture fuera de
  assets empaquetados. Capturador20 estados aprobado, configuración12.
  Gate final Flutter127 completos y analyze lib/test/tool limpio; lib/test/tool/
  assets de la copia ejecutada idénticos byte a byte al checkout.
- Diferencias pequeñas de métricas de tipografía/sombras requieren revisión
  instalada; banda100 y datos adicionales están documentados. No aceptación
  visual integral, CI remoto ni Codemagic atribuidos. Próximo: vacíos y apoyo
  intercalado, luego favoritos/match/chat y demás recorridos. Objetivo activo.

## Loop 09 · Vacíos reales de Adoptar · 2026-09-30

- Referencia `a3c969cd9103fd46dc5cd886999912526ce75efb` reconsultada. Sin
  publicaciones y fin del recorrido ahora son estados distintos. Empty usa
  tarjeta320/radio28, Fraunces26/1.2, cuerpo14/1.45 y acción cápsula52; se
  revisó la cascada posterior: acción global negra y secundaria #faf8f5.
- Vacío global sólo después de comprobar las dos especies sin filtros. Si la
  consulta de la otra especie falla, no se afirma vacío global. Vacío filtrado
  permite limpiar claves conservando especie; vacío de categoría consulta la
  alternativa; apoyo abre la ruta real. Reiniciar al final vuelve a consultar
  publicaciones vigentes en lugar de restaurar sólo el caché.
- End reproduce textos/acciones de referencia; mosaico de fotos y énfasis de
  palabras siguen pendientes antes de cerrar su paridad. Tarjeta de apoyo
  intercalada aún requiere su ciclo propio. No se declara Adoptar completo.
- Tres pruebas nuevas cubren categoría alternativa, ambas vacías y limpieza
  real. Capturador añade vacío normal/ampliado y fin del recorrido. Evidencia
  de comparación en docs/design-reviews/parity-loop-09; revisión de navegador
  de esos estados aún pendiente. No aceptación instalada/Codemagic atribuidos.
  Suite Flutter130 y analyze limpios; tras ajustar radio cápsula se repitieron
  las tres pruebas de vacío y captura23 estados, aprobadas. Configuración12.
- Próximo: terminar mosaico/énfasis y tarjeta de apoyo intercalada; luego
  favoritos/match/chat y resto de rutas. Objetivo original y entrega final
  android-guardian-internal permanecen activos.


## Loop 10 — cierre de Adoptar y contraste de vacíos

- Referencia verificada al inicio/final: `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.
- DiscoveryEnd usa cuatro fotos decorativas de las publicaciones aprobadas retornadas; sin imágenes simuladas en producción. Reproduce saturación .85, opacidad .38, radios22, dos columnas y recorte del contenedor de referencia. Botones enfatizan favoritos/descubrir; se añadió la segunda sombra de la tarjeta.
- Navegador377×852: vacío global, recorrido Gatos→Misha→Nube→apoyo Milo (arrastre)→fin y reinicio a Misha comprobados. Medidas: tarjeta final x28.8/y144/ancho320/alto333.2; contenedor final termina493.2. Título vacío max244.244. Se corrigieron los22px extra de separación sólo en los estados sin tarjeta vigente.
- Evidencia reference/actual en `docs/design-reviews/parity-loop-10`. Datos/fotos equivalentes siguen pendientes para comparar el mosaico exacto; encabezado con ubicación real puede mostrar Elegir ubicación, y el tono del contorno secundario requiere contraste adicional. No se declara paridad total ni aceptación instalada.
- Flutter130 pruebas aprobadas; analyze limpio; config12 aprobadas. Después de separación/recorte, pruebas de vacío3 y capturador23 estados aprobados. Sin cambios de esquema ni permisos.
- Próximo ciclo: tarjeta de apoyo intercalada, incluyendo arrastre y transición. Entrega final Codemagic android-guardian-internal autorizada, todavía pendiente de completar el alcance.


## Loop 11 — tarjeta de apoyo intercalada

- Referencia inicio/cierre `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`. CSS/handlers leídos: amarillo, foto, degradado, nombre28 Fraunces, gasto/progreso6/montos, CTA y círculo64 con tab-donate original.
- Tarjeta real ahora usa `photo` del snapshot aprobado, `expense_title`, `funded_cents` y `reimbursable_cents`. Sin foto conserva fallback visible; no imagen simulada en app.
- Arrastre inmediato, retorno250ms, salida280ms ±420px/18°, opacidad .35 y umbral110 como Adoptar. Ambos sentidos pasan la oportunidad; tap/CTA abre `/rescue-cases/:id`. Se eliminó el salto previo al formulario por swipe. Acción accesible Seguir descubriendo; animación reducida y bloqueo durante salida conservados.
- Texto200% usa CTA vertical y tarjeta más alta. Capturas normal377×852 y pequeño320×640 en `docs/design-reviews/parity-loop-11`. Fixture sin foto prueba fallback; falta foto equivalente Milo, contraste directo de navegador, tap/regreso y cancelación de la tarjeta de apoyo para declarar el ciclo completo.
- Analyze limpio, pruebas dirigidas16 + captura25 estados aprobadas, configuración12 aprobada. Suite completa130 aprobada tras corregir disposición ampliada; no aceptación instalada/Play/Codemagic atribuida.
- Objetivo completo activo. Próximo: completar comparación y pruebas de navegación de esta tarjeta; después favoritos/match/chat y demás rutas. Codemagic final autorizado y pendiente.

## Secuencia pendiente

1. Completar Perfil y navegación global contra el mismo SHA; estados Guardián
   activo/inactivo/error y texto ampliado, sin perder accesos funcionales.
2. Adoptar, filtros, detalle, favoritos/match y chat: composición, arrastre,
   umbrales/velocidad, cancelación, transición, teclado y conservación de estado.
3. Apoyar, caso, galería, avances y perfil público; aportación/Guardián/historial
   con estados reales y errores, sin success simulado ni nuevos cobros por gesto.
4. Acceso/onboarding y todos los recorridos rescatista, formularios y evidencia.
5. Comparar cada ruta/estado de `design-parity.md` al tamaño de referencia,
   dispositivo pequeño/texto ampliado y candidatos instalados Android/iOS.

Cada loop implementa, prueba, captura, contrasta y registra diferencias antes del
siguiente. Revisar curvas, duraciones, gestos, regreso y scroll además de imágenes.
Usar datos equivalentes de prueba para comparaciones; separar las diferencias
necesarias por reglas reales. Compilación y pruebas unitarias no prueban sensaciones
en dispositivo ni aceptación visual del titular/Irlanda. El objetivo sigue activo
hasta que exista evidencia para todo el alcance, no sólo para este perfil.
