# Sincronización del mockup — protocolo estable

Leer primero [mock-sync-current.md](mock-sync-current.md), luego este protocolo.
El checkpoint contiene el estado vigente; [parity-current-review.md](parity-current-review.md)
es el único tablero del lote. [progress.md](progress.md) conserva el historial,
no una lista de tareas para reejecutar. Las entradas nuevas superseden pendientes antiguos.

## Perfil vigente: ENTREGA_CONTINUA_EFICIENTE_VERIFICADA (8/10/2026)

Decisión expresa del titular: ejecución continua sin presupuestos, cuotas ni
renovaciones. Supersede límites temporales/contadores históricos y el perfil
MVP_CONTINUO; conserva decisiones de negocio, autorización y gates obligatorios.
Los lotes organizan el trabajo; no requieren renovar autorización de lo ya
aprobado. Un cierre documental no autoriza funcionalidades ni nuevas referencias.

Congelar un SHA autorizado, inventariar una vez grupos funcionales y avanzar
con una cola Flutter. Corregir diferencias perceptibles, gestos y estados reales;
no microajustes imperceptibles ni ingeniería innecesaria. Reutilizar evidencia
válida y repetir sólo bloques invalidados por un cambio/fallo nuevo. CI/Codemagic
siguen ejecutando sus gates obligatorios. Documentación sola no reinicia pruebas.

Revisión de eficiencia, UI, UX, código y seguridad debe quedar explícita con
su alcance, evidencia, hallazgos y límites. Una suite verde no sustituye revisión
visual ni aprobación humana. No atribuir auditoría independiente o aceptación
sin evidencia. Las cuatro perspectivas, integración real y recorridos finales
instalados forman parte de la entrega; no posponer QA ordinario ni convertir
requisitos obligatorios en mejoras opcionales al cerrar.

Ante falta de progreso: diagnosticar la causa y cambiar de estrategia; no
repetir auditorías globales ni polling de terminales. Subagentes sólo si están
autorizados y aportan una revisión concreta, con propiedad y sin colas Flutter
paralelas. Builds sólo para candidato aprobado o corrección justificada; una
espera/timeout nunca justifica duplicarlos. Verificar el mismo handle vivo.

Separar implementado, verificado técnicamente, publicado, probado en dispositivo
y aprobado por titular/diseñadora. Cerrar integralmente sólo cuando todos los
criterios obligatorios estén probados; si falta evidencia/permisos/dispositivo,
cerrar el chat con entrega pendiente y acción exacta, conservando último corte
implementado/verificado por grupo. QA posterior no equivale a aprobación.

Checkpoint corto para continuidad, tablero único para matriz de evidencia,
progress como ledger con enlaces; no replicar historial en handoff/checkpoint.
Conservar cambios ajenos y privados. Registrar SHA de producto y documentación
por separado, jobs externos y pruebas aún pertinentes. Commits documentales
con [skip ci], push y comprobación remota. No publicar secretos, datos o builds.

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

## Entrega por lotes y agentes

1. Verificar HEAD, remoto, PR, dirty tree y acceso existente. No reset, `add .`,
   limpieza global ni apropiarse de cambios de otro trabajo.
2. Inventariar **grupos funcionales**, no cada margen. Una inspección completa
   por lote: parte inferior, vacíos/errores, gestos y datos equivalentes.
3. Subagentes acotados, cuando el encargo lo autorice y aporten valor.
   Propietarios exclusivos por archivo/prueba antes de editar. Extraer archivos
   compartidos primero si hace falta. Integrador controla router, DTO/RPC,
   repositorios, SQL y componentes compartidos. Agentes no ejecutan Flutter,
   despliegan ni publican. Una sola cola Flutter.
4. Contratos aditivos primero; inspección paralela, luego implementación agrupada.
   Una ficha por lote enlazada desde tablero. Informar N→M grupos, defectos
   demostrados y pruebas/nativo pendientes.
5. Durante cada lote: implementar, autorrevisar diff, ejecutar pruebas dirigidas
   agrupadas y comparar UI/interacciones reales, corregir y registrar checkpoint.
   Fuente congelada y Flutter con fuentes cargadas, dimensiones/datos equivalentes;
   normal, Samsung115% y320px/200%. Capturas no acreditan movimiento: obtener
   evidencia temporal de disparador, curva/duración, cancelación y resultado.
   Diferencias perceptibles son defectos; el diff de imágenes sólo los localiza.
6. Correcciones agrupadas sobre defectos demostrados. Un fallo persistente exige
   reproducción y diagnóstico específico, nunca otra auditoría global. Reabrir
   lote cerrado sólo por defecto nuevo demostrado/dependencia modificada.
7. Reutilizar mecánicas ya aprobadas (navegación, entrada, swipe, carrusel,
   galería, horizontal, toque frente a scroll, switches). Añadir cobertura sólo
   de comportamiento nuevo, persistencia, aislamiento/concurrencia y negativos.
8. Antes de publicar: revisión independiente integrada desde UI/UX/código/
   ciberseguridad y regresión consolidada proporcional, junto con los gates
   obligatorios del pipeline. Reutilizar sólo bloques equivalentes; una corrección
   invalida evidencia afectada. No debilitar aserciones, aceptar goldens sin contraste
   ni duplicar runners cuando CI equivalente ya acredita el criterio.
9. Codemagic android-guardian-internal, publicación Play Internal, actualización
   desde Play y recorridos del teléfono son puertas distintas de esta entrega.
   Un binario nuevo requiere prueba de su versión instalada; emulador/APK local
   complementan, no reemplazan. Fixtures nuevas con inventario exacto desde creación;
   nunca consumir las cerradas ni borrar evidencia financiera para limpiar.
10. Ante la misma firma de fallo sin información nueva: detener esa estrategia,
    reducir reproducción y cambiar método según hipótesis/evidencia. Mantener el
    mismo job/buildId ante demoras; una observación fallida no demuestra parada.
    Completar trabajo independiente ante bloqueo, registrar espera y detener el
    trabajo dependiente. Sólo intervención material/acceso/permiso realmente nuevo.

## Autorización vigente del corte dde1bb9

Plan completo aprobado el8/10: implementar N01–N11 y QA pendiente UX01–07/09.
Commits/push propios en codex/design-foundation y PR6; sin merge/force-push.
DEV no destructivo identificado en plan: perfil público/contactos moderados,
feedback, historial unificado, notificaciones y adjuntos privados; preflight SQL/
historial y postflight reales antes/después de cada migración aditiva.
Contacto público requiere campos dedicados, consentimiento expreso y snapshot
aprobado; retirar consentimiento oculta contactos inmediatamente. Cambios editan
sólo nueva versión pública, no identidad/Connect. SMS real Twilio/Supabase:
configuración y costo operativo esperan acceso/aprobación concreta; no simular OTP.
Excepción acordada: titular cambia temporalmente a cuenta QA en Samsung y restaura
su cuenta; sin clear data y sin automatizar credenciales/login. ADB no accede a
Carpeta Segura por Knox: no intentar eludir esa protección.
Una revisión de eficiencia ya realizada fija contratos antes de consumidores,
cohorte compartida nueva y una ventana final del teléfono; reinvocarla sólo por
bloqueo/dependencia/retrabajo demostrado. No mantener supervisor continuo.

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
