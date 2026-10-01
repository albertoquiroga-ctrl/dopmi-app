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


## Loop 12 — apoyo, regreso y foto equivalente

- Referencia Irlanda SHA `a3c969cd9103fd46dc5cd886999912526ce75efb`, reconsultada sin cambios. Reutiliza foto pública `milo-card.png` sólo como fixture del capturador, sin empaquetarla en producción.
- Prueba ampliada comprueba arrastre corto, CTA hacia caso real, historia del caso, regreso a la misma oportunidad y arrastre derecho hasta fin sin formulario de aportación. Repositorio de casos de prueba sustituye servicios externos; no acredita cuenta/flujo remoto instalado.
- Captura espera carga/decodificación tras cambiar tarjeta; PNG equivalente Milo ya visible. Normal reproduce fotografía, marco amarillo, radios32/22, progreso6 y CTA de referencia observada en loop10. Evidencia en loop12. Revisión simultánea navegador y cancelación explícita aún pendientes; no se declara equivalencia total del gesto desde una imagen.
- Pruebas dirigidas16 + capturador25 estados aprobadas; después de espera de imagen, capturador repetido aprobado. Analyze limpio. Código de producción no cambiado en este loop; no esquema/pagos ni nuevos guards.
- Continuar comparación de apoyo y luego favoritos/match/chat. Entrega final Codemagic android-guardian-internal sigue autorizada, pendiente de completar paridad global.


## Loop 13 — Mis match, favoritos reales

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb` sin cambios. Se inspeccionaron DonorMessages y CSS match-fav (148px, radio20, separación12, nombre15 y contacto).
- Nueva fila horizontal en Mis match consulta savedAdoptions; sólo disponibles muestran información/fotos. Ver más abre guardados existentes y refresca al regresar. Foto abre detalle; contacto confirma, crea hilo real, mide éxito y abre conversación; error no simula hilo. Textos Mis favoritos/Chats/aventura/Explorar tomados de referencia.
- Se quitaron accesos redundantes a guardados/donación de la pantalla principal; los tres tipos siguen en `/saved`. Vacío chats ahora texto14/1.45; no paginación de una sola página.
- Primera suite completa130 aprobada; tras agregar prueba de cancelación y ajustar vacío se aprobaron17 pruebas dirigidas + capturador27 estados. Analyze final limpio. Capturas normal y320×640/200% en loop13; no SQL ni cambios de autorización.
- Pendientes para completar Mis match: encabezado de ubicación/logo, vista completa y orden de favoritos, arte vacío, dimensión visual34 del botón de chat, búsqueda integrada, filas/avatar/hora/no leídos de chats, rol rescatista y contraste de navegador. Estado parcial no acredita paridad completa ni dispositivo instalado.
- Próximo ciclo continúa esta pantalla; objetivo global y Codemagic final siguen activos.


## Loop 14 — filas de chats reales

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb` sin cambios. Inspeccionados DonorMessages y estilos thread-row/avatar48/borde/nombre16/preview14/tiempo12/badge amarillo.
- MatchThreadRow reemplaza Card/ListTile: filas blancas con separación, nombre y participante diferenciados, preview gris, estado cerrado y conteo real. Actividad usa updated_at real (hora local hoy/Ayer/fecha); no afirma que sea hora de último mensaje. Datos ausentes no muestran null ni inventan actividad.
- Avatar consulta detail(post_id) pública y usa sólo fotos aprobadas. Ausencia/retirada/error usa marcador; lectura protegida se mantiene. Consulta por fila con actualización periódica existente; optimización de payload y validación remota de desempeño pendientes, sin modificar RPC/autorización en este loop.
- Prueba nueva cubre no leídos3/estado cerrado/previsualización y ausencia de null. Suite Flutter132 aprobada; analyze limpio; configuración12 aprobada. Capturador añade chats normal377×852 y320×640/200%.
- Pendientes: contraste navegador con datos equivalentes, foto/avatar en fixture, encabezado de ubicación, búsqueda integrada, vista completa/orden/arte favoritos y rol rescatista. No atribuir paridad global ni aceptación instalada. Codemagic final pendiente de completar objetivo.


## Loop 15 — encabezado Mis match e icono favorito

- Referencia inicio/cierre `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. DonorChromeTop de Mis match no contiene ubicación; se conserva esa diferencia respecto a Adoptar.
- Reemplazado PageFrame genérico por Scaffold blanco, SafeArea y ListView18/16/18/110 con barra flotante; logo huella40 y campana20 en círculo42/borde1.5. Encabezado desplaza con contenido. Botón favorito ahora34 y SVG inline exacto del renderFavCard de referencia.
- Pruebas dirigidas18 + capturador29 estados aprobadas; analyze limpio. Tras copiar path exacto SVG se repite capturador. Sólo presentación; no cambios SQL/identidad/finanzas.
- Capturas loop15 normal/ampliada. Pendientes: contador real de notificaciones (página parcial no prueba total), foto equivalente, búsqueda integrada, vista completa/orden/arte vacío, rol rescatista y navegador. No declarar paridad global ni aceptación instalada. Objetivo y Codemagic final continúan pendientes.


## Loop 16 — vista completa de favoritos

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Se inspeccionaron cuadrícula3/gap10/tarjeta20/nombre13/chat30, volver y ordenar de DonorMessages.
- Ver más abre vista interna con cuadrícula y oculta título/chats. Volver conserva Mis match; fotografía/contacto usan los mismos servicios reales y confirmación. Vista completa consulta todas las páginas de20, deduplica y conserva orden SQL; más antiguos invierte la lista completa, no sólo la primera página. Disponibles únicamente muestran fotos/nombre; guardados retirados conservan gestión en `/saved` desde Perfil.
- Tarjetas tres columnas normales; una al200% para nombres/controles legibles. Orden usa tipografía16/12 y colores ink/muted; espaciado superior corregido tras captura. Sin SQL ni autorización/finanzas modificadas.
- Prueba con21 favoritos comprueba segunda página, orden completo y regreso. Flutter133/analyze aprobados; después de espaciado/color,19 pruebas dirigidas y capturador31 estados aprobados. PNGs loop16 normal/ampliada.
- Pendientes: comparación simultánea navegador/datos equivalentes, gesto Android de regreso de vista interna, arte vacío y búsqueda, contador notificaciones, rol rescatista y rendimiento de listas largas. No declarar paridad global ni aceptación instalada. Codemagic final sigue pendiente del objetivo completo.


## Loop 17 — regreso del sistema y conservación del orden

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios.
- PopScope de Mis match intercepta Atrás sólo cuando está abierta la cuadrícula interna; devuelve la vista principal en vez de abandonar la ruta. Flecha y evento de plataforma comparten showFavorites. ScrollController guarda/restaura offset de la vista principal limitado al contenido vigente.
- Clave estable en MatchFavorites conserva el orden escogido al regresar/reabrir, aunque cambie el conjunto de widgets del encabezado. La consulta pública y su refresco siguen protegidos.
- Prueba nueva usa handlePopRoute y verifica Mis match/Chats; prueba multipágina ampliada confirma Más antiguos al reabrir. Pruebas dirigidas20, suite completa134, analyze y configuración12 aprobados. No nueva captura estática: el cambio es de navegación/estado; no se atribuye gesto físico instalado.
- Pendientes: probar scroll restaurado con contenido largo/dispositivo, Android predictive-back instalado, contraste de navegador, vacío/búsqueda/notificaciones/rol rescatista y rutas restantes. Objetivo global sigue activo; Codemagic final autorizado, pendiente de completar paridad.


## Loop 18 — vacío de favoritos

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Copia composición CSS140×110/tarjetas78×92/radio14/borde3/rotaciones-12° y10° y capa central. Rocky/Toby copiados como arte estático; Luna reutilizada de onboarding. ExcludeSemantics evita presentarlos como publicaciones/personas reales.
- Texto aventura18/1.3/700, ancho que escala con fuente; CTA48 cápsula amarilla15/700, flecha28 y sombra de referencia. Explorar abre catálogo real mediante navegación existente. Vacío no fabrica favoritos ni conteos.
- Prueba nueva confirma vacío sin Ver más y acceso real a Adoptar. Flutter135 y analyze aprobados; tras ajustar ancho ampliado se repitieron21 pruebas dirigidas y capturador33 estados, aprobados. PNGs loop18 normal y320×640/200% desplazado para mostrar CTA. Sólo scratch limpio para regenerar manifiesto de assets; producción/builds locales del titular preservados.
- Pendientes: medir ancho18ch y geometría en navegador simultáneo, fotos equivalentes para listas reales, búsqueda/notificaciones/rol rescatista/rutas restantes y pruebas físicas instaladas. Paridad global no completa. Codemagic final sigue autorizado y pendiente.


## Loop 19 — burbujas del chat

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Leídos Messages/bubble/adopter-chat: ancho78%, padding10/16/8, radios24 y esquina12, tiempo10 y gap14.
- ChatMessageBubble usa remitente real contra repo.userId para alineación; preferencias existentes cambian acento amarillo adoptante/morado rescatista, sin permisos derivados del modo. Entrantes #efede8/#f0eff8; contenido seleccionable. Se quitaron etiquetas repetidas visibles Tú/La otra persona; accesibilidad conserva origen y fecha completa. Hora local procede de created_at, ausencia no inventa hora.
- Envío, idempotencia, retry/cancelar, reconexión, cierre y autorización no cambiados. Pruebas dirigidas21 y suite completa135 aprobadas; analyze limpio; capturador35 estados aprobado, incluyendo conversación ficticia explícita normal377×852 y320×640/200%. PNGs loop19; datos de fixture nunca empaquetados como conversaciones reales.
- Sólo burbujas contrastadas con CSS; encabezado genérico, compositor desplazable y cierre aún difieren del mockup. Próximo ciclo reestructura chat con barra superior y compositor fijo, conserva errores/reintentos reales. Comparación de navegador y teclado/dispositivo pendientes; no declarar chat o paridad global completos. Codemagic final continúa pendiente.

## Loop 20 — compositor fijo y teclado del chat

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Historial desplazable separado de AppBar y compositor fijo; SafeArea y ajuste por teclado conservan acceso al envío. Nombre real de mascota, participante sólo cuando disponible; detalle y cierre usan rutas/RPC existentes.
- Campo multilínea con límite2000, icono send SVG de referencia, botón40/radio14/gap8 y vacío deshabilitado. Reintento ambiguo conserva identificador/cuerpo; cancelar permite editar. Cierre se encuentra en menú y respeta busy. No cambios de permisos, esquema o dinero.
- Prueba nueva confirma compositor sobre teclado300 y envío vacío deshabilitado; fixtures de confirmación actualizados al nuevo encabezado sin alterar condiciones de RPC. Flutter136, analyze limpio, configuración12 y capturador35 estados aprobados. Capturas normal377×852 y320×640/200% inspeccionadas: historial desplaza, compositor permanece accesible.
- Pendientes: comparación simultánea en navegador, medidas exactas de barra/campo/superficies, acento del compositor rescatista, conservación de scroll y teclado físico. No atribuir paridad global ni aceptación instalada. Codemagic final sigue autorizado y pendiente de completar objetivo.

## Loop 21 — medidas renderizadas del chat y modo rescatista

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Vite local y navegador IAB a377×852: TopBar70, compositor77.6, input44.8/padding12×14/radio14, botón40 de ancho. ComputedStyle confirmó burbujas14/21.7 (el párrafo global prevalece sobre contenedor16); se corrige la suposición del loop19.
- AppBar70 con borde por experiencia, título centrado, volver con SVG exacto y Ver detalle12/600/subrayado. Compositor usa borde y padding de referencia; botón alto calculado con fuente para conservar accesibilidad y texto multilineal. Adoptante amarillo/ink; rescatista lila#b995ff/icono blanco; ListenableBuilder reacciona a preferencia real sin conceder permisos. Texto de burbuja14/1.55.
- analyze limpio, Flutter136, configuración12 y capturador36 estados aprobados. Inspeccionadas capturas normal/ampliada y rescatista; datos sintéticos, sin conversaciones reales. Referencias navegador archivadas conservan imágenes/textos propios del mockup y control Modo prueba; no equivalencia de fotos/píxeles afirmada. Campo vacío/deshabilitado y envío sintético en mockup comprobados; envío real/idempotencia cubiertos por suite existente.
- Pendientes: scroll al enviar/recibir/teclado y mensajes anteriores, participante real en payload cuando disponible, menú real de cierre adicional a mockup, adjuntos según alcance autorizado, teclado/gestos instalados y comparación integral de rutas. No declarar paridad completa. Codemagic final continúa autorizado, pendiente del objetivo completo.

## Loop 22 — composición completa de Apoyar

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Vite/IAB377×852: header42/y16, Descubre casos28/1.1/y78, rail126.4/y124.8, Guardian sección y279.2, tarjeta y394.95/h752.8, dock44/y716. Desplazar referencia296px mantiene dockY716; CTA abre `/impact/support` sin confirmar pago. Imagen guardian-urgent.jpg tiene SHA256 idéntico a asset existente.
- SupportHomePage sustituye contenido genérico: logo40/campana42, rail84/gap16/imagen72 con arco4/radio34/cap redondo, nombre13 y importes11 diferenciados. Importes y elegibilidad siguen catálogo real, paginación20 se conserva; no estados ni fotos reales inventados. Ver todos retirado al no existir en referencia; todos los resultados siguen disponibles en rail/paginación.
- Promoción copia título/texto/beneficios e iconos SVG, imagen y degradado, radio superior28, altura y padding; dock sobre navegación conserva ruta real `/guardian`. Barra permanece disponible durante carga/error del catálogo. No nuevos cobros, flags ni permisos. Progreso actual corresponde agregado público del caso, mientras referencia elige una necesidad activa; selección equivalente pendiente, no afirmar equivalencia de importes por necesidad.
- Al200% rail aumenta ancho/alto y dock se integra en la imagen desplazable para evitar texto blanco sobre contenido blanco. Medición tipográfica decide fila/columna del CTA, incluida fuente de pruebas. Captura ampliada desplazada muestra suscripción completa sobre barra. Prueba nueva de vacío/200% abre GuardianScreen, lee estado y comprueba cero activaciones; caso/progreso/gastos reales mantienen prueba existente. Primeras pruebas detectaron overflow del rail0.2 y CTA por fuente Ahem; corregidos. Fixture de preferencias inicializado para cargar estado Guardián, sin modificar su lógica.
- Flutter137, analyze limpio, configuración12 y capturador38 estados aprobados. PNGs normal/ampliada inspeccionados; normal contrastado con referencia renderizada. Cuatro fotos del rail usan fixture Rocky explícito; no comparación de mascotas equivalentes afirmada. No SQL/finanzas modificadas. Pendientes: datos por necesidad, contador real de notificaciones, detalle de caso/galería/perfil público/Guardián, comparación y gestos instalados. No declarar paridad global ni aceptación instalada. Codemagic final continúa autorizado y pendiente.

## Loop 23 — estructura del caso público y galería

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Vite/IAB377×852: hero340/y0, hoja y318/radio28/padding22×20, heading y340, funding y446.95/h59, footer y671.2/h80.8 y blanco100 inferior (igual que detalle Adoptar). Se contrastó primera vista con Rocky equivalente de fixture: foto/hoja/títulos/progreso/categorías/historia/footer muy próximos; control Modo prueba sólo en referencia.
- CaseDetailLayout sustituye lista genérica: hero de ancho completo, PageView con fotos del snapshot aprobado, dots seleccionables y avatar/nombre aprobados que abre perfil real; hoja superpuesta22, SVG compartir/localización/verificación y estadísticas18/13 con iconos36, barra8, tags34, historia18/14/1.55. Botón Donar fijo abre gasto aprobado con remanente; no inicia cobro. Guardar, compartir, reportar y avances actuales preservados debajo, sin fabricar seis fotos como el mock.
- Verificación visual procede del catálogo público, cuyo predicado de fuente exige rescatista verificada/snapshot aprobado. Lectura local de `private.dopmi_rescue_public_visible` y `private.dopmi_expense_payable`: caso y gasto aprobados son necesarios para aportar. Cliente refleja caso cerrado en footer y acción de gasto; controles servidor/Connect/propiedad no modificados. Ninguna nueva verificación remota o autorización monetaria atribuida.
- RescuePublicPhoto separado: URL conservada por widget/path, altura/radio configurables, error mantiene geometría y ofrece reintento real. Prueba detectó callback setState que retornaba Future; corregido a actualización síncrona. Prueba comprueba nueva solicitud, altura340 conservada y swipe a foto2. Otra prueba verifica historia conservada y ambas entradas deshabilitadas en caso cerrado. LiveSection recibe statusFrame opcional sólo para carga/error de caso, con regreso visible; comportamiento predeterminado y descarte por error/revocación intactos.
- analyze limpio, Flutter139, configuración12 y capturador40 estados aprobados. PNGs normal/320×640 al200% inspeccionados; estadísticas se apilan y contenido desplaza al ampliar. Publicación/gesto físico no verificados. Sin SQL, tarifas, mínimo Guardián o flags cambiados.
- Pendientes: tarjetas de gastos/evidencia aún genéricas; diálogo de monto del mock frente a ruta real de aportación actual; paginar todos los gastos de casos con más de20 registros; perfil público/avances y errores equivalentes; fotos posteriores equivalentes, layout/animaciones/gestos instalados. No declarar caso/paridad global completos. Codemagic final continúa autorizado, pendiente del objetivo completo.

## Loop 24 — tarjetas de gastos y evidencia pública

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Contraste de fuente NeedCard/CSS: radio18, icono44/radio14, columna de acción48, padding14, progreso6, chevron20 y evidencia16:10/radio14. Apertura instantánea como referencia; primer gasto aprobado con remanente abierto inicialmente, identidad de widget conserva selección.
- PublicExpenseCard sustituye tarjetas genéricas con categoría/color, progreso e importes reales, título/urgencia del snapshot público aprobado y aportación existente. Estado cerrado/cubierto conserva acción deshabilitada. Sólo public_data.photos alimenta evidencia; nunca archivos privados ni comprobantes de ejemplo. Ausencia aprobada se informa explícitamente, diferencia necesaria frente a imagen simulada del mockup.
- analyze limpio, Flutter139, configuración12 y capturador42 estados aprobados. Pruebas dirigidas9 incluyen capturador y apertura/caso cerrado; selector Semantics ajustado a etiqueta explícita por composición de etiquetas descendientes. PNGs normal377×852 y320×640/200% inspeccionados y archivados. No overflow; importes se apilan con texto ampliado. Emojis no renderizados por fuente de capturador: apariencia Android pendiente, no equivalencia afirmada. Fixture no tiene evidencia pública y no prueba comparación visual de recibos llenos.
- Sin SQL, autorización ni dinero modificados. Pendientes: evidencia aprobada con fotos equivalentes, contraste de tarjeta renderizada en navegador/dispositivo, diálogo de monto, paginación completa de gastos, perfil/avances/Guardián y demás rutas. No declarar caso ni objetivo completos. Codemagic final autorizado, pendiente de completar paridad integral.

## Loop 25 — selector de monto conectado a aportación real

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Fuente DonateAmountDialog/CSS: overlay ink48% centrado/padding16, blanco340/radio24/max88%, padding16/20/22, gaps18, título24/1.2, controles36, presets56/radio14, input52/radio14, CTA52 amarillo. Apertura/cierre instantáneos como CSS; fondo, volver, cerrar y regreso nativo cancelan sin cobro.
- Donar del caso y acción individual abren selector $50/$100/faltante exacto/custom. Centavos se conservan, sin redondear el faltante real. Selección vuelve a ruta protegida existente con amount_cents, semilla validada10–10000/dos decimales y revisión inicial. Nunca crea intento, Checkout ni confirmación al elegir. Restauración existente tiene prioridad sobre semilla y conserva monto/identificador de intento pendiente.
- Diferencias necesarias documentadas: mínimo puntual vigente$10 (decisión$50 sólo Guardián), sin checkbox de costos$0 simulado. Texto informa descuentos reales y revisión Stripe; política/comisión runtime no cambiada. No estimación de costos ni neto inventados. Texto200% apila presets y permite scroll/teclado; selección de faltante independiente aunque coincida con preset.
- analyze limpio, Flutter142, configuración12 y capturador44 estados aprobados. Pruebas nuevas comprueban faltante120025/custom10025 en centavos, importe9.99 deshabilitado, cancelación nula, acceso con320×640/200%/teclado200 y intento guardado7525 prevalece sobre nueva semilla120025 con cero checkout. Primera prueba falló por botón fuera del viewport/falta de pump: corregida usando scroll y render, sin reducir condiciones. Capturas normal/ampliada inspeccionadas y archivadas, sólo fixtures.
- Pendientes: contraste de selector en navegador/dispositivo, teclado físico, pantalla real de revisión/pago/resultados aún genérica, política comercial3% y asignación de costos fijos pendientes de instrumentación autorizada, todos los gastos paginados y demás rutas. No afirmar paridad integral, aceptación instalada ni publicación. Codemagic final continúa autorizado y pendiente del objetivo completo.

## Loop 26 — todos los gastos aprobados del caso

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. El mock presenta todas las necesidades de un caso sin controles de página. La app sólo pedía página1; el RPC público vigente documentado ordena kind/approved_at/id y limita20, incluyendo el propio caso. Se inspeccionó SQL local, sin modificar ni atribuir nueva comprobación remota.
- completeCaseCatalog recorre páginas autorizadas, conserva orden y deduplica por id, y publica el conjunto sólo al terminar. Catálogo Apoyar general conserva su paginación existente. Detalle, tags y selección de gasto ahora reciben todas las necesidades aprobadas; importes agregados siguen siendo los suministrados por servidor. No consultas privadas, nuevos permisos o dinero.
- Fallo de una página descarta resultado parcial mediante LiveSection existente. Revocación con total0 devuelve vacío; página vacía inesperada o cantidad distinta de total tras deduplicar produce error/reintento. No afirmar lectura transaccional: cada página es una consulta independiente; modificaciones concurrentes que conserven total pueden necesitar siguiente actualización. Guardas de autorización del pago siguen en servidor.
- analyze limpio, suiteFlutter144, configuración12 y capturador44 estados aprobados. Pruebas dirigidas10 finales: caso+22 gastos devuelve23 registros, solicita páginas1/2, interrupción/página vacía/duplicado fallan completos, revocación descarta lo reunido. Widget real desplaza hastaGasto22, toca acción y abre selector con$75 real, luego cierra sin Checkout. Sin nueva geometría: capturas44 regeneradas; evidencia visual de loops24/25 sigue aplicando a cada tarjeta/selector, sin atribuir paridad global.
- Pendientes: selector contrastado en navegador/dispositivo, revisión de pago/resultados/Guardián y perfiles/avances, selección por necesidad en Apoyar, urgencia root del RPC frente a snapshot, demás recorridos y animaciones/gestos instalados. Codemagic final autorizado sigue pendiente del objetivo completo.

## Loop 27 — revisión de aportación y contexto público real

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Vite/IAB377×852: TopBar68, mini-case y88/h83.6/imagen58/radio14, Resumen19/1.3/y189.6 con margen inferior15.77, summary y248.06/h186/radio24/padding20/filas13, CTA48/y452.06, secundario48/y518.06. Botones16/600 y gap18. Medición renderizada corrige supuestos de altura/font/line-height de primera implementación.
- ContributionFrame blanco, barra centrada/SVG regreso, cuerpo desplazable16/20/32, mini-case aprobado, resumen con filas alineadas a derecha y adaptación vertical200%, botones cápsula amarilla/blanca. Selector/directo conservan paso de monto con presets50/150/300 y disponible real, campo existente y revisión explícita. Regreso de revisión vuelve al monto; intento bloqueado conserva su salida e identificador. Estado de pago/errores/consulta/historial/disponibilidad preservados; ninguna lógica de Checkout/idempotencia/flags/servidor alterada.
- Enlaces desde caso/gasto incluyen case público. Funding sigue fuente de disponibilidad; se carga catálogo autorizado y sólo añade nombre/foto si hay un gasto coincidente y parent_id correcto. Error de contexto o case ajeno conserva funding y omite caso/foto, nunca usa fallback de otra mascota. Mini-case sin contexto conserva título del gasto con icono neutro. Método dice En Stripe, sin Visa4242 simulada. Texto de prueba/descuentos y métricas reales sigue bajo acciones; runtime2% preservado hasta instrumentar decisión comercial3% y atribución de costos fijos, sin inventar tarifas.
- Comparadas capturas normal con Rocky/Cirugía100 equivalentes: hoja/resumen/CTA se aproximan a referencia; filas se alinean y monto entero no inventa decimales, conserva centavos cuando existen. Primeros PNG detectaron pérdida de Inter en ButtonStyle (Ahem de pruebas), corregida a fontFamily explícita, también evita fallback diferente en app. Diferencias necesarias de método/confirmación/notas financieras documentadas. Alineación exacta de header/bordes aún tiene pequeñas diferencias y no se afirma pixel parity.
- SuiteFlutter146 aprobada; cambios finales de lint sin comportamiento luego dirigidas8 y analyze limpio; configuración12 y capturador48 estados aprobados. Pruebas nuevas validan caso real frente a case ajeno, importe10025 y método real, cambiar monto sin Checkout; reintento pendiente e idempotencia anteriores pasan. Capturador requirió SharedPreferences sintéticas por restore async; inicialización limitada al archivo flutter_test con ignore scoped de API visibleForTesting, no producción. PNGs normal y320×640/200% inspeccionados/archivados; fuente, tamaños y scroll adaptados. Vite/tab cerrados y viewport restaurado. Ningún pago real, publicación instalada o aceptación visual atribuidos.
- Pendientes: resultados de pago/historial/Guardián aún genéricos, header/bordes/gesto/teclado instalados, caso/perfil/avances/urgencia y selección por necesidad en Apoyar, recorridos completos restantes. Codemagic final continúa autorizado y pendiente de paridad integral.

## Loop 28 — resultados de aportación con evidencia del servidor

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. Vite/IAB377×852: success icon64/y237.41/margen14, h124/1.25/h60, párrafo14/1.55, gaps12 y márgenes reales; CTA48. Error: TopBar68, padding40/20, círculo96/y108/borde3, SVG48, h124/y222 y summary24. SVG check/payment-card-error copiados íntegros del mock. Tabla de estilos y capturas renderizadas archivadas.
- PaymentResultPage sustituye tarjeta genérica por confirmación centrada sin barra, cancelación con marco Pago no completado y variantes pendientes/devueltas veraces. Sólo checkOutcome con fila de history que coincide por idempotency_key establece resultado; elegir monto, abrir Stripe, seed o preferencia local no confirman pago. Gross/allocated/transfer aparecen sólo cuando vienen en fila, sin monto desconocido0 inventado. Confirmado informa asignación neta/transferencia real, sin afirmar que todo bruto ya fue asignado/depositado. Nombre/enlace de caso se conservan sólo desde catálogo público validado por gasto/parent_id.
- Pendiente conserva identificador y sólo consulta resultado/historial; no nuevo intento desde esa vista. Cancelado autoritativo puede abrir una nueva revisión: navegación no cobra; confirmar explícitamente genera UUID distinto porque el terminal se liberó por lectura existente. Confirmado/devuelto no ofrecen reintento. Error de red/Checkout ambiguo conserva flujo anterior y UUID estable, sin hacerse pasar por cancelación. Comprobación, medición, guardas servidor y flags no se cambiaron.
- SuiteFlutter150 y configuración12 aprobadas; después de ajustar jerarquía visual del botón Historial, analyze limpio y dirigidas11 (incluye capturador) aprobadas. Cuatro pruebas nuevas comprueban confirmado/pending/canceled/refunded procedentes del repo, ausencia de éxito en otros estados, neto9200/transfer pending, consulta sin nuevo checkout y cancelación→revisión sin cargo→confirmación nueva con UUID distinto. Recuperación ambigua anterior sigue reutilizando su UUID.
- Capturador53 estados aprobado y PNGs normal/200% inspeccionados. Primeras capturas omitieron SVG por manifest de assets cacheado; precarga estricta descubrió recursos ausentes del bundle, Flutter clean sólo en scratch regeneró manifest y capturas finales muestran ambos iconos. No se ocultó error de recursos. A texto200% el contenido/acciones desplazan. Datos10000/9200 de fixture explícito, no transacciones reales. Vite/tab cerrados y viewport restaurado.
- Diferencias necesarias frente al mock: método/tarjeta ficticia omitidos, estado Cancelado sin cobro en lugar de fallo simulado, neto/transferencia/aviso test y consulta para incertidumbre. Textos reales y métricas cambian altura/centrado; no afirmar igualdad de píxeles ni prueba instalada. Pendientes: badges/error/scroll/gestos físicos, lookup de intento todavía limitado a primera página20 de historial, historial/Guardián y demás rutas completas. Codemagic final autorizado sigue pendiente de completar objetivo.

## Loop 29 — resultado exacto fuera de la primera página de historial

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. El flujo real de resultado se quedaba sin encontrar intentos antiguos al consultar sólo history1/20; no cambia composición ya contrastada en loop28. Se preserva el resultado del procesador, no la simulación inmediata del mock.
- PaymentRepository.outcome consulta directamente la fila por donor_id del usuario autenticado, expense_id y idempotency_key, con maybeSingle. Anónimo falla antes de HTTP. La recuperación no recorre historial ni depende de fecha/página/mode elegido; historial recibido y permisos de PostgreSQL conservados. Fuente SQL local: SELECT sólo authenticated, RLS actor activo y participante, unique(donor_id,idempotency_key). No SQL ni permisos/migración/conexión remotos modificados o atribuidos como verificados.
- checkOutcome usa lookup exacto, limpia error anterior al consultar y descarta resultado cacheado si no encuentra evidencia; no interpreta ausencia como éxito/cancelación ni libera intento. Mediciones, liberación terminal e idempotencia anteriores se preservan. Aviso de incertidumbre mantiene mismo intento y pide consultar sin nueva aportación.
- analyze limpio, Flutter155, configuración12 y capturador53 estados aprobados. Pruebas de SDK real con MockClient/JWT sólo sintéticos verifican URL/tabla/filtros de actor/gasto/key, una consulta sin offset, fila7525/ausente/403 y rechazo anónimo sin red. Mock inicial omitía response.request requerido por postgrest2.9.1; corregido al contrato HTTP, sin debilitar afirmaciones. Prueba de widget restaura intento antiguo ausente de20 recientes, consulta resultado, muestra asignación7000 y libera key terminal con cero checkout. Casos ambiguos/cancelados/confirmados/refund anteriores pasan.
- Sin nueva geometría; capturas53 regeneradas con fixtures, evidencia visual de loop28 conserva vigencia para estados equivalentes. RLS real de esta consulta no se ejercitó contra remoto, sin declarar aceptación instalada. Pendientes: historial UI/Guardian, todos los recorridos/gestos, estados nulos/403 instalados y demás diferencias globales. Codemagic final continúa autorizado, pendiente de paridad integral.

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

## Loop 30 — historial compacto con comprobantes reales

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. App.tsx History y styles.css profile-activity-row: columnas52/1fr/auto, gap10, padding12/14, altura mínima64, radios20, fecha12, título14, importe13 y pill11/padding3/9. Sin nueva simulación de cobros.
- Historial usa barra Mi historial, explicación y lista compacta; fechas/importe/estado vienen de cada fila autorizada. Métodos muestran Stripe sólo cuando processor=stripe; falta de datos no inventa tarjeta ni importe. Confirmed/pending/canceled/refunded se muestran Pagado/En proceso/Cancelado/Devuelto.
- Tocar fila despliega comprobante real, referencia, costos, neto, devolución, transferencia y continuación sólo de pendientes enviados. Detalles permanecen dentro de pantalla protegida por identidad; no se cachea comprobante en un modal que sobreviva al cambio de actor. Filtro recibido, refresco, paginación, Guardián y Connect conservados bajo lista. Ningún cambio de consultas/RLS/cobros.
- Flutter158 y configuración12 aprobados; analyze limpio. Después del ajuste de interlineado, dirigidas3 más capturador aprobado (56 estados). PNG normal/320×640 a200% y vacío archivados; primera captura tenía filas72, corregido interlineado1.2 a filas64 aproximadas. Texto ampliado cambia a columnas verticales sin overflow.
- Diferencias necesarias: método real, títulos de gasto públicos disponibles y comprobante expandible en lugar de inventar mascota o navegación desde un account_id de Stripe. Pendientes: integrar movimientos reales de Guardián al historial común, perfil de barra, comparación renderizada exacta/gestos instalados y resto del alcance global. No se afirma paridad integral ni aceptación instalada. Codemagic final autorizado sigue pendiente de completar objetivo.

## Loop 31 — historial común con ciclos reales de Guardián

- Referencia Irlanda inicio/cierre `a3c969cd9103fd46dc5cd886999912526ce75efb`, sin cambios. History une suscripciones antes de aportaciones; reproducción del HTML en IAB377×852 confirma barra68, texto y88/h21.7, margin-bottom14 y gap12: lista y135.7. Filas64/padding12/14, separador~0.8 a zoom del navegador, x16.8. Se corrigió separación Flutter12→26; captura final lista y135. No se afirma identidad absoluta de rasterización.
- Primera página enviada reúne la página20 puntual y primera página autorizada de dopmi_guardian_history en lecturas independientes concurrentes. Flag Guardian apagado o filtro recibido/página puntual posterior no consulta ciclos personales. Cursor real permite ir a historial paginado de ciclos; no se inventan fechas, método ni transacciones. Si falla una fuente se presenta error de consulta, no historial vacío ficticio; refresco conjunto sigue accesible.
- Suscripción muestra Pagado sólo assigned/transferred con paid_cents positivo. Processing/omitido/not_paid/refund tienen estados distintos: En proceso/Sin cargo/Sin pago/Por devolver/Devuelto/En conciliación/En revisión. Importe sin pago se identifica como autorizado; confirmado usa paid_cents real. Activación mantiene etiqueta específica. No se muestra Visa4242 ni ApplePay ficticios.
- GuardianCycleReceipt extrae sin cambiar reglas el detalle financiero anterior: fechas, importe autorizado/confirmado, tarifas/neto/transferencias, devoluciones parciales/conciliación/reversión, motivo de omisión y revisión. Asignaciones se cargan al abrir su control por RPC autorizado, con paginación y descarte de actor anteriores. Ruta de ciclos conserva sus detalles visibles; historial común los despliega al tocar fila. Private cycles no se suscriben como tabla pública Realtime; el RPC refresca con sección puntual. No SQL/RLS/servidor/cargos cambiados.
- analyze limpio, Flutter162 y configuración12 aprobados. Nuevas4 pruebas comprueban orden de ciclos/puntual, importe7525, carga de asignaciones sólo bajo acción, cero cargos, omitido sin éxito, filtro recibido sin ciclos/reanudar y flag apagado sin lecturas; respuesta tardía del actor anterior no aparece. Diez regresiones de historial Guardian pasan. Primera extracción tenía separador Dart inválido, corregido; prueba de asignación detectó Ink/ListTile detrás de DecoratedBox, sustituida superficie por Material con mismo borde/radio, sin suprimir aserción. Test de respuesta pendiente usa pumps acotados en vez de settle sobre spinner infinito.
- Después de margen/etiqueta final, dirigidas4 + capturador56 aprobados. Capturas normal/200%/vacía comparadas y archivadas junto a referencia renderizada. Fixtures incluyen ciclos pagado/omitido/pending explícitamente sintéticos. Filas compactas y texto ampliado legibles, sin overflow. Vite/tab temporales cerrados y viewport restaurado.
- Pendientes: botón/perfil de encabezado, regreso/scroll instalado, más de20 ciclos requiere ruta existente, composición de esa ruta y pantallas de alta/gestión Guardian, error independiente por fuente y todas las rutas/gestos globales. Datos/tarjeta/número de filas distintos por fuentes reales; no atribuir aceptación instalada. Codemagic final autorizado sigue pendiente de completar objetivo integral.
