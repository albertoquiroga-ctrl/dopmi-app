# Sincronización del mockup — protocolo estable

Leer primero [mock-sync-current.md](mock-sync-current.md), luego este protocolo.
El checkpoint contiene el estado vigente; [parity-current-review.md](parity-current-review.md)
es el único tablero del lote. [progress.md](progress.md) conserva el historial,
no una lista de tareas para reejecutar. Las entradas nuevas superseden pendientes antiguos.

## Perfil vigente: MVP_CONTINUO (aprobado 6/10/2026)

La decisión del titular sustituye las puertas históricas de QA durante la fase
MVP. Entregar todo el delta esencial congelado con funciones reales, conservando
diseño, navegación y gestos esenciales. El gate consolidado obligatorio debe
aprobar; el candidato queda pendiente de QA. Los lotes organizan el trabajo:
no son nuevas autorizaciones ni paradas. Mantener negocio, seguridad y pipeline.

Inventariar una vez la entrega completa e implementar lotes consecutivos, con
comprobaciones focalizadas cuando aporten valor. No exigir suites completas,
capturas por cambio, auditoría independiente ni QA del lote anterior para
avanzar. Auditoría profunda y del delta, comparación visual exhaustiva,
regresión adicional, emulador y aceptación instalada permanecen como
**fase de QA posterior**. Las suites y capturas exigidas por CI/Codemagic
siguen siendo obligatorias.

Esta ejecución dispone de 90 minutos globales de tiempo real, incluidos
subagentes y esperas. Desde el minuto 80, dedicar el tiempo al checkpoint y
cierre. Hasta tres subagentes simultáneos y seis invocaciones nuevas por tramo,
sin recursión y con archivos de propiedad exclusiva. El integrador controla
contratos, router, repositorios, SQL, compartidos y la única cola Flutter.
Máximo dos pasadas de corrección por lote y dos intentos por causa; conservar
los contadores entre lotes y sesiones. Dos rondas sin progreso verificable
requieren diagnóstico y trabajo independiente. Hasta dos builds Codemagic:
candidato consolidado y corrección justificada; nunca por lote ni por estar
en cola. No renovar el presupuesto sin autorización explícita.

Guardar el plan aprobado antes del código. Actualizar un checkpoint corto tras
cada lote y antes de operaciones externas, separando implementación,
comprobación, publicación y aceptación. Registrar QA y pulido pendientes,
tiempo, agentes, builds, causas, evidencia y siguiente acción. No crear otro
protocolo, backlog ni tablero. Conservar cambios locales ajenos y versionar
solo los propios. No reutilizar fixtures ni helpers de entregas consumidas.

Parada efectiva: comandos largos con PID propio y timeout real limitado al
tiempo restante; esperas de hasta 60 segundos y terminación del árbol propio
al vencer. Yield no equivale a timeout. Interrumpir agentes al cierre y no
crear Goal, heartbeat ni loop autorreanudable para esta cadena. Si existe un
objetivo persistente, pausarlo bajo la autorización de parada del titular al
agotar el tiempo o quedar sin trabajo independiente. Registrar trabajos
remotos activos y siguiente consulta, sin polling indefinido. No atribuir al
cliente un supervisor global que no expone.

## Invariantes conservadas

- Corregir diferencias **perceptibles**, animaciones y gestos móviles. Aceptar
  diferencias imperceptibles del renderizador. Hover excluido. Español mexicano,
  colores/activos Dopmi, Inter/Fraunces locales y contraste accesible.
- Mockup React `src/` es referencia; producto real en `apps/` y `supabase/`.
  Comparar contra un SHA congelado por entrega, nunca absorber nuevos pushes
  silenciosamente. Registrar la rama viva al inicio/cierre; un cambio posterior
  pasa al próximo inventario autorizado.
- Preservar funciones reales, identidad, adopción, mensajes privados, moderación,
  evidencia, Connect, aportaciones y Guardián. Dinero **exclusivamente test**;
  no tienda, videos, fondo comunitario, bonos, cashback ni analítica avanzada.
- Modo Rescatista no concede permisos. Autorización en PostgreSQL; nunca metadata
  editable. Borradores/correcciones privados, snapshots públicos sólo aprobados.
  Apoyo aprobado no editable por su autor. Cierre/archivo conserva expediente
  y guardas financieras; confirmar sólo después del éxito real del servidor.
- Métricas mínimas privadas: personas únicas consentidas, tarjeta frontal
  efectivamente mostrada, sin precarga/propietario/reconstrucción ni históricos
  inventados. Leer chat no equivale a responder. Necesidades visuales
  Veterinario→Medicina→Comida→Otro no cambian prioridad financiera.
- Adopción: nueve personalidades centralizadas, hasta tres nuevas selecciones,
  rasgos históricos preservados, convivencia explícita y edad categórica elegida;
  nunca deducir clasificación histórica. Seis fotos privadas (principal+cinco).
  Contacto nuevo envía un único saludo transaccional; hilo existente no reenvía.
  Preview usa renderizadores reales sin escrituras/acciones públicas.

## Loop finito y agentes

1. Verificar HEAD, remoto, PR, dirty tree y acceso existente. No reset, `add .`,
   limpieza global ni apropiarse de cambios de otro trabajo.
2. Inventariar **grupos funcionales**, no cada margen. Una inspección completa
   por lote: parte inferior, vacíos/errores, gestos y datos equivalentes.
3. Máximo tres subagentes más integrador, cuando el encargo lo autorice.
   Propietarios exclusivos por archivo/prueba antes de editar. Extraer archivos
   compartidos primero si hace falta. Integrador controla router, DTO/RPC,
   repositorios, SQL y componentes compartidos. Agentes no ejecutan Flutter,
   despliegan ni publican. Una sola cola Flutter.
4. Contratos aditivos primero; inspección paralela, luego implementación agrupada.
   Una ficha por lote enlazada desde tablero. Informar N→M grupos, defectos
   demostrados y pruebas/nativo pendientes.
5. En MVP, pruebas dirigidas sólo cuando aporten valor; recaptura afectada si es
   necesaria. En QA posterior, comparación Source/Flutter con
   fuentes cargadas, dimensiones y datos iguales; normal, Samsung115% y320px/200%.
   Diff de imágenes localiza problemas; decisión de cierre perceptual.
6. Máximo **dos pasadas agrupadas** de corrección. Un fallo persistente exige
   reproducción y diagnóstico específico, nunca otra auditoría global. Reabrir
   lote cerrado sólo por defecto nuevo demostrado/dependencia modificada.
7. Reutilizar mecánicas ya aprobadas (navegación, entrada, swipe, carrusel,
   galería, horizontal, toque frente a scroll, switches). Añadir cobertura sólo
   de comportamiento nuevo, persistencia, aislamiento/concurrencia y negativos.
8. Gate obligatorio agrupado del candidato MVP; repetir sólo bloque invalidado
   tras fallo/cambio. Auditoría independiente y regresión integral adicional son
   QA posterior. Documentación sola no reinicia gates; capturas no prueban funciones.
9. Emulador y Samsung son QA posterior, salvo necesidad concreta de implementación.
   Fixtures nuevos se inventarían desde su creación; nunca consumir los cerrados.
   Codemagic sólo candidato consolidado aprobado (o corrección justificada);
   compilar, publicar Play y comprobar Samsung son puertas separadas.

## Comandos y herramientas comprobados (no ejecutarlos automáticamente)

Desde raíz, PowerShell; rutas del host actual, comprobar existencia en otra máquina:

```powershell
git status --short
git branch --show-current
git ls-remote origin refs/heads/codex/design-foundation refs/heads/codex/Dopmi
git ls-remote https://github.com/albertoquiroga-ctrl/dopmi-functional-mockup.git refs/heads/irlanda/apoyar-detalle-perfil
$flutterExe = 'C:/Users/betoq/dopmi-functional-mockup/.tools/flutter/bin/flutter.bat'
$adbExe = 'C:/Users/betoq/dopmi-functional-mockup/.tools/android-sdk/platform-tools/adb.exe'
```

- `apps/mobile`: `flutter analyze`, `flutter test`; dirigidas por archivo.
  Capturador existente:
  `flutter test tool/capture_profile_test.dart --dart-define=CAPTURE_FILTER=bccd-`.
  `CAPTURE_FILTER` usa `String.fromEnvironment`: variable de entorno sola **no**
  lo alimenta. Elegir prefijos reales; exige al menos una pantalla. Output
  relativo a mobile: `../../.tools/design-review`. `capture_design_test.dart`
  y `capture_profile_test.dart` son herramientas canónicas, no recrearlas.
- `apps/admin`: `npm test`, `npm run build`; `tools/verification`: `npm test`.
  Raíz: `python scripts/test_mobile_config.py` (CI usa `python3`).
- Gate reproducible [.github/workflows/milestone-1.yml](../.github/workflows/milestone-1.yml):
  scope `full` integral, `mobile` **toda** suite móvil/capturas/APK, `photo`
  subconjunto de fotos/motion. CI incluye PostgreSQL real, permisos y concurrencia
  de Guardián/contacto; no sustituirlos por PGlite. macOS/iOS usa CI.
- Windows: scratch caliente usado
  `C:/Users/betoq/AppData/Local/Temp/dopmi-parity-20260930/mobile`;
  output scratch `C:/Users/betoq/AppData/Local/Temp/.tools/design-review`.
  Si se reutiliza, sincronizar **archivos afectados desde rutas absolutas**,
  comprobar equivalencia con candidato y no capturar copia vieja.
- Codemagic API existente: token local de usuario `CM_API_TOKEN`, nunca imprimir.
  Helper privado `.tools/bccd-native/codemagic.ps1 status` sólo entrega bccd;
  `submit` tiene diario anti-duplicado, **no reutilizarlo para nueva entrega**.
  Workflow `android-guardian-internal`, paquete `com.mycompany.dopmi`, firma
  existente. `android-internal` desactiva Guardian; flags servidor separados.
  Publicación exige log/consulta `google-play tracks get --track internal
  --package-name com.mycompany.dopmi`, no sólo build finished.

## Teléfono: ADB, sin controlar Windows

```powershell
& $adbExe devices
& $adbExe -s R5CY51260VK shell dumpsys package com.mycompany.dopmi
& $adbExe -s R5CY51260VK shell settings get system font_scale
& $adbExe -s R5CY51260VK shell uiautomator dump /sdcard/dopmi-review.xml
& $adbExe -s R5CY51260VK pull /sdcard/dopmi-review.xml .tools/bccd-native/samsung-ui.xml
& $adbExe -s R5CY51260VK shell screencap -p /sdcard/dopmi-review.png
& $adbExe -s R5CY51260VK pull /sdcard/dopmi-review.png .tools/bccd-native/samsung-review.png
```

Samsung SM-S938B/Android16:1080×2340, serial R5CY51260VK; coordenadas del XML
original, no de la imagen redimensionada. Etiquetas Flutter generalmente en
`content-desc`, no `text`. Tap/swipe/keyevent4 via `shell input`; observar XML
fresco después de acciones. No reutilizar XML si dump falla/null root.
Verificar paquete/foreground: usuario puede cambiar app durante revisión.
No repetir gestos ciegos. Teclado: `dumpsys input_method`, comprobar UI tras
animación; un primer flag true después de Back no prueba fallo.
Preservar sesión, modo y escala originales; no logout/clear data de cuenta real,
mensajes de prueba ni edición de sus borradores. Usar fixtures controladas en
emulador para operaciones que su cuenta no ofrece, y declarar ese alcance.
`emulator-5554` no sustituye al teléfono. Debug QA no es Play aunque comparta código.

## Backend y limpieza

DEV `ohqxranynackjignryep`; no interpretar etiqueta genérica main/PRODUCTION
del dashboard como proyecto financiero autorizado. Consultar
[migration-history-audit.md](migration-history-audit.md) y
[legacy-retirement.md](legacy-retirement.md) antes de schema remoto.
Preflight: historial **y cuerpos SQL**; aplicar una vez/postflight. Timestamps
local/remoto distintos son conocidos: nunca replay, rename, repair ni db push
para igualarlos. Leer skill Supabase vigente. Reutilizar MCP autorizado;
no claves en chat, commits o logs.

Fixtures: IDs/patrones exactos, digest de inventario, ausencia de referencias
financieras y filas inesperadas; retiro RPC, Storage API, transacción DB y
postflight cero. Nunca borrar metadata Storage por SQL. No resetear estados,
desactivar guardas ni eliminar evidencia financiera para facilitar cleanup.
El archivo QA aprobado/cerrado no se pudo borrar con JWT autor: la sesión
administrativa existente de Supabase Dashboard sí lo retiró, sin clave nueva.
El dashboard crea `.emptyFolderPlaceholder`; retirar sólo las carpetas QA
vacías verificadas y volver a contar. Conservar singleton de fecha de medición.

## Fallos conocidos: diagnóstico acotado

- SQL `40001` manual puede provocar reintentos PostgREST14/timeouts. Nuevas RPC
  bccd usan `PT409`; wrapper de cierre apoyo delega función legacy sin alterar
  guardas/build295. No reintroducir40001 ni aplicar esa solución globalmente.
- Runner Node/red falló después de checkpoints: puente privado `request.ps1`
  con `DOPMI_QA_POWERSHELL_HTTP=1` funcionó; parsear `raw_text` JSON en Node.
  Reanudar sólo bloques pendientes y reconciliar respuesta incierta antes de retry.
- Tests heredados fallaron por textos/datos anteriores, no producto. Corregir
  fixture tras contraste Source; nunca debilitar aserciones para verde.
  Capturas owned-cases deben seleccionar **Apoyo** para sus fixtures antiguas.
- Gestos de tests: `ensureVisible` + `pumpAndSettle` antes de tap; no atribuir
  control fuera de viewport a defecto UI. Copia scratch desactualizada es otro
  fallo de harness, no motivo para rehacer lote.
- PowerShell/UTF8: lectura/escritura explícitas; Python consola cp1252 puede
  deformar tildes. No interpolar secretos, backticks o `$()` en shell.
- `22then` en SQL de cleanup produjo error de parseo, sin escrituras; añadir
  espacio y conservar transacción/guards. No ejecutar scripts antiguos de
  staging masivo (`.tools/stage-bccd.py`) ni planes de cleanup ya consumidos.
- CM queued no acredita build/Play; reconsultar **mismo buildId**, nunca crear
  duplicado por demora. Sin autorización específica no enviar soporte/email.
- Private proof anterior puede decir `mobile_pending:true`: el gate posterior
  es la autoridad. Siempre ordenar evidencia por SHA/run/fecha, no un flag viejo.

## Documentación/versionado

Checkpoint corto con hechos, alcance aceptado, evidencia y próxima acción;
historia extensa queda en progress/fichas. Publicar sólo documentación propia
autorizada. En archivos ya dirty, formar index desde HEAD + modificación propia,
preservando working copy ajena. Verificar `git diff --cached --check/--stat`;
commit documental `[skip ci]`, push y comparar remoto. No afirmar que rutas
privadas ignoradas están en GitHub. No secretos, datos de personas ni builds.
