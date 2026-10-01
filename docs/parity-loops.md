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
