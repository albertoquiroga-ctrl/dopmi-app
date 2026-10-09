# Checkpoint Dopmi — dde1bb9, 9/10/2026

Estado **PLAY308_INSTALADA_QA_SMS_REAL_PENDIENTE**.
Entrega integral incompleta. Este checkpoint es la fuente de estado vigente;
[parity-current-review.md](parity-current-review.md) conserva el tablero y
[progress.md](progress.md) la evidencia fechada. Estados históricos inferiores
quedan supersedidos por este corte del 9/10/2026.

## Estado vigente — teléfono 308

- Referencia congelada dde1bb9d01e5f4c427424bffed99bf1c3ed1beca, incluye QA9ced.
- Producto final84687bb873760b806be93b5645c7c930bb1af0a1. Documentación c4dd59c
  y este cierre no crean otro candidato. Rama codex/design-foundation; PR6 borrador.
- CM6ac945b4a02ae85db266e20e finalizado success; build-info fuente exacta,
  Guardian true, Play internal, 2.3.3(308). Play release151/bundle308 publicada.
- Samsung SM-S938B conectado por ADB: package com.mycompany.dopmi,
  versionName2.3.3/versionCode308, installer com.android.vending comprobados.
  Inicio→Perfil→Información básica abiertos en308; sesión personal y teléfono
  vinculado conservados. Sin guardar cambios, desvincular teléfono ni enviar SMS.
  Fuente1.15/density420 conservadas. Capturas privadas en .tools/dde1/device-qa/
  play308-*. No disponibles en GitHub; no publicar datos personales.
- Reutilizar FULLCI37967904270, 19 pruebas dirigidas y revisiones846 sin defecto
  material, QA303/302 equivalente descrita abajo. Sin repetir suites/builds/flujos
  consumidos. La navegación308 no acredita mensajes de error Auth reales.
- Titular confirma NO haber probado código incorrecto/reenvío y NO disponer de
  otro número controlado no vinculado. QA real SMS negativa/reenvío sigue pendiente;
  no sustituirla por unit tests ni retirar el vínculo personal para forzarla.
- Próxima acción exacta: cuando exista un número controlado no vinculado, ingresarlo
  directamente en la app308, ejecutar código incorrecto y reenvío, comprobar mensajes
  seguros y confirmación final en la misma cuenta; registrar evidencia privada.
  Mantener aprobación humana UI/UX pendiente donde no esté expresamente acreditada.
  La siguiente conversación debe RETOMAR ESTA ENTREGA, no planear nuevo delta.

## Alcance y preservación

- ENTREGA_CONTINUA_EFICIENTE_VERIFICADA: N01–N11 dde1 más QA9ced, sin cuotas;
  cuatro lentes y una cola Flutter/ADB del integrador. No reabrir entregas/fixtures cerradas.
- Mock congelado dde1bb9d01e5f4c427424bffed99bf1c3ed1beca; archivo autorizado en
  Temp/dopmi-plan-dde1bb9-20261008/dopmi-functional-mockup-dde1bb9d01e5f4c427424bffed99bf1c3ed1beca.
  No usar .tools/design-reference ni absorber pushes posteriores.
- Rama codex/design-foundation, HEAD/remoto84687bb873760b806be93b5645c7c930bb1af0a1;
  PR6 abierto/borrador, base codex/Dopmi ba9f897. Inicio b4ac415/producto281fc37.
- Autorizados cambios/commit/push propios, FULLCI, PlayInternal y TestFlight para equipo.
  Sin merge/forcepush/limpieza global, producción/dinero real/invitaciones nuevas.
  Conservar com.mycompany.dopmi, firma, gates y guardas financieras.
- Dirty ajeno conservado. Baseline vigente compartidos .tools/dde1/postdocs-f4faaff-baseline;
  progress sólo append propio, parity merge3way limpio. Preview .tools/dde1/closing-preview,
  regenerar después de cambios. Commit documental f4faaff ya remoto; nuevos docs sin commit.

## Builds y gate

- Play303 instalada desde com.android.vending, fuente5080090; dumpsys/origen/sesión
  comprobados. FULLCI37946992790/allsteps success. CM6ac903950e26cbb7565d916f finalizado;
  Play tracks internal/completed303 y build-info Guardian true comprobados. No repetir build.
- Corrección SMS84687bb: phone_exists/otp_expired/rate-limit con mensajes fijos seguros;
  actor/UUID/confirmación conservados.19 pruebas dirigidas/analyze0issues, autorrevisión y
  revisión independiente código/seguridad/UI/UX sin defecto material. Presentación instalada pendiente.
- FULLCI37967904270 para84687bb: cuatro jobs/todos steps success confirmadosAPI.
  Android nuevo6ac92cb06d3df14ff7705612, android-guardian-internal, enviado18:04:34UTC;
  última API queued/fuente846, sin artifacts. Helpers/gate .tools/dde1/candidate-84687bb.
  No duplicar; conservar HEAD/remoto hasta fetch para garantizar fuente exacta.
- iOS6ac912b5a252e7188db7d6f6/fuente508: IPA2.3.3(304) generado/subido. Apple confirma
  carga Finalizado y DopMi Inner Team asignado; grupo5testers/15builds y dos filas con
  Instalada304/9oct: disponibilidad equipo acreditada. No atribuir aceptación visual/funcional.
  Sin cambios de roles/grupos/invitaciones/AppStore. .tools/dde1/ios-5080090.
  Timeouts API/Chrome fueron observación transitoria; no reinicios.

## SMS personal

- Fallo personal reproducido en303: Auth422phone_exists, falso mensaje conexión.
  Mismo teléfono confirmado en QAowner comprobado por huella privada.
- Titular autorizó específicamente retirar sólo vínculo QA en DEV. Transacción con
  precondiciones dejó phone/confirmación nulos, cero identidades phone y email/contraseña
  preservados. Sin eliminar usuarios/perfiles/datos. No repetir ni mover otro vínculo.
- Titular verificó personalmente su cuenta; SQL Auth confirma un único teléfono confirmado
  fuera de QA. No imprimir número/correo/OTP. Personal restaurada, modoAdoptante tras historial.
- Titular confirma que no probó código incorrecto ni reenvío y no tiene otro número;
  no afirmar esa cobertura ni quitar teléfono personal para forzar prueba.

## QA instalada vigente303 y evidencia equivalente302

- Login QA manual exacto comprobado. SMS real recibido/ingresado por titular;
  Verificación QA histórica acreditada; vínculo retirado después con permiso específico.
  Twilio Primary Approved/remitente activo/providerPhone DEV habilitado; secretos,
  número personal y OTP fuera de Git/log/chat. Teléfono Auth no se publica.
- Perfil writer Guardar/reabrir UI+SQL: version20/draft, marcador sintético bio,
  snapshot aprobado hash1577bbee04122c1742a6595bd86be158 intacto sin marcador.
  Preview nombre sólo memoria/Back descartado ya acreditado; no repetir reviews.
- Público REAL desde Cuenta y privacidad: tres tabs/cuerpos, contactos aprobados
  sin phoneAuth; filtro Macho vacío esperado SQLfemale, limpiar restaura tarjetas;
  detalle activo/Back conserva tab. Revisión independiente directa sin defecto material.
- Texto físico200%: perfil/editor/consentimiento/footer/bio con teclado;
  público header/tabs/tres cuerpos/grid/footer y filtros open/scroll/Back;
  notificaciones tres filas/Back sin nuevas lecturas; historial QA vacío/Back.
  Revisión independiente directa sin defecto material. Fuente1.15/density420
  restauradas exactamente. Historial personal no vacío/detalle200 acreditado después; no inferir acciones
  Aplicar/Limpiar200 por sólo alcanzar botones. Modal historias200/Back revisados independientemente sin defecto material.
- Chat: picker cancelar sin huérfanos, envío con teclado/persistencia, inbox
  activo/histórico acreditados. Zoom foto existente ahora acreditado/revisado:
  pinch real dos punteros amplía/reduce, pan desplaza, X vuelve mismo hilo/dos
  mensajes. Helper temporal exacto /data/local/tmp/dopmi-dde1-pinch.dex retirado.
- Inicio: En adopción inicial, período Ayer/Listo y semana/X persisten inmediato
  conforme frozen; Este mes restaurado. Resumen→borradorQA→editor→Back, tips/Back.
- Historias303 y revisión independiente directa: tapfoto siguiente/anterior;
  swipetexto arriba→detalle/Back y abajo→cierre; X/AndroidBack→Apoyar;
  hold8500ms texto y foto pausa, soltar avanza/fin; Home7s/resume conserva
  historia y luego avanza/finApoyar. No afirmar duración/progreso precisos.
  Motion screenshot-only, aislamiento PhoneLink temporal y restauración exacta.
  Consultar árbol activa accessibleNavigation; pausa accesible es intencional.
- Historias303 al200 físico: modal/nombre/CTA/importes/X legibles; updetalle/Back,
  downcierre, phototapnext yX ejecutados/revisión independiente sin defecto material.
  Font2 confirmada/restauración1.15/density420. No inferir pagos/cuerpo detalle completo.
- Historial personal303: movimiento existente Sin pago confirmado, lista/detalle/scroll/AndroidBack→Perfil al200 físico y revisión independiente directa. Sin activar Ver caso ni pagos.
  Notificación propia→editor/read_at, footer/modo y necesidad expandida acreditados.

## DEV, dispositivo y próxima acción

- Sólo DEV ohqxranynackjignryep; prod ysaoeuidcvgtlmphmeyb intacto. Cinco migraciones
  aditivas desplegadas una vez: mappings en migration-history-audit.md; sin replay/repair.
- Run6618130b-e715-44c9-b606-22136d484ff2, owner8fa6d91e-bbf9-481c-bc4f-9740f87c9a5a,
  vieweraf411001-9579-4c73-89d8-ce5a50dc62da. Credenciales sólo privadoTemp/active-runtime;
  no imprimir actorJSON/tokens ni automatizar login manual.
- Dos mensajesQA/cuatro objetos/dos read_at preservados; sin huérfanos/finanzas/Connect/cohorte nuevos.
  Writer version20/draft y snapshot hash1577bbee04122c1742a6595bd86be158 preservados.
- Samsung conectado, configuración original font1.15/density420 restaurada; único controlador Root.
1. Consultar mismo Android846 cuando avance: fuente/artifact/Publishing y Play tracks por separado.
2. Actualizar desde Play, confirmar versión/origen/sesión y revalidar delta SMS instalado;
   reutilizar QA303 equivalente, sin nuevas escrituras personales/fixtures consumidas.
3. Resolver evidencia factual SMSwrong/resend con respuesta humana o nueva fixture autorizada.
4. Regenerar/revisar/stage selectivo docs propios y push tras fetch del candidato;
   auditar alcance completo antes de ENTREGA_VERIFICADA_EN_DISPOSITIVO. No declarar cierre por CI.


### 2026-10-09 — Espera externa Android846

Tres turnos consecutivos revalidaron el mismo CM6ac92cb06d3df14ff7705612 queued/sin inicio ni artifacts. Trabajo independiente completado; entrega bloqueada hasta avance externo o respuesta factual SMSwrong/resend pendiente. No cancelar/reiniciar ni inferir fallo terminal; polling detenido. Commit documental propio8123bfd local, remoto846 conservado hasta fetch. TestFlight304 disponible al equipo y teléfono personal confirmado. Retomar mismo handle; publicar/verificar Play/instalar/revalidar delta y cierre Git aún pendientes. No ENTREGA_VERIFICADA_EN_DISPOSITIVO.


**Nuevo build solicitado por titular9/10:** anterior6ac92cb06d3df14ff7705612 confirmado canceled18:42:32UTC/sin inicio. Nuevo6ac936950aa4713b7ce0013c enviado18:46:47UTC/misma fuente846/FULLCI aprobado/android-guardian-internal; API posterior queued. Helpers .tools/dde1/candidate-84687bb-retry-20261009. Continuar con este handle; anterior terminal no repollar. No publicación/instalación nueva acreditada.

**Diagnóstico vigente de cola:** consola autenticada sin otros builds activos; Billing personal gratuito343/500 minutos macOS; #46 es número de build, no posición. Mac mini M2 queued sin inicio en API. Capacidad del proveedor es hipótesis, no causa confirmada; estado público operativo. No duplicar builds/comprar concurrencia. Primer turno de espera verificada después del diagnóstico; pendiente avance de6ac936950aa4713b7ce0013c y respuesta SMSwrong/resend. Cierre sigue sin acreditar.

**Bloqueo externo vigente del reintento846:** tres turnos consecutivos tras diagnóstico verificaron por API el mismo handle6ac936950aa4713b7ce0013c queued, started/finished null, sin artifacts ni pasos iniciados. No hay otro trabajo independiente ejecutable que sustituya publicación/instalación/QA del candidato; SMSwrong/resend sigue pendiente de evidencia factual. Se detiene polling y no se cancela/duplica. Reanudar ante avance externo o intervención del titular. Entrega no completada; alcance frozen y gates conservados.

### 2026-10-09 — Ticket Codemagic21219 enviado por autorización expresa
Titular autorizó enviar soporte tras diagnóstico. Formulario autenticado confirmó Issue #21219 / Your request form has been received y copia al correo de cuenta. Incluye build6ac936950aa4713b7ce0013c, workflow/fuente/hora/M2 y diagnóstico de cuota/concurrencia; solicita causa y ayuda para arrancar, sin suscripción/concurrencia de pago. Sin credenciales ni adjuntos privados. Evidencia privada .tools/dde1/codemagic-ticket-21219.png. Esperar respuesta por correo; publicación/QA siguen pendientes, no cierre.

### 2026-10-09 — Soporte confirma causa de cola, ticket21219
Respuesta directa visible de David Trdic: pico de carga en el pool de máquinas para la versión Xcode utilizada; están agregando máquinas y esperan inicio pronto. Alternativa sugerida: otra versión Xcode en configuración. Esto confirma capacidad del proveedor, no defecto app/cuota. No se respondió ni cambió configuración en esta consulta de estado del titular. Evaluar workaround con compatibilidad/gates antes de nuevo candidato; no inferir inicio del existente por respuesta.


### 2026-10-09 — Workaround autorizado Xcode26.5
Usuario solicita intentar sugerencia ticket21219. Se conserva fuente846 y FULLCI37967904270; override API environment.softwareVersions.xcode=26.5 sólo android-guardian-internal/M2, sin alterar YAML/firma/guards. Reemplazar anterior únicamente si sigue queued; preparar journal antes de POST; comprobar resultado nuevo.


Nuevo CM6ac945b4a02ae85db266e20e enviado19:51:17UTC; API confirma dynamicConfig.environment.softwareVersions.xcode=26.5, instanceType mac_mini_m2, fuente846, inicialmente queued. Anterior6ac936950aa4713b7ce0013c cancelado y confirmado terminal antes del reemplazo. Helpers .tools/dde1/candidate-84687bb-xcode265-20261009. Próxima consulta exclusivamente nuevo handle; no afirmar workaround resuelto hasta inicio/Publishing/Play.
