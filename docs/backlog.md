# Correctivo vigente — Tienda, 24/nov/2026 CDMX

Dos diferencias de Irlanda corregidas: sin bloque extra bajo banner Amazon y
foto/borde de tarjetas grises. Referencia d9f9aa43 y producto previo conservados.
Producto dbac483b/tagcodex/store-irlanda-correction-20261124, CI45438832854 cuatro
SUCCESS.23 pruebas de Tienda/analyze/capturas aprobadas y revisión independiente
sin P1/P2. [Candidato y recibos](candidate-release-current.md).

Android442: AAB/firma/configuración y publicación interna verificados. iOS443:
IPA/configuración/carga verificados; posproceso Apple finished/error=false18:11UTC.
Un envío por plataforma, ninguna build o lectura larga activa. No repetir builds,
reservas o descargas. Sin publicación pública del correctivo.

Pendientes finitos: root verifica canales y actualización/portada/tarjetas/aviso
antes de Amazon cuando el titular conecte Samsung; titular revisa y acepta o señala
el delta. Ya dijo que lo conectará después; conservar sesión y preferencias. La
disponibilidad en el grupo TestFlight y QA física iOS tampoco están acreditadas.
Sin nueva fuente, esquema, servicio, campaña ni aceptación humana por inferencia.

# Cola vigente — Tienda de Irlanda, 23/nov/2026 CDMX

Seis grupos implementados: cabecera/banner, especie/búsqueda/orden, filtros,
tarjetas, kit y detalle. Referencia d9f9aa43 sólo Tienda; base fe378773/b471
conserva Android439 y mantiene fuera el Admin pendiente.
[Plan](superpowers/plans/2026-11-23-store-irlanda.md),
[candidato y recibos](candidate-release-current.md).

Producto97af3893/tagcodex/store-irlanda-97af3893, CI45262749872 cuatro SUCCESS;
analyze limpio, 2125 Flutter PASS/4 SKIP y 39 dirigidas PASS. Capturas del perfil
real con cuatro pestañas, normal/115%/320px200%, revisadas independientemente.
Cerrados dos P2: marca incompatible al cambiar especie y altura del collar.
Fotos de captura:15 fixtures de URL exacta, sin compras ni cuentas reales.

Android440: 14 SUCCESS, AAB/firma/configuración y log de publicación interna
verificados. iOS441: 15 SUCCESS, IPA/configuración y carga verificados; tarea Apple
finished/error=false22:00UTC. Una cola, una ventana de5min y un envío por plataforma.

Pendientes finitos: root confirma canales y prueba instalada cuando vuelvan Chrome
estable y Samsung USB; titular prueba TestFlight441 y acepta o señala diferencias.
ADB sin dispositivos; Chrome lee DOM del mock, pero captura/viewport/control nativo
y lectura posterior de Play agotaron tiempo. No atribuir screenshot del mock,
instalación, disponibilidad de grupo TestFlight ni aceptación humana.
Sin nuevo SQL, servicios, campañas o publicación pública por este lote.

# Cola vigente — Meta de producción, 22/nov/2026 CDMX

Petición expresa de integrar los eventos de valor, comprobarlos en Meta y después
activar los pilotos con públicos/anuncios de descargas conservados. Base congelada
`3e52c871` / producto437 `a24408be`. Contratos aditivos preservan V3, las señales
confirmadas, tokens de atribución y Play Install Referrer.

Código b471bdaf y SQL PROD aplicados/verificados; CI45080438018 cuatroSUCCESS.
Android2.3.11(439) disponible interna, CM6b037b2b3b42a788f941ec41/14SUCCESS,
artefacto/firma/perfil comprobados. Aviso público publicado y DataSafetyMeta en
revisión; gateMetaOFF/purgaON/entregaOFF. Esperando SamsungUSB y confirmación de
la aceptación adicional que solicita Meta para revisar eventos. Falta QA439/PROD,
recepción visible, publicación del mismo binario y cotejo final públicos/ocho
anuncios/gasto antes de activar. El panel1+1 previo corresponde a435/DEV.
[Plan finito](superpowers/plans/2026-11-22-meta-production.md).

# Corte anterior — Analytics 437/438, 22/nov/2026 CDMX

GA y SQLPROD20261122204434 verificados. Candidatoa24408be/CI45065888007 cuatro
SUCCESS. Android2.3.10(437) instalado desde Play en Samsung: misma sesión, cuatro
pestañas y cierre frío correctos; analítica y diagnóstico OFF conservados. iOS438
«En pruebas» en DopMi Inner Team, cinco testers; QA física y aceptación pendientes.

Reutilizados los mismos437/438 para envío público, sin nuevas builds: Play
«Changes in review», rollout100% y comprobaciones rápidas pendientes; Apple
«Pendiente de revisión»,7fe3bc72-b510-4119-995a-67230b73a672. Publicación automática
al aprobar. Antes de promover se comprobaron Play433 activo y Apple434 Listo para
distribución; no se cancelaron sus envíos. [Corte](candidate-release-current.md).

Pendientes finitos: tiendas resuelven esas solicitudes; integrador concilia su
resultado sin reenviar. Titular comprueba438 en iPhone/iPad cuando esté disponible.
La recepción GA de las tres señales espera uso legítimo consentido; no crear
contactos/adopciones de QA ni activar medición para poblar informes. Cuentas y
activos medidos tienen poblaciones distintas, sin reconstrucción del histórico.
Conservar servicios, piloto y decisiones; no repetir SQL, builds o publicaciones.
[Operación](adoption-first-publication-operations.md).

# Cola vigente — revisión pública 433/434, 21/nov/2026 CDMX

El titular autorizó expresamente publicar los fixes acumulados. Android433 e
iOS434, misma fuenteefc3277a/CI44980552352 cuatro SUCCESS, se enviaron desde sus
binarios existentes a producción pública. Play aceptó un único cambio433/rollout100%
y muestra «Changes in review», con comprobaciones rápidas pendientes; Apple muestra
2.3.9 «Pendiente de revisión», envío b75e9093-3d90-451c-aefd-888180ece1fb.
Ambas tiendas tienen publicación automática tras aprobación. Últimos públicos
verificados antes del envío: Android418 e iOS419 (Apple ya Listo para distribución).

Siguientes acciones finitas: integrador concilia el resultado de las mismas
solicitudes y disponibilidad pública; titular/integrador comprueban sesión, acciones
de Adoptar con aumento y clip en433/434 cuando haya dispositivo. No repetir builds,
subidas ni envíos durante la revisión. La autorización de promoción sustituye la
exclusión de promoción del corte anterior; no acepta la QA física ni activa finanzas
o campañas. Preservar OFF del iPad426,0/60 contactos y60tokens noQAOFF. Ver
[candidato vigente](candidate-release-current.md) y recibos privados
`.tools/public-fixes-20261121`.

# Corte anterior — Adoptar con aumento y campañas, 21/nov/2026 CDMX

La corrección de botones de Adoptar tapados por navbar con aumento usa la misma
fuente `efc3277a7c11f8633235584a4cf2c95c7d471181` en ambas plataformas, tag
`codex/discovery-zoom-efc3277a`, CI44980552352 cuatro SUCCESS. Perfil PROD de
3/4 pestañas: 6 PASS; regresiones 108 PASS, análisis 0 y revisión independiente
sin P1/P2. Android 433 / `6b0264a98a656efc66c206b5` terminó con 14 SUCCESS;
AAB firmado verificado y log 433 / internal / completed cotejado. iOS 434 /
`6b0269376a61881b3ef5d093` terminó con 15 SUCCESS; IPA de 55,001,686 B verificado.
Apple task `6b026c17a14b9f22af016cd2` terminó sin error el 22/nov a las
04:19:11 UTC. Chrome confirmó 434 «Lista para enviar», DopMi Inner Team,
90 días e invitaciones «–» a las 04:21:42 UTC: disponible en TestFlight.
Recibo privado del corte: `ios/testflight-readback.private.json`.

**Pendiente: QA física en Android 433 e iOS 434.** No hay aceptación física nueva.
ADB del 22/nov a las 04:22:16 UTC: cero conectados y cero no autorizados; paquete
no leído, sin instalación ni apertura solicitadas. Titular/integrador comprueban
botones de Adoptar, sesión y clip en un chat existente, sin enviar mensajes ni
fotos ni crear likes o casos. Si Samsung no tiene paquete, coordinar su primera
instalación/apertura con la QA de atribución pendiente. Ver [candidato](candidate-release-current.md).
No generar otra build, promoción pública, cambios de servidor ni SQL por esta
espera. Conservar el OFF del iPad 426 y los gates del piloto. El corte 432/430
se mantiene abajo como evidencia anterior; la siguiente instalación es 433/434.

## Historial del clip — corte 432/430

El clip del chat quedó integrado en Android **2.3.9 (432)**, fuente
`968e6d7de31efb36450c4ad6b9482780a740167f`, conservando la base de campañas
`1544a852`. CI44975634368 terminó con cuatro SUCCESS y Codemagic
`6b0257e42985c05978fa8aab` con 14 SUCCESS. El integrador verificó firma del AAB,
SVG del clip y marcadores de campaña en los tres ABI. El log de Publishing
cotejado confirma 432 / internal / completed; la lectura independiente de Console
permanece separada.

iOS **2.3.9 (430)** conservó fuente
`6aa34db85f0d26c57cc9281d948533fb90c957f1`: IPA y SVG verificados, disponible
en TestFlight. Las fuentes por plataforma quedan registradas por separado;
se reutilizó 430, con el comportamiento iOS conservado, para ese corte.

**Evidencia anterior del clip, corte 432/430.** Su QA física quedó pendiente;
la lectura ADB del 22/nov a las 03:00:57 UTC registró cero dispositivos conectados.
Ese pendiente continúa en 433/434 según el corte superior, conservando sesión
y el OFF elegido en iPad 426. No instalar versiones anteriores ni generar otra
build, cuenta QA o casos por la espera de esta corrección.

## Campañas — corte 429 conservado y continuación 433

Etiquetas por comentario y piloto60 autorizados: cliente/servidor implementados,
landing pública y revisión independiente limpia. Continuar [gates del piloto](campaign-placement-pilot.md):
Fuente1544a852/CI44966371479 cuatroSUCCESS y SQLPROD20261122004520/31PASS.
429/CM6b02411ebc3b31211424b493 terminó14SUCCESS; AAB/runtime/firma verificados y
logCLI confirma publicación interna. Esa base y el clip se conservan en 433;
continuar lectura Console y entrega 433, QA real con consentimiento personal y
cliente público compatible antes de habilitar tokens y comentar. El titular
necesita otra mascota real; no reusar primeras fichas consumidas. La evidencia
SQL se reutiliza sin reaplicar y el último estado registrado conserva **0/60
contactos** y **60 tokens no QA OFF**; este cierre no atribuye una auditoría remota nueva.
Mantener Analítica OFF del iPad 426.

Elección inicial de Analítica21/nov: implementada y revisada en af0e2274;
CI44878177593 cuatroSUCCESS. Titular autorizó el paquete exacto. SQLPROD
20261121223246 aplicado una vez y cotejado (historia72/prefijo71intacto/16PASS),
textos públicos c95be7f/READY/HTTP200hash exacto y tres categorías de App Privacy
Apple publicadas (16tipos/trackingNO). Play Data Safety publicado por Submission165
con un solo cambio; no promoción de binarios públicos. iOS426 tiene QA humana
de sesión/navegación y retirada/OFF persistente confirmada; Android sin instalar.
[Plan](superpowers/plans/2026-11-21-usage-analytics-choice.md).

Android6b021e276328dae170dd4245 terminó14SUCCESS; Play interno425
completed/publicado y AAB/runtime/firma cotejados. No repetir build ni auditoría
completa por la espera de instalación. Las fichas Apple/Play ya están publicadas;
audiencia16–17/18+ conservada. iOS6b02219da77af65f4a2437b1 terminó15SUCCESS/426;
IPA/runtime cotejados y posprocesamiento Apple terminado sin error. Chrome
confirma Lista para enviar/DopMi Inner Team/5invitaciones: TestFlight disponible.
El titular ya actualizó426 y aceptó sesión/navegación correctas. Analítica aparece
ON con preferencia previa desconocida; no es prueba de primera elección ni de
preservación de un OFF anterior. Flags del cliente separados de servicios remotos,
que no se apagaron en este lote.

El titular apagó Analítica en426, esperó guardar y cerró/reabrió: confirma OFF
persistente e inicio de sesión conservado. El estado final es OFF y debe
respetarse. No se conoce la preferencia anterior al primer ON observado; no es
prueba de primera elección, onboarding nuevo ni tráfico real del SDK.

Pendiente externo finito de esta entrega:
- Integrador: continuar el expediente Google existente para la descarga del
  Samsung. Un intento desde Play interno mostró «No se puede descargar DopMi»,
  paquete ausente; no se acreditó código de error ni versión solicitada. No otra
  build, sideload o prueba repetida sin información nueva. No queda otra QA humana
  solicitada para el alcance iOS de este delta.

La selección inicial no es consentimiento ya otorgado. Errores/publicaciones
siguen independientes. No otro build por espera ni reaplicar la migración.

Campañas21nov: contrato operativo en [handoff](campaign-attribution-handoff.md) y
[protocolo experimental](superpowers/specs/2026-11-21-rescuer-acquisition-experiment-design.md).
Comparador confirmado Meta/Google pagados; objetivo primera ficha por cuenta.
Siguiente: medición/namespace nuevos, baseline pagado y piloto operativo antes
de congelar muestra/contrastes. Diseño listo, sin ensayo confirmatorio ni cambios
de presupuesto/trackers. Conservar gates y evidencia técnica del piloto inferior.

Prioridad de corrección: Favoritos de Mis match tras swipe derecho, incluida
respuesta de guardado que llega después de abrir la pestaña. Cliente corregido,
11regresionesPASS y revisión independiente cerrada; análisis0incidencias,
suite1940PASS/4SKIP y CI44869286815/1441e295 cuatroSUCCESS. Android423 publicado
enPlayinterno/14SUCCESS y iOS424 procesado/TestFlightInnerTeam/15SUCCESS,
artefactos/runtime cotejados; se conserva la misma fuente1441 y una cola.
S25 pidió423 y repitió1010 antes de descargar; Google tiene la actualización
en el caso existente/SENT. El titular eligió ahora el Samsung conectado, paquete
ausente: el intento actual desde Play interno también falló, pero sin logs nuevos
que permitan asignar1010 o un número solicitado. Integrador + titular comprueban
el favorito tras instalar el candidato; caso Google y QA anterior conservados,
sin nueva build por espera.
Datos/permisos/SQL/servicios y regla de excluir después de mensaje conservados.

Continuación autorizada: piloto individual iOS `personal-a` con descarga directa,
sin códigos ni login previo. Corte reciente e48a653b inventariado e integrado,
incluye compartir perfil HTTPS de b278540d/build420 interno. Código cliente y
contrato SQL aditivo implementados; revisión independiente sin P1/P2 tras
corregir persistencia/cambio de propietario. CI44860327579/55061f99 cuatroSUCCESS;
SQL PROD20261121034107 aplicado y cotejado sin alterar333funciones previas.
Codemagic6b0112f68d36bd30d38e3998 terminó15SUCCESS; IPA2.3.9(421) cotejado y
Apple procesado/Lista para enviar/DopMi Inner Team confirmado en Chrome.
CPP guardada en borrador, sin activar
el `ppid`. La cola técnica sigue en [plan iOS](superpowers/plans/2026-11-20-ios-cpp-personal-a.md)
y [runbook](ios-cpp-personal-a-runbook.md); consultar candidato/progress para
resultados de CI, despliegue y carga. Captura confirma iPad Pro12.9″/5.ªgeneración,
iPadOS26.6.1, compatible con el mismo421. Titular confirma421 instalado desde
TestFlight; fuente personal-a/ios_cpp_open automática cotejada en PROD tras
apertura desde Safari. Primera ficha real enviada desde el iPad21nov16:37:27CDMX:
PROD coteja misma cuenta/fuente original personal-a, referencia exacta a esa ficha
submitted, dos fotos privadas, AnalíticaON/revisión3 y una sola ficha/fuente.
Aprobación/publicaciónNULL; ficha ahora archivada. Saludo automático16:58:58 y
primer mensaje16:59:59CDMX verificados por separado21nov en contacto real de
adopción elegido por titular, mismo actor/fuente/hilo y sin ajuste administrativo.
Eventos QA excluidos; respuesta como dueño pendiente por decisión expresa del
titular. No reactivar/publicar para forzar ese tercer hito ni atribuirle la
respuesta del dueño externo al actor adoptante.
Fuente y primer envío QA excluidos del experimento por filtro privado, noQA0.
Recibo independiente favorable de421/55061f99; no acredita QA del424 posterior.
Primera ficha y mensajes instalados desde App Store pendientes. No sustituir esa aceptación
por pruebas automatizadas. Aviso «mensaje escrito» ya actualizado a «enviado».
Pendientes del piloto: cliente público compatible tras la revisión vigente419,
CPP aprobada y activación ppid; después instalación limpia desde CPP/Abrir en
iPhone con iOS18+ o iPad con iPadOS18+, primera ficha privada y eventos legítimos de mensajes. No enviar
campaña iOS nueva ni retomar A/B con atribución iOS como si ya estuviera aceptada.

Entrega autorizada en el chat: atribución y eventos separados sobre release
reciente, recuperar visor/compartir y sello por perfil, conservar Tienda y fixes.
Base congelada c9d9d03d; rama `codex/production-attribution-restored-20261120`.
Única cola Flutter. Inventario, interfaces y gates en
[plan de integración](superpowers/plans/2026-11-20-production-attribution.md).
Implementación y CI44823640872/ee3ef773 cerradas; SQL PROD agrupado y Admin
desplegados/cotejados. Codemagic6b00c856/14SUCCESS genera2.3.8(418), fuenteee3,
entornoPROD/AmazonON/finanzasOFF; Play cerrado attribution-dev-qa/release6 disponible.
Samsung ya instaló418/Vending desde personal-a y la primera ficha privada quedó
atribuida automáticamente en PROD20nov18:22CDMX. Paso opcional/Tienda comprobados.
QA de visor/carrusel/compartir, producto de Tienda y reinstalación cerrada en el
Samsung; fuente/primer envío conservados. El mismo418 se promovió a producción/
release43 y se envió como único cambio. Consulta20nov18:52CDMX: comprobaciones
previas terminadas y revisión de Google en curso; alcance100% de países existentes,
sin recompilar. Consulta posterior20nov19:41CDMX de Production confirma Active,
Latest release2.3.8 y métricas vinculadas a versionCode418: disponibilidad pública
confirmada, sin segundo envío ni build.
Apple2.3.8(419), fuenteefcce99f (sólo notas distintas respectoee3), ya cargó por
Codemagic6b00f498/15SUCCESS; tareaApple6b00f7c1 terminada y WAITING_FOR_REVIEW
confirmado20nov19:50CDMX. Pendientes aprobación/disponibilidad y QA de iPhone.
Los cuatro enlaces iOS de campaña están publicados/verificados en la landing;
miden descargas agregadas, no la cuenta/primera ficha ni mensajes. Conservar el
contrato separado del piloto Android y no anunciar significancia por inspección.
Excluir cuenta QA conocida del análisis, sin borrar el recibo de prueba.
Checkpoint operativo: [candidate-release-current](candidate-release-current.md).
Play interno: reenvío único autorizado **2.3.8 (422)**, fuente inmutable
b278540d/configuración420, CM6b01170e/14SUCCESS; artefacto y readback
internal/completed cotejados. Samsung pidió422 tras refrescar Play y repitió
1010 antes de descargar; no instalado. Google confirmó caso3-8197000042220;
seguimiento422 + descarga reportada en ZFlip enviado en el mismo hilo/SENT.
Integrador: analizar respuesta del expediente, sin duplicar build/caso ni
atribuir aceptación física del Samsung a la publicación.
P3 de copy resuelto en el piloto iOS: «primer mensaje enviado como adoptante»;
no cambia el contrato de texto o foto del contador de compositor.
Las colas históricas inferiores no reinician trabajo consumido.

# Cola histórica — beta real por canales de prueba, 28/oct/2026

La paridad341/f693 está aceptada. Nuevo alcance LIVE autorizado, producción limpia,
reserva declarada20,000MXN/sin tope agregado; decisiones en product-decisions.md.
Una cola Flutter; reutilizar paridad. No copiar fixtures ni activar comercio.

| Batch / dueño | Dependencia y objetivo | Estado / salida |
|---|---|---|
| B0 / integrador | Descubrir entornos y acuerdos actuales | Cotejo48resuelto/47exactos+cleanupsemántico; Authsignup/anonymousOFF/confirmemailON; customSecrets0, sinDEVmodificado. SMTPPRODguardado; faltan OAuth/entrega/operación. |
| B1 / móvil + revisores | B0; configuración estricta TEST/producción | Configuración y fixformato integrados en83e6e6fc/CI40793197789 cuatroSUCCESS. |
| B2 / backend; integrador SQL | B0; contratos/mode/consentimientos | Fuente83e6e6fc/CI4SUCCESS; revisiones cerradas. Ningún despliegue nuevo; historial y modo protegidos. |
| B3 / integrador + seguridad | B0/B2; preparar producción | Historia51 y8Edge verificadas; RAK/SMTP y dos webhooks LIVE+firmas24/1 configurados. Worker correctivo aplicado/verificado una vez: job1PAUSADO/runs0/HTTP0/finanzas0. Legales38b9 publicados/verificados; bindingPROD cerrado/masterFALSE/job1pausado/10tablas0. Google exige cambio de tipo del dominio; paquete revisado/confirmación puntual pendiente. Correo real/admin/ON financiero pendientes. No copiarDEV ni inventar cargos. |
| B4 / móvil + integrador | B1/B2; SDK y distribución | f20b27e6/CI40936283326 cuatro SUCCESS; baseGoogle d5171d9f/CI4SUCCESS y TestFlight609/Python29PASS revisados. Copy Stream condicional corregida/revisada. Runtime/OAuth/pin reales pendientes. Una ventana5min y un Codemagic cuando esté listo; ninguna build beta aún. |
| B5 / integrador + titular | B3/B4; aceptación beta | Pendiente: instalación desdePlay, registro estándar/correo y roles, identidad y recorrido financiero legítimo acordado; conciliación/operación y demo. |

Bloqueos/paquetes nuevos se concretan antes de pedir intervención. Stripe tiene
sesiónLIVE de navegador operativa yRAKguardada; conectorMCP no es requisito para
recrear credenciales. No repetir creación ni verificaciones2FA ya resueltas. Todavía no hay betaLIVE publicada/instalada ni pagos reales ejecutados.

## Corte aceptado anterior — conservar evidencia, no reejecutar

# Cola vigente — f693, entrega341 aceptada con sus límites

App3cf65d73/CI40632841781 cuatroSUCCESS/Play2.3.3(341)/CM13SUCCESS/SamsungVending115%.
TEST; una cola Flutter. No nueva implementación ni build este turno.

| Lote / dueño | Estado comprobado | Siguiente salida |
|---|---|---|
| Implementación/QA/distribución / root | CERRADO técnico de los paquetes y recorridos documentados.341 instalada; cámara reutilizada; historial/link/Stripe/regreso comprobados | No repetir suites, pagos, cámara, Tienda oP3. |
| Alta nativa / root | CERRADO:1job expired, mismoSETI canceled/métodoNULL, sinretry niotroSDK; UIvencimiento limpia intento | Conservar clienteTEST/auditoría y cierreOFF; no nuevo intento para ocupar espera. |
| Aceptación / titular | CERRADO28oct: «Acepto el corte con sus límites»;341/f693/warm-trust e informe existente | Sin lote activo de esta entrega. Futuras activaciones o referencias requieren alcance propio. |

Handoff de acceso resuelto. Video/Tienda/preview/enlaces/limpieza OFF; job6pausado.
El cliente eliminado de la cuenta anterior sigue sin reemplazo automático.

## Cola histórica inmediatamente anterior

| Batch | Dueño / dependencia | Escenarios y salida |
|---|---|---|
| Base cerrada | Root conserva evidencia | W1–W3/W4H/W4C, QA331–332, Play336/28dac instalada, backend e05 y ambasCI verdes; P3 movimiento/salida comprobados. No repetir pagos, recuperación, fixtures, P3, build o suites intactas. |
| 1. Candidato publicación4 | Root; Play337 publicada | Cuatro pasos/selector/ayuda/CTA48; guards de medios y PageStorage corregidos.97focalesPASS/analyze0/11renders y revisiones independientes. CI40358538461 cuatroSUCCESS, CM13SUCCESS/1485PASS, artefacto2.3.3(337)/fb0 y Playinternal/completed reales. Falta actualización/QA afectada tras handoff; sin repetirCI/POST. |
| 2. Cámara E2E | Root + humano; handoff privado pendiente | f827 reservada14:07:15UTC; cámara única14:14:55, sin respuesta de toma durante ventana. CierreOFF verificado14:25:57 antesmax14:27:15; 18assets exactos/nuevos0/cola0. Confirmar estado local humano antes de leer teléfono. Cámara→Stream sigue pendiente; no repetir toma por rutina. |
| Aislamiento Tienda | CERRADO técnico | MismaAuth6e catálogo congrant→revocada04:51:41→mensaje no disponible04:51:52 conpreviewON→OFF04:52:33/revocada. Catálogo/protegido/full18 exactos salvo metadata autorizada. No dos identidades; foto de entrada ausente tiene límite de reloj/cierre, ver parity. No repetir QA. |
| 3. Demo Stripe y comparación final | Root + titular/UX; teléfono tras handoff | Fix354bbe6e/Payments108/994PASS8SKIP/CI40269488735. AccountSessionsWrite ya guardado tras SMS humano: readback176filas, sólo ese cambioTEST, seguridad cerrada. Comprobar componente nativo; no pagos/altas por inferencia. |
| 4. Aceptación | Titular/UX; demo e informe conciliados | Registrar conformidad o lista concreta de diferencias; implementación, QA, publicación, instalación y aceptación separados. iOS físico/TestFlight y comercio público son límites declarados, no pruebas ejecutadas. |

Sin nueva operaciónON: último servidor verificadoOFF/job6pausado/cola0.
CI40358538461 cuatroSUCCESS/fb0a3495; únicoCM6adf83cc93adc6d8e55fa26d13SUCCESS.
Artefacto337 y Playinternal/completed verificados; instalación aún pendiente.
Si se conserva toma local, resolverla antes de actualizar. Estado local de cámara
pendiente de respuesta humana; no leer ni controlar teléfono. Estimación previa2–4h excluía defectos nuevos; se añadió corrección concreta de publicación, excluye esperas humanas
y defectos nuevos. Mismo fallo sin información nueva→parar estrategia, cerrarOFF,
diagnosticar antes de otro intento. Documentar al cerrar tarea/bloqueo, no cada lectura.

Los apartados inferiores se conservan como historial; la cola superior los supersede.

Actualización vigente17oct: titular950d1 autoriza preparar versiones y aceptación; B5-L1/L2 implementados localmente, B5-L3 gates/revisión en curso en matriz existente. Los pendientes de decisión de versionado inferiores quedan resueltos por product-decisions.md. Sin publicación/despliegue/build adicional autorizados; instalado318sin cambios. Retención/respaldos y legado conservan límites.

## Cola vigente — 17/10/2026, d304535

Actualización posterior: titular coordina verificación y elige solicitud pendiente/revisión por caso sin nuevo sistema de recuperación. Borradores de páginas existentes /delete-account, /privacy-policy y /terms preparados/revisados técnicamente y render local; no publicar. Pendiente decisión de versiones/aceptación coherente con móvil/SQL; retención/respaldos y compatibilidad integral del legado siguen gates. Evidencia, demo y retro en meta-social-verification.md; no nueva build, pago ni QA D/R. Demás dependencias externas y aceptación318 siguen abiertas.

Cierre posterior D17oct: D Instagram cerrada17oct22:06:37.5527CDMX en Play2.3.3(318)/7caea887: permiso específico, una confirmación en Dopmi y postflight único. Facebook0/Instagram0;20 grupos propios conservan exactamente conteos/huellas frente al baseline fresco. UI asentada muestra «Retiramos la conexión de Dopmi», sin cuenta conectada ni controles Desconectar; Conectar sigue deshabilitado. Revisiones independientes de producto y seguridad cerradas. No acredita retirada del permiso Instagram en Meta ni denegación OAuth. Modo Adoptante original restaurado después del cotejo. Sin SMS, cambios de teléfono, pagos, flags, OAuth, build ni reconexión. QA de teléfono no vacío en318 cerrada en este recorrido: la pantalla «Teléfono de tu cuenta» muestra «Vinculado» y una lectura READ ONLY ligada al dueño confirma coincidencia con Auth y phone_confirmed_at presente17oct22:07:49.688015CDMX. Fuentes y pruebas vigentes revisadas, sin repetir suites. No se reprodujo caché SDK obsoleta en dispositivo ni se capturó GET de red; SMS incorrecto/reenvío siguen pendientes por falta del otro número controlado ya informada. Captura con contactos sólo privada. Pendientes concretos: denegación OAuth real, SMS con otro número aún no disponible, mecanismo privado de reclamantes/compatibilidad legado y revisión/publicación de contenido y requisitos Meta, aceptación con Irlanda diferida. No habilitar conexiones ni iniciar otro flujo OAuth por esta autorización. TalkBack post-MVP. Dueños: integrador prepara operaciones; titular resuelve revisión/autoridad y disponibilidad; Irlanda evalúa el candidato. Siguiente dependiente: revisión humana del procedimiento de privacidad/eliminación preparado; ninguna publicación o eliminación autorizada. Mejora de texto para próxima entrega autorizada: sustituir «cuando quieras» por una explicación que no prometa disponibilidad de reconexión; no bloquea D ni autoriza nueva build.

Actualización posterior: **7caea887 / 2.3.3(318) publicada e instalada desde Play interno**, CI39078062316 cuatro jobsPASS, únicoCM57finished1212pruebas/AAB/PublishingPASS, Play158 disponible17oct17:58CDMX. Acceso visible desde cancelado→impacto→Back probado en normal/115/320200 y revisión independiente cerrada; valores reales mensuales cotejados, preferencias restauradas. PAYG habilitado por titular y saldo observadoUSD1.71, sin autorización para otra build. QA financiera317 equivalente y retención90561 cerradas; no repetir cargos/fixtures/helpers. B6 aceptación con Irlanda pendiente; QA TalkBack pasa a post-MVP por decisión expresa17oct (product-decisions.md), parcial sin aprobación; B5 SMS sin otro número y gates sociales/legado/Meta conservados. Siguiente: evaluación humana del318 y resolver dependencias externas específicas.

Preparación de cierre posterior17oct: responsable de soporte confirmado (titular); contraste técnico de privacidad/social/OTP y borradores preparados/revisión seguridad cerrada sin publicar. Paquete D/R acotado preparado, no listo para ejecutar: cuentaIrlanda318 sin redes conectadas, requiere cuenta previa disponible y permiso por etapa. No abrir flag global para desconexión/revocación; denegación OAuth separada. ModoAdoptante restaurado. Detalle en meta-social-verification.md; no otro tablero.

Cierre R17oct: revocación Facebook en proveedor/backend verificada tras permiso específico; postflight único Facebook0/Instagram1/21 grupos idénticos y revisiones independientes cerradas. No repetir retirada ni reconectar. No acredita D desde Dopmi ni denegación OAuth. Estado y límites en meta-social-verification.md; demás gates B5 e Irlanda conservados.

Plan aprobado por el titular: paridad funcional/visual contra d304535c63c2d15686476b421e140de475ff6b6f, preservando producto c53b6686 y QA equivalente. Decisiones en product-decisions.md; matriz única en parity-current-review.md; checkpoint en mock-sync-current.md.

**B0 cerrado17oct, sin repetición.** B1–B4 implementados/revisados, DEV financiero V5 verificado y candidato33b12a77/CI39073315974 cuatrojobsPASS. Play interno2.3.3(317) instaladaVending; P2dock corregido y revisado en teléfono normal/115/320200. Nueva QA específica autorizada10TEST por caso confirmó un intento/net584/transferido/reserva0 y conserva B0/Guardián/método; cotejo posterior5GET/revisión independiente cerrados. B5 retenciónV5 soportada autorizada/aplicada/job5/catalog8PASS, primer run90561 succeeded17:17CDMX/8catálogo+3ejecucióntrue/otros4jobs intactos, cola root conservada hasta readback; SMS sin otro número, negativos sociales/legado/Meta conservan bloqueos específicos. B6 aceptación titular-Irlanda pendiente; lector real post-MVP por decisión posterior17oct. Una cola Flutter y root único operador. Evidencia y siguiente acción en checkpoint/matriz existentes; no repetir fixtures, cargos o builds.

## Cola vigente — 15/10/2026

Terminar directamente el [candidato Guardián/pagos](candidate-release-current.md)
por encargo humano: cerrar pruebas/CI, operación TEST revisada y publicación
interna; después teléfono Irlanda/aceptación. Una cola Flutter y un seguimiento.

## Cola histórica al cerrar — 9/10/2026

RETOMAR ESTA ENTREGA según [checkpoint](mock-sync-current.md), no nuevo delta.
1. Completar sólo los gates sociales pendientes del [registro social](meta-social-verification.md), conservando cuenta y activación DEV cerrada fuera de QA autorizada.
2. QA SMS real incorrecto/reenvío con número controlado no vinculado; Irlanda propuesta, resultado no acreditado. No desvincular teléfono personal.
3. Recabar aceptación humana UI/UX pendiente y cerrar sólo al satisfacer requisitos obligatorios.

Play311 ya publicado/probado para éxito Instagram/Facebook; paridad846/308 conserva
sus verificaciones válidas. Los pendientes históricos inferiores se interpretan con
el checkpoint vigente. Este cierre no ejecuta la cola.

# Dopmi — entregas

> Alcance aprobado8/10: ejecutar N01–N11 sobre mock congelado dde1bb9 y QA pendiente9ced
> hasta candidato de Play verificado en teléfono. Tablero y checkpoint vigentes
> prevalecen sobre pendientes históricos inferiores. SMS real espera acceso/costo.

> Corte vigente8/10/2026: [checkpoint](mock-sync-current.md) y
> [tablero único](parity-current-review.md). Delta9ced implementada/gates y
> QA instalada focalizada301 verificadas; aceptación final pendiente. Próximo
> chat: RETOMAR entrega9ced para revisión titular/Irlanda y QA final con evidencia,
> sin repetir verificaciones válidas.4369 posterior no inventariado. Perfil
> ENTREGA_CONTINUA_EFICIENTE_VERIFICADA; no presupuestos/renovaciones.

> Decisión vigente 27/9/2026: el titular admite las pantallas actuales para continuar; la fidelidad visual queda aplazada, sin aceptación atribuida a Irlanda. H9 autorizado: aceptación integrada y correcciones, con revisión final agrupada en Internal Testing. Ver [H9](h9-acceptance.md). Esta decisión supersede los bloqueos visuales históricos inferiores.

Cada tarea se completa con código, prueba de aceptación y evidencia en `progress.md`.

## Hito 1 — completado

- [x] H1.1 Preparar estructura y reglas. Aceptación: prototipo conservado, apps separadas, configuración fuera de Git.
- [x] H1.2 Identidad en PostgreSQL. Depende de H1.1. Aceptación: perfil creado con cada usuario, datos propios editables, permisos administrativos fuera del cliente y cierre del acceso heredado inseguro.
- [x] H1.3 Flutter. Diez pruebas de estado/interfaz y dos recorridos de integración contra Auth/PostgreSQL/SMTP reales. Registro y confirmación del titular comprobados; su sesión web se restauró tras reiniciar Windows. Edición y lectura del perfil comprobadas en remoto; recuperación por código/enlace y persistencia de sesión/PKCE comprobadas con cuentas desechables locales.
- [x] H1.4 Admin. Código, cinco pruebas y build listos. Membresía del titular habilitada en servidor después de comprobar correo confirmado y perfil activo. Su sesión abrió el directorio de diez cuentas al recargar el panel.
- [x] H1.5 Verificación. SQL local/remoto, recuperación con correo local, Android e iOS simulator en macOS comprobados. Los cuatro jobs del [CI ampliado](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34788208103) aprobaron el commit de implementación y pruebas `788a236`.

## Hito 2 — completado

- [x] H2.1 Backend y permisos. Migraciones para publicaciones, fotos, favoritos, conversaciones, mensajes y notificaciones. Aceptación: aislamiento de borradores/conversaciones, moderación en servidor y reintentos sin duplicados. 58 comprobaciones nuevas pgTAP aprobadas en local y remoto.
- [x] H2.2 Publicación y revisión. Depende de H2.1. Flutter permite guardar, adjuntar fotos, enviar, corregir y cerrar; el panel revisa la versión exacta y registra su decisión. Datos conservados al corregir y contenido no aprobado ausente del catálogo, comprobados por integración y recorrido visual.
- [x] H2.3 Descubrimiento. Depende de H2.1–2. Catálogo, filtros, detalle, guardados y perfiles públicos. Solo contenido aprobado, paginación y favoritos por cuenta, sin datos privados publicados; pruebas SQL, integración e interfaz aprobadas.
- [x] H2.4 Comunicación. Depende de H2.3. Inicio de conversación desde una publicación, mensajes privados, cierre y notificaciones. Aceptación de Realtime desde base nueva, lectura persistente y reintentos sin duplicados; recepción visual comprobada con otra cuenta local.
- [x] H2.5 Verificación y entrega. Depende de H2.1–4. Migraciones remotas y revisión visual completas. Análisis y 14 pruebas Flutter, nueve admin, 69 SQL local, diez PGlite y tres recorridos contra servicios reales aprobados. Los cuatro jobs de [CI 34792258918](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34792258918) aprobaron `7039f35`, incluidos Android e iOS simulator.

## Hito 3 — completado

- [x] H3.1 Backend y permisos. Se agregó `public.dopmi_rescue_records`, `private.dopmi_rescue_history`, políticas de Storage privadas y funciones de guardado/revisión con control de estado, deduplicación y validación de montos urgencia en centavos.
- [x] H3.2 Rescatista móvil. Se implementó el flujo completo de verificación/caso/gasto en `apps/mobile/lib/features/rescue/`, incluyendo borradores, evidencia por rol, envíos, correcciones, retiro y estado.
- [x] H3.3 Administración. Se agregó revisión de expedientes de rescate en `apps/admin/src/Rescues.tsx` con detalle, decisión, auditoría y cambios de estado protegidos por RLS/funciones RPC.
- [x] H3.4 Seguimiento y cierre. El backend cierra casos solo cuando no hay gastos pendientes, bloquea nuevos gastos contra expedientes cerrados, publica solo snapshots aprobados y mantiene notificaciones por cambios de estado.
- [x] H3.5 Verificación y entrega. Se ejecutaron análisis/tests locales de Flutter, pruebas admin y suites SQL de hito (`identity`, `adoption`, `rescue`) en base local; migración y pruebas listas para mover a CI de hito siguiente.

## Hito 4 — aportaciones y Connect (completado en modo prueba)

- [x] H4.1 Contribuciones en base de datos: tablas, índices y política/registro de funciones para guardar aportaciones y asignaciones determinísticas.
- [x] H4.2 Consola administrativa: vista de aportaciones, filtro por estado, recarga y manejo de errores.
- [x] H4.3 Pruebas locales: test de unidad/admin y suite SQL inicial para idempotencia/allocación/publicación.
- [x] H4.4 Ejecución completa de `supabase test db` con stack local activo para validar la suite `supabase/tests/contributions.test.sql`. Aprobado en CI con PostgreSQL local y migraciones reales.
- [x] H4.5 Activar en el proyecto las funciones ya implementadas de Stripe Connect, webhooks y trabajador; validar una aportación, transferencia, devolución y conciliación completas en modo prueba bajo idempotencia. La producción queda fuera hasta una revisión independiente. Incluye trabajo periódico verificado con HTTP 200 y devolución/reversión comprobada en Stripe, base de datos y Android.
- [x] H4.6 Cerrar documentación de entrega del hito y propuesta de siguiente alcance (Guardián). Véase `docs/hito4-delivery.md`.

## Hito 5 — Guardián (completado en modo prueba)

Cierre: 25 de septiembre de 2026. Aceptación del titular con excepción explícita para disputa posterior a transferencia, según recomendación de soporte Stripe. Evidencia y límites en [entrega H5](hito5-delivery.md). No autoriza dinero real.

- [x] H5.1 Planificador del neto: urgencia, antigüedad y desempate estable; sin asignación parcial cuando falta capacidad.
- [x] H5.2 Decisiones del titular: primer cobro al activar, mensualidad condicionada, mes omitido sin deuda, cambio futuro y cancelación. Consentimiento e interfaz implementados. Reglas en `product-decisions.md`.
- [x] H5.3 Aceptación de reserva y liquidación transaccional completada en test: alta/renovación, omisión, concurrencia, devolución y reversiones conciliadas. Excepción de disputa documentada en hito5-delivery.md.
- [x] H5.4 Ciclo de vida aceptado: alta/abandono, calendario, cobro/omisión, recuperación, monto/cancelación, tarjeta/3DS e historial privado. CI36202506285, commit943a7d4: cuatro jobs aprobados. Límites de calendario preparado y dispositivo explícitos en entrega H5.
- [x] H5.5 Revisión independiente de seguridad y correcciones registrada; revisión final documental/test sin otro recorrido pendiente. Excepción de cobertura de disputa aceptada por el titular. No habilita dinero real.

### Cola inmediata

- [x] H5.A Comparar entorno remoto actual con el código y [historial de migraciones](migration-history-audit.md). SQL, catálogos y cinco Edge Functions comparados; diferencias de timestamps/defaults/formato explicadas. Conservar correspondencia explícita y no usar `db push`/repair sin renovar la auditoría; no se reejecutó SQL ni se alineó artificialmente el historial.
- [x] H5.B `payment-worker` v10 desplegado y comparado; preflight 1616 aprobó las 16 lecturas. Escrituras acreditadas separadamente por alta, renovación, cambio de monto/tarjeta, cancelación y reversión automática de la devolución en Stripe test. Evidencia en `progress.md`; no equivale a cerrar todos los escenarios de H5.G.
- [x] H5.C Preparación de flags de procesamiento con nuevas altas cerradas, acreditada por CI 36071101143 y registro previo. Reconsultar estado antes de abrir la aceptación; no contar como una comprobación remota nueva.
- [x] H5.D Configuración TestFlight que incluye Guardián y conserva bundle/firma; CI 36074983990 aprobado. Configuración no equivale a IPA firmado ni instalación.
- [x] H5.E Android 2.3.3 (247), SHA `3fe7a1d`, publicado por Codemagic e instalado desde Google Play interno; recorridos acreditados con capturas del titular. Dispositivo confirmado: Samsung Galaxy S25 Ultra (SM-S938B), Android 16, One UI 8.5. Actualización compilada e instalada según el titular; captura 1000343790 verifica el arreglo visual de cancelación. Codemagic confirma actualización 2.3.3 (248), commit a1e3b76267ff39200a47c720dbf472da044dc007, publicación internal completed; evidencia en la guía de aceptación. TestFlight queda como alternativa.
- [x] H5.F Altas **test** habilitadas con dispositivo/capacidad/Connect listos; 18 smoke checks aprobados con --expect-enabled y respuestas reales de Cron comprobadas. Primera aportación y renovación procesadas en test. Abrir test afecta a todos los usuarios autenticados elegibles; no hay allowlist individual. Los recorridos restantes siguen en H5.G.
- [x] H5.G Matriz aceptada en modo prueba, con disputa automática remota y conciliación posterior a transferencia simulada como cobertura alternativa autorizada. La secuencia remota posterior a transferencia no se ejecutó.
- [x] H5.H Defectos corregidos, revisiones independientes y cierre verificable registrados en hito5-delivery.md.

La APK Android separada queda como alternativa. La ruta elegida ahora es Google Play interno; el workflow estándar `android-internal` no habilita Guardián.

## H6 — Base única y trazable (completado)

Plan autorizado: [H6–H12](release-roadmap.md). Las casillas de aceptación visual/dispositivo nunca se cierran por código solamente.

- [x] H6.1 Comparar refs y reunir continuación/principal sin perder archivos locales.
- [x] H6.2 Registrar alcance MVP/post-MVP, responsables y correspondencia R0–R6.
- [x] H6.3 Registrar referencia viva de Irlanda y matriz por ruta/estado.
- [x] H6.4 Publicar PR, verificar CI e integrar en la rama principal.
- [x] H6.5 Registrar SHA integrado y CI; comprobar referencia de diseño al cierre.

## H7 — Legado y límites de código

- [x] H7.1 Inventariar objetos antiguos, dependencias, permisos, cron, Storage y funciones Edge.
- [x] H7.2 Respaldar legado fuera de Git y demostrar restauración aislada.
- [x] H7.3 Revocar superficies antiguas; retirar Cron/Edge/objetos por lotes; verificar autorización y sistema actual.
- [x] H7.4 Retirar exposiciones antiguas y documentar RPC/tablas privadas intencionales en legacy-retirement.md. Configuración de protección de contraseñas queda explícitamente en H10.6.
- [x] H7.5 Modelos tipados en límites y servicio común de archivos (sin videos).

Evidencia H7: [retiro reversible](legacy-retirement.md). PR #5 integrado en `ba9f897`, CI 36208309068 aprobado en sus cuatro trabajos. La restauración probada es lógica del legado, no recuperación completa de producción.

## H8 — Paridad completa y funcional (alcance corregido 26/9/2026)

Plan vigente: [h8-execution.md](h8-execution.md). Las casillas históricas inferiores documentan implementación parcial, no aceptación de H8. Los recorridos visibles de H9 se ejecutan ahora dentro de H8.

- [x] H8.0 Matriz concreta de pantallas/acciones, dependencias y evidencia separada. Es un registro vivo: cada ciclo actualiza I/T/V sin borrar diferencias abiertas.
- [x] H8.1 Dos experiencias completas; cambio dedicado de modo y conservación de estado. I/T completos; V pendiente del candidato instalado.
- [x] H8.2 Swipe, filtros, personalidad, zona/radio aproximado y paginación. Implementación y comprobación técnica completas; aceptación visual se conserva en H8.7.
- [x] H8.3 Detalles, favoritos de mascotas/casos/rescatistas, Mis match y comunicación. I/T completos; V pendiente.
- [x] H8.4 Perfil, configuración separada, historial real y ayuda. I/T completos; textos legales definitivos permanecen H10.
- [x] H8.5 Apoyar, historias moderadas, perfil público e impacto real. I/T completos; V pendiente.
- [x] H8.6 Panel/Casos/Publicar/Mensajes/Perfil rescatista; verificación/evidencia por pasos. I/T completos; V pendiente.
- [ ] H8.7 Aportaciones/Guardián fieles con resultados reales: I/T completos. Android 2.3.3 (256), SHA `ea5350e`, publicado con CI y Publishing aprobados; falta aceptación visual/dispositivo de Irlanda para cerrar H8.

### Registro anterior: componentes implementados, no cierre de paridad

- [x] H8.1 Base de tokens, fuentes/assets y controles del mockup implementada; revisión visual pendiente H8.3.
- [x] H8.2 Navegación por experiencia y conservación de estado entre pestañas; cuentas separadas y recuperación cubiertas por pruebas.
- [ ] H8.3 Capturas comparables, accesibilidad y revisión de Irlanda.
- [x] H8.4 Implementar onboarding contextual, entrada de cuenta y formularios con componentes de la referencia; conservar confirmación/recuperación reales y gates OAuth. Aceptación de paridad visual pendiente en H8.3.

Detalle y capturas de componentes/acceso: [H8](design-foundation.md). H8 permanece abierto hasta revisión y aceptación visual de Irlanda; no equivale a H9 ni a aceptación en dispositivo.

## H9 — Aceptación integrada y confiabilidad funcional

Plan autorizado 27/9/2026: [matriz, defectos y revisión agrupada](h9-acceptance.md). El titular aplaza la fidelidad visual y admite las pantallas actuales para continuar.

- [x] H9.0 Base, conexiones, matriz y fixtures locales reproducibles.
- [x] H9.1 Integración de adopción/favoritos/contacto/retiro y privacidad entre cuentas.
- [x] H9.2 Integración de rescate, correcciones, fotos, avances, perfil y adopción vinculada; defectos de notificación/visibilidad corregidos.
- [x] H9.3 Regresiones financieras y acceso remoto test; evidencia histórica H5 preservada. Aceptación instalada se agrupa en H9.5.
- [x] H9.4 Correcciones de moderación, permisos, paginación y guía operativa.
- [ ] H9.5 CI 36330974531 aprobado; Android 2.3.3 (259) publicado en Internal Testing desde 73c731f. Falta aceptación funcional agrupada del titular; no cerrar por compilación/publicación.

## H10 — Identidad pública y operación

Plan autorizado y cola detallada: [h10-execution.md](h10-execution.md).
Inicio 28/9: guardas de entorno y cliente Google nativo comprobados localmente;
Apple sólo adaptador preparatorio. Ningún subhito H10 cerrado todavía.

- [x] H10.1 Configurar/verificar Google y Apple, callbacks y no duplicación de identidad. Google aprobado en Android/iOS; Apple nativo aprobado sólo en iOS/iPadOS por decisión de producto; vinculación conserva el mismo perfil.
- [x] H10.2 Eliminación de cuenta y tratamiento de sesiones/contenido/evidencia. Reintento Auth parcial, operaciones pendientes, Guardián, aislamiento y permisos servidor verificados.
- [x] H10.3 Analítica mínima y errores sin datos privados; consentimiento comprobado.
- [x] H10.4 Correo, soporte/moderación, legal y declaraciones de privacidad definitivas. App Privacy quedó publicada; Data Safety fue enviada a revisión. La ficha Apple 2.3.3 y la resolución del aviso histórico de Google se revalidarán con el candidato final, sin bloquear el siguiente bloque.
- [x] H10.5 Separar configuración test/producción, conservando identidad y firma. Producción quedó sin altas, proveedores sociales, secretos personalizados, usuarios ni datos; Android 281 y iOS 282 se publicaron internamente desde el mismo SHA `0a25ba8`.

- [ ] H10.6 Habilitar/verificar protección de contraseñas filtradas en Supabase Auth, sujeto a disponibilidad del plan. MCP actual no permite configurar Auth.

Estado vigente 28/9: proveedores test, eliminación servidor, medición, Resend y
proyecto de producción ya están implementados/configurados. Las tareas H10.1–H10.5
permanecen abiertas únicamente hasta completar aceptación instalada, Firebase,
Private Relay y el candidato conjunto. H10.6 se difiere por decisión del titular
a H12 porque requiere Supabase Pro; debe cerrarse antes del lanzamiento público.

### Corte H10 del 28/9/2026

- [x] Términos/privacidad/18+ versionados y aviso de desarrollo retirado.
- [x] Eliminación dentro de Configuración, solicitud web y proceso servidor
  idempotente desplegado en test; conserva evidencia y contenido ajeno.
- [x] Interfaces Analytics/Crashlytics con consentimientos independientes,
  apagados por defecto; configuración Firebase segura preparada en Codemagic.
- [x] Activar Google/Apple y vinculación manual en Supabase test; flags seguros
  activos en los candidatos H10. Google quedó aceptado en Android/iOS; Apple
  nativo, Private Relay y revocación quedaron aceptados en iOS/iPadOS.
- [x] Vinculación explícita confirmada sobre el mismo perfil. Apple web en
  Android se retiró del alcance por decisión del titular: Android ofrece
  Google/correo y Apple permanece exclusivo de iOS/iPadOS.
- [x] Probar recepción/respuesta y configurar SMTP transaccional. Resend quedó
  verificado en ambos sentidos; la clave `Supabase` se reserva para Auth/SMTP
  y `Codex Dopmi` para envíos controlados de prueba.
- [x] Aprobar costo cero actual y crear Supabase producción limpio y cerrado.
- [x] Publicar el mismo SHA en Internal Testing y TestFlight e instalar ambos:
  Android 277 e iOS/iPadOS 278; Google y persistencia aprobados por el titular.

## H11 — Beta en ambas tiendas

- [x] H11.1 Mismo SHA por Codemagic en Play interno y TestFlight; verificar publicación. Android 283 e iOS 284 provienen de `94cb82e` y están disponibles en los canales internos.
- [x] H11.2 Recorridos disponibles en Android, accesibilidad, instalación/actualización y recuperación. El titular trasladó correo real e iOS final a H12.
- [x] H11.3 Sin defectos críticos/altos en la evidencia ejecutada; recuperación automática queda como fricción media. Revisión visual externa trasladada expresamente al candidato final H12.
- [x] H11.4 Procedimiento de reversión probado sin mutar las tiendas: SHA conocido como bueno recuperable, diferencias acotadas, identidad/firma/canales conservados y rebuild monotónico definido. La reversión real sólo se ejecuta ante un defecto.

## H12 — Lanzamiento

- [ ] H12.0 Integrar los cambios finales de Irlanda y el parche de consentimiento; publicar un mismo SHA nuevo en Play interno y TestFlight. Repetir regresión Android/iOS, correo real y revisión visual externa.
- [ ] H12.1 Landing, fichas, capturas, privacidad y soporte listos.
- [ ] H12.2 Revisar Stripe live/Connect, conciliación, disputas, depósitos y límites.
- [ ] H12.3 Obtener autorización explícita de dinero real antes de activarlo.
- [ ] H12.4 Publicación gradual y monitoreo operativo verificado.

## Controles recurrentes

- [x] Monitor diario de diseño 09:00 configurado; sólo notifica novedades accionables.
- [x] Revisión semanal de dependencias, seguridad, costos, soporte y deuda.
- [x] Revisión mensual de restauración, accesos y firma.
- [ ] Comprobación de artefactos/publicación por build y monitoreo de producción.

Los monitores de Codex requieren equipo/conexiones disponibles; no reemplazan Cron ni observabilidad del servidor.

## 2026-10-04 — Actualización889 autorizada, supersede el aplazamiento anterior

Implementar REF-01–19 del tablero parity-current-review.md hasta889c096,
desde8785f66/Play290. Funciones completas con contratos aditivos mínimos;
saludo sólo al confirmar el primer contacto, transaccional y sin duplicados.
Tres subagentes/frentes exclusivos y un integrador/cola Flutter. Commits nuevos
posteriores al corte quedan para otra entrega. Codemagic únicamente candidato
final; cierre requiere regresión y Android instalado. Dinero exclusivamente test.

Estado5/10 del corte889:19/19 grupos implementados y cerrados en desarrollo,
candidato51cc7c1 con gate integral37278538360 aprobado (846 tests móviles,
backend/SQL/integración y compilaciones). Nativo emulador aprobado después de
corregir el offset entre pasos. Codemagic6ac3570f3a34cf7c3070ed0f entregó
2.3.3(291), Play internal/completed comprobado; Guardián permanece en test.
- [x] Comprobar291 instalada y ocho recorridos modificados en Samsung al115%.
- [x] Limpiar sólo las dos identidades y15 objetos sintéticos del manifest QA889; postflight cero y participante Samsung conservado.
Los commits Source posteriores a889c096 y los pendientes H12 siguen separados.

### 2026-10-05 — Swipe cerrado en Samsung y Play 295

Supera el pendiente del candidato fcc2ce7: único release interno 2.3.3 (295), source 7cf8202; Play completed confirmado y Samsung actualizado desde tienda. Diez avances efectivos sobre catálogo repetido; videos 293/295 comparados por cuadros intermedios, transiciones mixtas centradas y foto/texto unidos. Codemagic 877 tests; gate móvil 37406799890/41c5a37 y checks iOS/web/backend 37405575748 acreditados. Auditoría cerrada sin pendientes; dos correcciones sólo de verificación. Ver docs/swipe-stack-delivery.md. No hay otro loop de swipe abierto.

## 2026-10-06 — Actualización bccd040 autorizada

22/22 grupos cerrados en desarrollo; referencia congelada bccd040 y base
ed4b788/Play295. Tablero vigente parity-current-review y cuatro fichasupdatebccd.
Pendientes de entrega: auditoría delta, gate SHA final, nativo emulador,
CodemagicGuardianInternal/Play/Samsung y limpieza exacta. Conservar fotos/swipe295,
privacidad, revisión y edición de apoyo aprobado bloqueada; dinero test.


## 2026-10-06 — checkpoint de sincronización vigente

Corte bccd040 cerrado22/22, Android296/Samsung y cleanup cero comprobados; supersede los pendientes de entrega bccd anteriores. No hay lote de paridad activo. Referencia viva9ced070 observada por Git, delta aún no inspeccionado ni implementado. Siguiente: esperar encargo y congelar su alcance antes de inventariar. Leer [mock-sync-current.md](mock-sync-current.md) y [mock-sync-workflow.md](mock-sync-workflow.md); no reiniciar gates/fixtures cerradas.


## Encargo adicional Meta — 9/10/2026

Autorizado por el titular: verificar Facebook y cuentas profesionales de Instagram
desde la sesión Dopmi; Instagram personal conserva enlace/revisión manual.
Implementado a941815, aún no entregado. Cola y evidencia únicas:
[meta-social-verification.md](meta-social-verification.md). Configuración mínima
Meta/secretos DEV, OAuth real, gate CI, candidato Play y teléfono pendientes.
Conservar el pendiente SMS real de Play308; no repetir QA válida.
## 23/10/2026 — Cámara330 y preparación P3

Root: cerrar revisiones del paquete camera330-newdraft-qa y solicitar permiso concreto para máximo un nuevo borrador/foto sintética con servicios OFF y una toma privada con revisión local, carga segura o descarte y cierre OFF/pausado. Disponibilidad humana confirmada; sin autoridad operativa todavía. P3 $100/$20 elegido sólo para preparación: identificar donante distinto y completar actores, conciliación, capacidad y cierre antes de pedir ejecución. Stripe TEST de lectura: reloj ready, invoices draft/open cero en el corte; refrescar antes de cualquier capacidad nueva. Conservar CLOSED40/DRAFT4/PDF/16assets y cinco trabajos ajenos.
## 23/10/2026 — P3 decisiones completadas por titular

Donante TEST distinto elegido y comprobado activo/confirmado por SELECT; conservar caso abierto y aporte TEST para revisar Impacto elegido. Root completa paquete ejecutable y acceso legítimo antes de permiso propio. No volver a preguntar actor/retención; falta sesión donante, frescura financiera y revisión/autoridad de ejecución. Cámara330 consulta propia pendiente, sin renovación implícita. No pagos ni capacidad creada.
## 23/10/2026 — P3 listo para permiso de ejecución

Root: solicitar paquete fb6dfcac…c6eb ya preparado/revisado y SELECTrealshapePASS; máximo2ventanas20min, único caso/gasto100/aporte20TEST, retención elegida, login/pagoOFF y cierreAdoptardonante. Después permiso: refrescar actores/fuentes/finanzas/SQL/device, modoRescatista y única creaciónUI, pins reales y payloads exactos; no fabricar UUID ni renovar permisos. Cámara330 consulta aparte pendiente. No reabrir donante/cierre ni duplicar caso por prototipo cámara inexistente. Evidencia y límites checkpoint/progress.
