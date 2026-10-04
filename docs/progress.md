# Dopmi — registro de avance

## H10 proveedores y producción — 28 de septiembre de 2026

- Google/Apple habilitados en Supabase test; redirecciones OAuth comprobadas y
  vinculación manual activa. Secretos fuera de Git. Codemagic tiene Firebase y
  clientes sociales en grupos seguros, con ambos flags de aceptación activos.
- `Dopmi Production` (`ysaoeuidcvgtlmphmeyb`, us-east-1, USD0/mes) creado con
  esquema/funciones/buckets vigentes, sin usuarios ni datos demo. Registro y
  proveedores sociales apagados; no existen secretos Stripe y el dinero real
  sigue bloqueado.
- CI del SHA `267646d` detectó configuración Firebase ausente en builds de
  desarrollo, dos expectativas legales antiguas y una FK de revisión restrictiva.
  Se prepararon placeholders no secretos sólo para CI, se actualizó la prueba y
  se aplicó `h10_auth_reference_cleanup` en test/producción. PostgreSQL local
  conserva 254 pruebas aprobadas; la instancia local tiene historial previo
  desalineado y no se reparó ni reejecutó.
- CI [36491606164](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36491606164)
  aprobó los cuatro trabajos del SHA `c8894b4`. Android Codemagic
  [6abae7c8c3323875fd396d2e](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abae7c8c3323875fd396d2e)
  publicó 2.3.3 (260) a Play internal con estado `completed`. iOS
  [6abae7c91b8a7fd2eacfde7b](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abae7c91b8a7fd2eacfde7b)
  cargó 2.3.3 (261) a App Store Connect con `UPLOAD SUCCEEDED`; procesamiento y
  disponibilidad TestFlight aún deben reconsultarse. Ambos usan el mismo SHA.

## H10 política de privacidad publicada — 28 de septiembre de 2026

- El titular confirmó que el aviso cubre exclusivamente la nueva app móvil.
  Se publicó en https://dopmi.org/privacy-policy desde el repositorio
  `albertoquiroga-ctrl/dopmi-landing-mockup`, commits `654b86d`, `e77237f` y
  `aa9a355`. La URL anterior redirige permanentemente a la nueva.
- La ruta devuelve HTTP 200 por HTTPS sin login y el contenido publicado
  identifica Dopmi, responsable y domicilio autorizado; detalla categorías de
  datos, finalidades, visibilidad, proveedores, transferencias, conservación,
  seguridad, permisos, mayores de 18 años, ARCO y eliminación por soporte.
- `npm run lint`, `npm run build` y `git diff --check` aprobaron. La página se
  comprobó en navegador, con navegación semántica y sin overlay de error. El
  footer de la landing ahora enlaza la política.
- El conector Vercel quedó instalado, pero no tiene alcance API para el equipo
  `dop-mi` (403). Vercel/GitHub publicaron correctamente y la respuesta pública
  lleva encabezado `Server: Vercel`; el acceso API del equipo queda pendiente.
- La página no sustituye la eliminación dentro de la app ni cierra H10.2. Aún
  deben probarse el buzón `soporte@dopmi.org`, la solicitud/eliminación real y
  la correspondencia con Seguridad de los datos de Google Play antes del cierre.

## H10 accesos y cotización — 28 de septiembre de 2026

- Titular completó sesiones Google Cloud, Apple Developer y GoDaddy; verificadas
  por lectura en Chrome. App ID actual conserva Sign in with Apple habilitado
  como primario. Falta Services ID de Dopmi y clave de autenticación.
- Clave Apple KLYH2Y22TT registrada sólo para Sign in with Apple/Dopmi. `.p8`
  guardado fuera del repo con ACL del usuario. Services ID
  `com.mycompany.dopmi.auth` registrado con App ID `com.mycompany.dopmi`, host
  Supabase test y callback `/auth/v1/callback` guardados y reconsultados.
  Proveedor Supabase aún deshabilitado y sin prueba real.
- El titular completó la compra del buzón Pro Light preparado: MXN263.88. El
  producto aparece en Correo electrónico y Office; su panel de alta seguía
  vacío, así que soporte@dopmi.org aún no se declara creado. Renovación indicada
  para septiembre2027 por MXN479.88 sujeta a cambios.
- CI36447795107 sobre d45a367 completed/success. Remotos conservan d45a367
  en continuación y ba9f897 en principal. No se alteraron firmas ni pagos.
- Pendientes: alta del buzón, secreto de cliente/proveedor Supabase y prueba OAuth
  real; el resto del alcance H10 continúa abierto.

## H10 servidor Apple — 28 de septiembre de 2026

- Base67b4041 y CI36427673710 comprobados success (cuatro trabajos). Mockup
  a246fa6 sin cambios. Google sigue en reautenticación; no se declaran nuevos accesos.
- Preparado registro privado cifrado y servicio de revocación Apple. Firma,
  issuer/audience/nonce/subject/exp verificados con pruebas JWT criptográficas.
  Incluye pérdida de respuesta al guardar, aislamiento por propietario y
  conservación de credencial ante fallo de revocación.
- Migración20260928154523 → remoto20260928155742; función apple-credentials v1,
  flag apagado, HTTP401 sin sesión/503 deshabilitado. RPC anon/authenticated
  denegada, RLS activo, cero credenciales. No hay login/revocación Apple real aún.
- Suite completa400 pruebas (nueve nuevas específicas) y Deno check aprobados. PostgreSQL
  local254 aprobadas después de aplicar las tres correcciones H9 ausentes en
  esa instancia; fallo inicial documentado, sin regresión remota ni cambios pagos.
- Pendiente integración nativa con registro servidor, secretos/capacidades Apple,
  cuentas OAuth, eliminación completa y demás H10. No se publicaron builds.


## H10 iniciado — 28 de septiembre de 2026

- Titular acepta H9 suficientemente para continuar; no se atribuye una nueva
  prueba instalada. Plan autorizado en h10-execution.md; pantallas aplazadas.
- PR6 abierto/draft, remoto ef9f009 y principal ba9f897 comprobados; mockup
  a246fa6 sin cambios. Archivos locales ajenos preservados.
- Guardas de configuración: entorno test explícito, rechazo de producción no
  comisionada, endpoint registrado y correspondencia de ref en claves anon.
  Las claves publishable opacas requieren comprobación remota independiente.
- Google nativo Android/iOS implementado a nivel cliente, cancelación y doble
  pulsación probadas mediante proveedor inyectable. Adaptador Apple preparado
  con nonce criptográfico; activación nativa bloqueada hasta disponer de
  revocación servidor. No se declara OAuth real comprobado ni habilitado.
- Python: 10 pruebas; Flutter analyze sin incidencias y 84 pruebas aprobadas
  desde copia de fuente fuera de OneDrive (el checkout bloquea unit_test_assets).
- MCP Supabase lista únicamente proyecto test ACTIVE_HEALTHY. No se desplegaron
  migraciones ni se creó producción. Apple Developer devolvió conexión reset;
  GoDaddy pendiente de acceso. Se solicitó apertura de ambas sesiones en Chrome.
- Pendientes H10: credenciales/callbacks y vinculación, revocación Apple,
  eliminación completa, medición/consentimientos, correo/legal, producción y
  entrega instalada. No cerrar H10 por este primer bloque.
- Código 7b3e589 enviado a PR6; CI 36427481966 iniciado, resultado pendiente.
  Google Cloud exige reautenticación del titular para consultar los clientes;
  pestaña conservada. No se compraron servicios ni se publicaron builds H10.


## H9 candidato publicado — 27 de septiembre de 2026

- Código candidato `73c731fcdb4b99b4dd94bc40c15a0e272efb713c`, diseño de referencia `a246fa6`. [CI 36330974531](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36330974531): cuatro trabajos success, incluidos PostgreSQL/concurrencia, integración real ampliada, Flutter y compilaciones Android/iOS simulator.
- [Codemagic 6ab93b1e75e12724939f4af7](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6ab93b1e75e12724939f4af7): android-guardian-internal, firma/análisis/tests/AAB/Publishing success; commit exacto comprobado. Android **2.3.3 (259)**, com.mycompany.dopmi. Log de publicación y consulta posterior de Play: track internal, status completed, versionCode259.
- Builds intermedios 6ab939ff78f056c20c4318d2 y 6ab93a8025013d476dd567db cancelados para distribuir únicamente el candidato corregido. El primer CI detectó codificación Windows-1252 en una prueba; normalizada a UTF-8.
- Protección adicional del avatar aprobado: migración 20260927154814 → remoto 20260927154928. Intento de borrado desde propietario y lectura posterior comprobados mediante Storage real. Las tres migraciones son compatibles con el cliente instalado anterior.
- Remoto: cinco adopciones/cinco casos públicos conservados. Se añadió un avance DEMO H9 ficticio a Choco · Recuperación demo mediante RPC de guardar/enviar/revisar, con procedencia sintética explícita en auditoría; consulta pública comprobada. No representa revisión humana ni gasto real, y no creó pagos.
- Pruebas integradas finales: cuatro recorridos completos aprobados, analyze limpio. Cero cuentas temporales de aceptación; instancia dopmi-h9 eliminada y contenedores locales originales restaurados conservando sus volúmenes.
- Asesores Supabase conservan avisos conocidos: tablas privadas sin políticas públicas, RPC SECURITY DEFINER intencionales y protección de contraseñas pendiente H10. No se ampliaron grants ni se declara auditoría de producción.
- H9 técnico listo para revisión agrupada en docs/h9-acceptance.md. **Aceptación funcional instalada del titular pendiente; H9 no cerrado.** Fidelidad visual aplazada por decisión del titular; no se atribuye aprobación a Irlanda. H10/H11, dinero live y excepción H5 permanecen separados.
- Este registro documental es posterior al SHA distribuido y no cambia la app.


## H9 — integración y correcciones, 27 de septiembre de 2026

- Autorizado H9 con aceptación final agrupada; el titular admite pantallas actuales y aplaza fidelidad visual. Matriz y guía en h9-acceptance.md. Rama codex/design-foundation preservada, PR6 abierto; Irlanda sigue a246fa6.
- Corregidos: fotos no visibles al moderar avances, ausencia de paginación/reintento, aprobación de perfil con parámetro inexistente, notificación duplicada al aprobar una corrección y acceso público a medios tras perder visibilidad/verificación. Panel conserva notas ante error, evita doble envío y exige resolución escrita.
- Integración real ampliada en adoption_backend y rescue_backend: favoritos aislados/tombstones, reportes idempotentes y resolución, avances con corrección/foto/revisión, perfil aprobado frente a edición privada, adopción vinculada y retirada de permisos de archivos. Cuentas y objetos temporales eliminados por teardown.
- Local: 23 pruebas admin y build; 80 Flutter; 391 Node/backend financiero; 247 pgTAP; seis configuración móvil; concurrencia financiera aprobada. Flutter analyze limpio después de corregir estilo. La evidencia final de CI y dispositivo se registra por separado.
- El Storage local anterior falló antes de subir por un índice incompatible (42P10). Se preservó su volumen y se levantó dopmi-h9 desechable desde cero; las cargas reales funcionan. OneDrive bloqueó unit_test_assets; Flutter se verificó desde copia de la misma fuente fuera de OneDrive. No se corrigió RLS para ocultar fallos de infraestructura.
- Supabase MCP, Codemagic API y lectura de cuenta Stripe test comprobados. Smoke financiero remoto: 18 comprobaciones aprobadas; Cron existente activo. No se efectuaron nuevos cobros ni se reabrió la excepción de disputa de H5.
- Migraciones H9 aplicadas por MCP, versiones 20260927154149 y 20260927154152, sin alterar firmas ni permisos existentes. Cuerpos remotos coinciden normalizando saltos de línea; correspondencia en migration-history-audit.md. Nuevas URLs firmadas de medios respetan visibilidad; las ya emitidas vencen a los 60 segundos.
- Pendiente: CI por SHA, candidato Internal Testing, preparación instalada y revisión del titular. No se declara H9 cerrado ni aceptación visual de Irlanda.


## H8 candidato corregido publicado — 26 de septiembre de 2026

- Candidato de aplicación `ea5350e2cff28aeac29938512bd1206a122cd94e`, referencia Irlanda `a246fa6f42ec517aae264d7fbd2358d647c4f840`.
- [CI 36294379013](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36294379013): los cuatro trabajos terminaron con `success`, incluidos formato, análisis, 80 pruebas Flutter, capturas, Android, iOS simulator, PostgreSQL/concurrencia financiera e integración real de identidad/adopción.
- [Codemagic 6ab89b4db5c299cd1e6841cc](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6ab89b4db5c299cd1e6841cc): workflow `android-guardian-internal`; configuración, firma, análisis, pruebas, AAB, Publishing y limpieza terminaron con `success`. Android **2.3.3 (256)**, paquete `com.mycompany.dopmi`, commit exacto comprobado.
- El build previo `6ab89a9871afc738798a3077` se canceló durante instalación de SDK antes de compilar/publicar porque el primer CI detectó una diferencia de formato. No produjo una versión de tienda.
- Google Play Internal Testing contiene el candidato corregido. H8 conserva V en No hasta que Irlanda/titular instalen 256, recorran la matriz y acepten o reporten diferencias. Dinero permanece en test; iOS de distribución sigue H11.
- Esta entrada documental es posterior al SHA distribuido y no cambia la aplicación instalada.

## H8 auditoría de cierre y correcciones de fidelidad — 26 de septiembre de 2026

- La auditoría requisito por requisito detectó que la matriz seguía marcando rutas implementadas como parciales o inexistentes y que la evidencia HTML completa se detenía en acceso. `design-parity.md` ahora registra I/T/V vigentes y correspondencias reales; V continúa en No.
- El HTML `a246fa6` se ejecutó localmente y se capturaron pantallas completas de Adoptar, Perfil, Apoyar, Inicio/Casos rescatista y detalle de caso. Las parejas HTML/Flutter quedaron versionadas en `docs/design-reviews/h8-complete`.
- Perfil donante incorpora el acceso y contador de **Rescatistas guardados**; abre directamente `/saved?kind=rescuer`. La vista de guardados inicializa la pestaña solicitada sin duplicar repositorios ni exponer contenido retirado. Una prueba nueva cubre el recorrido.
- Apoyar recupera la composición fotográfica y el CTA amarillo de Guardián con el asset vigente del mockup. El texto conserva las reglas reales: gastos pagados/aprobados, rescatistas verificados e impacto; no introduce fondo, bono o cashback. La suite detectó un overflow del hero a la altura inicial y se corrigió antes del cierre.
- Verificación desde una copia exacta fuera de OneDrive: `flutter analyze` limpio, **80 pruebas Flutter**, dos pruebas de generación de capturas y seis pruebas de configuración móvil aprobadas. El checkout sincronizado retuvo temporalmente `build/unit_test_assets`; no se atribuyó a la aplicación y la misma fuente se comprobó fuera de esa carpeta.
- Referencia Irlanda reconsultada al cierre: `a246fa6f42ec517aae264d7fbd2358d647c4f840`, sin cambios. Estas correcciones necesitan un nuevo candidato Internal Testing; build 254 no las contiene. Aceptación instalada sigue pendiente.

## H8 candidato completo en Google Play Internal Testing — 26 de septiembre de 2026

- Candidato de aplicación: `4ffc20fd0b07f51953175e148cfe82b37ecc369a`, referencia Irlanda `a246fa6f42ec517aae264d7fbd2358d647c4f840`. Este SHA reúne H8.0–H8.7; el cierre visual continúa sujeto a revisión instalada.
- [CI 36292534700](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36292534700): `web-and-database`, `flutter`, `ios` e `identity-and-adoption-backend` terminaron con `success`. Incluye análisis/pruebas Flutter, capturas, PostgreSQL/backend, concurrencia financiera, Android e iOS simulator.
- [Codemagic 6ab8927b80ac940ea0c3eaf8](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6ab8927b80ac940ea0c3eaf8): workflow `android-guardian-internal`, rama `codex/design-foundation`, commit exacto comprobado. Configuración Guardian, firma, análisis, pruebas, AAB y acción separada de Publishing terminaron con `success`.
- Android **2.3.3 (254)**, paquete `com.mycompany.dopmi`; artefacto firmado `app-release.aab`. El workflow publica en Google Play `internal` con `submit_as_draft: false`. Compilación y publicación quedaron verificadas por separado.
- Irlanda puede actualizar desde Internal Testing y revisar Perfil, cambio de modo, ambos navbar, swipe, Mis match/guardados, Apoyar/historias, recorridos de rescatista, aportaciones y Guardián. H8 permanece abierto hasta registrar esa aceptación visual y cualquier corrección resultante. Dinero continúa exclusivamente en test; este candidato no incluye un TestFlight equivalente.
- Esta entrada documental es posterior al SHA distribuido y no cambia la aplicación instalada.

## H8.7 aportaciones y Guardián — 26 de septiembre de 2026

- Aportar separa monto y revisión, usa cantidades sugeridas/personalizada y resume gasto e importe antes de abrir Checkout. Stripe sigue capturando el método; al regresar o reanudar la app se consulta el historial por la misma llave idempotente.
- El resultado sólo se presenta con estado persistido: procesamiento bloquea otro intento; confirmado muestra neto asignado y transferencia; cancelado y devuelto se distinguen. Un fallo incierto conserva llave e importe para reintentar sin duplicar el pago.
- Guardián adopta la composición visual del mockup para introducción y membresía activa, sustituyendo el fondo comunitario por gastos pagados/aprobados y capacidad real. Mantiene consentimiento, primer cobro al activar, meses omitidos sin deuda, cambio futuro de monto/tarjeta, cancelación, impacto e historial H5.
- Capturas Flutter reales a 377 × 852: `contribution-amount.png`, `guardian-intro.png` y `guardian-active.png`. La inspección comprobó jerarquía, importes reales y ausencia de fondo/bonos/cashback. Pruebas dirigidas: 36 aprobadas; análisis limpio. Aceptación instalada continúa pendiente.

## H8.6 perfil público moderado del rescatista — 26 de septiembre de 2026

- Perfil propio separado del expediente de identidad: nombre público, avatar, descripción, ciudad/estado e Instagram/Facebook. Domicilio, teléfono, correo, documentos y datos bancarios no forman parte de esta superficie.
- El dueño conserva borrador, correcciones, rechazo, envío y retiro. Una edición posterior no reemplaza la última instantánea pública aprobada; administración revisa y publica desde Moderación. La foto vive en un bucket privado y sólo se firma para el propietario o cuando aparece en la instantánea aprobada.
- Flutter incorpora `/rescuer/profile/edit`, accesos separados para editar/ver perfil, ayuda y Stripe Connect. El perfil público usa avatar/enlaces aprobados y conserva Actividad, En adopción y Casos. Administración añade cola de perfiles con versión y decisión.
- Migración local `20260927033610_moderated_rescuer_profiles.sql`, remota `20260927033251`. Remoto comprobado: tabla pública presente sin `SELECT` anónimo, auditoría en `private`, bucket no público y RPC administrativa sin ejecución anónima. El helper de política de Storage conserva ejecución anónima deliberada para evaluar avatares aprobados; retirar ese permiso rompió la prueba de lectura pública y se descartó localmente, sin aplicar una migración correctiva.
- PostgreSQL local reproducido desde cero: 243 pruebas. Flutter: prueba nueva de corrección/guardado/envío y análisis limpio; administración: 19 pruebas y build aprobados. Aceptación visual instalada continúa pendiente.
- La puerta financiera completa detectó que `public_case_progress` omitía las asignaciones de Guardián en los totales públicos. La migración local `20260927035600_public_case_guardian_progress.sql`, remota `20260927034007`, usa `dopmi_expense_funding` como fuente única para aportaciones individuales y Guardián. Las 338 regresiones financieras específicas aprobaron; remoto confirma que la RPC desplegada usa esa fuente sin referencia privada directa.

## H8.6 vínculo caso–adopción y publicación por pasos — 26 de septiembre de 2026

- Un caso aprobado del propietario puede crear o reabrir una única publicación de adopción vinculada. El vínculo no cambia el estado del caso ni publica la adopción: sus ciclos de borrador, envío y moderación siguen independientes.
- La publicación de adopción usa **Fotos → Información → Revisión**. Cada avance guarda el borrador en servidor, conserva el vínculo y permite regresar; el resumen no declara publicación antes de la respuesta del servidor.
- Migración local `20260927032540_case_adoption_link.sql`, remota `20260927031531`. Añade una FK aditiva/índice único parcial y conserva la firma de `dopmi_save_adoption`; build 253 sigue compatible. Remoto: columna presente, ejecución autenticada permitida y `anon` denegado.
- PostgreSQL completo: 236 pruebas; cubre creación vinculada y rechazo de duplicado. Flutter: análisis limpio y 20 pruebas dirigidas, incluidos reintento de borrador por pasos y persistencia del UUID del caso. Falta captura/revisión instalada.
- Verificación, caso y gasto usan ahora **Archivos → Información → Revisión**. Cada avance persiste el borrador, los estados enviados abren en resumen protegido y una operación de guardado/carga muestra progreso real. La prueba conserva campos privados tras un conflicto y completa el resumen al reintentar.
- Capturas reales nuevas a 377 × 852: Inicio, Mis casos y primer paso de verificación. Se corrigió el botón de regreso indebido en Inicio y se comprobó la barra rescatista de cinco destinos. Falta aceptación instalada de Irlanda.

## H8.6 Inicio del rescatista — 26 de septiembre de 2026

- Inicio consume un resumen autenticado y muestra verificación real, casos activos, borradores/correcciones, mensajes sin leer y actividad reciente. Las acciones conducen al registro o conversación correspondiente; el vacío ofrece Publicar.
- La tarjeta financiera ya no presenta un “saldo disponible”: separa montos **Asignado**, **Transferido** y **En revisión**, según estados persistidos. No afirma depósito bancario y no expone identidades de donantes ni referencias del procesador.
- Migración local `20260927031520_rescuer_dashboard.sql`, remota `20260927030616`. La RPC requiere cuenta autenticada. Remoto comprobado con un rescatista de pruebas: un caso activo, un gasto borrador y montos cero reales. PostgreSQL completo: 234 pruebas; Flutter dirigido: cuatro pruebas aprobadas y análisis limpio.
- Mis casos ya diferencia borrador, revisión, correcciones, publicado y cerrado; presenta feedback del equipo y acciones específicas. Un caso aprobado ofrece preparar una publicación de adopción separada, sin publicar mediante interruptor. La prueba a 390 px detectó y corrigió una restricción infinita en el encabezado.
- H8.6 continúa con el vínculo persistente caso–adopción, formularios por pasos, verificación/evidencia y perfil/configuración propios. Aceptación visual instalada pendiente.

## H8.5 Apoyar y detalle de caso — 26 de septiembre de 2026

- Apoyar reproduce la estructura vigente de Irlanda: encabezado con Mis match/notificaciones, “Descubre casos”, carrusel de progreso circular, “Ver todos” y entrada destacada a Guardián. Sólo muestra casos con gastos aprobados y capacidad restante; el vacío conduce a Adoptar.
- El detalle usa ubicación pública aproximada, responsable enlazado, recibido/objetivo, categorías, historia, gastos desplegables, galería pública, Guardar/Compartir/Reportar y avances moderados. Cada gasto aporta únicamente por el flujo real; la interfaz no anticipa éxito.
- La migración local `20260927030310_public_case_progress.sql`, remota `20260927025431`, repone en la RPC pública los agregados de asignación/transferencia y añade el objetivo calculado exclusivamente con gastos públicos aprobados. No expone donantes ni identificadores de Stripe y conserva firma/build 253.
- PostgreSQL: 232 pruebas aprobadas. Flutter: análisis limpio, suite completa de 75 pruebas y generación de capturas aprobadas. La inspección a 377 × 852 corrigió monto truncado, paginación innecesaria y ausencia de Mis match. Referencia reconsultada al cierre: `a246fa6f42ec517aae264d7fbd2358d647c4f840`, sin cambio. Aceptación instalada de Irlanda permanece pendiente.

## H8.5 perfil público e impacto asignado — 26 de septiembre de 2026

- El perfil público del rescatista ya obtiene un resumen único del servidor y separa **Actividad, En adopción y Casos**. Sólo agrega publicaciones y avances aprobados; conserva Guardar, Compartir, Reportar y el acceso a conversación sobre una publicación pública.
- “Mi impacto” relaciona únicamente las aportaciones confirmadas y efectivamente asignadas de la persona autenticada con los avances públicos de esos casos. No devuelve identidades de otros donantes, datos de Stripe, documentos ni información privada del rescatista.
- Migración local `20260927024050_public_rescuer_and_impact.sql`, remota `20260927024547`. Mantiene las RPC anteriores y el build 253 compatibles. En remoto se comprobó acceso anónimo al perfil público, denegación anónima de impacto y acceso autenticado sólo al impacto propio.
- PostgreSQL local completo: 230 pruebas aprobadas. Flutter: análisis limpio y 23 pruebas dirigidas aprobadas, incluidos pestañas públicas, monto asignado/avances y cambio de experiencia. Falta la nueva composición de Apoyar, comparación visual instalada y aceptación de Irlanda; H8.5 continúa abierto.

## H8.5 avances moderados de casos — 26 de septiembre de 2026

- Los casos aprobados/cerrados admiten avances independientes con borrador recuperable, hasta seis fotos, envío, correcciones/rechazo y publicación administrativa. La edición no sustituye un snapshot público: un avance publicado se archiva o se complementa con otro registro.
- Storage nuevo `dopmi-case-update-media`, privado y limitado a imágenes de 5 MB. Escritura sólo del propietario mientras el avance es editable; lectura pública únicamente de rutas incluidas en el snapshot aprobado. Flutter reutiliza la preparación central que elimina EXIF y acota dimensiones.
- El detalle público muestra “Historia hasta ahora” en orden cronológico; el dueño entra a administrar avances, reanuda borradores y ve estados remotos. El panel añadió Moderación para avances y reportes persistentes.
- Migración local `20260927022858_moderated_case_updates.sql`, remota `20260927023747`. Es aditiva y no altera RPC consumidas por el build 253. Remoto comprobado: tablas pública/privada, bucket privado, RPC autenticada y ausencia de SELECT crudo. El aviso de tabla privada sin política pública es intencional y coincide con las tablas de auditoría existentes.
- PostgreSQL local reconstruido y cuatro suites: 224 pruebas aprobadas. Administración: 19 pruebas y build de producción aprobados, incluida la moderación de avance y resolución de reporte. Flutter: análisis limpio y suite completa de 73 pruebas aprobada. Falta aceptación visual y un build instalado; H8.5 continúa con Apoyar, perfil público completo e impacto.

## H8.3 detalle, guardados y Mis match en desarrollo — 26 de septiembre de 2026

- El detalle de adopción usa galería paginada, datos reales, historia, salud, convivencia, cuidados y responsable. Guardar es optimista y revierte ante fallo; compartir copia contenido identificable sin inventar un enlace; reportar persiste antes de confirmar; contactar exige confirmación y reutiliza el hilo idempotente existente.
- Volver del detalle ya no reinicia el mazo: reconsulta sólo la tarjeta abierta y conserva posición/filtros. Si la publicación dejó de estar disponible, la retira sin exponer su nuevo borrador.
- Mis match incorpora búsqueda real por mascota/persona, conversaciones y accesos a guardados. Guardados separa Adopción, Donación y Rescatistas, con conteos/vacíos y marcadores privados para contenido retirado; esos marcadores sólo incluyen UUID/disponibilidad y pueden eliminarse.
- Migración local `20260927020621_community_saved_reports.sql`, remota `20260927021744`: favoritos UUID de casos/rescatistas, búsqueda de conversaciones, reportes persistentes y bandeja administrativa auditada. `20260927021820_community_table_boundaries.sql`, remota `20260927021850`, añade políticas restrictivas que documentan acceso exclusivamente por RPC. Las tablas no conceden lectura cruda a clientes.
- PostgreSQL: 213 pruebas aprobadas desde la base local reproducida. Flutter: análisis sin incidencias y 72 pruebas aprobadas en secuencia; cubren rollback de favorito, confirmación de contacto, separación de guardados y reintento idempotente de mensajes. Remoto: objetos, ejecución autenticada y ausencia de lectura cruda comprobados. Los avisos nuevos de tablas sin políticas quedaron resueltos; permanecen avisos generales ya documentados y protección de contraseñas H10.
- Casos y perfiles públicos ya tienen Guardar, Compartir y Reportar con el mismo acuse de servidor. La migración local `20260927022451_public_case_favorite_state.sql`, remota `20260927022716`, añade el estado privado `saved` a la respuesta pública sin revelar al usuario ni alterar la firma. PostgreSQL aumentó a 217 pruebas y comunidad Flutter a 13; la prueba detectó/corrigió un desbordamiento del selector de reporte a 390 px.
- Referencia Irlanda reconsultada al cierre: `a246fa6f42ec517aae264d7fbd2358d647c4f840`, sin cambio. Este bloque no tiene aceptación visual instalada; H8.3 sigue abierto hasta generar evidencia visual y revisión en Internal Testing.

## H8.2 descubrimiento funcional en desarrollo — 26 de septiembre de 2026

- Adoptar ya usa un mazo con foto dominante, Perros/Gatos, Pasar, Contactar y Me gusta por gesto o botón. Me gusta persiste el favorito antes de avanzar; las acciones se bloquean mientras esperan al servidor. Incluye carga, error/reintento, fin del mazo, reinicio y acceso a filtros/favoritos.
- Filtros funcionales de sexo, tamaño y personalidad; ubicación opcional con alternativa manual. El permiso se solicita sólo al pulsar “Usar mi ubicación aproximada”. El cliente redondea a dos decimales y el servidor devuelve únicamente distancia calculada, nunca coordenadas.
- Migración `20260927013712_adoption_discovery.sql` aplicada por MCP como `20260927014731`. La RPC nueva mantiene `dopmi_catalog` y el build 253 compatibles. Cinco publicaciones demo aprobadas recibieron personalidad y ubicación aproximada ficticias para probar el mazo.
- PostgreSQL local reconstruido desde cero: 198 pruebas aprobadas. Remoto: filtros de personalidad/radio y ausencia de coordenadas verificados. Flutter: análisis sin incidencias, 65 pruebas aprobadas. Captura inicial a 377 × 852 inspeccionada; se retiró el encabezado duplicado antes de la captura final.
- Casos reales elegibles se intercalan una sola vez después de cada dos adopciones. La fuente sólo incluye casos aprobados con gasto aprobado, pagable y capacidad restante; el botón abre la aportación de prueba y no declara éxito. Migración local `20260927015519_adoption_support_cards.sql`, remota `20260927015643`; consulta remota devolvió dos oportunidades reales de prueba.
- Pruebas ampliadas cubren arrastre corto/largo, botones equivalentes, fallo de favorito sin avanzar, paginación sin duplicados y tarjeta de apoyo después de dos adopciones; nueve pruebas de comunidad aprobadas y análisis limpio.
- H8.2 queda implementado y comprobado técnicamente en local/remoto; falta el paquete instalado y aceptación visual, por lo que V permanece pendiente. Referencia Irlanda continúa en `a246fa6`.

## H8.0 cerrado y Perfil/cambio de modo en ejecución — 26 de septiembre de 2026

- H8.0 convertido en matriz concreta de pantallas, acciones, datos, prueba y estado separado I/T/V. Ninguna pantalla se declara aceptada por Irlanda.
- Perfil deja de ser el formulario de datos: incorpora tarjeta de identidad, condición real de miembro/Guardián, historial real con carga/vacío/error, guardados, Configuración y cambio de experiencia dedicado. Información básica conserva su formulario en una ruta separada.
- Cambiar de modo actualiza únicamente `profiles.active_mode`, no confiere verificación y abre el inicio correspondiente. El guardado de datos personales ya no puede pisar esa preferencia. Publicar rescatista abre el selector Adopción/Caso.
- Capturas reales a 377 × 852 generadas para Perfil, Configuración y selector Publicar. La inspección confirma las barras distintas por experiencia y ausencia de cifras simuladas; la comparación/aceptación en Internal Testing sigue pendiente.
- Verificación del bloque: `flutter analyze --no-pub` sin incidencias; pruebas dirigidas de navegación, historial y cambio de modo, 20 aprobadas; suite completa Flutter, 64 aprobadas. La suite completa detectó inicialmente que Perfil intentaba construir el repositorio de pagos sin Supabase inicializado en pruebas; se corrigió convirtiendo esa lectura en error asíncrono presentable y la repetición completa aprobó.
- Referencia reconsultada: `irlanda/apoyar-detalle-perfil@a246fa6f42ec517aae264d7fbd2358d647c4f840`, sin cambio. Dinero permanece en test.

## Contenido demo disponible — 26 de septiembre de 2026

- Carga autorizada en Supabase de pruebas: cinco adopciones públicas con fotos y perfil ficticio, una en revisión, una con correcciones y tres casos demo (dos aprobados y uno cerrado). Inventario y límites en `demo-data.md`.
- Verificado por API pública: catálogo, filtros, perfil y cinco fotos accesibles; dos fotos privadas bloqueadas. Casos visibles con cero nuevos montos reembolsables. Sin cambios de esquema, permisos, servicios o movimientos financieros.
- Disponible para Internal Testing 2.3.3 (253) sin nuevo build. No se asignaron borradores a Irlanda sin confirmar su correo; revisión en dispositivo pendiente.

## H8: publicado para revisión por Internal Testing — 26 de septiembre de 2026

- A petición del titular, Codex inició por API `android-guardian-internal` sobre `codex/design-foundation`, SHA `74fd92286b089a162cd1448e3835c34fc44bc4f8`.
- [Codemagic 6ab783481453f4d0a7737de5](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6ab783481453f4d0a7737de5): finished; análisis, pruebas, compilación firmada y publicación success. Android **2.3.3 (253)**, paquete `com.mycompany.dopmi`.
- Log de Publishing verificado: publicación en `internal` exitosa; consulta posterior `google-play tracks get` devuelve release `completed`, version code `253`. Firma y Guardián test conservados; dinero real sin activar.
- Irlanda revisa exclusivamente desde Internal Testing. Instalación y aceptación visual pendientes; las capturas son complementarias. PR #6 continúa en borrador. iOS no se recompiló en esta entrega.
- Este registro es documentación posterior al SHA distribuido, sin cambios de aplicación.

## H8: CI final aprobado; aceptación visual pendiente — 25 de septiembre de 2026 (México)

- Código `3d5c6e3aafb69d1724e98e01db6a8e5ddd27623d`, [CI 36211702329](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36211702329): los cuatro trabajos terminaron con success, consultados directamente. Incluye PostgreSQL/backend, integración real de identidad/adopción, análisis/pruebas Flutter, capturas y compilaciones Android/iOS simulator. Supersede el pendiente de CI de la entrada anterior.
- [Artefacto de capturas 10895364071](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36211702329/artifacts/10895364071), `dopmi-design-review`, comprobado disponible. Capturas comparables permanentes y diferencias en `design-foundation.md`.
- [PR #6](https://github.com/albertoquiroga-ctrl/dopmi-app/pull/6) permanece en borrador para revisión visual de Irlanda. No se recibió aceptación visual, no se fusionó H8 ni se inició H9. H6/H7 ya integrados. No se generó candidato Codemagic ni se activó dinero real. Este cierre documental no cambia el código validado.

## H8: acceso adaptado y revisión visual preparada — 25 de septiembre de 2026 (México)

- PR #6 en borrador: `codex/design-foundation`. Primer commit `f9f3fe3d9eeb63292dff81c72cf85eea3fa422da`, CI [36210411470](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36210411470), cuatro trabajos success comprobados. La ampliación de acceso posterior requiere su propio CI; no atribuirle ese resultado.
- Incorporados dos pasos de onboarding para cada intención, entrada de cuenta, formularios y confirmación con marco visual común. Ilustraciones Flutter basadas en assets/estructura de Irlanda; copias económicas corregidas para gastos pagados y aprobados. Google/Apple conservan gates; legal de desarrollo sigue pendiente H10.
- Verificación local ampliada: 61 pruebas Flutter + generación de capturas aprobadas; regresión de historial cubre entrada por `push` y cambio de propietario. Navegación, regreso e intención de registro comprobados a 320 × 640 con texto al 200 %. Entrada normal rescatista resuelta sin reemplazar enlaces explícitos. Análisis sin incidencias y cuatro recorridos reales de backend local aprobados. Capturas HTML/Flutter por ruta versionadas en `design-reviews/h8-access`, con diferencias y límites en `design-foundation.md`.
- CI incorporará capturas de los componentes reales y acceso como artefacto `dopmi-design-review` vinculado al SHA. H8.1, H8.2 y H8.4 implementados; **H8.3 pendiente de revisión de Irlanda y ajustes visuales**. Se solicitó revisión al titular; no se recibió aceptación todavía. H8 no se cierra automáticamente. H9–H12 no están completados y no se activó dinero real.

## H7 integrado; base visual H8 implementada — 25 de septiembre de 2026 (México)

- H7 integrado mediante [PR #5](https://github.com/albertoquiroga-ctrl/dopmi-app/pull/5), head `08c72e2d44787ae16d59e0c57caadb41b306caa7`, merge `ba9f897f3fa418e952b98e4c604cffe468a8aa95`. CI [36208309068](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36208309068): cuatro trabajos success comprobados. Supersede el pendiente de integración anterior.
- H8 en `codex/design-foundation`: fuentes locales con licencias, tokens/componentes, SVG y barras por experiencia; bienvenida con tres intenciones. Estado conservado entre pestañas y eliminado al cambiar de identidad. Recuperación y estados financieros existentes conservados. Referencia de Irlanda reconsultada: sigue `a246fa6`.
- Pruebas locales: 57 Flutter + una generación de capturas; cuatro recorridos de backend real aprobados; análisis sin incidencias y seis pruebas de configuración móvil. Capturas a 377 × 852 y 320 × 640/texto 200 %, fuentes reales y sin datos personales; detalles en `design-foundation.md`.
- H8 no está cerrado: pendiente portar onboarding/formularios y revisión visual de Irlanda. CI del PR de esta base pendiente al escribir esta entrada. No hay nuevo build firmado, aceptación móvil ni activación de dinero real. H9–H12 siguen pendientes.

## H6 integrado; H7 aplicado y verificado — 25 de septiembre de 2026 (México)

- H6 integrado por [PR #4](https://github.com/albertoquiroga-ctrl/dopmi-app/pull/4), merge `99d3118ae69bc7c4c79200c28107bfb9cd2f26b1`. CI [36206671710](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36206671710) con cuatro jobs success sobre head `5741ef4`. Irlanda reconsultada al cierre: continúa `a246fa6`.
- H7 continúa en `codex/legacy-boundary`. Titular autoriza Supabase MCP directo con datos de prueba. Respaldo lógico fuera de Git y restauración en PostgreSQL local con PostGIS aprobados: 29 tablas, 25 filas, 142 restricciones, 20 rutinas. Los blobs permanecen en Storage; no se afirma backup completo del proyecto.
- Migración remota `20260926011355` aplicada; legado archivado, tres Cron antiguos desactivados, 16 políticas antiguas retiradas y buckets antiguos privados. Permisos actuales idénticos antes/después, trabajador financiero activo/succeeded y signup remoto transaccional revertido aprobado. Las 20 Edge antiguas en v13 responden retiro; fuentes comparadas, JWT preservado, cinco Edge actuales sin cambio. Detalles y recuperación en `legacy-retirement.md`.
- Resueltos avisos antiguos de vistas expuestas y search_path. Documentadas tablas privadas y RPC deliberadas. Protección de contraseñas filtradas pendiente H10.6: el MCP disponible no expone configuración Auth. No se declara auditoría de producción completa.
- Capa común de archivos Flutter implementada: validación, preparación sin EXIF, rutas/buckets/MIME, firma temporal y control de cambio de sesión; sin videos. Análisis Flutter sin hallazgos, 54 pruebas Flutter y cuatro recorridos backend local reales aprobados (identidad OTP/PKCE, adopción/Storage/mensajes y rescate/evidencia).
- PostgreSQL local actualizado sin reset desde sus seis migraciones existentes; pgTAP aprobado, 191 pruebas. El primer intento detectó que esa base local aún carecía de H4; se corrigió aplicando sólo migraciones locales pendientes. Seis pruebas de configuración móvil aprobadas. Flutter 3.47.4 localizado en el SDK ya instalado y Docker Desktop iniciado: supersede la limitación local de la entrada H6 anterior.
- Suite backend final: 391 pruebas aprobadas (incluye archivo/permisos y respuestas de retiro); administración: 18 pruebas y build aprobados. CI e integración final del PR H7 pendientes al escribir esta entrada. No se generó build Codemagic ni aceptación visual/dispositivo nueva. Dinero sigue en test.

## H6: consolidación y plan autorizado — 25 de septiembre de 2026 (México)

- Fetch remoto y comparación completados: principal `c6114b6`, continuación `b1a4ac9`; rama `codex/mvp-consolidation` creada desde continuación e integrada con principal sin conflictos. Archivos no rastreados del usuario conservados. PR/CI/integración final pendientes al escribir esta entrada.
- Actualizados alcance, instrucciones y backlog H6–H12. H5 conserva su aceptación test y excepción; videos/Meta/push/analítica avanzada post-MVP. Se mantiene la evidencia histórica.
- Referencia de Irlanda `a246fa6f42ec517aae264d7fbd2358d647c4f840`, consultada por Git. Matriz de 52 rutas y hashes SHA256 de 126 archivos; no se declara aceptación visual ni de dispositivos. Copia de inspección en `.tools/design-reference`, ignorada por Git.
- Codemagic API autenticada por variable de usuario: Android 2.3.3 (252), `0140fbd`, workflow `android-guardian-internal`, build `6ab6e1527e2cdbe815b37fa0`: firma/tests/publicación success. iOS 2.3.3 (241), `d74fe97`, build `6ab0b449b7d55fe4cc45f28e`, es anterior a Guardián. No se ejecutaron builds ni pagos nuevos.
- Automatizaciones activas del chat: `dopmi-cambios-de-dise-o` (diario 09:00), `dopmi-revisi-n-semanal` (lunes 09:30), `dopmi-recuperaci-n-y-accesos` (día 1, 10:00), hora de México. Sólo novedades accionables; no sustituyen monitoreo de servidor.
- Seis pruebas de configuración móvil aprobadas y diff sin errores. Docker instalado pero motor no disponible; Flutter no localizado en PATH. El gate completo se verificará en GitHub CI, sin atribuirlo a pruebas locales nuevas.


## H5 aceptado en modo prueba — 25 de septiembre de 2026

El titular autoriza seguir la recomendación del agente humano de Stripe. Se registra la excepción explícita: disputa automática remota y conciliación post-transferencia aislada con evidencia Stripe simulada; secuencia remota completa no ejecutada. Caso sco_VKNrYjqxXyMbJi. Revisión independiente final no identifica otro recorrido funcional pendiente; alcance documental/test. CI36202506285 sobre943a7d4 reconsultado: cuatro jobs completed/success. Entrega y límites en hito5-delivery.md; backlog y decisiones actualizados. Sin cambios de runtime, schema, gates ni nuevo build. Dinero real y R0–R6 permanecen separados.

## Soporte Stripe confirma limitación de disputa diferida — 25 de septiembre de 2026

Consulta enviada por chat del Dashboard con autorización explícita del titular. Agente humano Smile, caso `sco_VKNrYjqxXyMbJi`, respuesta observada el 25/9 a las 18:14 de México. Confirma que no se puede reproducir en test la secuencia cargo exitoso → transferencia confirmada → creación posterior de disputa: las tarjetas de disputa la generan al crear el cargo. No ofrece disparador manual, demora configurable ni mecanismo asistido por soporte para un cargo test ya liquidado.

Soporte recomienda dos capas separadas: integración real con tarjetas de disputa automática, verificando webhook y charge.disputed; conciliación posterior a transferencia aislada con evidencia Stripe simulada y transferencia confirmada. Ambas tienen evidencia previa: disputa inicial remota y Android (847e184/0140fbd), y variante local sin devolución con historial/reconciliación repetida (943a7d4, 388 tests locales y CI36202506285 con cuatro jobs aprobados). Esta recomendación no acredita un recorrido remoto posterior a transferencia ni autoriza dinero real. No se modificaron controles ni se hicieron pagos durante la consulta. H5 no se marca cerrado automáticamente: queda por resolver el cierre de aceptación con esta limitación explícita.

## CI final de cobertura de disputa — 25 de septiembre de 2026

GitHub Actions [36202506285](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36202506285), commit `943a7d4fb8797333e49981cbf7f1d96de15f2583`: cuatro jobs completed/success, consultados directamente por ID. Incluye web/base de datos, permisos y concurrencia PostgreSQL, integración de identidad/adopción, análisis/tests Flutter y compilaciones Android/iOS simulator. La consulta inicial por commit no mostraba esta ejecución porque el conector filtra ejecuciones de pull request; esta se originó por push. No fue ausencia ni fallo de CI.

No sustituye la prueba remota de disputa posterior a transferencia, único escenario de aceptación pendiente. No hay cambios de runtime ni necesidad de otro build móvil por esta evidencia. La consulta al titular sobre un mecanismo soportado por Stripe sigue sin respuesta; no consta un ticket de soporte enviado.

## Cobertura local de disputa posterior a entrega — 25 de septiembre de 2026

Prueba existente reforzada: adjustment review/disputed, historial propietario refund_review conserva asignado/transferido4314 y revertido0; reconciliación repetida no llama createReversal ni refunds.create. Variante nueva sin devolución elimina refunds del fixture y amount_refunded=0, cubriendo disputa sola después de transferencia. Evidencia Stripe simulada/RPC local real: no sustituye aceptación remota. Revisión independiente sin bloqueos, con ese límite explícito.

`npm test` en tools/verification:388 aprobadas,0 fallos. Intento de filtro aislado falló en inicialización PGlite cerrado; ejecución completa payments337 pasó antes de añadir variante y suite final388 pasó después. Sin cambios de runtime ni despliegue. Disputa real posterior a transferencia sigue pendiente de mecanismo soportado por Stripe; consulta al titular para soporte sin respuesta en conversación.

## Fin de mes aceptado en app y cancelación sin renovación — 25 de septiembre de 2026

Capturas1000344230/1000344228 confirman febrero28→marzo30 y marzo30→abril30, ambos pago200/fee4/Stripe12.99/net183.01, asignación confirmada. Captura1000344232 confirma Plan cancelado/Cancelación confirmada. SQL y Stripe consultados: suscripción y schedule canceled, seis ciclos mensuales. Revisión independiente anterior no encontró inconsistencias y limitó pendientes a estas pantallas y ausencia de renovación posterior.

Avance del mismo reloj clock_1UJhwr2ZjyMOQ0uLZSfYQN1Q después del siguiente aniversario, key dopmi-h5-calendar-ec3532d1-canceled-april30. Verificado ready1809128883(30/4/2027 23:48:03UTC), suscripción canceled; listado completo conserva exactamente seis facturas pagadas, última in_1UJi9u2ZjyMOQ0uLju5UmewR de marzo, sin factura de abril. Base conserva seis ciclos, último inicio1806446883(30/3), sin ciclo posterior. Recorrido integrado fin de mes aceptado **desde calendario preparado**, sin atribuir ancla30 a fecha del cargo inicial. No repetir. H5 permanece abierto por disputa posterior a transferencia y cierre de esa evidencia.

## Febrero corto y regreso al30 con nuevo monto — 25 de septiembre de 2026

Solicitud b00e8cf7-6956-455b-a525-3f61f6ab85f0 aplicada20000, attempts1/error null, effective_from1803854883(28/2/2027), precio price_1UJi822ZjyMOQ0uL4bXOgGUl. Captura1000344226 acredita plan200 y fecha28/2. Factura enero sigue paid5000. Avances del reloj con keys dopmi-h5-calendar-ec3532d1-{february28,march30}; actual ready1806450483.

Febrero in_1UJi8l2ZjyMOQ0uLVErWOLLT/ciclo5c23fdcc-cda1-459e-91ac-f172927d414e, período1803854883–1806446883(28/2→30/3), transferencia tr_3UJi902ZjyMOQ0uL1kLxd8NF fuente ch_3UJi902ZjyMOQ0uL1bAhaixk. Marzo in_1UJi9u2ZjyMOQ0uLju5UmewR/ciclo69f7b4fd-fd44-4c41-a7ca-ab32735fb94c, período1806446883–1809125283(30/3→30/4), transferencia tr_3UJiAy2ZjyMOQ0uL16MyFkiY fuente ch_3UJiAy2ZjyMOQ0uL1BGaKed2. Ambos paid20000, fee400/Stripe1299/net18301. Transferencias verificadas directamente test/18301/fuente exacta/revertido0. Listado completo seis facturas, todas paid con attempt_count1; sin factura extra del reset. Pendiente pantalla de ciclos febrero/marzo y cancelación normal con ausencia de siguiente factura. No repetir renovación.

## Renovaciones del calendario preparado hasta enero — 25 de septiembre de 2026

Reloj integrado avanzado secuencialmente, esperando cada conciliación:30/10→30/11→30/12→30/1/2027. Actual ready1801352883; período de enero1801349283–1803854883, siguiente28/2/2027 22:48:03UTC. Cuatro facturas subscription_cycle pagadas5000, cada una con fee100/Stripe586/net4314 transferido. Lectura directa de las cuatro transferencias confirma test,4314, fuente exacta y reversión0. No factura adicional de reset en listado completo.

Octubre in_1UJi122ZjyMOQ0uLzk5zOFNa/ciclo e2b5bfac-2dc7-4ff3-9d4d-b0a3dbffd517/tr_3UJi1J2ZjyMOQ0uL0AiN8qZN; noviembre in_1UJi282ZjyMOQ0uLJlI2rUgD/8189041a-ef2f-4491-b716-881577b919dc/tr_3UJi3C2ZjyMOQ0uL0wnxz6hP; diciembre in_1UJi3i2ZjyMOQ0uLfx3hFb8s/272da4d7-4277-4a99-873b-f89cd9b20614/tr_3UJi4A2ZjyMOQ0uL1vvnu1Qx; enero in_1UJi4r2ZjyMOQ0uLgU0nS1q0/e20cdb25-dad3-42e1-a4d2-3a54bd5bd0da/tr_3UJi582ZjyMOQ0uL1sGr1R8Z. Keys avances dopmi-h5-calendar-ec3532d1-{october30,november30,december30,january30}.

Pendiente acción móvil: solicitar200 para28/2, comprobar enero conserva50, cruzar febrero y retorno30/3, cancelación y pantalla. No avanzar reloj mientras se coordina esa solicitud. H5 sigue abierto.

## Alta móvil real y calendario de fin de mes preparado — 25 de septiembre de 2026

Capturas1000344214/1000344216: plan activo50 e inicial25/9 con pago50, fee1, Stripe5.86, asignado/transferido43.14. SQL y Stripe coinciden: ciclo ec3532d1-25e2-40b6-93e7-cf281fc854dc, sub_1UJhvU2ZjyMOQ0uLoXRDXJiU, price_1UJhvT2ZjyMOQ0uL4nKUoCXZ, cargo ch_3UJhuQ2ZjyMOQ0uL1SqAq1ae creado1790376483, transferencia tr_3UJhuQ2ZjyMOQ0uL1cq9IGIc4314 sin reversión. Schedule ready/attempt1, sin solicitudes pendientes. Reconsulta posterior de la sonda técnica cancelada anterior sigue sin facturas.

Asociado reloj clock_1UJhwr2ZjyMOQ0uLZSfYQN1Q al cliente real test cus_VKMdvrBZ0z0IUm; inicialización ready y avance al30/9/2026 22:48:03UTC(1790808483) confirmado. Preparación explícita por API: billing_cycle_anchor=now/proration_behavior=none; ancla anterior1792968483, nueva1790808483, siguiente1793400483(30/10). Pausa keep_as_draft conservada, active5000, listado completo de facturas vacío en lectura inmediata y posterior. SQL posterior active/ready/error null/cero pendientes. Keys dopmi-h5-calendar-ec3532d1-{clock,september30,reanchor30}. Estado ignorado .tools/guardian-integrated-calendar.json. No se editaron SQL ni fechas/referencias financieras. Pendiente avanzar renovaciones hacia febrero, gestionar monto/cancelación y validar móvil; esta preparación no demuestra alta originada en día30.

## Reanclaje Stripe test viable sin esperar fecha real — 25 de septiembre de 2026

Titular solicita alternativa a esperar cinco días. Revisión independiente acepta fixture integrada desde plan preparado, con alta ordinaria acreditada aparte y referencias financieras reales. Prueba técnica real sin PM: sub_1UJhpP2ZjyMOQ0uLsAqf3eLp en cliente técnico del reloj31/3/2027, precio5000, send_invoice/due1, ancla25. Se activó pausa keep_as_draft y actualizó billing_cycle_anchor=now, proration_behavior=none. GET: active, ancla cambió1808661600→1806501600, siguiente1809093600(30/4), pausa conservada. Dos listados completos sin facturas/pagos. Suscripción técnica cancelada después con invoice_now=false/prorate=false; no altera fixture original. Keys dopmi-h5-anchor-reset-probe-{create,pause,reset,cleanup}-20260925; estado local ignorado .tools/guardian-anchor-reset-probe.json.

Ruta elegida para futura alta del titular: reanclar al30/9 del reloj, anterior a primera renovación25/10; septiembre no tiene31. No requiere SQL manual ni cambios del servidor. Revisión pide comprobar facturación diferida del reset antes de usarla y tratar explícitamente cualquier factura subscription_update fuera de los validadores de renovación. Todavía no se pidió otro pago. Evidencia técnica viable, no aceptación móvil/económica completa ni prueba de programación inicial desde cargo31. Sustituye la espera real como dependencia obligatoria; H5 permanece abierto.

## Calendario real conservado por RPC e historial aislados — 25 de septiembre de 2026

Nuevo ejecutor `tools/verification/guardian-calendar-readonly.mjs`: sólo GET Stripe, todas las migraciones en PGlite efímero, registro inicial explícitamente sintético y sin liquidaciones. Las renovaciones reales in_1UJhNA2ZjyMOQ0uLoTPtIK17 e in_1UJhNF2ZjyMOQ0uLeLZ4LlKx pasan guardianRenewalCandidate; preparación RPC repetida devuelve el mismo ciclo, decisión skip con fresh:false; historial bajo rol propietario conserva exactamente 28/2→31/3 y 31/3→30/4/2027 a14UTC, sin pago confirmado. Ejecución final aprobada, cero escrituras remotas. La factura inicial subscription_create no es una renovación válida.

Revisión independiente sin bloqueos de seguridad; observó que exigir dos facturas no fijaba períodos concretos. Se añadieron expectativas exactas y unicidad de ambos períodos y se volvió a ejecutar satisfactoriamente. Alcance y comando en guardian-calendar-readonly.md. No acredita alta31, cobro/anulación mensual, año bisiesto, Supabase remoto ni app. H5 permanece abierto por calendario integrado completo y disputa posterior a transferencia; no repetir los casos ya aceptados.

## Calendario Stripe aislado: enero31–febrero28–marzo31 — 25 de septiembre de 2026

Lectura del cliente técnico confirmó correo sintético guardado, cero suscripciones y has_more false tras rechazos previos. Nueva key dopmi-h5-calendar-fixture-sub-email-ready-20260925 creó sub_1UJhM62ZjyMOQ0uLA0uURMeR, precio price_1UJhJU2ZjyMOQ0uLyE8PdFOQ, ancla day31/hour14. Configuración del ancla calculada por guardianMonthlyAnchor con timestamp explícito de fixture1801404000; no representa fecha de un cargo Dopmi. Crear exactamente sobre el ancla produjo factura inicial in_1UJhM62ZjyMOQ0uLG3jZUY8r draft/due5000/paid0, por lo que falló la expectativa técnica latest_invoice null; no se considera alta de producción.

Suscripción técnica puesta en send_invoice/keep_as_draft sin cancelación al final; auto_advance de factura inicial desactivado explícitamente. Reloj técnico clock_1UJgih2ZjyMOQ0uLc9TDSqN3 avanzado y verificado ready1806501600 (31/3/2027 14UTC). Listado completo, tres facturas draft/paid0/auto_advance false: inicial31/1→28/2; in_1UJhNA2ZjyMOQ0uLoTPtIK17 28/2→31/3; in_1UJhNF2ZjyMOQ0uLeLZ4LlKx 31/3→30/4. Todas5000, ancla31 conservada. Estado técnico ignorado en .tools/guardian-calendar-fixture.json.

Acredita el calendario real de Stripe con la configuración calculada, sin cobros. No hay vínculo con cuenta nueva ni tablas Dopmi; no acredita integración RPC/app de fin de mes, alta móvil31 ni año bisiesto. Mantener ese requisito abierto. No modificar fechas reales de cargos para aparentar cobertura.

## Cruce incierto aceptado en Android — 25 de septiembre de 2026

Capturas1000344188/1000344190 del titular,16:09: plan activo50, solicitud50 confirmada desde25/7/2028; historial de ese ciclo con siguiente25/8/2028, pago50, comisión1, Stripe5.86, asignado/transferido43.14 y asignación test confirmada. Coinciden con solicitud77f3f0f1-ebf8-49bd-a579-011647a534b4 y ciclo e9fecd46-53bc-44ad-9120-51d820897c31. Revisión independiente de2dd86c6 confirma coherencia técnica; estas capturas completan el único pendiente móvil del recorrido. No repetir. H5 sigue abierto por fin de mes y disputa posterior a transferencia.

Investigación separada: menú del pago test existente en Dashboard ofrece allowlist/blocklist/acceso, sin disparador de disputa visible; esto sólo descarta esa vía, no prueba imposibilidad global. Fixture calendario aislada: precio price_1UJhJU2ZjyMOQ0uLyE8PdFOQ creado para5000 mensual; intento de suscripción con cliente técnico previo rechazado Missing email. Se actualizó sólo ese cliente técnico a dirección sintética guardian-calendar@example.invalid y la misma key volvió a devolver ese error. No se registró suscripción ni factura creada en estos intentos; verificar por lectura antes de continuar (posible resultado idempotente). No se vinculó cuenta nueva ni alteró calendario de Dopmi. Prueba de calendario aún no acreditada.

## Escritura real perdida y aniversario cruzado — 25 de septiembre de 2026

Resultado posterior: conciliación normal applied a22:05:06.126948, attempts1/error null, conserva effective_from1848147669, verified_period_start1848147669 y boundary_invoice_id in_1UJhAE2ZjyMOQ0uLaG1E9SHD. Factura paid5000/attempt_count1, única del período en listado completo. Ciclo e9fecd46-53bc-44ad-9120-51d820897c31, cargo ch_3UJhFq2ZjyMOQ0uL107P1pCh test/paid5000/sin disputa ni devolución, fee100/Stripe586/net4314. Transferencia única tr_3UJhFq2ZjyMOQ0uL181fostv por4314 aacct_1UIimXFRDgVgGJcB, misma fuente, sin reversión, confirmada22:06:12.063514. No duplicados económicos observados ni aumento de intentos registrados. Backend/Stripe del cruce acreditado; falta pantalla móvil final del cambio y ciclo. Revisión independiente anterior pidió justamente fecha/período/factura originales y resultado económico, ahora consultados.

Titular confirmó disponibilidad antes de instalar target 5000, vencimiento 22:22:57 UTC, worker/webhook v20 y client v12; 18 smoke checks aprobados. Captura 1000344186 muestra plan 200 y solicitud nueva de 50 pendiente. Request 77f3f0f1-ebf8-49bd-a579-011647a534b4, price_1UJh932ZjyMOQ0uLpHTzqSn3, mutation_requested_at 21:59:05.735772, attempts1, effective_from1848147669.

Log 21:59:06.616 UTC confirma POST real 200 consumido antes del SDK, req_vwuu8POq3m7aKk, mismo UUID/precio y monto5000. Lectura Stripe independiente confirma suscripción activa test con ese precio y monto; base mantiene pending/guardian_processor_unavailable. Reloj avanzado con key dopmi-h5-cross-77f3f0f1-ebf8-49bd-a579-011647a534b4 a1848151269 y verificado ready. Nuevo período1848147669–1850826069; factura in_1UJhAE2ZjyMOQ0uLaG1E9SHD draft, paid0/due5000 y línea del precio exacto. Consulta de solicitud después del cruce aún pending, applied_at null, misma fecha efectiva y attempts1.

Instrumentación retirada inmediatamente: worker/webhook v21, client v13. Todos los archivos comparados iguales con originales y otros18 smoke checks aprobados. Falta observar recuperación normal después de available_at (failed impone espera5min), comprobar resultado/factura y pantalla móvil. No declarar todavía aceptación completa ni repetir POST. Esta es pérdida inyectada en transporte HTTP antes del SDK y ocultación temporal de lecturas, no un corte TCP.

## Intento de cruce no concluyente; restauración verificada — 25 de septiembre de 2026

Tras tres consultas sin solicitud nueva, se empezó a retirar instrumentación. La operación del titular llegó durante esa restauración: request 107aab57-346c-4e39-8a1c-ed6b9ff3e1b5 creado 21:54:13.814845 UTC, aplicado normalmente con mutación 21:55:06.069927, attempts 1, price_1UJh5B2ZjyMOQ0uLkELo7LAE, effective_from 1848147669. Reinstalación temporal v18/v18/v10 llegó después de la ejecución normal; no acredita pérdida. Consulta de logs 21:50–21:56 sin guardian_test_change_response_consumed. No se cruzó reloj, no reescribió solicitud ni fabricó fallo.

Instrumentación retirada de nuevo: worker v19, webhook v19, client v11. Todos los archivos recuperados comparados con originales v15/v15/v7, iguales; 18 smoke checks aprobados. Base active/20000/revisión5/cero pendientes. El siguiente intento requiere coordinar la acción antes de instalar/retirar para no repetir esta carrera; no interpretar ausencia momentánea de solicitud como abandono del titular. H5 y el caso de cruce incierto permanecen abiertos. Copia local ignorada .tools/guardian-change-originals.json conserva bundles originales sin valores de secretos.

## Aviso móvil aceptado e instrumento temporal instalado — 25 de septiembre de 2026

Captura 1000344178 muestra final del formulario tras actualizar: sin aviso genérico «Solicitud recibida», consentimiento desmarcado, monto 50 y botón deshabilitado. Junto a 1000344174/1000344176 (solicitud retirada, plan 50) cierra la comprobación visual pendiente. No muestra versionCode exacto.

Lectura previa confirma active/5000/revisión4/cero pendientes. Desplegado instrumento de cambio revisado: worker v16, webhook v16, client v8; originales recuperados v15/v15/v7 para restaurar. Target exclusivo sub_1UJa0n2ZjyMOQ0uLrY1yEBLv, cliente e item conocidos, monto nuevo 20000, vencimiento 2026-09-25T22:15:00Z. Runtime selecciona fetch normal al vencer. Helper recuperado de los tres despliegues coincide con archivo local; 18 smoke checks aprobados. No cambiaron flags, secretos, esquema ni reglas económicas. Todavía no hay solicitud ni pérdida observada: falta operación del titular, cotejar request/precio, cruzar reloj y restaurar inmediatamente los bundles.

## Transporte de cambio comprobado con SDK — 25 de septiembre de 2026

Prueba local adicional con Stripe SDK 22.6.0 y createFetchHttpClient: serialización real de subscriptions.update coincide con el filtro; SDK recibe StripeConnectionError tras consumir respuesta POST y lectura posterior. Al retirar wrapper, recupera la misma suscripción con monto nuevo mediante GET. Secuencia observada GET/POST/GET/GET, una sola escritura, eventos correlacionados por solicitud/precio. Cinco pruebas específicas aprobadas. Upstream simulado: no es aceptación remota ni cruce real. Instrumento sigue sin desplegar mientras se termina la captura pendiente del titular.

## Reloj preparado antes del aniversario — 25 de septiembre de 2026

Revisión independiente de bb3cbb4 confirma resuelto el bloqueo de atribución, sin nuevos bloqueos para preparar el despliegue temporal. Es revisión estática, no aceptación real. Lectura remota: plan test sub_1UJa0n2ZjyMOQ0uLrY1yEBLv active, 5000 centavos, management_revision 4, cero solicitudes pendientes; última solicitud amount withdrawn. Captura 1000344174 coincide. Se pidió sólo la parte inferior del formulario para verificar aviso residual.

Reloj clock_1UJaEp2ZjyMOQ0uLL5n6YZe1 avanzado mediante key dopmi-h5-change-boundary-preparation-1848147669 y reconsultado ready en 1848147069, diez minutos antes del period_end 1848147669. Suscripción conserva monto 5000 y última factura in_1UJfSg2ZjyMOQ0uLCDHFixMy. No se cruzó aniversario ni solicitó cambio. Bundles originales recuperados: worker v15, webhook v15, client v7. Instrumento aún no desplegado; instalar sólo al coordinar operación del titular para no consumir la ventana de 30 minutos esperando.

## Preparación de cruce de aniversario incierto — 25 de septiembre de 2026

Revisión independiente detectó falta de atribución por solicitud/precio. Corregido antes de despliegue: POST exige precio devuelto igual al solicitado y log registra UUID/precio; GET registra precio observado. Cuatro pruebas específicas aprobadas, incluyendo precio discordante y correlación. El operador deberá cotejar ambos identificadores con la solicitud persistida antes de avanzar el reloj. La ocultación GET es deliberadamente por suscripción/monto, no por solicitud. Sigue sin desplegar ni acreditar el escenario real.

Se añadió instrumento local guardian-change-loss-fetch.mjs: consume respuesta real de cambio de precio y oculta temporalmente lecturas de la suscripción activa exacta con el monto nuevo, también entre instancias, para poder cruzar el reloj antes de confirmar. No cambia solicitudes ni fabrica evidencia. Scope test/customer/sub/item/monto, key Guardián y body exactos, límite de respuesta y vencimiento máximo 30 minutos; cancelación confirmada pasa sin ocultación. Procedimiento en tools/verification/guardian-change-loss.md. No importado ni desplegado.

Tres pruebas de aislamiento/recuperación aprobadas; suite completa 385 aprobadas. Endurecimiento posterior para dejar pasar status canceled verificado con las tres pruebas específicas. Revisión independiente del instrumento solicitada y pendiente; no ejecutar todavía en remoto. No acredita el cruce integrado. Se pidió al titular confirmar el estado del plan existente para la comprobación móvil pendiente, sin solicitar aún cambio ni cancelación.

Revisión independiente del calendario: la fixture aislada puede probar calendario Stripe + servicios/RPC desde suscripción preparada, pero no un alta real del día 31. Mantener explícito ese límite; no sustituir silenciosamente el requisito ni falsificar charge.created. Consulta oficial de tarjetas de disputa confirma disparadores automáticos 0259/2685; no demuestra control del momento posterior a transferencia. Ese escenario sigue pendiente sin generar nuevos pagos al azar.

## Fecha real del cargo frente al reloj técnico — 25 de septiembre de 2026

Prueba aislada Stripe test con el mismo cliente técnico, sin metadatos de ciclo Dopmi ni vínculo con la cuenta nueva: reloj ready frozen_time 1801404000 (2027-01-31T14:00:00Z). PaymentIntent pi_3UJgqn2ZjyMOQ0uL1ojS6N5q, tarjeta de prueba pm_card_visa, succeeded por 5000 MXN centavos; cargo ch_3UJgqn2ZjyMOQ0uL1FZ9KEaz paid y livemode false tiene created 1790372413 (2026-09-25T21:40:13Z), fecha real en lugar del reloj. Refund completo re_3UJgqn2ZjyMOQ0uL1RSxGH5w succeeded por 5000. Keys estables dopmi-h5-calendar-charge-timestamp-20260925 y dopmi-h5-calendar-charge-timestamp-refund-20260925.

La ruta de cliente con reloj no basta para preparar el aniversario del día 31: guardian-schedule deriva el calendario del cargo verificado y además exige que el siguiente aniversario sea posterior al tiempo Stripe. No modificar charge_created en base ni suplantar la respuesta Stripe. No se pidió pago al titular. Se solicitó revisión independiente del montaje posible y del alcance que podría acreditar una fixture explícita frente al recorrido completo. Fin de mes permanece pendiente.

## Cuenta nueva y variante Checkout con cliente previo — 25 de septiembre de 2026

El titular entregó captura 1000344172 de la nueva cuenta con correo confirmado. Lectura remota confirma correo validado y cero activaciones, suscripciones y ciclos Guardián. No se inició alta ni se vinculó esa cuenta al cliente técnico.

Se probó únicamente con el cliente técnico de la entrada siguiente la variante Checkout payment con customer y sin customer_creation. Stripe creó cs_test_a1CEpSYMmow3xGVNweSMM1zmDLQhbZuhzoqcaWPSbtvBJL6tVOTaWECpFB, open/unpaid, customer_creation null y created 1790372316. Se expiró inmediatamente: expired/unpaid. Key estable dopmi-h5-calendar-compat-existing-only-20260925. No se abrió enlace ni se proporcionó medio de pago.

Esto precisa la incompatibilidad previa: Stripe admite cliente existente con reloj, pero no junto a customer_creation=always. El validador actual del alta exige always; no se alteró para esta prueba. guardian-schedule.mjs obtiene el aniversario de verified.charge.created: la fecha de una sesión creada no acredita la fecha de un cargo ni la aceptación de fin de mes. Sigue pendiente un montaje válido para ese recorrido; no pedir todavía el pago al titular. Sin cambios en código desplegado ni estado financiero de Dopmi.

## Compatibilidad Checkout y reloj previo — 25 de septiembre de 2026

Prueba API real de preparación, sin pago ni activación Dopmi: clock_1UJgih2ZjyMOQ0uLc9TDSqN3 y cliente técnico cus_VKLP2q0A8FgXQ4, test, metadata dopmi_acceptance=calendar_checkout_compat. Estado técnico fuera de Git en .tools/guardian-calendar-checkout-probe.json. Se intentó Checkout payment con customer preexistente del reloj y customer_creation=always para conservar la validación vigente del alta. Stripe 2026-08-26.dahlia rechazó HTTP 400, param customer: You may only specify one of these parameters: customer, customer_creation. Lectura posterior del cliente confirmó test_clock esperado, livemode false y cero sesiones (has_more false). Repetición diagnóstica conservó la misma key y fue rechazada igual; no hubo Checkout, cargo ni suscripción.

Esto descarta añadir simplemente un customer con reloj al request existente. No se cambió código desplegado, fechas de cargos, claves ni SQL. Los objetos técnicos quedan identificados para investigación; no pertenecen a una cuenta del titular ni contienen medio de pago. La prueba de fin de mes sigue pendiente: requiere un montaje que preserve evidencia financiera real, sin fingir que esta compatibilidad rechazada acredita el recorrido. La cuenta solicitada al titular aún no debe activar/pagar.

## Revisión del alcance de recuperación — 25 de septiembre de 2026

Auditoría independiente de coherencia de e693d96: evidencia suficiente para recuperación backend de reversión tras respuesta perdida antes del SDK, preservación de asignación pendiente y ausencia de duplicados económicos. Se precisa la redacción: attempts 1 más listado Stripe único no demuestra ausencia absoluta de peticiones HTTP adicionales; afirmar recuperación del mismo ID sin aumentar intentos registrados ni duplicar movimientos. Revisor no reconsultó fuentes remotas; consultas originales están descritas en la entrada anterior.

Se retiró del resumen el pendiente genérico de reversión incierta ya acreditado. La matriz exige reversión de cada destino y recuperación sin duplicados; no exige una nueva combinación de todos los fallos. Se conservan fin de mes, gestión con escritura incierta al cruzar aniversario, disputa posterior a transferencia y validación móvil pendiente. No se declara H5 completo.

Para fin de mes se revisaron calendar anchor y documentación Stripe: day_of_month 31 conserva fin de mes y febrero corto/bisiesto. Esto es documentación, no nueva evidencia integrada. Se solicitó al titular una cuenta de prueba sin plan previo, sin pedir pago aún. Falta establecer de forma válida el reloj del primer Checkout; no modificar fechas de cargos ni evidencia persistida para simularlo.

## Respuesta de reversión perdida y recuperada en entorno real — 25 de septiembre de 2026

Caso ciclo 8bea3790-89ea-4237-9c93-05eb2c10bbc5 (25/4/2028), cargo ch_3UJcvm2ZjyMOQ0uL0bNx3MeA, transferencia tr_3UJcvm2ZjyMOQ0uL0iVTYd9I por 4314. Verificación previa: cargo test pagado 5000, cliente esperado, sin disputa ni refund. Refund total re_3UJcvm2ZjyMOQ0uL0ACjDAwJ succeeded con key dopmi-h5-worker-response-loss-8bea3790-89ea-4237-9c93-05eb2c10bbc5.

Despliegue temporal limitado al transfer/ciclo/gasto/importe y vencimiento 1790373002390: worker/webhook v14 y client v6. Target vencido selecciona fetch normal. Se compararon bundles antes y después; 18 smoke checks aprobaron antes del refund. No se cambiaron flags, claves, SQL, leases ni Cron.

Log real a las 21:25:53.224 UTC: guardian_test_refund_response_consumed, HTTP 200, Request-Id req_x2si1gKLDtLXdK, reversión trr_1UJgcu2ZjyMOQ0uLTPv3xSyH por 4314. Se consumió la respuesta en el cliente HTTP antes de entregarla al SDK; no se declara corte TCP. El servicio registró guardian_refund_processor_unavailable; lectura SQL posterior: reversal_id null, attempts 1, asignación 4314 y comisión 100 conservadas, available_at 21:26:53.266. Stripe independiente ya mostraba exactamente una reversión completa.

Restaurados inmediatamente worker/webhook v15 y client v7. Comparación de todos los archivos contra los bundles originales: iguales, instrumento ausente. Otros 18 smoke checks aprobados. Sin intervención financiera posterior, ajuste completed a las 21:27:05.333 UTC: mismo reversal_id, attempts 1, refund 5000, comisión/asignación cero. Lectura Stripe posterior confirma una sola reversión 4314 y un solo refund succeeded 5000; ambos listados sin más páginas. Suite local completa: 382 pruebas aprobadas.

Acredita recuperación del servicio desplegado y RPC reales ante respuesta de escritura financiera perdida en cliente HTTP, sin duplicados ni liberación anticipada de asignación. Captura Android 1000344170 confirma ciclo 25/4/2028, siguiente aniversario 25/5/2028, devolución confirmada de 50.00 MXN, transferencias revertidas 43.14, comisión/asignación/transferido cero y asignación test de 43.14 con reversión confirmada. Costo Stripe histórico 5.86 sin reducir lo devuelto. Recorrido integrado de recuperación validado también en dispositivo; no acredita todavía cruce de aniversario incierto ni múltiples destinos con respuesta perdida (la devolución múltiple normal ya está aceptada).

## Instrumentación de transporte revisada — 25 de septiembre de 2026

Tras comprobar que el trabajador ganaba al relay, se preparó guardian-refund-loss-fetch.mjs sólo en tools/verification; no está importado ni desplegado. Inyecta pérdida antes de entregar al SDK una respuesta real de reversión compatible con transferencia/importe/MXN. Ruta, key, body y autorización test exactos; rechaza Stripe-Account. Límite 32 KiB/20 segundos y target <=30 minutos. Tres pruebas aprobadas, incluidas negativas por clave, cuenta, método, cuerpo y respuesta ajenos; añadidas a npm test.

Revisión independiente sin bloqueo del wrapper; exige que la integración temporal use fetch normal cuando venza el target (no invocar entonces su constructor). La intercepción es por instancia, no global; documentado. Falta preparar target y bundle temporal, ejecutar la reversión real, comprobar recuperación e inmediatamente restaurar bundles. No se declara corte TCP ni aceptación financiera a partir de estas pruebas locales.

## Intento financiero: trabajador ganó la conciliación — 25 de septiembre de 2026

Se ejecutó el instrumento local para ciclo c101a18a-e1ad-469a-9229-99fe05121f3c, cargo ch_3UJcwo2ZjyMOQ0uL0xVYySBz, transferencia tr_3UJcwo2ZjyMOQ0uL0VGq9emL. Lecturas previas: test, pagado 5000 MXN centavos, cliente esperado, sin disputa ni refund previo. Refund total re_3UJcwo2ZjyMOQ0uL0pXPw6Rs succeeded, creado con key estable dopmi-h5-response-loss-refund-c101a18a-e1ad-469a-9229-99fe05121f3c.

El ejecutor usó el servicio de producción y se relayaron get/observe/claim/checked a la RPC real. El trabajador normal completó antes de observe: ajuste completed, asignación/comisión cero. La validación de claim del instrumento encontró reversión ya confirmada y salió AssertionError, attempted=false, evidence vacía; no envió POST a Stripe. Lectura Stripe independiente confirma una sola reversión trr_1UJgWX2ZjyMOQ0uLCxmCzVrM por 4314, transferencia completamente revertida, has_more=false. No se desactivó Cron, editó estado financiero ni reintentó bajo otra clave.

Resultado no concluyente para pérdida de respuesta: sólo acredita conciliación normal y exclusión del ejecutor tardío. No repetir devoluciones al azar para ganar la carrera. El próximo mecanismo debe inyectar el fallo en el transporte del ejecutor que obtenga la concesión, restringido a una operación test concreta y con vencimiento; requiere revisión antes de desplegar. El proxy de precio previo y este intento no cierran el escenario financiero incierto.

## Preparación de pérdida de respuesta financiera — 25 de septiembre de 2026

Se añadió guardian-refund-loss-runner.mjs: importa guardianRefundService de producción y comunica sus RPC por JSON secuencial al operador/conector Supabase, sin copiar credenciales de servidor. El único POST Stripe permitido es una reversión test indicada, con el cuerpo y key autorizados por la RPC; el proxy pierde la respuesta TCP real. No crea refunds ni modifica estados financieros directamente. Procedimiento en tools/verification/guardian-response-loss.md.

Validación: node --check correcto; diez pruebas del proxy aprobadas. Revisión independiente security_review sin bloqueo de seguridad evidente para ejecución controlada; señaló el límite de cinco minutos del lease, relays tardíos y competencia con Cron. Ejecutar secuencialmente y conservar stdout. Si Cron gana o no hay evidencia 2xx descartada, no contar el caso como aprobado. Todavía no se ejecutó una reversión financiera mediante este instrumento: preparación técnica, no aceptación cerrada. No se requieren cambios desplegados ni otro build móvil.

## Build 252 y revisión independiente — 25 de septiembre de 2026

Verificación directa en navegador: Codemagic 6ab6e1527e2cdbe815b37fa0, workflow android-guardian-internal, commit 0140fbded894cf71ac9ffd50c80d37b06d9a32fe, finished en 5m46s. Publicación Google Play internal completed, versión 2.3.3 (252), paquete com.mycompany.dopmi, Debuggable No; SHA256 AAB 00f4084c9c9dec96242ff36d39a19432c98abd1ce187ebb1e5f72b69dd32f23b. El build anterior 6ab6dd26d7b32e57ee0d9b68 falló instalando Android SDK 36 por archivo no ZIP; el reintento del mismo commit sí compiló/publicó. No hubo cambio de claves ni firma. El titular reportó actualización y capturas 1000344166/1000344168 validan el comportamiento; no muestran versionCode del teléfono.

GitHub CI 36187337633 sobre 0140fbd: flutter, web-and-database, identity-and-adoption-backend e ios success. Revisión independiente security_review del diff frente a f11061e: sin hallazgos verificables; bloqueo del Checkout en attention conserva referencia y cancelación, y pending permite recuperar la misma referencia. Alcance estático; ejecución local de 52 pruebas y capturas se acreditan separadamente. La prueba comprueba presencia de cancelación, no repite su recorrido sin cambios.

H5 sigue abierto: calendario de fin de mes, recuperación de escritura financiera con respuesta perdida, cruce de aniversario con resultado incierto, disputa posterior a transferencia y comprobación específica del aviso tras retirar monto. La devolución a dos destinos y la pantalla de revisión inicial ya están acreditadas y no deben repetirse para cubrir esos casos distintos.

## Alta en revisión: ocultar reintento móvil — 25 de septiembre de 2026

Capturas 1000344119 y 1000344121 acreditan estado Alta en revisión e historial En revisión para el alta disputada, separado del intento anterior cerrado sin pago. La pantalla conservaba una intención Checkout local y mostraba Reintentar mi solicitud junto a No vuelvas a pagar. Se ocultan formulario y reintento cuando esa intención está en attention, y se bloquea su envío en el controlador; se preservan referencia, actualización y cancelación. No cambia la conciliación del servidor.

Flutter analyze sin incidencias; 52 pruebas Flutter aprobadas. La regresión reproduce pending → attention con intención conservada, verifica ausencia de nuevos envíos/apertura de Checkout y recuperación de la misma referencia si el servidor vuelve a pending. Capturas Android 1000344166 y 1000344168, tras actualización reportada por el titular, confirman Alta en revisión sin formulario ni botón de reintento, conservando Cancelar mi plan y Actualizar estado. El historial muestra el alta en revisión por 50 MXN y el intento anterior cerrado sin pago por separado. Corrección visual validada en dispositivo; estas capturas no muestran versionCode ni identifican el nuevo build. Pendiente cotejo de CI/build; H5 permanece abierto.

## Renovación distribuida a dos rescatistas — 25 de septiembre de 2026

El titular preparó y aprobó el segundo gasto; captura Android 1000344098 muestra Aprobado, versión 11. Consulta remota confirma gasto `9cc08f48-0b7b-440a-955c-9cdc757b36eb`, aprobado por 1549700 centavos, payable, con destino Connect test habilitado `acct_1UJfGkFIsxNzuUmN`. El gasto previo sigue urgente y primero por prioridad; capacidad previa 1491432 centavos. No se alteraron montos aprobados, urgencia ni fechas.

Preparación sólo técnica mediante dopmi_guardian_reserve: claves `b55e0ea8-6438-43fd-a8c2-746d530523e4` y `ec93875b-a30e-42e8-8bab-c772019f81ed`, ciclos `144f5b1e-8a53-40b9-9c97-753ad3e86b72` y `07d6b235-6089-4efe-b789-cfa95ce1d239`; reservaron 980000 y 509432 centavos sin Checkout/pago, dejando 2000 en el primer gasto. Se verificó previamente el plan ya autorizado de 5000 centavos, activo, send_invoice y keep_as_draft. Su reloj test se avanzó una vez de 1842880836 a 1845559269 (25/6/2028 después del aniversario), para esta prueba de múltiples destinos, no para repetir paginación.

Resultado real: ciclo `e27673c6-fa4b-4722-befc-d75e157319eb`, factura `in_1UJfSg2ZjyMOQ0uLCDHFixMy` paid 5000, attempt_count 1; cargo `ch_3UJfT52ZjyMOQ0uL1BgdOXxo`. Base concilia comisión 100, costo Stripe 586 y neto 4314. Stripe confirma dos transferencias test del mismo cargo y grupo del ciclo: `tr_3UJfT52ZjyMOQ0uL1Avwwllb` por 2000 al destino anterior y `tr_3UJfT52ZjyMOQ0uL1mVP4QV9` por 2314 al nuevo destino, ambas sin reversión. Reloj ready. Las dos reservas técnicas se liberaron mediante RPC y quedaron released.

Captura Android 1000344110 confirma el ciclo de junio y ambas asignaciones: test 20.00 y crowuetas 23.14 MXN, Transferencia confirmada. Distribución integrada aceptada.

Se emitió una devolución test total de 5000 centavos con clave estable `dopmi-h5-multidest-refund-e27673c6-fa4b-4722-befc-d75e157319eb`. Lectura independiente confirma único refund `re_3UJfT52ZjyMOQ0uL16ynupl1`, succeeded. La conciliación normal completó el ajuste a las 20:21:42.626 UTC: reversión `trr_1UJfcm2ZjyMOQ0uL67YSoF26` por 2000 y `trr_1UJfcn2ZjyMOQ0uLG2LRlQSw` por 2314. Cada transferencia tiene exactamente una reversión completa en Stripe; cada registro SQL muestra attempts 1. Ajuste completed sin error, allocated_cents 0, platform_fee_cents 0, refund_cents 5000 y platform_loss_cents 586. No se editaron estados financieros manualmente. Captura Android 1000344117 recibida: ciclo 25/6/2028, Devolución confirmada, devuelto 50.00 MXN, transferencias revertidas 43.14, comisión/neto asignado/transferido 0.00; conserva costo Stripe 5.86 sin descontarlo de la devolución. Ambas asignaciones desplegadas muestran Importe original; reversión confirmada: test 20.00 y crowuetas 23.14. Queda aceptado el recorrido integrado de devolución total a dos destinos en app, servidor y Stripe test. Este caso no acredita pérdida de respuesta financiera ni recuperación incierta. No requiere nuevo build.

## CI completo del arreglo de disputa inicial — 25 de septiembre de 2026

CI `36177947929`, commit `5984e16906e52716f6603e934980903e78db3aea` (incluye implementación `847e184`), terminó con identity-and-adoption-backend, web-and-database, flutter e ios todos success. Acredita migraciones/pgTAP/concurrencia en PostgreSQL del CI y compilaciones Android/iOS; no reemplaza la captura del teléfono. La ejecución previa `36177639142` fue sustituida al publicar documentación, por lo que no se declara success global de aquella ejecución.

Lectura independiente de Stripe: una disputa `du_1UJeKy2ZjyMOQ0uLROCbzj8J`, test, needs_response, product_not_received, 5000 centavos MXN, vinculada al cargo original `ch_3UJeKv2ZjyMOQ0uL1VaeVpvG`. No se respondió la disputa ni se creó refund. Comprobación del backend a las 19:09:57 UTC conserva la misma marca de revisión de 19:08:02, cero settlements/jobs y reserva 4900. Pendiente evidencia Android; H5 permanece abierto con el resto de la matriz. Este registro es documental y no requiere otro build móvil.

## Disputa inicial enviada a revisión por el conciliador real — 25 de septiembre de 2026

Corrección `847e184` desplegada: migración remota `20260925190650_guardian_initial_dispute_review` (archivo local `20260925190500`); payment-worker v13, stripe-webhook v13 y guardian-client v5. Consulta posterior de todos sus archivos coincide con el repositorio normalizando CRLF y salto final; verify_jwt=false conserva autenticación propia existente. Los 18 smokes remotos aprobaron. Permisos verificados: activation_server/settlement_server inaccesibles para anon/authenticated y ejecutables sólo por service_role. Advisors consultado conserva avisos del esquema heredado y de funciones públicas con seguridad de definidor; no aparece apertura de las dos RPC modificadas.

A las 19:08:02 UTC el conciliador normal marcó el mismo ciclo `fad96a44-93e9-4c05-be8d-55fb37a9c7e9` attention, con motivo disputed y referencias originales. Comprobación 19:08:24: reserva 4900, cero settlements y cero jobs financieros. RPC del titular: plan null, activation attention; historial review, paid_cents/assigned_cents null, transferred/refunded cero y sin IDs Stripe privados. No se escribieron estados manualmente ni se repitió el pago. Esta evidencia cubre disputa anterior a asignación; no reemplaza la pendiente de disputa posterior a transferencias/múltiples destinos.

Pendiente captura Android tras Actualizar estado y cierre del CI `36177639142` para `847e1845fbd970de88986f7457598cbfa16961df`. Identity-and-adoption-backend ya success; los otros tres jobs seguían en progreso al registrar. No declarar cierre integral de H5 ni CI completo todavía.

## Disputa real antes de liquidación: corrección preparada — 25 de septiembre de 2026

Alta nueva del titular: ciclo `fad96a44-93e9-4c05-be8d-55fb37a9c7e9`, sesión `cs_test_a1HOOVeaSqW9fcvFOvtHfBt8I8c4NjO6EpsGDaFMK98lGfozTEkHtwImc8`, PI `pi_3UJeKv2ZjyMOQ0uL1FykSWZS` succeeded y cargo `ch_3UJeKv2ZjyMOQ0uL1VaeVpvG` paid/disputed=true, sin refund, 5000 centavos test. A las 19:01:53 UTC la activación seguía pending pese a conciliación 19:01:02; reserva 4900, cero settlements y cero planes. El guard financiero bloqueaba correctamente la asignación, pero no persistía la necesidad de revisión: defecto confirmado, no prueba aprobada.

Corrección: verificar identidad antes de clasificar disputa, guardar atención/evidencia privada mediante RPC service-only y bloquear settlement posterior por JS y SQL. No crear contabilidad ni alterar reserva, vencimiento, asignaciones o devoluciones. La caducidad y cancelación previas se conservan; no afirmar retención indefinida. Historial existente proyecta review y paid_cents null sin inventar liquidación. Tres regresiones cubren referencias ajenas, permisos, idempotencia, historial privado, replay y settlement ganador. Suite backend 379/379 aprobada; revisión independiente sin bloqueos. Pendiente desplegar y verificar el mismo caso real.

El PostgreSQL local en ejecución conserva esquema anterior a H4/H5: aplicación de la nueva migración falló al faltar dopmi_guardian_activations y pgTAP contributions al faltar dopmi_connect_accounts; no se reseteó ni reconstruyó esa base. Identity/adoption/rescue aprobaron 120 comprobaciones. La suite PGlite sí aplicó todas las migraciones y las nuevas regresiones; CI de esta corrección debe acreditar el stack PostgreSQL completo.

## Pérdida real de respuesta de precio test — 25 de septiembre de 2026

Ejecutor aislado `tools/verification/guardian-stripe-transport-acceptance.mjs`: a las 18:53:13 UTC Stripe respondió 200 a POST /v1/prices, Request-Id `req_GI3c5kTXelfvRC`; el proxy consumió la respuesta y cerró TCP sin entregarla. Stripe 22.6.0/Fetch observó StripeConnectionError. Reintento con mismo cuerpo/key recuperó `price_1UJeFA2ZjyMOQ0uLWSTNfwBu`; lectura independiente confirmó 5000 centavos MXN y listado del producto `prod_VKIquTAncoOfoG` devolvió un precio. La coincidencia con el ID del proxy acredita recuperación del mismo objeto; el listado por producto no pretende descartar productos duplicados globalmente.

No hubo clientes, suscripciones, pagos, transferencias ni refunds en este experimento. Precio/producto propios archivados y verificados a las 18:54:29 UTC; Stripe exigió quitar primero el default_price del producto. Reejecución posterior confirmó ambos inactivos sin nuevas escrituras. Estado técnico local ignorado por Git; credencial test fuera del repositorio, sin valores en evidencias. Revisión independiente P2 por cuerpo persistido no validado corregida antes de ejecutar: UUID/key/fechas/cuerpo canónico y producto propio comprobados; revisión final sin nuevos bloqueos. Diez pruebas TCP/SDK del instrumento aprobadas.

Alcance explícito: evidencia real de transporte/idempotencia de precio, **no cierre de recuperación financiera ni worker/RPC/app**. H5 sigue abierto. Siguiente recorrido con titular: disputa test en un alta nueva; la cuenta del caso de expiración conserva plan null, activación expired sin cancelación y capacity_preview(5000).can_activate=true, comprobados nuevamente por RPC autenticadas. La documentación Stripe de testing describe la tarjeta 4000000000002685 para pago seguido de disputa product_not_received incluso con 3DS; no se ha realizado ese pago ni se declara disputa aprobada.

## Expiración natural aceptada en Android — 25 de septiembre de 2026

Captura 1000344048 del titular, después de Actualizar estado a las 12:43 hora local: «Intento vencido sin pago confirmado», formulario de nueva alta por 50 MXN, consentimiento desmarcado y Activar en Stripe deshabilitado. No aparece plan activo ni aviso de solicitud recibida en la pantalla completa aportada. Coincide con el ciclo `dfda0ccb-ef61-4435-87e2-64348bf37a65` expired, reserva cero, ausencia de cancelación y sesión Stripe expired/unpaid sin PaymentIntent/suscripción comprobados a las 18:41:41 UTC. Queda completo el recorrido integrado de expiración natural sin pagar ni cancelar; no repetirlo. Esta captura no sustituye la comprobación específica del aviso tras retirar un cambio de monto ni identifica el versionCode instalado.

El titular guardó la credencial test en un archivo privado local fuera del repositorio/OneDrive. Validación sin imprimirla: formato test correcto y consulta autenticada de la sesión esperada devuelve livemode false, expired/unpaid. Queda disponible el acceso del ejecutor local; no se acredita todavía ninguna escritura a través del proxy ni el escenario aislado completo.

## Expiración natural confirmada en backend y Stripe — 25 de septiembre de 2026

Consulta a las 18:41:41 UTC del ciclo `dfda0ccb-ef61-4435-87e2-64348bf37a65`: activación expired, cancellation_requested_at null, reserva expired con reserved_cents 0 y cero suscripciones del donante. Conserva los vencimientos originales de Checkout 18:34:46 UTC y reserva 18:39:46 UTC. Consulta Stripe independiente de la misma sesión `cs_test_a1qfHlwmhBMH2VIXpcf9sUmt78LEQwY4XKzDJns4d653y7fUluM3dDXXi1`: test, expired/unpaid, total 5000, PaymentIntent y subscription null. No se canceló manualmente ni se modificaron fechas/estados para provocar el resultado. Queda acreditada expiración natural y liberación automática sin pago en backend/Stripe; falta captura Android tras Actualizar estado para cerrar el recorrido integrado.

## CI del instrumento y SDK aprobado — 25 de septiembre de 2026

Verificación directa en GitHub: CI `36171852910` sobre `c3bc62de89ac606aab7d1f1c3b4d8c57aec954e5` terminó success. CI posterior `36172547261` sobre `90823c66b81a74b45b8c1587a8cee3dbffdad4c9`, que incluye Stripe SDK 22.6.0 y sus pruebas de transporte, terminó también con flutter, ios, web-and-database e identity-and-adoption-backend todos success, confirmado a las 18:24:35 UTC. Los cambios son de verificación/documentación: no requieren otra instalación móvil ni despliegue de funciones.

Acceso del futuro ejecutor: no había variables Stripe/Supabase en la sesión local ni entradas Stripe/Guardián en los nombres de Vault consultados. El conector Stripe no permite interceptar su transporte. Se consultó al titular si ya existe un archivo local de credencial test, pidiendo sólo ubicación y nunca el secreto por chat; sin respuesta todavía. La sesión natural pendiente conserva su vencimiento 18:34:46 UTC y margen de reserva 18:39:46 UTC. Estos pendientes no se marcan aprobados por el CI.

## Transporte del SDK Stripe contrastado — 25 de septiembre de 2026

Se fijó Stripe 22.6.0 como dependencia de verificación, la misma versión de `guardian-runtime.ts`. El SDK real con Fetch contra el proxy/fixture TCP observa StripeConnectionError tras un solo envío y recupera el mismo objeto por lectura. El transporte Node por defecto reintenta ECONNRESET una vez aun con maxNetworkRetries=0 (comprobado en README/código instalado y por prueba); el proxy rechaza ese segundo POST con 409 y el upstream conserva una sola escritura. La variante deno del paquete selecciona worker/WebPlatformFunctions/Fetch: el procedimiento exige Fetch explícito en el futuro ejecutor local. No cambiar el runtime remoto para adaptar la prueba.

Diez pruebas del instrumento y suite completa de 376 pruebas aprobadas, cero fallos. npm añadió únicamente la dependencia Stripe fijada y reportó cero vulnerabilidades. No hubo llamadas Stripe reales, credenciales nuevas, Deno/Edge ejecutado ni cambios financieros; sigue pendiente la aceptación real del transporte. El CI `36171852910` corresponde al commit anterior `c3bc62d`, no a estas dos nuevas pruebas.

## Instrumento local para pérdida real de transporte — 25 de septiembre de 2026

Se añadió `tools/verification/guardian-response-loss-proxy.mjs`, separado del runtime desplegado. Reenvía un único POST con ruta/clave de idempotencia exactas y credencial test; después de consumir el 2xx upstream destruye la conexión TCP descendente antes de responder al cliente. Sólo admite lecturas explícitas de recuperación, bloquea reintentos/concurrencia de escritura y no guarda credenciales ni cuerpos en la evidencia. Upstream real fijo HTTPS Stripe, alternativa sólo loopback para fixtures; escucha únicamente loopback. Plazo absoluto máximo de 20 segundos y cierre de conexiones en ambas direcciones.

Ocho pruebas locales TCP aprobadas: respuesta perdida con efecto aplicado y recuperación por lectura, exclusión de duplicados y operaciones no permitidas, error upstream sin falsa evidencia de éxito, destino/clave live rechazados, query GET exacta, goteo acotado y cierre en vuelo. Suite backend completa: 374 pruebas aprobadas, cero fallos. Revisión independiente detectó primero timeout sólo de inactividad; se corrigió y la revisión final confirmó P2 resuelto sin hallazgos adicionales. No se desplegó código ni se alteró el alta pendiente.

El instrumento prepara aceptación, no la acredita: falta ejecutor aislado con credenciales test por canal seguro, módulos de servicio y RPC reales, referencias acordadas y evidencia independiente de Stripe. No sustituir este caso por pérdida móvil→Edge ni por excepción de un doble. Para incertidumbre al cruzar aniversario también se necesita aislar el escenario de Cron/webhooks, sin apagarlos globalmente. Los planes con aniversario 24/25 no acreditan 31→28/29→31; no alterar sus timestamps ni insertar una suscripción ficticia para cerrar la matriz. Procedimiento y límites en `tools/verification/guardian-response-loss.md`.

## Build 250 publicado y expiración natural en curso — 25 de septiembre de 2026

Consulta directa de Codemagic: build `6ab6b1ecd585f0389192548f`, workflow Dopmi Guardián — Google Play Internal Testing, rama `codex/stripe-transfer-delivery`, commit `bcbc2e77fc582328a5a873568ff809c536454b3e`, finished en 5m49s, iniciado a las 11:40 CST. El log Publishing confirma versión 2.3.3, versionCode 250, paquete com.mycompany.dopmi, Debuggable No y track internal completed, también en la consulta posterior del track. SHA256 AAB: `a3131073587bcbad871f3f975b5c3fbe8a0c29e2fd5ad43364c4301af3101173`. Git confirma que incluye `291dcd0`. Esto identifica la compilación publicada; la declaración del titular de instalación y las capturas son compatibles, pero no muestran el versionCode instalado ni el final del formulario. No declarar todavía comprobada toda la limpieza visual tras una nueva operación.

El titular abrió un alta nueva sin pagar ni cancelar. Base a las 18:00:44 UTC: ciclo `dfda0ccb-ef61-4435-87e2-64348bf37a65`, pending, cancellation_requested_at null, bruto 5000 centavos y reserva 4900. Sesión Stripe `cs_test_a1qfHlwmhBMH2VIXpcf9sUmt78LEQwY4XKzDJns4d653y7fUluM3dDXXi1` verificada directamente: test, open/unpaid, total 5000, PaymentIntent y subscription null. Checkout vence a las 18:34:46 UTC; reserva a las 18:39:46 UTC. Es la evidencia inicial del recorrido de expiración natural, no su cierre. Pendiente comprobar estado terminal, reserva liberada, ausencia de pago/suscripción y pantalla del titular después del plazo. No cambiar fechas ni cancelar manualmente esta sesión.

## Estado de solicitud retirada visible en Android — 25 de septiembre de 2026

Tras informar que instaló el nuevo build de Codemagic, el titular aportó 1000344033 y 1000344035. La pantalla del plan (1000344033) muestra Plan activo por 50 MXN y, debajo de Cambio a 200 MXN, «Solicitud retirada; se conservó el monto anterior». Queda acreditada la presentación del estado autoritativo solicitado; no necesita generar otro cambio para encontrar ese texto. No se ve el aviso genérico en la parte capturada, pero la imagen no incluye el final del formulario ni identifica versión/commit del build; no acredita por sí sola la ausencia del aviso en toda la pantalla ni una nueva operación de retiro. La captura del historial 1000344035 confirma el ciclo de mayo de 2028 por 50 MXN y 43.14 transferidos. También muestra marzo antes de abril: el historial actual pagina por creación del registro, no por período; revisar esta presentación separadamente, sin atribuirla a duplicación o nuevos cobros.

## Paginación Android aceptada — 25 de septiembre de 2026

El titular confirmó «Sí salió» y aportó captura 1000344002 después de solicitar pulsar «Ver ciclos anteriores». Se ve el alta del 25/9/2026 debajo del ciclo omitido del 25/10/2026: autorizado/pagado 50.00 MXN, comisión 1.00, Stripe 5.86, neto asignado/transferido 43.14. Coincide con el único registro de la segunda página previamente verificada por RPC (20 + 1, sin intersección y cursor final null). Queda aceptado el recorrido de paginación Android con más de 20 ciclos. No necesita más avances del reloj ni repetir esta captura. La imagen no identifica versión/commit del build y no acredita la corrección visual de gestión de solicitudes `291dcd0`. Los demás pendientes de H5 permanecen abiertos.

## Historial de 21 ciclos preparado y CI aprobado — 25 de septiembre de 2026

CI `36166363025`, commit `bf9d566a217523be985575a0aa628d1b3250954c`: ios, flutter, web-and-database e identity-and-adoption-backend terminaron success. El arreglo también se verificó en un caso nuevo: factura `in_1UJcno2ZjyMOQ0uL0zYYvlWY` quedó pending/guardian_recovery_void_unconfirmed tras la lectura inmediata de Stripe; Cron la cerró skipped en el segundo intento a las 17:24:04 UTC, sin reencolado manual ni pay_requested_at. Confirma recuperación automática posterior al despliegue, además del caso histórico reparado.

Reloj test del segundo plan avanzado por tandas, esperando conciliación entre ellas, hasta `1842880836` (25/5/2028 09:20 GMT-6), ready. Hay 21 ciclos (alta + 20 mensualidades), cero collection_jobs pendientes/en atención. Consulta Stripe completa sin has_more: 20 facturas test, 11 paid por 5000 con attempt_count 1 y nueve void con amount_paid 0. Los saltos de dos meses producen períodos anteriores omitidos por antigüedad; no presentarlos como omisión por capacidad ni como deuda recuperada. No se modificaron fechas de base.

Consulta autenticada del historial con el tamaño predeterminado de la app: primera página 20 registros, cursor `0bc6abf4-bf0a-43bf-9d17-801c36506e56`/`2026-09-25T14:39:02.355138+00:00`; segunda página un registro, alta `7e93d285-de6d-4548-9599-9d728297eb2c`, next_cursor null, intersección de IDs cero. El ciclo más nuevo `c101a18a-e1ad-469a-9229-99fe05121f3c` corresponde a 25/5–25/6/2028: pagado 5000, comisión 100, Stripe 586, neto transferido 4314; factura `in_1UJcwV2ZjyMOQ0uLyTerC7Zw`, transferencia `tr_3UJcwo2ZjyMOQ0uL0VGq9emL`, verificada independientemente test por 4314, sin reversión. Datos preparados y paginación RPC acreditada; falta pulsar «Ver ciclos anteriores» en Android y comprobar el alta inicial. No generar más ciclos para esta prueba.

## Conciliación de anulación visible por etapas — 25 de septiembre de 2026

Al preparar paginación mediante el reloj test del segundo plan, tres avances de dos meses llevaron el reloj a 25/8/2027 (`1819207236`) y el historial de 6 a 12 ciclos. Los períodos anteriores descubiertos fuera de la ventana de 48 horas se omiten; no son falta de capacidad ni cobros de deuda. Stripe confirmó los nuevos períodos pagados por 5000 una sola vez y los anteriores void con amount_paid 0/attempt_count 0. La paginación móvil todavía no está preparada (>20) ni aceptada.

Se detectó un defecto real en factura `in_1UJccC2ZjyMOQ0uLzcA9HHC2`, ciclo `8098b607-c5b6-4e1d-b453-1f4127009e5b`: Stripe ya mostraba invoice void pero durante la consulta inmediata aún no confirmaba cancelación completa; el error guardian_recovery_void_unconfirmed dejó attention sin pay_requested_at y el colector no lo reintentaba. GET posterior confirmó InvoicePayment `inpay_1UJcdV2ZjyMOQ0uLHBoiczeL` canceled y PaymentIntent `pi_3UJcdU2ZjyMOQ0uL1riOe7F1` canceled, received/capturable 0.

El colector conserva pendiente sólo ese error cuando la factura observada ya es void y nunca se autorizó pay. Reutiliza relectura con backoff y límite de ocho intentos/23 horas; no repite pay ni void. Identidades/importes incongruentes siguen attention. Nueva migración reencola sólo filas skip elegibles, sin alterar reservas, importes, referencias, contadores ni autorizaciones. Prueba de regresión falló antes y pasó después; suite completa tools/verification: 366 pruebas aprobadas, incluidas diez nuevas de visibilidad, identidad, límite y alcance/idempotencia de reparación. Revisión independiente security_review sin hallazgos; inspeccionó también las ocho pruebas añadidas de límites/reparación.

Desplegados payment-worker v12, stripe-webhook v12 y guardian-client v4; todos sus archivos comparados con el paquete esperado, único cambio guardian-collection.mjs. Se preservó autenticación propia y verify_jwt existente. Migración local 20260925171348 aplicada remotamente como 20260925171711 después del despliegue; no db push/repair ni reejecución histórica. Los 18 smoke HTTP --expect-enabled aprobaron. Cron a las 17:18:05 UTC dejó el caso skipped, error null, pay_requested_at null, attempts 2, ciclo released/reserved_cents 0: conciliación real posterior al arreglo acreditada. H5 sigue abierto y el reloj se detuvo en agosto para resolver este caso antes de generar más ciclos.

## Aviso transitorio en retiro de monto — 25 de septiembre de 2026

Captura 1000343982 y estado remoto withdrawn mostraron que el aviso genérico Solicitud recibida también sobrevivía al retiro confirmado. Se elimina su asignación después de operaciones de gestión; la recarga existente presenta el estado autoritativo de solicitudes, incluido Solicitud retirada; se conservó el monto anterior, o el pendiente/revisión correspondiente. Evita nuevas excepciones por cada estado terminal. Flutter analyze --no-pub sin incidencias; 51 pruebas Flutter --no-pub aprobadas, incluidos retiro, recuperación y conflicto. CI 36163237337 sobre 446d3947acfe769c654b90b095ba9ee71730db38 (contiene 291dcd0): cuatro jobs success. La ejecución previa 36163002243 terminó cancelada, no se cuenta como aprobada. Cambio móvil pendiente de próximo build y aceptación visual; no requiere despliegue de servidor.


## Corrección del aviso tras cancelar un alta — 25 de septiembre de 2026

La captura 1000343899 mostró una cancelación inicial ya terminada con el aviso transitorio de solicitud todavía visible. GuardianScreen limpia ahora ese mensaje cuando cancellation_status es stopped, además del caso de plan canceled existente; mantiene la información autoritativa sobre pago y devolución. Flutter analyze sin incidencias y las 51 pruebas Flutter aprobadas. CI 36156881343 del commit fc4a6ef19037777b1c74e9cab9b3d71c073e2f96: los cuatro jobs (Flutter/Android, iOS, web/base de datos e identidad/adopción) terminaron success. Captura Android 1000343972 recibida del titular tras solicitar la actualización: conserva Alta detenida e Intento vencido sin pago confirmado y ya no muestra Solicitud recibida. Comprobación visual satisfecha; captura Codemagic 1000343974 identifica build 6ab69f12bbba44dc026a34ef terminado sobre 9cb3f5f, que contiene la corrección; versión/versionCode no visibles en esa captura. No modifica backend ni operaciones Stripe. Recorrido de abandono/reapertura/cancelación sin pago y reserva liberada documentado en guardian-acceptance.md.


## Aceptación integrada actualizada — 25 de septiembre de 2026

Los registros detallados en `guardian-acceptance.md` y las capturas Android 1000343853, 1000343863 y 1000343881 completan omisión por capacidad, renovación posterior, rechazo mensual, actualización de tarjeta y renovación siguiente sin recobrar meses omitidos. Enero cobra 5000 centavos una vez y transfiere 4314; diciembre permanece omitido. También consta reenvío firmado de invoice.paid con HTTP 200 sin duplicado, y devolución parcial retenida en revisión hasta completar el total y conciliar la reversión. Estos resultados sustituyen los pendientes históricos equivalentes debajo, pero no cierran toda H5.

Siguiente recorrido móvil: alta abandonada y recuperación del mismo intento, seguida de cancelación/expiración sin pago y liberación de reserva. Requiere cuenta sin plan previo y distinta del dueño del gasto aprobado; se solicitó al titular. La interfaz actual no ofrece alta sobre el registro de un plan cancelado. El Checkout inicial vence a los 35 minutos y la reserva a los 40; no alterar fechas de base para aparentar expiración integrada. Antes de pagar, comprobar recuperación del mismo identificador al reabrir la app. Mantener pendientes separados: límites de aniversario/fin de mes, pérdida real de respuesta durante escritura, disputa/múltiples destinos y paginación móvil. Las pruebas locales existentes de fallos y concurrencia no se presentan como evidencia remota de esos casos.


## Revisión independiente de Guardián — 25 de septiembre de 2026

Revisión de seguridad independiente completada sobre `fe976a3`, incluyendo backend ya integrado en la rama predeterminada y no sólo el diff reciente. Sin vulnerabilidades verificables encontradas en el alcance inspeccionado: autenticación del cliente, worker y webhook, privilegios/RLS de RPC, propiedad e importes, reservas, idempotencia, cambios de tarjeta/monto, cancelación, devoluciones/reversiones e historial privado. Ocho pruebas existentes de evidencia financiera y propiedad de `guardian.test.mjs` ejecutadas por el revisor y aprobadas; no se repitió la suite completa.

Alcance estático, no auditoría exhaustiva de aplicación, infraestructura o dependencias; no acredita pruebas ofensivas ni una nueva verificación remota de permisos. La evaluación independiente queda registrada, pero H5.5 sigue abierto por los recorridos integrados pendientes de la matriz, especialmente omisión sin capacidad, límites de aniversario, interrupción de escrituras y evidencia de dispositivo. No autoriza dinero real.


## Continuación local de H5 — 25 de septiembre de 2026 (UTC)

- CI completo aprobado para arreglo de avisos 37895d26cb36d4c1697a0418af937c3533d3da32: run 36142869179, completed/success; jobs flutter/Android, iOS, identity-and-adoption-backend y web-and-database exitosos. No equivale a publicación de nuevo build en Play ni verificación visual de la corrección en dispositivo.

- Devolución: ajuste completed sin error, capacidad ocupada por asignación original 4314−4314=0; refund 5000, comisión Dopmi 0, pérdida de plataforma por costo Stripe 586. Reprocesamiento autenticado de la misma devolución, request 2396, HTTP 200 completed. GET Stripe posterior conserva exactamente la misma única reversión trr_1UJZR32ZjyMOQ0uLWuhjvjkX por 4314; sin duplicado. Esto acredita repetición del reconciliador, no reenvío de webhook firmado ni fallo de red durante la escritura.

- Devolución total integrada del alta de 50 MXN: lista previa de refunds vacía; emitida devolución test re_3UJNdz2ZjyMOQ0uL11JJyIzs por 5000, succeeded. Dopmi concilió y revirtió automáticamente transferencia tr_3UJNdz2ZjyMOQ0uL1m3TAIwR: GET Stripe confirma reversed true, amount_reversed 4314 y exactamente una reversión trr_1UJZR32ZjyMOQ0uLWuhjvjkX. RPC de historial del donante: alta refunded, refunded_cents 5000, reversed_cents 4314, assigned/transferred/platform_fee 0, Stripe fee histórico 586; mensual de 20000 permanece transferred con neto 18301. Pendiente captura móvil y comprobación detallada de liberación de capacidad e idempotencia posterior.

- Corregidos avisos residuales observados al cancelar: la consulta de estado canceled limpia el mensaje transitorio de solicitud; el aviso de medio para próximos ciclos se muestra solo en plan active. Flutter analyze sin incidencias, 22 pruebas Guardián y suite completa de 51 pruebas aprobadas. Requiere nuevo build para verificar esta mejora visual en el teléfono; no cambia procesamiento de pagos.

- Prueba posterior a cancelación: reloj clock_1UJNsh2ZjyMOQ0uLXx9GXAwl avanzado un mes adicional hasta frozen_time 1795570015 (24/11/2026, 19:26 GMT-6), después del siguiente aniversario. GET Stripe expandido confirma reloj ready, suscripción canceled y misma última factura in_1UJNvd2ZjyMOQ0uLTRvFgXMK. Supabase conserva dos ciclos y total autorizado histórico 25000 centavos, sin tercer ciclo. Se verifica que este aniversario posterior a cancelación no genera renovación del plan.

- Historial conservado después de cancelar, acreditado por captura Android del titular: ciclo mensual 24/10/2026 pagado 200.00, neto transferido 183.01; alta 24/9/2026 pagada 50.00, neto transferido 43.14. Sin alteración visual de importes ni desaparición de ciclos. La fecha «siguiente aniversario de este ciclo» es información del período histórico; no acredita programación de otro cobro. Falta avance del reloj después del aniversario para verificar ausencia de nuevo cobro.

- Cancelación confirmada visualmente en Android: captura del titular muestra «Plan cancelado» y «Cancelación confirmada», coincidentes con Stripe y Supabase. El titular observó demora hasta actualizar. Quedan avisos residuales de «medio actualizado para los próximos ciclos» y «Solicitud recibida» pese al estado terminal: revisar claridad de interfaz. Pendiente probar el siguiente aniversario sin cobro y conservación visual del historial tras cancelar.

- Cancelación solicitada desde Android el 25 de septiembre a las 13:36:17 UTC: captura muestra solicitud pendiente y futuros cobros detenidos. Consulta posterior confirma plan canceled en Supabase, solicitud cancel applied revisión 4, Cron HTTP 200 con changes_applied 1 y failed 0. GET Stripe independiente confirma sub_1UJNeL2ZjyMOQ0uLHjVYo1s4 canceled, test, canceled_at 1792891615 (reloj simulado), misma última factura mensual. Falta actualizar pantalla y avanzar más allá del siguiente aniversario para acreditar ausencia de nueva factura/cobro.

- Confirmación móvil de recuperación tras rechazo: nueva captura del titular muestra «Medio de pago actualizado para los próximos ciclos. No se realizó un cobro por este cambio» y plan activo de 200 MXN. Se completa el recorrido de tarjeta rechazada, reintento exitoso en el mismo Checkout y retorno confirmado en Android. No acredita todavía rechazo de una renovación off-session.

- Recuperación tras tarjeta 9995 rechazada: titular reemplazó por tarjeta test 3155 en el mismo Checkout y aportó capturas del desafío 3DS y guardado exitoso. El mismo trabajo `b3d668cc-5c85-4f02-ba27-0d8227820c0d` y sesión `cs_test_c1XveBmrvSnUjviMAAxrJVx5B3nzITALMyQO09cA67chn9PNnIwdZRzwyQ` ahora están applied sin error, SetupIntent `seti_1UJO6o2ZjyMOQ0uLq4pfyUis`, medio `pm_1UJO8r2ZjyMOQ0uL4RhVj82A`. Se recuperó la solicitud original; pendiente visualización tras retorno a Dopmi.

- Tarjeta rechazada durante actualización: captura Stripe Checkout muestra «Tu tarjeta no tiene fondos suficientes. Prueba con otra» para tarjeta test 9995. GET de la suscripción mantiene active, precio 20000, medio anterior `pm_1UJNnd2ZjyMOQ0uLNb69TOP2`, aniversario y última factura mensual sin cambio. Trabajo `b3d668cc-5c85-4f02-ba27-0d8227820c0d` sigue pending, sin medio nuevo aplicado; sesión `cs_test_c1XveBmrvSnUjviMAAxrJVx5B3nzITALMyQO09cA67chn9PNnIwdZRzwyQ`. Acredita rechazo de setup y conservación del plan; no equivale a rechazo del cobro mensual. Falta resolver o expirar este mismo intento.

- Renovación confirmada visualmente por el titular en Android: «Ciclo mensual · 24/10/2026», siguiente aniversario 24/11/2026, neto transferido. Autorizado/pagado 200.00 MXN, comisión Dopmi 4.00, Stripe 12.99, asignado/transferido 183.01; debajo permanece el alta de 50.00 con neto 43.14. Importes coinciden con las consultas previas de base y Stripe. Queda acreditada la renovación con capacidad en app/servidor/Stripe; omisión sin capacidad y otros casos restantes siguen pendientes.

- Historial paginado remoto del donante con page_size 1: primera página ciclo mensual de 20000 centavos, cursor al mensual; segunda página ciclo inicial de 5000, next_cursor null. Dos IDs distintos, importes intactos, sin repetición; acredita paginación RPC con datos integrados, no botón de paginación móvil (tamaño normal 20). Transferencia mensual persistida `tr_3UJNwh2ZjyMOQ0uL0ePNuZko`, 18301 centavos, transferida a las 01:29:08 UTC.

- Renovación integrada ejecutada: reloj `clock_1UJNsh2ZjyMOQ0uLXx9GXAwl` avanzado desde Dashboard un mes a frozen_time `1792891615`, ready. Factura `in_1UJNvd2ZjyMOQ0uLTRvFgXMK` confirmada por GET Stripe: paid 20000, remaining 0, attempt_count 1, auto_advance false, test; suscripción conserva pausa keep_as_draft sin resumes_at. Ciclo `06cbe7ae-6e08-4f3c-874c-5735923fe06c` allocated: bruto 20000, Stripe 1299, Dopmi 400, neto asignado/transferido 18301, refund 0; cargo `ch_3UJNwh2ZjyMOQ0uL0KUAHa7Z`. El ciclo inicial de 5000 permanece intacto. Cron primero devolvió guardian_collection_clock_unavailable mientras reloj avanzaba; siguiente ejecución HTTP 200, monthly_processed 1, failed 0, job paid sin error: recuperación automática sin intervención ni nuevo intento manual. Falta captura móvil del ciclo mensual y comprobación independiente de la transferencia; no acredita todavía mes sin capacidad.

- Vuelta a la cuenta donante original del pago acreditada visualmente: reaparecen plan activo de 200 MXN, aviso de medio actualizado e historial del único pago de 50. Detalle expandido muestra gasto «test», 43.14 MXN y «Transferencia confirmada», coincidente con la asignación registrada. Se acredita restauración del estado propio tras cambiar de cuenta y detalle básico de asignación; un solo resultado no prueba paginación.

- Reloj de aceptación creado mediante API Stripe para el cliente existente del plan integrado: `clock_1UJNsh2ZjyMOQ0uLXx9GXAwl`, test, nombre «Dopmi H5 Android 247 renewal acceptance». Tras inicialización de dos minutos, consulta expandida de la suscripción confirma cliente asociado y reloj `ready`, frozen_time `1790299615`; aniversario `1792890584` y latest_invoice null conservados. Todavía no se adelantó al aniversario ni se acreditó renovación. Asociación admitida por API 2026-05-27+, corrigiendo la suposición previa; no borrar el reloj porque elimina también el cliente/suscripciones.

- Historial vacío confirmado en Android tras cambiar cuenta: captura «Todavía no tienes ciclos registrados». Estado e historial ajenos no permanecen visibles. Consulta remota de solo lectura en ese contexto devuelve `dopmi_is_admin()=true`, estado vacío e historial vacío; la denegación 42501 ya observada al pedir asignaciones ajenas también cubre a esta identidad administradora. No acredita paginación ni todos los posibles recorridos de sesión.

- Cambio de cuenta visible en Android: después de entrar con la otra cuenta indicada, captura muestra formulario de alta con 50 MXN predeterminados, sin plan activo de 200 ni aviso del medio anterior. Coincide con estado vacío de la RPC. Falta abrir historial en esta sesión para acreditar su limpieza visual.

- Aislamiento remoto de consultas comprobado en transacciones de solo lectura con rol `authenticated` y contexto de la otra cuenta del titular: estado sin plan/activación/medio e historial vacío; petición explícita de asignaciones del ciclo ajeno rechazada con SQLSTATE 42501 «Ciclo no disponible». No se modificaron usuarios ni datos. Acredita RPC/propiedad en PostgreSQL; no sustituye sesión HTTP ni limpieza visual al cambiar cuenta en el dispositivo, pendientes de captura.

- Retorno de cambio de tarjeta comprobado en Android: captura del titular muestra «Medio de pago actualizado para los próximos ciclos. No se realizó un cobro por este cambio», plan activo de 200 MXN y aplicación del monto desde 24/10/2026. Consentimiento, Checkout setup, autenticación 3DS exitosa, aplicación en servidor y confirmación móvil quedan acreditados para este recorrido.

- Cambio de tarjeta/3DS confirmado por Stripe y servidor: trabajo `e930cd31-6d5a-4395-8798-0a7afe16f786` aplicado a las 01:19:55 UTC sin error; SetupIntent `seti_1UJNn12ZjyMOQ0uL107Y8D1J` succeeded, off_session, test, mismo cliente. Intento `setatt_1UJNne2ZjyMOQ0uLuQPw96qg` expandido acredita 3DS 2.1.0, challenge, authenticated, sin setup_error, tarjeta test terminada 3155. Nuevo medio predeterminado `pm_1UJNnd2ZjyMOQ0uLNb69TOP2`; aniversario `1792890584` conservado y latest_invoice null. Pendiente captura posterior en Dopmi; no acredita rechazo ni cobro mensual.

- Confirmación visual posterior del cambio: tras actualizar, Android muestra plan de 200 MXN y «Confirmado. Aplica desde 24/10/2026». Consulta de ciclos conserva uno solo, bruto/pago 5000, asignación 4314 y devolución cero. Cambio ordinario acreditado con app/base/Stripe; escenarios de aniversario y fin de mes siguen pendientes.

- Cambio de monto enviado desde Android: captura del titular muestra solicitud de 50 a 200 MXN pendiente de confirmación. Consulta posterior: solicitud `amount` aplicada, revisión 1 y plan 20000 centavos. GET Stripe de `sub_1UJNeL2ZjyMOQ0uLHjVYo1s4` confirma precio `price_1UJNl42ZjyMOQ0uLzKiDGCNx` de 20000, aniversario `1792890584` conservado, `send_invoice`, pausa `keep_as_draft`, `latest_invoice=null`, activo y test. Falta comprobar la pantalla tras «Actualizar estado»; la captura pendiente no representa un fallo de aplicación.

- Evidencia visual del titular en Android, después de volver de Stripe: pantalla «Plan activo» con 50 MXN mensuales y un único historial «Intento de alta · 24/9/2026», estado «Neto transferido». Importes visibles coinciden con base/Stripe: autorizado/pagado 50.00, comisión 1.00, costo Stripe 5.86, asignado/transferido 43.14 MXN. Retorno, consulta de estado e historial básico del primer pago quedan acreditados. No acredita todavía privacidad entre cuentas, paginación, renovación, 3DS ni devolución.
- Primera aportación integrada confirmada en servidor y Stripe test: ciclo `8724966d-3a05-47c4-9c0d-cd968e3a6c81`, bruto 5000 centavos, reserva previa 4900, costo Stripe 586, comisión Dopmi 100 y neto completo 4314. Activación `settled`, ciclo `allocated`, trabajo de transferencia `done` sin error; cero devolución. Cargo `ch_3UJNdz2ZjyMOQ0uL1A4wHmV6`, transferencia `tr_3UJNdz2ZjyMOQ0uL1m3TAIwR`; GET Stripe independiente confirma `livemode=false`, 4314 MXN centavos, el mismo cargo origen, ciclo y destino `acct_1UIimXFRDgVgGJcB`, sin reversión. No es evidencia de depósito bancario.
- Plan `sub_1UJNeL2ZjyMOQ0uLHjVYo1s4` activo en base y Stripe. GET Stripe confirma precio mensual 5000 centavos, `collection_method=send_invoice`, `pause_collection.behavior=keep_as_draft`, `resumes_at=null`, medio predeterminado establecido y fin del período `1792890584`. `test_clock=null`: este plan no permite demostrar renovación acelerando un reloj; se requiere un escenario de prueba con reloj propio. El titular recibió el retorno de texto esperado y está comprobando el plan/historial en la app.
- CI completo de `fc11fbf` aprobado: [36080186965](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36080186965). Los runs anteriores se cancelaron por nuevos pushes; no se cuentan como fallos ni como aprobaciones.
- Con el titular listo en Android y una segunda cuenta donante confirmada/activa que no es propietaria del gasto, se activó `DOPMI_GUARDIAN_CHECKOUT_ENABLED=true` en el proyecto de prueba. Las 18 comprobaciones HTTP aprobaron con `--expect-enabled`; el cliente anónimo devuelve `401 sign_in_required`. Cron observado con HTTP 200 y `guardian.failed=0`. Alta habilitada para cuentas elegibles, sin allowlist individual; aún no se ha acreditado un cobro. La primera consulta de activaciones de esta segunda cuenta no devolvió filas.
- Primera evidencia de dispositivo aportada por el titular: app instalada desde Play interno y pantalla Guardián accesible. Al intentar el alta con su cuenta donante (confirmada/activa), aparece «Por ahora no hay gastos aprobados suficientes para asignar tu aportación completa. No se abrió un pago ni se activó un plan». El único gasto elegible pertenece a esa misma cuenta; consulta de capacidad excluyendo propietario devuelve cero. Esta prueba acredita el rechazo previo por capacidad en la app; Checkout aún cerrado, por lo que no acredita autorización del endpoint habilitado ni un pago Stripe. Modelo/versión Android pendientes de identificar; captura privada conservada fuera del repositorio.
- Publicación Android verificada en el log de [Codemagic 6ab5c5e946e81f437f2a45d9](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6ab5c5e946e81f437f2a45d9?open-step=build-step-10): commit `3fe7a1d`, versión **2.3.3 (247)**, paquete `com.mycompany.dopmi`, no debuggable. Google Play aceptó el AAB y la consulta posterior de `track internal` confirmó `status=completed`, código 247. SHA-256 del bundle: `4642dcbb7f3537b1ebc2865d20039d1e442e886ff4fc503423fd8eb47ff1a1c5`. Falta instalación/recorrido del titular; Checkout sigue cerrado. El índice visible del workflow (1) no equivale a `PROJECT_BUILD_NUMBER`; el log de publicación es la evidencia del código 247.
- H5.A resuelto: además del catálogo, recuperadas y comparadas `guardian-client` v2 (14 archivos), `stripe-webhook` v10 (14), `payments` v8 (3), `payment-return` v7 (1), sin diferencias de contenido. `payment-worker` v10 (15) ya comprobado tras desplegar. Correspondencia histórica preservada sin `db push`/repair; todavía faltan aceptación integrada y revisión independiente.
- Auditoría extendida: cuatro triggers, permisos de 30 tablas/cinco columnas y 14 políticas de Storage coinciden con las migraciones reproducidas bajo los defaults reales de Supabase. Las cinco diferencias de funciones de identidad son espacios/comentario; las ACL coinciden al incluir defaults. El titular inició [Codemagic 6ab5c5e946e81f437f2a45d9](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6ab5c5e946e81f437f2a45d9), workflow Guardián Google Play interno, commit `3fe7a1d`, índice 1; observado en compilación, todavía no acredita publicación ni instalación.
- El titular eligió Google Play interno en Android y ejecutar Codemagic personalmente. Añadido workflow `android-guardian-internal`: configuración Guardián test, Flutter 3.47.4, firma e identidad existentes, canal exclusivamente interno y artefacto con SHA/build. Seis pruebas de configuración aprobadas. Las 18 comprobaciones HTTP remotas también aprobaron con Checkout cerrado. El último build observado en Codemagic era índice 5, `12b4078`, rama `codex/mvp-release-foundation`, anterior a Guardián; no usarlo como aceptación H5.
- Actualización posterior: el titular autorizó los permisos mínimos de la clave `Dopmi Supabase Test` y completó el SMS de Stripe. Configurados escritura en Customers, Products, Prices, Subscriptions e Invoices; lectura en Payment Methods y Setup Intents; permisos Connect conservados. Preflight `1616`: HTTP 200, `reads_ready=true`, las 16 lecturas HTTP 200. Se resuelve el bloqueo de lectura descrito debajo. La clave sigue restringida y test; `write_permissions=not_verified` hasta ejecutar los recorridos integrados.
- Checkout sigue cerrado; H5 no está aceptado. Se recuperó la rama `codex/stripe-transfer-delivery` desde `e16e1da` y se verificó el entorno remoto `ohqxranynackjignryep`.
- Corregida portabilidad Windows mediante `.gitattributes`: SQL permanece en LF. La conversión automática a CRLF rompía el reemplazo exacto de una definición en `guardian_payment_method`; no se cambió la lógica histórica. Tras corregirlo, 356 pruebas backend aprobadas. Flutter 3.47.4: análisis sin incidencias y 51 pruebas aprobadas; admin: 18 pruebas y build aprobados.
- `payment-worker` v10 desplegado desde el código publicado, incorporando únicamente el diagnóstico autenticado `guardian_preflight` y su importación. Los otros 13 archivos compartidos ya coincidían. Se recuperaron los 15 archivos desplegados para comprobar su contenido. Autenticación por secreto existente conservada.
- Preflight remoto mediante token de Vault sin exportarlo: petición `1599`, 2026-09-25 00:33:37 UTC, HTTP 503; clave restringida y test verificados. HTTP 403 en `customers`, `payment_methods`, `prices`, `subscriptions`, `invoices`, `invoice_payments`; HTTP 200 en las otras diez lecturas. Permisos de escritura todavía no verificados. Esto bloquea aceptación, no demuestra un fallo del procesamiento ordinario.
- Cron `dopmi-payment-worker-reconcile` activo cada minuto; respuestas `1597`/`1598` HTTP 200 con todos los contadores de error en cero. Cero ciclos, suscripciones y liquidaciones Guardián al consultar. No se crearon operaciones financieras.
- Historial consultado directamente: 19 filas remotas con SQL equivalente a los archivos locales normalizando CRLF/LF; 19 timestamps distintos, incluyendo `payment_delivery` omitido en la auditoría documental anterior. Las siete primeras migraciones no tienen fila de historial. Comparación inicial del catálogo: 84 funciones esperadas y 84 presentes; 79 definiciones idénticas normalizadas por saltos de línea. Quedan cinco funciones antiguas de identidad con diferencias de formato por revisar y diferencias de grants, incluida ejecución anónima adicional de `dopmi_can_write_photo`. No se reparó historial ni se cambió esquema. H5.A permanece pendiente hasta completar tablas, restricciones, índices, políticas y permisos.


## Traspaso documental a Codex — 25 de septiembre de 2026 (UTC)

- Solicitud del titular: dejar GitHub listo para continuar en Codex; compilará en Codemagic y probará en TestFlight. [Guía de continuidad](codex-handoff.md), [matriz de aceptación](guardian-acceptance.md) y backlog reconciliados. README ahora describe la implementación; la referencia UX original se conserva en `prototype-reference.md`. `AGENTS.md` ya apunta al hito 5, no al 3.
- Estado GitHub leído directamente: predeterminada `codex/Dopmi` en `21628a6`; continuación `codex/stripe-transfer-delivery` en `8e6663d`, con seis commits posteriores al PR #2. PR #1/#2 integrados; sin PR/issues abiertos al consultar. Este traspaso es solo documental y no integra esos cambios de ejecución entre ramas.
- CI del código `8e6663d` comprobado por estado, pasos y logs: [36074983990](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36074983990), cuatro jobs `success`. Seis pruebas de configuración, 356 backend, 191 pgTAP, 51 Flutter, 18 admin y cuatro prototipo; concurrencia, integración local, Android debug e iOS simulator aprobados. Se resuelve el pendiente de CI del registro anterior. No equivale a un IPA firmado ni al recorrido Guardián en TestFlight.
- Encontradas 18 diferencias entre timestamps de archivos de migración y versiones remotas documentadas: [tabla y procedimiento de auditoría](migration-history-audit.md). No se consultó nuevamente el historial remoto, ni se reparó o ejecutó SQL. No afirmar divergencia de contenido sin comparar.
- H5 sigue abierto: despliegue/ejecución remotos del nuevo preflight y permisos de escritura Stripe, apertura de alta test cuando esté listo el recorrido, aceptación en dispositivo y revisión independiente. Último estado remoto registrado: procesamiento preparado, Checkout cerrado. No se volvieron a verificar ni modificar flags, funciones, webhook, Cron o pagos en este traspaso.
- No había Flutter ni Docker en esta sesión. Se consultó la evidencia de CI existente; no se atribuye a nuevas pruebas locales. Los registros siguientes conservan el contexto histórico: los estados más recientes sustituyen sus pendientes antiguos.

- Preparación para prueba por Codemagic/TestFlight solicitada por el titular: el workflow iOS de TestFlight incluye Guardián, conserva la firma y la identidad de la app existente y exporta para pruebas internas. Configuración cliente generada con validación previa, sin registrar credenciales; las demás compilaciones mantienen Guardián apagado. Se agrega una comprobación de acceso Stripe de sólo lectura protegida por la autenticación existente del trabajador. Seis pruebas de configuración y 356 pruebas backend aprobadas; YAML y scripts de compilación validados. Esta comprobación no acredita escrituras con una clave restringida ni aceptación de pagos. Pendientes al registrar: comprobación remota, habilitación de prueba y CI; la compilación firmada y el recorrido TestFlight los realizará el titular.

- Preparación para aceptación Guardián completada: acceso automatizado disponible, procesamiento de prueba comprobado sin fallos y nuevas altas todavía cerradas. APK conectado generado como **Dopmi Guardián (prueba)**, instalable junto a la app habitual. Las compilaciones por arquitectura y las cuatro verificaciones de integración aprobaron. No se generaron cargos ni operaciones financieras durante esta preparación. Faltan instalación e inicio de sesión en el dispositivo, comprobación de permisos específicos de Stripe y los recorridos integrados de la guía de aceptación. El hito 5 permanece abierto. Este estado sustituye los pendientes de acceso y compilación del registro anterior; no acredita aceptación en dispositivo.

- Preparación remota de aceptación Guardián (24 de septiembre de 2026): conexiones Supabase y Stripe test verificadas. Desplegados `guardian-client` v1, `payment-worker` v8 y `stripe-webhook` v9 desde el código publicado `5a38a36`; archivos remotos comparados sin diferencias. `payments` v7 ya coincide. Webhook de prueba ampliado de ocho a 21 eventos, preservando URL, versión y secreto; lectura posterior confirmó los 13 eventos mensuales/reversiones añadidos. Cron activo cada minuto con token de Vault; varias respuestas posteriores al despliegue HTTP 200, `failed=0`. La prueba HTTP detectó que Supabase servía como texto plano el HTML de retorno: corregido `payment-return` v6 con instrucciones legibles para volver a la app y consultar el mismo intento. **18 comprobaciones remotas aprobadas** mediante `tools/verification/guardian-remote-smoke.mjs`, incluidas denegación anónima de nueve RPC de servidor y tres consultas privadas; **352/352 pruebas backend locales**, sintaxis Node, Deno y `git diff --check` aprobados. El script no acredita credenciales Stripe ni pagos. Workflow de despliegue actualizado para incluir `guardian-client`, sin ejecutarlo ni activar flags. Guía y matriz de aceptación en `docs/guardian-acceptance.md`. Alta remota cerrada (`503 guardian_disabled`), trabajador Guardián sin activar, cero ciclos/suscripciones/liquidaciones; sin cargos ni cambios de esquema. Falta configurar flags y comprobar permisos de la clave Stripe del servidor: el MCP no gestiona secretos, no hay CLI autenticada y el navegador pide sesión Supabase. Android requiere la compilación conectada en el equipo/teléfono del titular; no hay Flutter/ADB locales. El navegador de la sesión bloqueó la URL de retorno (`ERR_BLOCKED_BY_CLIENT`): su contenido y headers se verificaron por HTTP, no como recorrido visual de dispositivo. El hito 5 sigue abierto hasta los recorridos integrados y la evaluación independiente.

- Devoluciones posteriores a transferencias Guardián implementadas: conciliación de devoluciones existentes por cargo persistido, sin crear nuevos reembolsos. Una devolución total confirmada permite revertir cada transferencia por su importe/destino originales; las asignaciones conservan capacidad hasta confirmar todas las reversiones bajo los bloqueos de rescatistas. Concesión por ciclo, claves estables, máximo ocho escrituras y ventana inferior a 23 horas por asignación; recuperación por lectura después de agotar el presupuesto. Guarda evidencia y estado anterior; historial del titular distingue devolución confirmada de reversión pendiente y conserva asignaciones originales después del cierre. Eventos reconsultados, descubrimiento periódico y reproceso protegido; `DOPMI_GUARDIAN_REFUNDS_ENABLED` desactivado y requerido para habilitar el cliente. **352 pruebas backend locales y Deno aprobados**, con 36 casos nuevos; añadidas cinco comprobaciones pgTAP, dos carreras PostgreSQL y tres casos Flutter. Publicado en `fc99fd9`. [CI 36066848009](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36066848009): **cuatro jobs aprobados en la primera ejecución**, análisis Flutter sin observaciones, **51 pruebas Flutter**, APK Android de desarrollo, iOS simulator y backend integrado aprobados; **352 pruebas backend, 191 pgTAP y concurrencia PostgreSQL**. Las carreras nuevas comprobaron una sola concesión de reversión por ciclo y liberación atómica de capacidad bajo el bloqueo compartido del rescatista. Migración remota `20260924222351_guardian_refund_reversals` aplicada con el SQL publicado y verificada: RPC exclusiva de `service_role`, dos tablas privadas con RLS sin lectura de clientes, seis funciones con `search_path` fijo, índices válidos y protecciones de capacidad, entrega e historial presentes. Cero ajustes, reversiones, liquidaciones y candidatos. Comparación de advisories: dos INFO esperados por RLS sin políticas en tablas privadas y un INFO por el índice nuevo de gasto todavía sin uso; ningún WARN/ERROR nuevo. Flutter y PostgreSQL se comprobaron en CI porque no están disponibles localmente. Devoluciones parciales, disputas, reversiones parciales y transferencias aún no confirmadas quedan en revisión sin liberar capacidad ni inventar movimientos. Sin despliegue, habilitación de flags ni operaciones Stripe; Stripe Tax desactivado. La prueba integrada de devolución/reversión y la aceptación integral con Stripe/dispositivo siguen pendientes.

- Revisión del aniversario Guardián: preparación de factura revalida precio/importe verificados bajo el bloqueo del plan; una lectura antigua no puede reservar un importe nuevo. Recuperación de cambio tras cruzar el período exige una factura única del aniversario original, comprobada mediante lectura independiente (propietario, precio, importe y período), antes de confirmar la fecha efectiva; no infiere esa fecha del precio actual de la suscripción. Evidencia ausente, contradictoria o fuera del límite de lectura conserva el bloqueo, sin otra mutación. El titular puede retirar expresamente un cambio de monto sólo antes de autorizar la mutación de suscripción: RPC con identidad, revisión, auditoría, respuesta idempotente y bloqueo compartido con el trabajador; conserva el importe anterior y permite nuevas solicitudes. Flutter explica el motivo de revisión, confirma el retiro y persiste su reintento por cuenta; los casos inciertos conservan la cancelación del plan. **316 pruebas backend locales y Deno aprobados**; 23 casos nuevos cubren lectura antigua, carrera con renovación, umbral de 120 segundos, fin de mes/bisiesto, evidencia tardía y retiro. Añadidas cuatro pruebas Flutter, cuatro comprobaciones pgTAP y tres carreras PostgreSQL reales. Publicado en `320a49b`, con corrección de estilo Flutter en `d83d28a` y aislamiento del usuario sintético de concurrencia en `caffb3c`. [CI 36062877634](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36062877634): **cuatro jobs aprobados**, análisis Flutter sin observaciones, **48 pruebas Flutter**, APK Android de desarrollo, iOS simulator y backend integrado aprobados; **316 pruebas backend, 186 pgTAP y concurrencia PostgreSQL**. Las tres carreras nuevas comprueban retiro antes de mutación, mutación antes de retiro y cambio confirmado antes de una reserva basada en lectura antigua. Los primeros CI detectaron una condición Dart sin llaves y un ID sintético compartido por dos escenarios; ambos quedaron corregidos. Migración remota `20260924214410_guardian_anniversary_review` aplicada con el SQL publicado y verificada: RPC sólo para `authenticated`, filtro del titular, cuatro funciones con `search_path` fijo, RLS sin lectura directa, restricciones de retiro/evidencia y barreras de snapshot/aniversario presentes. Cero suscripciones, solicitudes y trabajos de cobro. La comparación de advisories añadió únicamente el WARN esperado de la nueva RPC SECURITY DEFINER accesible al titular; sin cambios de rendimiento ni otros hallazgos nuevos. Flutter y PostgreSQL se verificaron en CI porque no están disponibles localmente. Sin despliegue, habilitación de flags, llamadas a Stripe ni cargos; Stripe Tax desactivado. Falta aceptación integrada con reloj de Stripe/dispositivo. Siguiente bloque: devoluciones posteriores a transferencias y después aceptación integral del hito 5.

- Historial privado de ciclos Guardián implementado: consulta por `auth.uid()` con paginación por fecha/ID y detalle de asignaciones paginado por gasto, ambos limitados a 50 filas. Muestra intentos iniciales y ciclos mensuales, importe autorizado de cada ciclo, pago/comisiones confirmados, neto asignado, transferencias y devoluciones; no presenta reservas como pagos ni transferencias como depósitos bancarios. Omisiones sólo tras cierre confirmado; resultados inciertos siguen en conciliación. Las consultas no exponen IDs Stripe, claves de intención, datos de rescatistas ni comprobantes/drafts; si un gasto deja de ser público se conserva el importe con título genérico. Otros usuarios y administradores no reciben acceso al historial del titular. Flutter añade pantalla privada, carga de asignaciones bajo demanda, reintento con el mismo cursor, actualización y descarte de respuestas tras cambio de cuenta; el titular conserva consulta aun sin correo confirmado o con cuenta suspendida. Añadidas 11 pruebas backend, diez comprobaciones pgTAP y siete pruebas Flutter. **293/293 pruebas backend locales aprobadas**. Publicado en `c9dbd6d`; el primer CI aprobó backend integrado, 182 pgTAP y concurrencia PostgreSQL, con análisis Flutter sin observaciones, pero detectó que el historial podía seguir cargando tras un cambio de cuenta. Corrección publicada en `b7b3140`: la pantalla escucha el controlador de identidad y reconstruye el estado por titular; una prueba adicional cubre la eliminación de datos financieros ya mostrados. [CI 36054815419](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36054815419): **cuatro jobs aprobados**, análisis Flutter sin observaciones, **44 pruebas Flutter, 293 backend y 182 pgTAP**, concurrencia PostgreSQL, backend integrado de identidad/adopción y compilaciones Android de desarrollo/iOS simulator. Migración remota `20260924202605_guardian_cycle_history` aplicada después del gate PostgreSQL: ambas RPCs sólo para `authenticated`, `search_path` fijo, funciones estables, índice válido y sin lectura directa de clientes; cero ciclos, liquidaciones y suscripciones. La comparación de advisories añadió sólo dos WARN esperados por las RPCs SECURITY DEFINER del titular: su acceso está filtrado por `auth.uid()` y probado frente a terceros y administradores. Hallazgos heredados sin cambios. No hay Flutter, Docker ni PostgreSQL locales disponibles; las verificaciones móviles y PostgreSQL real se ejecutan en CI. Sin despliegue, habilitación de flags ni operaciones Stripe. El siguiente bloque sigue siendo revisión de cambios cercanos al aniversario, seguido de devoluciones posteriores a transferencias y aceptación integral (incluido SetupIntent/3DS e historial en dispositivo).


- Medio de pago Guardián: Checkout `setup` para guardar y autenticar sin cargo inmediato; consentimiento, cliente del titular, revisión y sesión persistida con claves estables. Un SetupIntent `off_session` confirmado y el medio ligado al cliente son requisitos para cambiar el predeterminado de la suscripción; se confirma por lectura independiente y se conserva el aniversario. El cambio sólo afecta nuevas preparaciones; mantiene evidencia del pago inicial y snapshots de facturas anteriores. La preparación se serializa con cobros/cambios y comparte la concesión con cancelación, que puede sustituir una confirmación tardía. Webhook y trabajador recuperan respuestas perdidas; creación/escrituras limitadas a ocho intentos y 23 horas, con recuperación por lectura después del límite. Flutter pide autorización, persiste/reanuda por cuenta y distingue autenticación pendiente, actualización y ciclo omitido. La recuperación mensual existente anula ciclos rechazados o que requieren autenticación; actualizar el medio no los cobra de nuevo. Publicado en `ee7f4c3`, con corrección de selectores Flutter en `3ad7e39`. La autorización explícita del titular para publicar código y documentación en el repositorio público y la rama acordados resolvió el bloqueo de revisión automática. [CI 36049349514](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36049349514): **cuatro jobs aprobados**, análisis Flutter sin observaciones, **37 pruebas Flutter, 282 backend y 172 pgTAP**, concurrencia PostgreSQL real, backend integrado de identidad/adopción, APK Android de desarrollo e iOS simulator. Las carreras nuevas comprueban que una actualización pendiente bloquea reservas, dos trabajadores comparten una concesión y la cancelación impide una confirmación tardía. El primer CI detectó dos pruebas que buscaban botones de texto como botones rellenos; se corrigieron los selectores sin cambiar el comportamiento del producto. Deno aprobado localmente para cliente, trabajador y webhook. Migración remota `20260924193738_guardian_payment_method` aplicada después del gate PostgreSQL y verificada: RPC sólo para `service_role`, tabla con RLS sin lectura directa de clientes, cuatro funciones con `search_path` fijo, barrera de cobro y selección del medio para nuevas facturas presentes; cero altas, suscripciones, trabajos y candidatos. La comparación de advisories añadió únicamente el INFO esperado de RLS sin políticas en la tabla privada `dopmi_guardian_method_jobs`; sin nuevos WARN/ERROR. Sin despliegue, llamadas a Stripe ni cargos; flags y Stripe Tax desactivados. Falta aceptación integrada de SetupIntent/3DS en dispositivo. El hito 5 sigue abierto: siguiente bloque, historial de ciclos; también faltan revisión cerca del aniversario, devoluciones posteriores a transferencias y aceptación integral.


- Cancelación durante el alta Guardián implementada: RPC del titular ligada a la clave de activación, accesible aun con cuenta suspendida; bloquea la reserva y una nueva activación. Checkout recupera respuestas perdidas con la clave original y confirma su vencimiento mediante lectura independiente; un pago tardío sigue la devolución completa existente. El calendario se detiene antes de su primera concesión o recupera/cancela la suscripción ya creada sin factura final ni prorrateo. El registro y la cancelación comparten bloqueo; si el registro ganó, la RPC usa la solicitud normal del plan. Flutter conserva el intento de cancelación por cuenta y distingue cierre del alta del estado del primer pago. **261/261 pruebas backend locales** y Deno aprobados. Añadidas dos carreras PostgreSQL, tres comprobaciones pgTAP y dos casos Flutter. Publicado en `2fc30ec`, con corrección del fixture de concurrencia en `7f18987`. [CI 36043207208](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36043207208): **cuatro jobs aprobados**, análisis Flutter sin observaciones, **33 pruebas Flutter**, APK Android de desarrollo, iOS simulator y backend integrado aprobados; **261 pruebas backend, 168 pgTAP y concurrencia PostgreSQL**. Las carreras nuevas confirman que una cancelación que gana impide la concesión de Checkout y el registro del calendario. El primer CI rechazó un fixture que intentaba modificar un gasto ya financiado; se corrigió creando un gasto sintético independiente, sin cambiar la protección del historial. Migración remota `20260924184639_guardian_activation_cancel` aplicada con el SQL probado y verificada: RPC exclusiva de `authenticated`, filtro por titular, cinco funciones con `search_path` fijo, RLS sin lectura directa y barrera de registro presentes; cero altas, suscripciones y solicitudes. Comparación de advisories: sólo se añadió el WARN esperado `authenticated_security_definer_function_executable` de la nueva RPC del titular; hallazgos heredados sin cambios. Las pruebas Stripe siguen simuladas; falta aceptación integrada en dispositivo. Flags desactivados, sin despliegue ni llamadas a Stripe en este bloque. Siguiente bloque: gestión de medio de pago/autenticación adicional; también faltan historial de ciclos, revisión cerca del aniversario, devoluciones posteriores a transferencias y aceptación integral.

## Hito 5 — preparación de Guardián en modo de prueba

- Integración móvil protegida de Guardián: pantalla Flutter de alta/consentimiento, consulta, cambios y cancelación detrás de `ENABLE_GUARDIAN_TEST=false`; persistencia de intentos por cuenta y claves estables, consulta al volver de Stripe y recuperación desde servidor. Nueva proyección `dopmi_guardian_state()` del titular, sin IDs Stripe, y endpoint `guardian-client` con identidad verificada, campos permitidos y cinco flags de ciclo de vida exigidos. **251/251 pruebas backend locales** y comprobación Deno del endpoint aprobadas. Publicado en `4497bb2` y corregido en `cc4ec6e`/`36c05ee`. [CI 36039251239](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36039251239): **cuatro jobs aprobados**, 31 pruebas Flutter (12 nuevas), análisis sin observaciones, 251 backend, 165 pgTAP y concurrencia PostgreSQL; backend integrado y compilaciones Android de desarrollo/iOS simulator aprobados. El primer CI detectó una importación faltante en tests y cinco observaciones de estilo; el segundo detectó una animación de carga permanente mientras el diálogo esperaba confirmación. Se corrigieron y todas las pruebas pasaron en la versión final. Formato Dart 3.13.3 comprobado localmente; análisis/tests Flutter ejecutados en CI. Migración remota `20260924180505_guardian_mobile_state` aplicada y verificada: RPC sin parámetros, sólo `authenticated`, identidad mediante `auth.uid()`, filtro del titular y `search_path` fijo; cero altas y suscripciones. La comparación de advisories añadió únicamente el aviso esperado por esta RPC SECURITY DEFINER accesible al usuario autenticado; su acceso privado queda limitado al titular y probado frente a anónimos, otros usuarios y administradores. No se ha desplegado el endpoint ni habilitado Guardian. Las pruebas de interfaz usan repositorios falsos; el recorrido integrado con Stripe y la aceptación en dispositivo permanecen pendientes.

- Aplicación de solicitudes: `guardian-changes.mjs` y migración `20260924163547_guardian_request_processing.sql`. Cambia precio desde el próximo período sin prorrateo ni alterar el aniversario; cancela sin factura final. Confirmación mediante lectura independiente, concesión exclusiva, claves estables, recuperación de respuestas perdidas, límites de reintentos y cancelación que sustituye cambios en vuelo. Historial privado por período y snapshots de factura conservan los importes anteriores para cobro/conciliación. Monitor protegido frente a lecturas antiguas y orden uniforme de bloqueo. **244/244 pruebas backend locales** (35 nuevas) y `deno check` aprobados. Añadidas cuatro comprobaciones pgTAP y carreras PostgreSQL para cancelación frente a confirmación de monto y dos trabajadores sobre la misma solicitud. Publicado en `27de0b3`, con árbol idéntico al estado local verificado `58777c0` (implementación `4d0b915` y registro del bloqueo inicial). El titular autorizó expresamente la publicación en el repositorio público y la rama acordados, resolviendo el rechazo de revisión automática. [CI 36032672751](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36032672751): **los cuatro jobs aprobaron**, incluidos web/base, backend integrado de identidad/adopción, análisis/tests Flutter y APK Android de desarrollo, e iOS simulator. Confirmados en CI: 244 pruebas backend, **163 comprobaciones pgTAP** y concurrencia PostgreSQL; una cancelación que confirma primero impide publicar un cambio de monto tardío y dos trabajadores comparten una sola concesión/intento de escritura. Migración remota `20260924171515_guardian_request_processing` aplicada con el SQL probado: RLS e historial sin acceso directo de clientes, RPC sólo para `service_role`, cuatro funciones con `search_path` fijo, trigger de precio inicial, tres columnas de snapshot y protecciones de bloqueo/monitor verificadas. Cero suscripciones, solicitudes, trabajos, precios históricos y candidatos. La comparación de advisories sólo añadió el INFO esperado por RLS sin políticas en `private.dopmi_guardian_prices`: la tabla es privada, sin privilegios de cliente y se accede mediante funciones controladas; no aparecieron nuevos WARN/ERROR. Los hallazgos heredados permanecen fuera de este bloque. Stripe sandbox aislado: `sub_1UJFvU2ZjyMOQ0uLFXQGNjEY` cambió de $50 a $200 MXN conservando fechas y pausa, sin factura ni cargo; una lectura posterior confirmó su cancelación sin prorrateo. La prueba no acredita todavía el flujo integrado. No se desplegaron funciones ni se habilitó `DOPMI_GUARDIAN_CHANGES_ENABLED`; Stripe Tax desactivado. Siguen pendientes interfaz Flutter, revisión de cambios cercanos al aniversario, devoluciones posteriores a transferencias y aceptación integral.

- Solicitudes del titular: migración `20260924160633_guardian_owner_requests.sql`, consulta privada del plan y solicitudes de monto/cancelación ligadas a `auth.uid()`. Consentimiento versionado, clave estable, control de revisión y una solicitud pendiente por suscripción. La cancelación sustituye una intención de monto sin borrar auditoría y bloquea nuevas autorizaciones de pago bajo la misma fila de suscripción; un pago previamente autorizado conserva su conciliación. El cambio de monto conserva los ciclos preparados e impide preparar otros hasta confirmar su aplicación. **209/209 pruebas locales y de CI** (21 nuevas). Publicado en `09709ac`, con árbol idéntico al commit local `10400e8`. [CI 36026092790](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36026092790): 159 comprobaciones pgTAP y concurrencia PostgreSQL aprobadas; dos solicitudes simultáneas producen una intención y una revisión, un nuevo ciclo queda bloqueado y una cancelación que confirma primero impide autorizar el pago. Los cuatro jobs aprobaron: base/web, backend integrado, análisis/tests Flutter y APK Android de desarrollo, e iOS simulator. Migración remota `20260924161814_guardian_owner_requests` aplicada y verificada: tabla con RLS sin lectura/escritura directa de clientes, RPCs sólo para `authenticated` con identidad del titular y `search_path` fijo, barrera de cobro presente, suscripción desconocida rechazada y cero solicitudes/suscripciones. Comparación de advisories sin nuevos hallazgos. No se desplegaron funciones ni se habilitaron flags. Es el contrato de recepción/control: aún no cambia precio ni cancela en Stripe, y la interfaz Flutter sigue pendiente. Siguiente bloque: aplicar solicitudes con evidencia Stripe e historial por período, antes de habilitar la gestión en la app.

- Recuperación de pagos mensuales: `guardian-recovery.mjs` y migración `20260924151905_guardian_payment_recovery.sql`. Consulta InvoicePayment predeterminado e intento vinculados; conserva IDs y comparte la concesión de cobro. Rechazo, autenticación adicional o intento sin confirmar se cierran sólo tras leer factura `void`, InvoicePayment `canceled` e intento `canceled` sin fondos recibidos/capturables; `processing` y éxito aún no reflejado en la factura esperan evidencia, sin repetir `pay`. Un éxito tardío reutiliza la devolución por reserva vencida. **188/188 pruebas locales** (30 nuevas) y `deno check` aprobados. Publicado en `271109d` tras la autorización explícita del titular; árbol idéntico al commit local `7d34808` (implementación `025162d` más registro de evidencia). [CI 36024136834](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36024136834): 188 pruebas backend, 151 comprobaciones pgTAP y concurrencia PostgreSQL aprobadas: una sola concesión de recuperación y una sola autorización de anulación. Los cuatro jobs aprobaron: base/web, backend integrado, análisis/tests Flutter y APK Android de desarrollo, e iOS simulator. El primer intento del backend integrado falló antes de ejecutar pruebas porque el puerto 54322 ya estaba ocupado; la repetición del job aprobó sin cambios de código. Migración remota `20260924160254_guardian_payment_recovery` aplicada y verificada: seis columnas de recuperación, RLS, sin acceso directo de clientes, RPC exclusiva de `service_role` con `search_path` fijo, transición de pago actualizada y cero trabajos/fuentes/candidatos. Comparación de advisories sin nuevos hallazgos. Prueba aislada de Stripe test confirmó anulación y cancelación del intento, sin cargo: `in_1UJEUo2ZjyMOQ0uLSE5vRczi`. Encontró y corrigió una suposición anterior: Stripe conserva `amount_remaining=5000` al anular, aunque la factura ya no sea cobrable; no debe exigirse cero en ese campo. La aceptación se basa en estados terminales y ausencia de fondos recibidos. No se desplegaron funciones ni se habilitaron flags; Stripe Tax permanece desactivado. Siguiente bloque: cambio de monto/cancelación desde la app, seguido de devoluciones posteriores a transferencias, interfaz (incluida gestión del medio de pago/autenticación) y aceptación integral.

- Cobro mensual condicionado: `guardian-collection.mjs` y migración `20260924142301_guardian_monthly_collection.sql`. Reserva y vínculo de factura atómicos, unicidad por período, concesión de ejecución y autorización de pago de un solo uso tras revalidar capacidad, cuenta, calendario y vigencia. Finalización con `auto_advance=false`; sin capacidad, cancelación o reserva vencida, anulación sin llamar a `pay` (la exigencia inicial de saldo cero se corrigió en el loop de recuperación). Facturas antiguas se omiten. Pagos confirmados reutilizan liquidación/transferencias/devolución; una respuesta incierta después de la autorización sólo permite consultar y conciliar, nunca otro intento. Webhooks de facturas y descubrimiento paginado por suscripción con rotación para recuperar eventos perdidos. **158/158 pruebas locales** (23 nuevas) y `deno check` de trabajador/webhook aprobados; Publicado en `92c85da`, con árbol Git idéntico al commit local `7d7407f`. [CI 36013973724](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36013973724): los cuatro jobs aprobaron: base/web, backend integrado, análisis/tests Flutter y APK Android de desarrollo, e iOS simulator. Las 158 pruebas backend, 151 comprobaciones pgTAP y concurrencia PostgreSQL aprobaron: dos procesos obtienen una sola reserva de factura y una sola autorización de pago. Migración remota `20260924143909_guardian_monthly_collection` aplicada y verificada: RLS, sin acceso `anon`/`authenticated`, RPC exclusiva de `service_role` con `search_path` fijo, cero trabajos y listas de fuentes/candidatos vacías. Comparación de advisories sin nuevos hallazgos. Flag adicional `DOPMI_GUARDIAN_COLLECTION_ENABLED` desactivado; no se desplegaron funciones ni se hicieron cargos remotos. Pendientes: tratamiento definitivo de rechazo/autenticación/pago asíncrono incierto, cambios/cancelación desde la app, devoluciones posteriores a transferencias e integración/aceptación integral de Stripe antes de habilitar Guardián.

- Calendario mensual posterior al primer pago: migración `20260924134958_guardian_monthly_schedule.sql` y servicio privado para precio/suscripción de prueba. Requiere primer neto entregado, cargo sin devolución/disputa y medio de pago del cliente guardado. Creación `send_invoice` sin prorrateo inicial y con cancelación al terminar el primer período; una sola actualización activa `keep_as_draft` y retira esa cancelación, seguida de lectura de verificación antes de registrar la suscripción. Claves estables, etapas persistidas, concesiones, reintentos acotados, sincronización de cancelaciones por webhook y lectura periódica. **135/135 pruebas locales** aprobadas (17 nuevas), con fin de mes/años bisiestos y recuperación de respuestas perdidas. `deno check` de trabajador/webhook aprobado. Publicado en `0f95d8f`. Los cuatro jobs de [CI 36010212187](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36010212187) aprobaron: 135 pruebas backend, 151 comprobaciones pgTAP, concurrencia real de Billing (una sola concesión y un intento), web/admin, backend integrado, Flutter/Android e iOS simulator. Migración aplicada remotamente como `20260924141312_guardian_monthly_schedule`; tabla con RLS, sin acceso de `anon`/`authenticated`, RPC exclusiva de servicio con `search_path` fijo, vista de activación actualizada, cero trabajos y candidatos vacíos. Comparación de advisories sin nuevos hallazgos. Prueba aislada en Stripe test: creación sin factura inicial, cancelación protectora y actualización conjunta de pausa/retirada de cancelación confirmadas; suscripción `sub_1UJDNX2ZjyMOQ0uLrGrkDiSp` cancelada al terminar sin factura ni cargos. Detalles y límites en `docs/guardian-billing-design.md`. No se desplegaron funciones; `DOPMI_GUARDIAN_SCHEDULE_ENABLED` y el trabajador continúan desactivados. Faltan el recorrido integrado con Checkout/medio de pago, cobro mensual condicionado, cambios/cancelación desde la app y aceptación integral; no se habilita aún el alta.

- Primer pago Guardián: nueva migración `20260924035436_guardian_initial_checkout.sql`, consentimiento versionado, una sola alta pendiente por donante, reserva antes de Checkout y recuperación de creación con clave estable y plazo acotado. La confirmación valida Checkout/PaymentIntent/cargo/comisión y comparte liquidación y cola de transferencias/devoluciones. Los fallos asíncronos y pagos tardíos no consumen otra reserva. **118/118 pruebas locales** aprobadas, 16 nuevas de alta y primer pago; `deno check` aprobado para trabajador y webhook. Se amplió CI para probar altas y concesiones de creación simultáneas en conexiones PostgreSQL separadas. Publicado en `53e7412` (árbol idéntico al commit local `b888724`). En [CI 35954359436](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35954359436) aprobaron los cuatro jobs: base/web, backend integrado, análisis/tests Flutter y APK Android de desarrollo, e iOS simulator. Las 118 pruebas backend, 151 comprobaciones pgTAP y pruebas de concurrencia reales aprobaron: una sola alta pendiente por donante y una sola concesión de creación. Migración aplicada a Supabase como `20260924041103_guardian_initial_checkout`; tabla privada con RLS, sin acceso `anon`/`authenticated`, RPC exclusiva de `service_role` con `search_path` fijo, cero altas/liquidaciones y candidatos vacíos. Restricción de origen Checkout/factura verificada. Sin nuevos errores ni advertencias de seguridad; sólo el aviso informativo esperado de [RLS sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) para la tabla privada. No se expone un endpoint de alta en la app, no se crea aún el calendario mensual ni se desplegaron/habilitaron funciones. Siguiente bloque: vincular el primer pago asignado con Billing mensual retenido en borrador y sus controles de renovación/cambio/cancelación.

- Loop backend, liquidación y procesamiento de pagos confirmados: la migración `20260924031643_guardian_settlement.sql` vincula la evidencia a la factura/ciclo persistidos, reduce la reserva al neto real de forma atómica y registra devolución del bruto completo si la reserva ya no es válida. Las asignaciones confirmadas ocupan capacidad junto a las aportaciones individuales y aparecen en los totales públicos. Cola privada con arrendamiento, reintentos limitados, claves Stripe estables, transferencias por gasto y devolución completa; recuperación de respuestas perdidas de Stripe y PostgreSQL. `payment-worker` integra el procesador mediante `DOPMI_GUARDIAN_WORKER_ENABLED=true`, desactivado por defecto. **102/102 pruebas locales y de CI** aprobadas con PGlite y Stripe simulado, incluidas cuentas destino cambiadas, importes de transferencia incorrectos, devolución parcial existente y múltiples asignaciones. `deno check` del trabajador aprobado con las dependencias fijadas en un entorno temporal aislado.

- Publicación y base remota del loop: commits `7657a8f` y `474170c` publicados en `codex/stripe-transfer-delivery` tras comprobar el destino y resolver el rechazo inicial de la revisión automática; árboles Git idénticos a los commits locales verificados `b947456` y `2d01b98`. En [CI 35952353186](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35952353186), los cuatro jobs aprobaron el commit `474170c`: 151 comprobaciones pgTAP, pruebas/builds web y admin, 102 pruebas backend, análisis/pruebas Flutter, APK Android de desarrollo, compilación iOS simulator y recorridos de identidad/adopción contra servicios reales. Concurrencia real de reservas y liquidación contra Checkout aprobada (1,900 centavos asignados, 60 reservados, capacidad final cero). La migración se aplicó en Supabase como `20260924034146_guardian_settlement`. Verificación remota: tablas de liquidaciones/trabajos con RLS y sin acceso `anon`/`authenticated`; RPC exclusiva de `service_role`, `search_path` fijo, candidatos vacíos y cero liquidaciones/trabajos; funciones de totales actualizadas. Advisories: sin nuevos errores ni advertencias, únicamente dos avisos informativos [RLS sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), intencionales para estas tablas privadas de servidor. No se desplegó ni habilitó el nuevo procesador, ni se ejecutaron pagos remotos en este loop. La creación y el cobro inicial/mensual, devoluciones posteriores a transferencias, interfaz y aceptación integral de Stripe siguen pendientes; este avance procesa facturas pagadas y previamente vinculadas.

- Lectura de evidencia para conciliación Guardián: `guardian-reconciliation.mjs` obtiene la factura con InvoicePayments, consulta el registro privado mediante una dependencia de servidor y recupera suscripción y PaymentIntent con cargo/comisión expandidos. Rechaza identidades ajenas, pagos incompletos, modo live y comisiones pendientes. La conciliación de un pago confirmado admite una suscripción ya cancelada; los validadores previos al cobro siguen exigiendo estado activo. **83/83 pruebas backend locales** aprobadas (18 de Guardián), con Stripe simulado y PGlite para las suites existentes. Este módulo devuelve evidencia: todavía no está conectado al trabajador, no escribe asignaciones ni transfiere. El siguiente paso es enlazar la factura con su ciclo reservado y liquidar el neto mediante una transacción SQL, incluyendo el camino de devolución. No se desplegaron funciones ni se hicieron cobros remotos en este cambio.

- Prueba aislada de Stripe Billing recuperada y verificada por API el 24 de septiembre de 2026: factura individual de **$50 MXN pagada**, saldo cero y un intento; la factura mensual posterior de la misma suscripción quedó **en borrador, sin intentos ni pagos**, con `auto_advance=false`. La suscripción aislada está cancelada y todos los objetos comprobados son de prueba (`livemode=false`). Detalle e identificadores en `docs/guardian-billing-design.md`. Esta prueba ya había sido realizada por el titular; se corrigió la documentación que aún la señalaba pendiente. Falta integrar cobro, reserva, neto real, devolución y conciliación con Guardián; no se habilitan cobros reales.

- Registro privado de suscripciones y facturas Guardián: migración de Git `20260924021815_guardian_subscription_registry.sql` aplicada a DopMi en Supabase como `20260924024539_guardian_subscription_registry` el 24 de septiembre de 2026. Verificación remota: existen `private.dopmi_guardian_subscriptions`, `private.dopmi_guardian_invoice_cycles` y `public.dopmi_guardian_subscription_server(text,jsonb)`; ambas tablas tienen RLS, la RPC permite `service_role` y deniega `anon`/`authenticated`, y hay **cero** suscripciones, facturas vinculadas y ciclos Guardián. [CI 35947375135](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35947375135) completó correctamente el commit `f7497c4`. Este registro no habilita cobros; el recorrido aislado de pago individual y renovación posterior ya fue verificado en Stripe test; falta la integración de creación, conciliación y devolución.

- Vista previa de capacidad `dopmi_guardian_capacity_preview(gross)` para usuarios autenticados y activos: calcula el neto máximo por reservar, descuenta aportaciones y reservas pendientes y excluye gastos propios/no elegibles. Es sólo una lectura; la reserva transaccional sigue siendo obligatoria antes de Checkout. Los cuatro jobs de [CI 35934568573](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35934568573) aprobaron: PostgreSQL/pgTAP, backend integrado, Flutter/Android e iOS simulator. La migración `20260923233000_guardian_capacity_preview.sql` se aplicó en Supabase como `20260923234106_guardian_capacity_preview`. Verificación remota: función presente, permiso `authenticated` sí, `anon` no, **cero ciclos creados**. Pruebas locales backend **65/65**. No se crea una suscripción ni se realiza un cobro.

- Decisión de producto confirmada el 23 de septiembre de 2026: cobro al activar Guardián y después mensual, sólo si el neto completo cabe en gastos aprobados; si no cabe, el ciclo se omite sin cargo ni deuda. Cancelación impide futuros ciclos y el cambio de monto rige desde el siguiente. Contrato de estados, autorización visible y condiciones para conectar Stripe Billing en `docs/guardian-billing-design.md`. H5.2 queda validado; todavía no hay interfaz, suscripción, cargo ni webhook Guardián activo.
- La ejecución de CI 35931321235 confirmó la prueba de concurrencia, el backend integrado y iOS; el job Flutter/Android se canceló automáticamente cuando el commit siguiente de documentación inició otra ejecución de la misma rama. La cancelación no es un fallo de prueba ni acredita Flutter/Android para ese commit.

- Reserva transaccional en `20260923224118_guardian_atomic_reservations.sql`, aplicada remotamente como `20260923225013_guardian_atomic_reservations`: ciclo privado por donante y clave estable, asignaciones privadas, capacidad calculada después de adquirir bloqueos por rescatista en orden, vencimiento a los 30 minutos y liberación idempotente. La capacidad individual y la lectura pública del disponible descuentan reservas vigentes. Solo `service_role` puede reservar o liberar; ambos controles y RLS se verificaron en remoto, junto con que hay cero ciclos creados. Los cuatro jobs de [CI 35930271928](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35930271928) pasaron, incluida la suite SQL con PostgreSQL real, backend integrado, Flutter, Android e iOS simulator; backend local **64/64** y pgTAP incluyó capacidad, liberación y permisos. Una prueba adicional en dos conexiones reales (`tools/verification/guardian-concurrency.mjs`) confirmó en el job `web-and-database` de [CI 35931321235](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35931321235) que el primer ciclo retiene el bloqueo y el segundo omite la reserva al no quedar capacidad. Se retiene el límite superior del neto (bruto menos comisión Dopmi) porque el costo real de Stripe aún se desconoce. Faltan integración de ciclos con Stripe y revalidación al confirmar; no hay endpoint móvil ni cobro Guardián.
- Se verificó [CI 35927758030](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35927758030): cuatro jobs completados correctamente para el cierre del Hito 4, incluidas las pruebas SQL, backend integrado, Flutter, APK Android y compilación iOS simulator.
- Planificador puro `supabase/functions/_shared/guardian-allocation.mjs`: recibe el neto **ya calculado** en centavos y gastos elegibles obtenidos por el servidor. Prioriza urgencia, aprobación más antigua e ID; llena cada saldo antes de pasar al siguiente. Cuando la capacidad no cubre el neto completo devuelve un plan vacío. Valida entradas y no modifica la base ni llama a Stripe. Suite backend **58/58**, incluyendo cuatro pruebas nuevas.
- Falta validar UX de autorización mensual y completar el ciclo de cobro, transferencia, devolución y conciliación; el resultado del planificador por sí solo no autoriza un cobro ni acredita disponibilidad futura. Guardián sigue sin activar y el modo live queda fuera.

## Hito 4 — completado en modo prueba

- Cierre del 23 de septiembre de 2026: alcance, evidencia y límites en `docs/hito4-delivery.md`. Los cuatro jobs de [CI 35926624549](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35926624549) aprobaron el commit `ca7d23e`: `supabase test db` con PostgreSQL y migraciones reales, tests/builds web, formato/análisis/tests Flutter, APK Android de desarrollo, compilación iOS simulator y pruebas integradas de backend. No se infiere un depósito bancario ni se habilita modo live.

- Trabajador periódico activado el 23 de septiembre de 2026:
  - Se confirmó solo la **existencia** del token en Vault, sin leer su valor. `pg_cron` invoca `payment-worker` cada minuto mediante `pg_net` y resuelve el token al ejecutarse. Trabajo remoto `dopmi-payment-worker-reconcile`, ID 4, activo.
  - La primera ejecución devolvió HTTP 503. Los logs de la función señalaron `reconcile_candidates` y SQLSTATE `42702`: el alias `d` de la consulta chocaba con la variable PL/pgSQL `d`. Se pausó temporalmente el trabajo, se añadió una prueba de regresión y la migración local `20260923215745_fix_payment_reconcile_candidates.sql`, aplicada remotamente como `20260923215929_fix_payment_reconcile_candidates`.
  - La RPC remota ya responde sin error. Se reactivó el trabajo: ejecución de Cron `succeeded`, respuesta HTTP **200**, `processed=3`, `failed=0`. Los tres eventos previamente en espera pasaron a `done`; no se abrió otro Checkout ni se pidió otro cobro. Suite local backend **54/54**. El depósito bancario y `supabase test db` siguen pendientes; esto no habilita modo live.

- Seguimiento del 23 de septiembre, tras la confirmación de Android: el historial del usuario muestra devolución completa, transferencia revertida y neto cero para la aportación de prueba. `tools/verification` volvió a pasar **53/53**; `apps/admin` pasó **18/18** y compiló. En el proyecto remoto están habilitados `pg_cron` y `pg_net`, pero sus tres trabajos existentes no llaman a `payment-worker`. La cola conserva tres eventos antiguos `ready` con cero intentos; un evento en cola no prueba por sí solo que haya un cobro pendiente. No se conoce la existencia de un programador externo ni se puede afirmar que el respaldo periódico esté activo. Se preparó `docs/payment-worker-schedule.sql` para un trabajo de un minuto con token leído de Vault; requiere guardar allí el secreto actual del trabajador y comprobar respuestas HTTP antes de ejecutarlo. H4.4–H4.6 permanecen abiertos.

- Devolución completa posterior a transferencia — implementada y comprobada el 23 de septiembre de 2026:
  - Migración `20260923190407_refund_reversal.sql` aplicada en remoto como `20260923190919_refund_reversal`. Añade evidencia privada de los importes anteriores, referencia de reversión y trabajo con arrendamiento. RPC exclusivo de `service_role`; permiso del cliente denegado comprobado en remoto. RLS activo en la evidencia privada.
  - El webhook comprueba cargo, devoluciones efectivamente exitosas, cuenta propietaria, transferencia y reversión antes de actualizar los importes. Conserva asignación hasta completar; revierte con clave estable y consulta Stripe para recuperar una respuesta perdida. El estado final y el trabajo se guardan juntos; conserva IDs anteriores para auditoría.
  - Desplegadas `stripe-webhook` v7, `payment-worker` v6 y `payments` v6. Autenticación existente conservada. `charge.refunded` ya estaba habilitado en el endpoint de prueba.
  - Devolución real en **sandbox**, iniciada por el conector Stripe: 5,000 centavos MXN, `succeeded`. El webhook creó automáticamente una sola reversión por 4,314 centavos. Stripe y Supabase coinciden; pago/devolución `refunded`, transferencia `reversed`, asignación 0, acumulados del gasto 0 y trabajo de reversión `done` en un intento. No hubo otro cobro. La comisión Dopmi pasa a 0; la comisión original de Stripe queda registrada como pérdida de plataforma. El usuario confirmó con captura del historial en Android que la aportación `07c69cde-c106-4927-8e56-a52fb2fdbcc1` aparece como «Devuelto», «Transferencia revertida», «Comisión Dopmi: $0.00 MXN», «Neto para el rescatista: $0.00 MXN» y «Devuelto: $50.00 MXN»; el historial aún muestra el costo original de Stripe de $5.86 MXN.
  - Backend: **53/53** pruebas locales. Cubre devolución completa, duplicados, respuesta perdida de Stripe/base de datos, saldo insuficiente, devolución aún pendiente, destino incorrecto, transferencia en curso y permisos. Stripe simulado en estas pruebas; la aceptación de sandbox se verificó por separado.
  - Alcance automático: devolución total sobre una transferencia completada. Devoluciones o reversiones parciales requieren revisión explícita; la función devuelve error reintentable, no afirma éxito. Transferencias sin resultado confirmado no se cancelan por suposición. Falta aceptación de depósitos bancarios y disponibilidad del trabajador programado.
  - `deno check` local sigue bloqueado por resolución de `@supabase/supabase-js@2.57.4`; despliegue y ejecución de sandbox comprobados. Sin nuevo build móvil ni cierre de H4.4/H4.6. Asesor de seguridad ejecutado: conserva avisos sobre objetos anteriores; no se declara una auditoría global aprobada. La comprobación directa de privilegios de la nueva RPC y RLS de la nueva tabla fue correcta.

- Aceptación adicional del 23 de septiembre de 2026 (posterior al reenvío firmado):
  - Stripe de prueba y Supabase conciliados por lectura: una transferencia por 4,314 centavos MXN para la aportación de 5,000 centavos; misma referencia en ambos sistemas, trabajo terminado en un intento y acumulado asignado/transferido de 4,314. Cero devoluciones y cero reversiones para ese cargo. El usuario confirmó el historial en su teléfono con los importes correctos.
  - `npm test` en `tools/verification`: **45/45**, con seis escenarios adicionales: pago no exitoso, Checkout expirado, devolución de importe no asignable, repetición sin otra devolución, respuesta perdida de devolución y devolución pendiente. El conteo incluye una caracterización explícita de la limitación de devolución posterior a transferencia; no acredita que esa funcionalidad esté terminada. Las llamadas a Stripe de estas pruebas son simuladas y la base usa PGlite.
  - La caracterización comprobó que un `charge.refunded` posterior a una transferencia cambia `transfer_status` a `attention`, conserva `allocated_cents` y deja `refund_status=none`; no invoca una reversión. **Bloquea la aceptación de devolución completa posterior a transferencia**: falta implementar reversión, conciliación de devolución/acumulados y estados de historial. La devolución externa de la aportación existente se pospuso para no dejarla deliberadamente en ese estado incompleto; no se ejecutó ningún reembolso remoto en esta sesión.
  - `npm test` en `apps/admin`: **18/18**; `npm run build`: **OK**. Se mantiene fuera de estos cambios la edición previa de `Rescues.tsx`.
  - Flutter y Docker no están disponibles en PATH; no se ejecutaron análisis/tests Flutter ni pgTAP con stack Supabase. La consulta de workflows del commit remoto devolvió cero ejecuciones de pull request (el conector filtra por ese tipo); no demuestra ausencia de workflows de push ni acredita CI móvil.
  - Los reintentos concurrentes, las firmas, la privacidad del historial y la recuperación de respuestas perdidas pasaron localmente. No se reenviaron eventos reales nuevos ni se probó un depósito bancario. H4.4–H4.6 siguen abiertos.

- Actualización posterior del 23 de septiembre de 2026:
  - Supabase conectado y proyecto comprobado `ACTIVE_HEALTHY`. Migración `payment_delivery` aplicada con versión remota `20260923145807` (archivo fuente `202609230001_payment_delivery.sql`); el historial previo estaba vacío aunque las migraciones anteriores ya estaban aplicadas manualmente. No se reejecutaron esas migraciones ni se alteró su historial.
  - Desplegadas y activas: `payments` v5, `stripe-webhook` v6, `payment-worker` v5. Se conserva su autenticación propia: Auth para clientes, firma de Stripe para eventos y secreto del trabajador. Petición anónima a `payments` devuelve `401 sign_in_required`.
  - El pago remoto investigado está confirmado, con neto asignado y transferencia aún pendiente, sin referencia de transferencia y con cero intentos del trabajo correspondiente. No hay un job de `pg_cron` que invoque `payment-worker`; esto no descarta un programador externo.
  - Ahora también se recuperan dependencias pendientes de eventos que la versión anterior ya marcó como completados. Un reenvío firmado del evento original consulta el mismo cargo y reclama su transferencia pendiente; los reenvíos posteriores conservan la misma transferencia.
  - Pruebas de backend actualizadas: **39/39** (10 identidad, 29 pagos), incluida recuperación de eventos antiguos. No se ha confirmado todavía una transferencia real en Stripe: la invocación autenticada del trabajador o el reenvío firmado del evento original siguen pendientes. No se extrajeron secretos de Edge Functions para ejecutar la recuperación.
  - El usuario autorizó expresamente el push a la rama propuesta. Git CLI carece de credenciales para el transporte HTTPS; se utiliza la integración conectada de GitHub para publicar los mismos archivos autorizados.

- Corrección de entrega de Stripe Connect del 23 de septiembre de 2026, validada localmente; **pendiente de despliegue y aceptación remota**:
  - El webhook anterior solo encolaba el evento y devolvía `200`; no garantizaba ejecutar sus transferencias. Ahora reclama el evento y completa sus trabajos dependientes antes de confirmar. Fallos necesarios devuelven `503` y quedan reintentables; no se presupone si el programador remoto estaba activo.
  - Transferencias vinculadas al cargo original, cuenta destino validada contra el rescatista, clave de idempotencia estable y persistencia atómica de referencia/estado. Se comprobaron duplicados, handlers simultáneos, comisión aún no disponible, respuesta perdida de Stripe y respuesta perdida después del commit de base de datos.
  - Migración nueva `202609230001_payment_delivery.sql`: reclamo dirigido con arrendamiento, finalización atómica, lectura administrativa para reprocesamiento y acumulados asignado/transferido por gasto y caso. Los RPC internos siguen siendo exclusivos de `service_role`.
  - `payment-worker` incorpora `reprocess_donation`: usa el Checkout/cargo existente, no crea otro cobro, no transfiere dos veces y se detiene fuera de la ventana segura de idempotencia. No se ha invocado contra la aportación remota del usuario.
  - Se separó la consulta de estado propio de Connect de la autorización de alta. El historial conserva RLS para donante/rescatista activos; una revisión pendiente no impide consultar aportaciones anteriores. Fallos de permisos de Stripe se distinguen de denegaciones del usuario. La causa exacta de los dos `403` remotos todavía requiere sus logs nuevos; no se declara confirmada.
  - Flutter muestra neto asignado y transferido con importes consultados, recarga y mensajes de error específicos; se eliminó el aviso fijo de que no hay aportaciones.
  - `npm test` en `tools/verification`: **38/38** (10 identidad, 28 pagos). Ejecuta todas las migraciones en PGlite/PostgreSQL; Stripe se simula. Incluye el escenario de 5,000 centavos brutos, 100 de plataforma, 586 de Stripe y 4,314 transferidos. No equivale a una prueba real de Stripe ni a concurrencia entre servidores PostgreSQL distintos.
  - `npm test` en `apps/admin`: **18/18**; `npm run build`: **OK**. Se preservó fuera del commit de pagos el cambio previo del usuario en la revisión administrativa de rescates.
  - `flutter analyze`, `flutter test` y formato Dart: pendientes, SDK no disponible en este entorno. `supabase test db`: pendiente, no hay stack local/Docker. `deno check`: no se pudo resolver el paquete fijado de Supabase por conexión rechazada al registro npm; no se declara aprobado.
  - Supabase no está conectado en esta conversación; se solicitó la integración. Antes de desplegar las funciones hay que aplicar la migración. No se habilitó modo live ni se movió dinero en remoto durante esta corrección. Procedimiento y límites en `docs/stripe-test-mode.md`.
  - El push de la rama `codex/stripe-transfer-delivery` fue bloqueado por el control de autorización del entorno: requiere aprobación explícita del destino y la rama para exportar código posiblemente privado. Los cambios siguen en commits locales; no se intentó eludir el bloqueo ni disparar un despliegue alternativo.
- Inicio de hito autorizado: Aportaciones base, consultas administrativas y lógica de asignación por cola.
- Verificación incremental del 21 de septiembre de 2026:
  - `cd tools/verification; npm test` → **23 pruebas, OK**. La cobertura nueva comprueba que el alta de Stripe Connect es reanudable, no duplica cuentas, solicita transferencias para México y consulta depósitos usando el contexto de la cuenta conectada.
  - `cd apps/admin; npm test` → **18 pruebas, OK**; `npm run build` → build de producción **OK**.
  - La migración `202609130007_donations.sql` se aplicó en el proyecto remoto. Un evento `payment_intent.succeeded` generado por Stripe CLI llegó al webhook remoto y respondió **HTTP 200** después de encolarse; el `404` previo de `dopmi_payment_server` quedó resuelto.
  - Los secretos aislados `STRIPE_SECRET_KEY_H4_TEST` y `STRIPE_WEBHOOK_SECRET_H4_TEST` tienen prioridad; los nombres existentes se conservan solamente como respaldo para no reemplazar la configuración previa.
  - El flujo permanece restringido deliberadamente a claves Stripe de prueba (`sk_test_`/`rk_test_`); no se habilitaron cobros reales.
  - `supabase test db` no pudo ejecutarse en este entorno porque no incluye daemon de Docker. `flutter analyze` y `flutter test` tampoco pudieron ejecutarse porque Flutter no está instalado. Las mismas comprobaciones quedan delegadas al CI versionado antes de considerar cerrado el hito.
- Implementación completada en este ciclo:
  - `apps/admin/src/api.ts`: se añadió tipo `Contribution` y API `listContributions`.
  - `apps/admin/src/App.tsx`: nueva sección “Aportes” en navegación administrativa.
  - `apps/admin/src/Contributions.tsx`: lista de aportaciones con filtro, estado, paginación y resumen económico con formato en MXN.
  - `apps/admin/src/Contributions.test.tsx`: pruebas de listado, recarga y error.
  - `apps/admin/src/App.test.tsx`: navegación a “Aportes” y llamada al RPC con `status='all'`.
  - `supabase/migrations/202609130007_donations.sql`: base de datos de aportaciones (`dopmi_donations`, `dopmi_donation_allocations`, funciones `dopmi_record_donation`, `dopmi_admin_donations`, `dopmi_apply_donation`, `dopmi_donation_status_summary`).
  - `supabase/tests/contributions.test.sql`: suite pgTAP para idempotencia, reintentos, estados e integración de asignación.
- Verificaciones del ciclo:
  - `cd apps/admin; npm test` → **18 pruebas, 4 archivos, OK**.
  - `cd apps/admin; npm run build` → build de producción **OK**.
  - `supabase test db` con `contributions.test.sql`: **bloqueado por falta de conexión local a PostgreSQL** (`ECONNREFUSED 127.0.0.1:54322`).
  - `docker version`: cliente OK, **daemon no disponible** (`dockerDesktopLinuxEngine` no encontrado).
- Pendiente de cierre del hito:
  - Ejecutar `supabase test db` al tener Docker/local stack activo.

## Hito 3 — completado

- Inicio autorizado y una sola secuencia de trabajo por ciclo, sin saltar H4.
- MCP Supabase conectado a `ohqxranynackjignryep` con estado `ACTIVE_HEALTHY`; acceso a tablas H1/H2 validado y Figma activo para contraste UX.
- Migración aplicada en remoto: `202609130006_rescue.sql` (borradores y expedientes, historial privado, publicación aprobada separada, reglas de Storage y funciones de revisión).
- Verificaciones locales de base:
  - `npm test` en `tools/verification` → **10 pruebas de identidad** (pasó).
  - `supabase test db` con `DOPMI_LOCAL_CONFIG` → **3 archivos, 120 pruebas** (pasó), incluyendo `supabase/tests/rescue.test.sql`.
- Verificaciones locales de mobile:
  - `flutter pub get`
  - `flutter analyze` sin incidencias.
  - `flutter test` → **16 pruebas** (pasó).
  - `flutter test test/rescue_test.dart` → **2 pruebas** (pasó).
  - `flutter test test_backend/rescue_backend_test.dart` → **1 prueba** (pasó).
- Verificaciones locales de panel admin:
  - `npm test` → **14 pruebas** (pasó).
  - `npm run build` (salida en `apps/admin/dist`) (pasó).
- Cierre funcional entregado en este hito:
  - `apps/mobile/lib/features/rescue/*` para registro, correcciones y revisión de estado desde móvil.
  - `apps/admin/src/Rescues.tsx` y `apps/admin/src/Rescues.test.tsx` para revisión de expedientes con evidencia privada y motivos de decisión.
  - `supabase/tests/rescue.test.sql` cubre acceso privado, versionado, rechazo de cambios inválidos, aprobación con monto/urgencia y publicación pública solo aprobada.

## Conexiones previas al hito 3 — 13 de septiembre de 2026

- Proyecto de desarrollo fijado a `ohqxranynackjignryep` y scopes de acceso confirmados en sesión.
- MCP Supabase y Figma activos. No se detectan restricciones nuevas de acceso.

## Hito 2 — completado

- Inicio autorizado: adopción, revisión administrativa, catálogo, guardados, perfiles públicos, mensajes y notificaciones internas.
- Se conserva la base de identidad y el trabajo posterior de emulación. Una sola secuencia de implementación está activa.
- Migraciones 003–005 aplicadas en PostgreSQL local: publicaciones moderadas, conversación privada y fotos en Storage privado. Las 58 comprobaciones nuevas de pgTAP y las once de identidad aprobaron.
- Flutter incorpora catálogo con filtros/paginación, detalle, favoritos, perfil público, borradores, fotos sin EXIF, revisión/correcciones, retirada/adopción realizada, conversación, cierre y notificaciones. El panel incorpora revisión con versión y motivos, fotos privadas e historial.
- Panel: nueve pruebas y build aprobados. Flutter: análisis sin incidencias y catorce pruebas aprobadas, incluidas catálogo, conservación de borrador, reintento de mensajes y eliminación de EXIF. Diez pruebas PGlite aprobadas.
- `verify-backend.ps1` aprobó las 69 comprobaciones SQL y los tres recorridos contra servicios reales: dos de identidad y uno de adopción, Storage, moderación, filtros, favoritos, perfil público, conversación, idempotencia concurrente, privacidad y cierre. Cuentas desechables eliminadas al terminar.
- Remoto: migraciones 003–005 aplicadas juntas desde SQL Editor en `ohqxranynackjignryep`. Las 58 comprobaciones nuevas de permisos aprobaron en una transacción revertida; diagnóstico vacío. Recibo final: cero usuarios/publicaciones temporales, diez perfiles conservados, cuatro tablas en Realtime y bucket privado. API anónima: catálogo público permitido y datos privados denegados.
- Primer CI de H2 (`f0457d0`, ejecución 34791108970): web, Android e iOS simulator aprobaron. La integración detectó una carrera de arranque: el join de Realtime se confirma antes de que PostgreSQL pueda emitir cambios. Se reprodujo en una base desechable nueva; aumentar la espera no la resolvía. La app ahora vuelve a leer al recibir `system: postgres_changes/ok`, también al reconectar. El recorrido completo pasó desde otra base nueva, sin precalentar Realtime. Referencia: https://supabase.com/docs/guides/realtime/protocol.
- Revisión visual local: cuenta responsable creó borrador, subió foto, envió a revisión y conservó los datos tras correcciones. El panel mostró foto, versión e historial; aprobó la versión corregida. Otra cuenta vio la publicación en el catálogo, la guardó y abrió una conversación. El mensaje enviado apareció en pantalla; al volver a la cuenta responsable, su notificación abrió el mismo mensaje recibido. Recibo de limpieza: cero cuentas de aceptación visual, publicaciones, mensajes y fotos. Los servicios locales se cerraron conservando los volúmenes del proyecto principal.
- Remoto: el panel restauró la sesión administrativa existente, mostró diez cuentas y abrió Adopciones con conexión activa y cola vacía. La vista Flutter ofrece el catálogo real conectado a Supabase; no se dejaron publicaciones de demostración en remoto.
- APK local 0.2.0+2 reconstruido correctamente el 13 de septiembre a las 18:19 con la corrección final, en `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. Es un build debug conectado al proyecto de desarrollo, no una distribución de tiendas.
- [CI final 34792258918](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34792258918), commit `7039f3517e9407eeb02ce57554c825217c6014a8`: los cuatro jobs terminaron con `success` (`web-and-database`, `flutter`, `ios`, `identity-and-adoption-backend`). Incluye Android, iOS simulator en macOS y los tres recorridos de backend reales. Código subido a `codex/Dopmi` en `albertoquiroga-ctrl/dopmi-app`; el cierre posterior modifica solo documentación.
- Hito 2 cerrado dentro del alcance de desarrollo. La revisión visual se realizó en Flutter web y React; la compilación nativa Android/iOS está comprobada. Galería tras interrupción del proceso, permisos/enlaces y almacenamiento seguro en dispositivos físicos se validarán en la beta del hito 6. Las notificaciones son internas; push permanece fuera de este hito. El siguiente alcance propuesto es H3: verificación de rescatistas y gastos con evidencias y revisión, sin iniciar todavía pagos.

## Hito 1

Estado: **hito 1 completado**. Flujos de identidad comprobados, Android e iOS simulator compilados, acceso administrativo del titular habilitado y cuatro jobs del CI ampliado aprobados.

- Referencias revisadas: prototipo, fuente funcional y documentos del ZIP; acceso al Figma comprobado.
- Proyecto de desarrollo: `ohqxranynackjignryep`. El usuario confirmó que las nueve identidades previas son de prueba. Se preservaron las tablas antiguas y sus datos.
- Entorno inicial: Windows, Node disponible; Flutter, Docker y Supabase CLI no disponibles en PATH.
- El cambio previo en el `package-lock.json` del prototipo pertenece al estado inicial y se conserva.

## Implementado

- Flutter con onboarding, registro, confirmación por enlace/código, sesión persistente, recuperación, perfil editable, consentimiento de desarrollo y cambio de experiencia. Almacenamiento seguro de sesión/PKCE en Android e iOS; callbacks configurados en ambos proyectos nativos.
- Panel administrativo con sesión real, permiso comprobado en servidor, búsqueda, paginación y detalle de usuarios. Las lecturas administrativas quedan registradas.
- Migración `202609130001_identity.sql` aplicada desde el dashboard: perfiles, RLS, membresías privadas, auditoría y RPC. Las nueve cuentas existentes tienen perfil. La función antigua `is_admin(uuid)` quedó intacta; la nueva es `dopmi_is_admin()`.
- Migración `202609130002_legacy_identity_boundary.sql` aplicada: se cerró la lectura y escritura de la tabla heredada `public.users` desde clientes. Su trigger de protección comprobaba `current_user` dentro de una función con `SECURITY DEFINER`, por lo que no impedía elevar el rol propio. Se preservaron datos y acceso del servidor. Se verificó que no hay vistas públicas que consulten esa tabla.
- Confirmación de correo habilitada en el remoto (antes estaba desactivada). Mínimo diez caracteres, mayúscula/minúscula/número y cambio seguro de contraseña. Tres callbacks exactos autorizados.
- Plantillas de confirmación y recuperación en español, con enlace y código. Copias versionadas en `supabase/templates`.
- Instrucciones, backlog, script de desarrollo y workflow de CI para web, SQL, Flutter, Android e iOS simulator.
- Se corrigió el tipo del sexo de las mascotas del prototipo, que impedía compilar con TypeScript. Sin cambio de comportamiento.

## Evidencia del 13 de septiembre de 2026

- PGlite/PostgreSQL: diez pruebas de RLS, privilegios, consentimiento, suspensión, búsqueda, auditoría y aislamiento de identidad heredada aprobadas. La segunda migración también se comprobó sin tablas anteriores.
- Supabase remoto: once comprobaciones pgTAP ejecutadas en una transacción con rollback. Sin diagnósticos de fallo; último resultado `ok 11 - anonymous profile access blocked`.
- API remota: Auth responde, exige confirmación y rechaza acceso anónimo a perfiles y RPC administrativas. La comprobación ampliada también incluye la tabla heredada.
- Admin: cinco pruebas aprobadas y compilación de producción correcta. Comprobación visual del login; una cuenta inexistente recibió el rechazo de credenciales de Supabase.
- Flutter: diez pruebas aprobadas, incluidas pantallas de 390×844, persistencia de recuperación, cierre de sesión y conservación de datos al fallar un guardado. El desbordamiento encontrado en el estado de correo confirmado se corrigió.
- Flutter analyze: sin incidencias en la comprobación final.
- Prototipo: cuatro pruebas aprobadas y build correcto después de corregir el tipo estrecho en `src/data.ts`.
- Vista Flutter abierta en `http://localhost:5175`; panel en `http://127.0.0.1:5174`.
- Android: compilación debug correcta tras limitar Gradle a 2 GB y dos trabajadores. APK `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, versión 0.1.0, paquete `io.dopmi.dopmi_mobile`, target SDK 36. Se comprobaron en el APK el nombre Dopmi, permiso de red, backups deshabilitados y callback `io.dopmi.app://auth/callback`.
- Reversión de las pruebas remotas confirmada: cero identidades temporales y cero membresías administrativas dejadas por las pruebas; nueve perfiles previos conservados.
- Activación administrativa posterior: el titular creó su cuenta y confirmó el correo. Supabase devolvió correo confirmado, perfil activo y membresía ausente. Se habilitó exclusivamente su membresía mediante una consulta de servidor condicionada a esos requisitos; el recibo devolvió `admin_active = true`. Al recargar su sesión del panel, apareció el directorio con diez cuentas y conexión activa. No se cambió su contraseña ni se omitió la confirmación de correo.
- Instalación inicial de contenedores: Docker Desktop 4.90.0, cliente 29.7.2, WSL 2.7.14.0 y kernel 6.18.33.2-2 instalados. En ese momento Windows tenía un reinicio pendiente y el motor no estaba disponible. Ese bloqueo se resolvió con el reinicio y las comprobaciones descritas abajo.
- Durante la instalación se comprobaron Supabase CLI 2.117.0 y las diez pruebas de `tools/verification` con `npm.cmd test`.

## Cierre de validaciones del hito 1

- Después del reinicio: Windows inició el 13 de septiembre de 2026 a las 16:36; no hay reinicio pendiente. `docker version` devuelve cliente y servidor 29.7.2 y WSL tiene la distribución `docker-desktop` en versión 2. Se inició Supabase local con las dos migraciones y los servicios reales Auth, REST y Mailpit.
- PostgreSQL local: `supabase test db` aprobó las once comprobaciones pgTAP. Ya no existe el bloqueo de Docker.
- CI existente verificado mediante la API de GitHub: [ejecución 34786807228](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34786807228), commit `f0ade1a`, terminó con éxito en sus tres jobs. Incluye pruebas/build del prototipo y admin, permisos PostgreSQL, análisis/pruebas Flutter, APK Android e iOS simulator compilado en macOS. La compilación de iOS ya está comprobada.
- Sesión del titular: después de reiniciar Windows y abrir de nuevo la vista Flutter, se restauró el perfil confirmado sin pedir credenciales. La experiencia se cambió a rescatista desde el formulario, se guardó en Supabase y persistió al recargar. Se restableció y guardó la experiencia original donante/adoptante. El panel también restauró la sesión administrativa y mostró las diez cuentas, incluida la experiencia original restaurada.
- Integración Flutter/Supabase: dos recorridos aprobados con cuentas locales desechables. Ambos comprueban registro con confirmación obligatoria, perfil editable persistente, cierre/restauración de cliente, denegación administrativa, recuperación, contraseña anterior rechazada y nueva contraseña aceptada. Uno consume el código recibido en Mailpit; el otro consume el enlace PKCE después de reiniciar el cliente. También se restaura una sesión interrumpida durante la recuperación sin permitirle entrar al perfil antes del cambio.
- Estas pruebas usan las clases de producción del repositorio, controlador y almacenamiento. Los servicios de Auth/PostgreSQL/SMTP son reales; las APIs nativas de preferencias y almacenamiento seguro están simuladas en el ejecutor de Flutter. No se declara una prueba de hardware móvil ni de Keychain/Keystore en dispositivo. La limpieza dejó cero identidades de aceptación y cero perfiles en la base local.
- `scripts/verify-identity.ps1` prepara el entorno local y ejecuta los permisos y ambos recorridos. El comando completo se ejecutó correctamente: once comprobaciones SQL y dos recorridos de identidad aprobados. El análisis final de Flutter no encontró incidencias.

## Resultado final

- [Ejecución 34788208103](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34788208103), commit `788a236278122c977190e91278f20709b6c7ca01`: resultado global `success`. Los cuatro jobs aprobaron: `web-and-database`, `flutter`, `ios` e `identity-backend`. Esto incluye las diez pruebas Flutter de estado/interfaz, cinco del admin, cuatro del prototipo, diez de PGlite, once comprobaciones pgTAP, dos recorridos completos de identidad, compilaciones web/Android/iOS simulator y formato/análisis de Flutter.
- Implementación y pruebas subidas a `codex/Dopmi` en `albertoquiroga-ctrl/dopmi-app`. El registro final es un cambio exclusivo de documentación; no modifica el código validado por esa ejecución.
- No quedan tareas abiertas del hito 1. El alcance de esta aceptación es desarrollo: los puntos de beta/distribución siguientes mantienen su hito original.

## Condiciones para los hitos posteriores

- La recuperación del titular no se ejecutó cambiando su contraseña personal; el recorrido completo se comprobó con identidades locales de prueba y las mismas clases de producción.
- Las compilaciones de Android e iOS simulator están comprobadas. Instalación, enlaces desde clientes de correo de cada sistema, almacenamiento seguro en hardware y firma de distribución requieren dispositivos y forman parte de la validación de beta/lanzamiento del hito 6.
- El correo integrado de Supabase sigue activo. SMTP propio es necesario para ampliar destinatarios/volumen de la beta. Google/Apple permanecen deshabilitados hasta configurar y verificar sus proveedores.

El siguiente alcance es H2: adopción y comunicación. No se inicia automáticamente como parte del cierre de identidad.

## Emulación solicitada después del cierre del hito 1

- Android Emulator 37.1.11 y la imagen oficial Android 15 / API 35 / x86_64 instalados en `.tools/android-sdk`, fuera de Git. Se creó `Dopmi_API_35`, con dos núcleos, 1536 MB de RAM y pantalla de 720×1520. El equipo tiene 8 GB de RAM y poca memoria libre; el primer arranque fue lento.
- La consulta de componentes de Windows indicó `HypervisorPlatform` desactivado, pero la comprobación directa `emulator -accel-check` devolvió `WHPX(10.0.19045) is installed and usable`. El registro de arranque confirmó aceleración operacional. No fue necesario cambiar componentes de Windows ni reiniciar.
- `emulator-5556` inició con `sys.boot_completed = 1`. Se instaló correctamente el APK de desarrollo existente, versión 0.1.0, que contiene x86_64. El primer `am start -W` agotó su espera; una comprobación posterior confirmó proceso activo, `MainActivity` reanudada y en primer plano, motor Flutter iniciado y búfer de errores de cierre vacío. Esto verifica instalación y ejecución nativas en el emulador; no añade una comprobación visual ni un recorrido autenticado de usuario en Android.
- `flutter analyze`: sin incidencias. `flutter test`: diez pruebas aprobadas en esta sesión.
- Se añadió `scripts/emulate-android.ps1` para abrir el dispositivo e instalar el APK; `-Rebuild` recompila cuando cambian código/configuración. El comando y las instrucciones para iOS están en `docs/development.md`. La sintaxis PowerShell se comprobó; el arranque/instalación se ejecutó con ese script y las comprobaciones posteriores usaron ADB.
- iOS interactivo queda pendiente por plataforma: esta sesión dispone de Windows, sin una Mac/Xcode conectada. El simulador oficial requiere macOS. Se conserva la evidencia previa de compilación iOS en CI; no se declara una ejecución interactiva de iOS nueva.
## H10 — legal, eliminación y medición — 28 de septiembre de 2026

- Migraciones H10 de términos/eliminación y conservación de contenido aplicadas
  en Supabase test como `20260928211754` y `20260928212147`.
- `account-deletion` v2 ACTIVE: bloqueo inmediato, revocación de Apple,
  limpieza de medios prescindibles, cierre global de sesión, eliminación Auth y
  finalización idempotente. Evidencia financiera y mensajes ajenos se conservan.
- App: términos y privacidad vigentes, mayoría de edad, eliminación en
  Configuración, vínculo explícito de identidades y medición opcional separada.
- Firebase Android/iOS validado para `com.mycompany.dopmi`; configuraciones
  fuera de Git y variables seguras creadas en Codemagic. Google/Apple siguen
  apagados porque los proveedores Supabase están deshabilitados.
- Web pública: `https://dopmi.org/privacy-policy`, `/terms` y
  `/delete-account` responden HTTP 200.
- Verificaciones: Flutter analyze y 86 pruebas; backend 402; administración 23
  y build; configuración móvil 10. Pagos permanecen test-only.
- Pendiente externo: guardar OAuth/manual linking, pruebas instaladas, correo
  transaccional, aprobación del proyecto Supabase producción y builds conjuntos.
- Resend comprobado en el equipo `enlacenest`: `dopmi.org` está verificado y se
  creó una credencial dedicada de envío, limitada a ese dominio y almacenada
  fuera del repositorio. El correo controlado de H10 salió desde
  `soporte@dopmi.org`, incluyó versiones HTML y texto, y Resend registró los
  eventos `Sent` y `Delivered` el 28 de septiembre de 2026. La recepción de una
  respuesta también se comprobó en el buzón `soporte@dopmi.org`: llegó desde la
  cuenta destinataria, conservó el asunto de la prueba y mostró el contenido
  esperado. El recorrido transaccional de ida y vuelta queda verificado.
- Medición H10 completada en código: los cinco eventos permitidos se emiten sólo
  tras confirmación del repositorio/servidor, sin payloads, y Firebase no puede
  interrumpir el resultado del producto. Los pagos evitan duplicados por intento.
  Los builds internos pueden mostrar una acción fija de Crashlytics mediante
  `ENABLE_MEASUREMENT_TEST`; los workflows estándar la excluyen.
- Gate local del bloque: Flutter analyze y 90 pruebas desde copia temporal limpia;
  backend 402; administración 23 y build; prototipo 4 y build; configuración
  móvil 11. La ejecución Flutter inicial dentro de OneDrive falló al copiar una
  caché ya existente y se repitió correctamente fuera de OneDrive.
- La protección contra contraseñas filtradas se difiere a H12 por decisión del
  titular, ya que requiere Supabase Pro. H10 continúa abierto por dispositivos,
  Firebase, Private Relay y un candidato conjunto nuevo.
- Candidato conjunto generado desde `3472c5b4ba5785ab9ab695f4a5d96a3e0befd4a3`.
  Los CI 36501932519 y 36501928018 aprobaron los cuatro trabajos. Android
  Codemagic `6abb04b63e1e341b2e6b97fb` publicó `2.3.3 (262)` y Play Console lo
  muestra disponible para testers internos. iOS Codemagic
  `6abb04b74427c92a169daabd` cargó `2.3.3 (263)` correctamente; App Store
  Connect terminó de procesarlo. Queda completar su declaración de exportación
  y asignarlo al grupo interno para volverlo instalable.
  La hoja `docs/h10-device-acceptance.md` conserva los recorridos y resultados
  pendientes sin documentar credenciales ni correos privados completos.
- Apple Developer aceptó `dopmi.org` como fuente de Private Email Relay y mostró
  SPF válido. App Store Connect guardó la declaración de exportación de iOS 263,
  lo dejó listo para pruebas y disponible para `DopMi Inner Team`. Se observó una
  instalación de 263 en iPhone 14 Pro Max / iOS 18.7.8. Falta comprobar correo al
  alias privado y ejecutar los recorridos funcionales; no se documentó el alias
  ni la identidad del tester.
- La aceptación Android 262 encontró un bloqueo crítico en Configuración: al
  abrir **Información básica** el dispositivo podía quedar en negro; además, la
  opción de eliminación no era visible en la lista y aún aparecía **Aviso de
  desarrollo**. Se separó la edición básica de la nueva pantalla **Privacidad y
  eliminación**, se autorizó explícitamente su ruta autenticada, se reemplazó el
  texto obsoleto por **Términos y privacidad** y se añadieron pruebas de ambas
  rutas. Flutter aprobó 92 pruebas y análisis sin incidencias; Android 262/iOS
  263 quedan superados para estos recorridos y requieren un candidato nuevo.
- iOS declara `ITSAppUsesNonExemptEncryption = false`, coherente con la
  declaración ya aceptada para 263, para evitar repetir la intervención manual
  de exportación en candidatos que no incorporan cifrado no exento.
- Candidato correctivo conjunto desde
  `af8027a47ddd6c94caebdcc3b2672033baf2c29e`: CI 36510163492 aprobó sus cuatro
  jobs. Codemagic Android `6abb1b18a7c0e10e9a05069e` generó y publicó
  `2.3.3 (264)`; Play Console confirmó el código 264 disponible para testers
  internos. Codemagic iOS `6abb1b1832bd8882759214f4` generó y cargó
  `2.3.3 (265)`; App Store Connect lo muestra `En pruebas` y asignado a
  `DopMi Inner Team`. Falta instalación y aceptación física de este candidato.
- La prueba instalada de Android 264 completó la eliminación real y el posterior
  acceso con Google. Supabase confirmó dos solicitudes `completado`, sin código
  de atención. El acceso reutilizó otra identidad Dopmi previa vinculada al
  proveedor; su perfil conservaba términos de desarrollo, sin versión de
  privacidad ni confirmación 18+, y la app no lo bloqueó. Información básica
  también continuó en negro.
- Corrección posterior: el consentimiento 18+/términos/privacidad pasa a una
  pantalla obligatoria global para cualquier perfil incompleto o desactualizado;
  Guardián y eliminación conservan acceso para poder cancelar o cerrar la
  cuenta. Google/Apple aparecen también como métodos en **Crear cuenta**. La
  edición básica se movió a la ruta superior `/basic-info`, sin barra de pestañas,
  y la restauración usa inmediatamente la sesión local mientras termina la
  comprobación servidor, evitando la carrera que reemplazaba la ruta por una
  pantalla vacía. Flutter aprobó 94 pruebas y análisis sin incidencias.
- Candidato conjunto correctivo desde
  `d3beba30c1d52206414a77657483789f0cc2d06d`: los CI 36514850944 y
  36514848612 terminaron `success`. Codemagic Android
  `6abb28b041594690c23be43c` publicó `2.3.3 (266)`; Play Console confirmó el
  código 266 disponible en Internal Testing. Codemagic iOS
  `6abb28b1483a70bbe6cb024e` cargó `2.3.3 (267)` correctamente; App Store
  Connect terminó de procesarlo y lo muestra `En pruebas`, asignado a
  `DopMi Inner Team`. El build y las tiendas no acreditan todavía la corrección
  de Información básica ni la aceptación del consentimiento en un dispositivo.
- La prueba instalada posterior no reprodujo el gate 18+ ni la entrada Google
  en alta. Supabase confirmó que el perfil Google reciente seguía con términos
  y privacidad nulos y sin `adult_confirmed_at`; por tanto, no se acepta como
  consentimiento previo. Se añadió una segunda barrera en el árbol de widgets:
  cualquier identidad verificada sin perfil legal vigente queda cubierta por
  **Antes de continuar**, incluso si la carga del perfil falla. Términos,
  eliminación y cancelación de Guardián conservan acceso. Configuración muestra
  desde el siguiente candidato la versión/build compilados para eliminar dudas
  sobre qué paquete está instalado. Flutter: análisis limpio y 95 pruebas;
  configuración móvil: 11 pruebas. Requiere candidato y confirmación física.
- Candidato de la segunda barrera desde
  `419a56dd595ae412fe2ba423c8b97c1ac56ae414`: CI 36522764232 y
  36522761588 aprobaron los cuatro trabajos. Codemagic Android
  `6abb41991ed2d10dbfd22286` terminó con publicación exitosa; Play Console
  confirmó `2.3.3 (268)` disponible en Internal Testing. Codemagic iOS
  `6abb419aac4cd795b1d9af7c` terminó con publicación exitosa y el IPA firmado
  confirma `2.3.3 (269)`, paquete `com.mycompany.dopmi`; queda comprobar su
  procesamiento en TestFlight. La corrección funcional continúa pendiente de
  prueba física.
- Aceptación física Android 268 recibida del titular con capturas
  `1000346255`, `1000346257`, `1000346259` y `1000346261`: Configuración muestra
  la versión correcta, el perfil incompleto queda bloqueado por **Antes de
  continuar**, la mayoría de edad y documentos vigentes requieren aceptación
  explícita, e **Información básica** abre el perfil real sin pantalla negra.
  Ambos defectos quedan solucionados y aceptados en Android. El acceso Google
  desde alta, vinculación, Apple, medición y los demás recorridos H10 conservan
  su aceptación independiente.

# 29/9/2026 — H10, preparación de aceptación final

- Supabase test, consultado por MCP sin exponer identificadores: 17 cuentas,
  identidades `email: 16` y `google: 3`, una aceptación 18+/legal vigente, tres
  eliminaciones `completado`, ninguna pendiente y cero credenciales Apple.
- Firebase DebugView no mostró dispositivo de depuración ni eventos durante la
  observación. Crashlytics Android continúa en **Add SDK**; ambos recorridos
  requieren activar los consentimientos y la acción de diagnóstico desde el
  build instalado. La actividad histórica de Firebase no se acepta como prueba.
- `apps/admin`: 23 pruebas y build aprobados. `tools/verification`: 105 pruebas
  aprobadas. `scripts/test_mobile_config.py`: 11 pruebas aprobadas. Flutter no
  está disponible localmente; CI del SHA candidato conserva esa comprobación.
- Se corrigió el backlog: Resend/SMTP y recepción-respuesta de soporte ya estaban
  comprobados. Permanecen Apple/Google en dispositivo, Private Relay,
  Analytics/Crashlytics y disponibilidad instalada de TestFlight 269.
- Prueba física Android 268: Firebase detectó el SDK tras habilitar Diagnóstico,
  registrar el error controlado y reiniciar Dopmi, pero no recibió el reporte.
  Se añadió un despacho explícito de reportes pendientes únicamente después de
  `recordError` consentido. `flutter analyze` quedó limpio, la prueba dirigida
  aprobó 6 casos y la suite Flutter completa aprobó 95 pruebas. La corrección
  queda pendiente de candidato instalado y recepción visible en Crashlytics.
- Android de corrección: Codemagic `6abbc365a2cb55def9efff17`, SHA `5c505c2`,
  versión **2.3.3 (270)**. Configuración, análisis, 95 pruebas, firma, AAB,
  Publishing y limpieza aprobaron. Play Console lo mostró como disponible para
  Internal Testing a las 08:08; el bundle anterior 268 quedó desactivado. iOS
  `6abbc3656e8a9a4c7f26ae72` seguía en cola al registrar esta evidencia.
- Android 270, aceptación física: la captura del titular confirmó Analítica
  apagada, Diagnóstico activado y el aviso de envío. Firebase recibió un no fatal
  `dopmi_diagnostics_test` con motivo `internal_acceptance_test`, 1 evento y 1
  usuario. El envío consentido de Crashlytics queda aprobado; falta comprobar la
  retirada del consentimiento. iOS inició y aprobó preparación, configuración,
  análisis, 95 pruebas y firma; la generación del IPA seguía en curso.
- La captura `1000346267` confirmó ambos controles apagados y la desaparición de
  la acción de diagnóstico. Se reforzó la retirada con `deleteUnsentReports`
  antes de activar, al apagar y al cambiar de cuenta, para impedir el envío
  posterior de reportes generados sin consentimiento. `flutter analyze` limpio,
  7 pruebas dirigidas y 96 pruebas Flutter completas aprobaron.
- iOS Codemagic `6abbc3656e8a9a4c7f26ae72` generó y firmó el IPA 2.3.3 (271).
  Publishing quedó `failed`: Apple emitió tres HTTP 500 al cerrar estados del
  upload, aunque `altool` terminó con `UPLOAD SUCCEEDED` y delivery UUID. No se
  declara TestFlight disponible hasta consultar App Store Connect; la sesión web
  expiró y solicita nuevo acceso.
- Decisión de arquitectura confirmada por el titular: Supabase concentra Auth,
  base de datos, Storage y funciones; Firebase queda limitado a Analytics y
  Crashlytics opcionales. Se añadió una comprobación reproducible que impide
  introducir SDK de backend Firebase sin cambiar expresamente esta decisión.
- Android 270: el titular ejecutó dos veces el resultado real de contacto sobre
  Rocky Demo con Analítica activada. La conversación se creó/recuperó, pero GA4
  Realtime no recibió `contact_started`; sólo mostró eventos heredados de
  FlutterFlow. La aceptación de Analytics permanece abierta. Se corrigió la
  integración para declarar explícitamente `analytics_storage` al activar,
  mantener publicidad/personalización denegadas y reiniciar los datos locales
  al retirar consentimiento o cambiar de identidad.
- Candidato de corrección Analytics: [Codemagic
  `6abbdec3af1a117ab3b161f5`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abbdec3af1a117ab3b161f5),
  SHA `e772445e7446b42d49a8ab41163a30b42400b470`, Android **2.3.3
  (272)**. Configuración Firebase, análisis, 96 pruebas, firma, AAB, Publishing y
  limpieza terminaron `success`; la consulta posterior del track confirmó
  `internal`, `completed`, código 272. Falta instalación y repetición del evento
  real; publicación no equivale a aceptación en dispositivo.
- Android 272 instalado y comprobado por captura; Analítica encendida. El
  contacto nuevo con Toby funcionó, pero `contact_started` no apareció. La
  investigación confirmó que Firebase enlaza la app ID Android vigente al
  stream `5400821083`, con recepción reciente y configuración descargada
  idéntica a la usada por Codemagic. La causa estaba en la app: el detalle sí
  medía el contacto, pero el botón del mazo/swipe usado en aceptación y el
  acceso equivalente desde el perfil público omitían el evento. Ambos quedan
  instrumentados después de `startThread`, nunca antes del resultado real.
- El primer gate de esta corrección (`6abbfa69b0dffe4b6f9e12a1`) detuvo la
  publicación porque el nuevo test liberaba dos veces su controlador; no fue un
  defecto productivo ni llegó a Play. Corregido el teardown, [Codemagic
  `6abbfb850c4e011265ad1a16`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abbfb850c4e011265ad1a16)
  aprobó análisis, 97 pruebas, firma, AAB, Publishing y limpieza sobre SHA
  `554e66866d69e65f2e8473a9477398a003e3807c`. Google Play Internal Testing
  confirmó `completed`, Android **2.3.3 (274)**. Falta aceptación instalada del
  evento corregido.
- Android 274 instalado: el titular confirmó por capturas el build, Analítica
  encendida y la creación real de una conversación nueva con Milo desde el
  mazo. GA4 Realtime todavía no mostró `contact_started`, aunque la app, el
  stream y el nombre del evento están verificados. Para dejar de inferir el
  comportamiento nativo, el candidato interno ahora muestra en Privacidad si
  Firebase aceptó el evento, lo omitió sin consentimiento o devolvió un error;
  conserva sólo ese resultado en memoria y no añade payloads.
- [Codemagic `6abc0b9355f874ca95621932`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc0b9355f874ca95621932),
  SHA `f1c0f7b63042122156536d626d5930cf296cc272`, aprobó configuración,
  análisis, 97 pruebas, firma, AAB, Publishing y limpieza. Google Play Internal
  Testing confirmó `completed`, Android **2.3.3 (275)**. Falta instalarlo,
  crear un contacto real y leer la señal interna antes de volver a consultar
  GA4.
- Android 275 instalado y recorrido por el titular: Analítica permaneció
  encendida, el contacto real con Nina creó/abrió la conversación y la señal
  interna mostró **Firebase aceptó contact_started**. Queda comprobado que el
  controlador consentido llamó al SDK sin payload y éste terminó sin error. La
  consulta inmediata de GA4 Realtime mostró actividad vigente y 49 nombres de
  eventos mezclados con telemetría antigua de FlutterFlow, pero no presentó el
  nuevo evento entre los resultados visibles consultados. La recepción
  procesada por GA4 permanece pendiente; no se repetirá otro cambio de código
  sin evidencia de rechazo.
- Se fijó el candidato Android 275 con el tag `codex-h10-android-275` y se lanzó
  iOS desde el mismo SHA `f1c0f7b63042122156536d626d5930cf296cc272`.
  [Codemagic `6abc16a31bed101ce54ac895`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc16a31bed101ce54ac895)
  aprobó configuración, análisis, 97 pruebas, firma, IPA, Publishing y limpieza.
  Apple aceptó **2.3.3 (276)** con `UPLOAD SUCCEEDED with no errors`. Falta
  confirmar procesamiento/disponibilidad e instalarlo desde TestFlight; App
  Store Connect solicitó una nueva sesión al intentar consultarlo.
- Supabase test, por consulta agregada: 17 cuentas, identidades `email: 16` y
  `google: 3`, una aceptación legal vigente completa, tres eliminaciones
  `completado`, ninguna pendiente y cero credenciales Apple. Google/gate legal y
  eliminación cuentan con evidencia real Android; Apple nativo, Private Relay
  y revocación continúan pendientes de la identidad desechable en iPhone.
- Renovada la sesión, App Store Connect confirmó la carga iOS 276 como
  **Finalizado** y el build como **En pruebas** dentro de `DopMi Inner Team`.
  Registraba tres invitaciones y cero instalaciones. El candidato conjunto ya
  está disponible en ambas tiendas internas; falta instalación y aceptación en
  iPhone, en particular Google, Apple nativo/Private Relay y revocación.
- iOS/iPadOS 276 instalado desde TestFlight. Google y Apple cancelados
  regresaron limpiamente. Apple nativo con Ocultar mi correo exigió el gate de
  18 años/términos y conservó sesión tras reinicio. Resend marcó `delivered` y
  el titular confirmó en su buzón la recuperación reenviada por Private Relay.
  La eliminación posterior terminó HTTP 200: Apple aceptó la revocación; el
  estado quedó `completado`, perfil `deleted`, sin atención pendiente, y las
  consultas posteriores mostraron cero usuario Auth, identidad, sesión y
  credencial Apple. No se documentaron alias, UUID, tokens ni IP. La adaptación
  visual específica de iPad queda como diferencia no bloqueante de H10.
- Google nativo en iPad falló primero con HTTP 400 por la comprobación de nonce.
  Se activó `Skip nonce check` sólo para Google en Supabase test, como exige la
  guía Flutter iOS; el mismo build entró después con HTTP 200, reutilizó el
  perfil existente y conservó sesión tras reinicio. Auth advirtió que futuras
  versiones exigirán también el access token. El cliente queda reforzado para
  obtenerlo y enviarlo en acceso, vinculación y reautenticación; prueba unitaria
  comprueba ambos tokens. Requiere gate y candidato nuevo.
- Candidato final de la corrección Google fijado en el tag
  `codex-h10-final-277`, SHA
  `7e0a4b09ece6833c74afa44e2eb30e0651a6cff6`. La compuerta integrada
  [36632568776](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36632568776)
  aprobó sus cuatro trabajos. [Android Codemagic
  `6abc2e07bb271484cec0e088`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc2e07bb271484cec0e088)
  publicó **2.3.3 (277)** a Play `internal`; publicación y consulta posterior
  marcaron `completed`. [iOS Codemagic
  `6abc2e104ec1ec8d686c0180`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc2e104ec1ec8d686c0180)
  cargó **2.3.3 (278)** a App Store Connect con `UPLOAD SUCCEEDED with no
  errors`. Ambos usan el mismo SHA. Falta procesamiento/instalación de iOS 278,
  instalación Android 277 y repetir Google con persistencia; Apple 276 conserva
  su evidencia porque este cambio no alteró su token.
- El titular instaló Android 277 e iOS/iPadOS 278 y confirmó en ambos Google
  exitoso y sesión persistente tras reiniciar Dopmi. Supabase test registró dos
  accesos Google HTTP 200 con `grant_type=id_token`; desapareció la advertencia
  anterior por `access_token` ausente. Un ID token no traía `at_hash` y Auth
  informó que el access token enviado no se utilizó en ese caso, sin error de
  sesión. La corrección Google del candidato conjunto queda aceptada. El
  titular confirmó que la vinculación conserva el mismo perfil. Apple queda
  disponible únicamente en iOS/iPadOS por decisión de producto; Android usa
  Google/correo y no mostrará Apple web. H10.1 queda aceptado.
- Auditoría de H10.2 añadió casos de cuenta vacía, aislamiento entre titulares,
  aportación pendiente y cancelación Guardián pendiente. Las operaciones
  financieras mantienen la cuenta bloqueada en `requiere_atencion` hasta su
  conciliación; el reintento finaliza después sin crear ni repetir movimientos.
  También se corrigió el reintento parcial: si PostgreSQL ya marcó la solicitud
  `completado` pero Auth no pudo retirar al usuario, el siguiente intento vuelve
  a cerrar sesiones globales y borrar Auth. `anon` y `authenticated` no pueden
  ejecutar la RPC servidor; sólo `service_role`. Las **405 pruebas backend** y
  las **12 comprobaciones de configuración móvil** aprobaron en el commit
  `21e2132e21ec0c9381107ead4c3c14f3e7b5c898`. La función
  `account-deletion` **v4** quedó activa con JWT obligatorio únicamente en
  Supabase test. La compuerta integrada
  [36637906708](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36637906708)
  aprobó sus cuatro trabajos: identidad/adopción, Flutter/Android,
  web/PostgreSQL e iOS simulator. H10.2 queda cerrado con la eliminación real
  previa en Android y Apple, más los escenarios automatizados de reintento,
  operación pendiente y aislamiento.
- H10.3: el reporte procesado de Firebase/GA4 hasta el 29/9 confirmó **3 eventos
  `contact_started` de 2 usuarios**. La recepción real de Analytics queda
  acreditada sin payloads; la interfaz sólo admite los cinco nombres permitidos
  y rechaza cualquier parámetro. La auditoría añadió los errores asíncronos de
  `PlatformDispatcher` a Crashlytics únicamente durante consentimiento, con
  restauración inmediata del manejador al apagar, salir o cambiar de cuenta.
  `flutter analyze` quedó limpio, aprobaron 99 pruebas Flutter, 405 backend y
  12 controles de configuración. CI
  [36639760146](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36639760146)
  aprobó los cuatro trabajos del SHA
  `d57aea8aef3fad2687b177d2f5ed3634c6672849`. Android Codemagic
  [`6abc3da85177262fd0fa5730`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc3da85177262fd0fa5730)
  publicó **2.3.3 (279)** en Internal Testing desde ese SHA; análisis, 99
  pruebas, firma, AAB y Publishing aprobaron. iOS Codemagic
  [`6abc3da82b57438d992a0231`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc3da82b57438d992a0231)
  generó, firmó y publicó **2.3.3 (280)**; análisis, 99 pruebas, IPA, Publishing
  y limpieza aprobaron sobre el mismo SHA. Google Play confirmó por separado
  que el bundle **279** está disponible para testers internos y que 277 quedó
  desactivado. App Store Connect terminó de procesar **280**, lo incorporó a
  `DopMi Inner Team` y lo muestra **En pruebas** para tres testers internos.
  Android 279 quedó instalado. Con Analítica y Diagnóstico apagados, un contacto
  real mostró que `contact_started` fue omitido antes del SDK y la acción interna
  de diagnóstico no apareció. La consulta posterior de GA4, ampliada hasta el
  29/9, permaneció en **3 eventos de 2 usuarios**, sin incremento respecto de la
  línea base. Las pruebas también acreditan borrado de reportes no enviados al
  retirar, activar o cambiar de cuenta. H10.3 queda cerrado con consentimientos
  independientes, apagados por defecto, recepción consentida y retirada real.
- H10.4, auditoría de tiendas: la web pública añadió
  `https://dopmi.org/support` y corrigió la ruta de eliminación dentro de la app
  en el commit `bf8cd76` de `dopmi-landing-mockup`; ambas páginas responden 200
  con el contenido nuevo. Google Play aún conserva una declaración Data Safety
  de 2023 y Apple App Privacy siete tipos con usos antiguos, incluida publicidad
  para correo, además de URLs obsoletas. Se preparó la matriz definitiva en
  `docs/h10-store-privacy-declarations.md` y un CSV de Google para vista previa.
  No se declara publicado: la importación/guardado externo requiere confirmación
  del titular. App Store exige una versión nueva para cambiar URLs de
  privacidad, soporte y marketing; los tipos de datos sí pueden corregirse de
  inmediato.
- El Centro de ayuda móvil añadió contacto operativo con
  `soporte@dopmi.org`, advertencia contra el envío de credenciales/datos de
  tarjeta y alternativa visible si el dispositivo no abre el cliente de correo.
  `flutter analyze`, las 99 pruebas Flutter y los 12 controles de configuración
  aprobaron. La revisión contra las definiciones oficiales de Google retiró del
  CSV la compartición por proveedores/acciones iniciadas por el usuario y los
  datos de tarjeta que Stripe Checkout recibe directamente; quedan 15 tipos,
  cero publicidad/personalización y cero compartición declarada.
- App Store App Privacy quedó publicada con 15 tipos, sin seguimiento y sin
  publicidad/marketing. Nombre, correo, teléfono, dirección, ubicación
  aproximada, mensajes, fotos, otro contenido, identificadores, compras,
  interacción y diagnósticos se vinculan con la cuenta o instalación según la
  definición de Apple. Se creó la ficha 2.3.3 **En preparación para el envío**,
  con publicación manual, sin compilación y sin añadirla a revisión. En esa
  versión se guardaron privacidad `/privacy-policy`, opciones de privacidad
  `/delete-account`, soporte `/support` y marketing `/`; no implica lanzamiento
  público. En Google Play se habilitó el acceso local de la extensión, se importó
  el CSV y la vista previa confirmó 15 tipos recopilados, ninguno compartido,
  cifrado en tránsito y las URLs vigentes de privacidad y eliminación. El
  titular confirmó el guardado y Play Console respondió `Change saved`. En
  Publishing overview figura exactamente un cambio no enviado: `Data safety —
  Complete Data safety questionnaire`. Con autorización separada, se envió ese
  único cambio; las comprobaciones automáticas terminaron sin incidencias y
  Publishing overview muestra `Your changes are now in review`. El aviso de la
  URL histórica permanece visible mientras Google resuelve la revisión.
- El aviso de política de Google Play se inspeccionó por separado: identifica la
  URL histórica `https://dopmi.org/pages/privacy-policy` como inválida y exige
  guardar la corrección y enviarla a revisión. La pantalla vigente de Política
  de privacidad ya muestra `https://dopmi.org/privacy-policy`; el botón Guardar
  está deshabilitado allí porque esa corrección ya quedó registrada. El aviso no
  se declarará resuelto hasta que Google procese el envío.
- Decisión del titular: H10.4 se cierra con la declaración Data Safety enviada a
  revisión y App Privacy ya publicada. Apple no permite enviar la ficha 2.3.3 a
  revisión sin seleccionar una compilación; ese envío se aplaza hasta terminar
  los demás pendientes y disponer del candidato final. También se reconsultará
  entonces la resolución del aviso histórico de Google. Las URLs y textos ya
  guardados se conservan; no se inició lanzamiento público.

## H10.5 — aislamiento y candidato conjunto — 29 de septiembre de 2026

- Supabase test `ohqxranynackjignryep` y producción `ysaoeuidcvgtlmphmeyb`
  continúan separados y `ACTIVE_HEALTHY`. En producción se comprobaron cero
  usuarios Auth, perfiles, donaciones, objetos Storage, secretos Vault y secretos
  personalizados de Edge Functions. Los cuatro buckets existen vacíos y las
  siete funciones actuales están desplegadas, pero sin secretos Stripe no pueden
  procesar dinero real.
- La configuración Auth de producción se inspeccionó directamente: altas,
  vinculación manual y acceso anónimo están apagados; Google y Apple figuran
  deshabilitados. Test conserva sus proveedores de aceptación. No se modificó
  configuración remota durante esta auditoría.
- Los advisories de seguridad de ambos proyectos coinciden: 27 tablas privadas
  con RLS y sin políticas deliberadamente inaccesibles, 15 funciones
  `SECURITY DEFINER` ejecutables por `anon` y 68 por `authenticated`, ya
  cubiertas por los controles servidor/titular documentados. Test añade la
  advertencia de protección de contraseñas filtradas, diferida a H12 por requerir
  Supabase Pro. Referencias: [RLS sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
  [`anon` y SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)
  y [`authenticated` y SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- Puertas locales: configuración móvil **12/12**, administración **23/23** y
  build de producción, backend/PostgreSQL **405/405**. Flutter no está instalado
  en este equipo; análisis y pruebas aprobaron dentro de los dos workflows
  reproducibles de Codemagic.
- El SHA `0a25ba81fc39192c772ca0bbe4453697fb9ca905` produjo ambos candidatos.
  [Android Codemagic `6abc62eb0f583f5c4835b814`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc62eb0f583f5c4835b814)
  aprobó configuración, Firebase, análisis, pruebas, firma, AAB y Publishing;
  Google Play confirmó **2.3.3 (281)** disponible para testers internos y
  desactivó 279. [iOS Codemagic `6abc62ec0f583f5c4835b816`](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc62ec0f583f5c4835b816)
  aprobó configuración, Firebase, análisis, pruebas, firma, IPA y Publishing;
  App Store Connect confirmó **2.3.3 (282)** `Finalizado`, **En pruebas** y
  asignado a `DopMi Inner Team`.
- H10.5 queda cerrado por publicación interna trazable y aislamiento comprobado.
  La instalación/actualización de 281/282 y los recorridos integrales pertenecen
  a H11. La revisión pública de la versión Apple y la reconsulta del aviso
  histórico de Google continúan aplazadas hasta el candidato final.

## Inicio H11 — 29 de septiembre de 2026

- Se fijó la matriz de aceptación en `docs/h11-acceptance.md`. La referencia de
  Irlanda continúa sin cambios en `a246fa6f42ec517aae264d7fbd2358d647c4f840`;
  no hay una diferencia nueva que reabra H8.
- H11.1 queda acreditado por Android 281 e iOS 282, ambos desde
  `0a25ba81fc39192c772ca0bbe4453697fb9ca905` y disponibles en sus canales
  internos. La instalación/actualización y los recorridos del build exacto aún
  requieren los dispositivos del titular.
- Se documentó una reversión de distribución segura: Android usa un rebuild del
  último SHA bueno con número mayor; TestFlight retira el build del grupo y
  reasigna o recompila con número mayor. El ensayo no altera 281/282, datos,
  migraciones ni movimientos financieros. Falta ejecutar el ensayo de
  comprobación y registrar revisión externa/cero defectos críticos o altos.
- El ensayo de reversión terminó `ROLLBACK_REHEARSAL_OK`: Git puede reconstruir
  `d57aea8aef3fad2687b177d2f5ed3634c6672849`; frente al candidato, el único
  cambio de app es el acceso por correo del Centro de ayuda. Ese SHA conserva
  workflows internos, identidad `com.mycompany.dopmi` y ausencia de envío a
  App Store. No se retiró ningún build ni se publicó otro porque no existe un
  defecto que amerite una reversión real. H11.4 queda cerrado.
- El titular aportó la captura `1000346499.jpg`: Android abre Configuración y
  muestra **Versión 2.3.3 (281)**. Queda acreditada la instalación del candidato
  Android exacto. Aún faltan los recorridos funcionales del build y la
  instalación de iOS/iPadOS 282; no se atribuye aceptación por la captura sola.
- En Android 281, cerrar completamente y volver a abrir Dopmi conservó la sesión
  sin pedir acceso ni repetir términos. Persistencia aprobada; el cierre de
  sesión y reingreso se verifican por separado.
- El titular aportó captura de iPadOS: Dopmi abierto desde TestFlight muestra
  **Versión 2.3.3 (282)** en Configuración. Android 281 e iPadOS 282 quedan
  instalados y corresponden al mismo SHA; la captura horizontal acredita que
  las acciones principales son visibles, no todavía los recorridos funcionales.
- Android 281 completó el recorrido de identidad: cerrar sesión regresó al
  acceso, cancelar Google no creó sesión y un segundo intento entró con la misma
  cuenta/perfil sin volver a pedir términos. Persistencia, cierre, cancelación y
  reingreso Google quedan aprobados para el candidato exacto.
- iPadOS 282 conservó la sesión después de cerrar completamente y volver a abrir
  Dopmi, sin pedir acceso ni repetir términos. Persistencia aprobada; cierre de
  sesión y accesos Google/Apple permanecen como pruebas separadas.
- iPadOS 282 completó Apple nativo con una identidad nueva. Apple ofreció
  compartir u ocultar el correo; el titular eligió Ocultar mi correo y Dopmi
  exigió 18 años/términos antes de permitir acceso. Cerrar sesión retiró el
  acceso; cancelar Apple no creó sesión; repetirlo entró correctamente y la
  sesión persistió tras reiniciar. No se registró el alias privado. La creación
  separada, con gate legal, confirma que no hubo fusión silenciosa por correo.
- Google en iPadOS 282 también aprobó: cancelar dejó la app sin sesión; el nuevo
  intento regresó al perfil Google existente sin repetir términos y la sesión
  persistió al reiniciar. Identidad social queda aprobada en Android 281 e
  iPadOS 282; Apple permanece exclusivo de iOS/iPadOS.
- En ambos candidatos, el titular recorrió Adoptar, Apoyar, Perfil,
  Configuración e Información básica sin pantalla negra, bloqueo ni pérdida de
  sesión. Ayuda/FAQ y el botón de soporte funcionaron sin enviar correo; los
  términos y la pantalla de privacidad/eliminación abrieron y regresaron
  correctamente. No se inició eliminación.
- Android 281 e iPadOS 282 aprobaron catálogo y comunicación: filtro
  aplicar/limpiar, detalle, guardado/retirada, contacto, envío, reapertura y
  cierre. El texto sintético `Prueba H11` persistió una sola vez al reabrir; no
  hubo duplicado visible.
- Publicar → Adopción aprobó el recorrido físico en ambos candidatos: foto no
  personal, nombre sintético, salida/reinicio y recuperación del borrador sin
  enviarlo. Android manejó rechazo inicial y concesión posterior del permiso;
  iPadOS funcionó con acceso limitado a fotos.
- Ambos candidatos aprobaron el smoke financiero sin movimientos nuevos:
  Aportar hasta monto/resumen y regreso previo a Checkout; Método de pago,
  Suscripción e Historial sin pantalla negra. No se cambió tarjeta, activó o
  canceló un plan ni se generó un pago. Se reutiliza la evidencia económica H5,
  pues el candidato sólo añadió el acceso de soporte y no cambió esos módulos.
- Consentimientos aprobados en ambos candidatos: Analítica y Diagnóstico
  persistieron al activarse, se retiraron por separado y permanecieron apagados
  tras reiniciar. No se envió diagnóstico controlado nuevo; la recepción y cero
  emisión posterior ya están acreditadas en H10.3 sobre el mismo código.
- H11 detectó un fallo intermitente y multiplataforma al cargar fotos privadas
  del catálogo: Android 281 e iPadOS 282 podían mostrar `Cargar foto`. El cliente
  generaba URLs firmadas por sólo 60 segundos, insuficientes tras suspensión o
  carga diferida. La corrección mantiene el bucket privado, amplía la URL a diez
  minutos y renueva una sola vez automáticamente antes de dejar el control de
  reintento manual. Se añadió una prueba que acota la vigencia entre cinco y
  diez minutos. Quedan pendientes CI, candidatos conjuntos nuevos y repetición
  del catálogo en ambos dispositivos; 281/282 ya no son finales.
- Corrección de fotos publicada desde
  `94cb82e2496e4943065d6464962a111fa719bedd`. GitHub CI
  [36660362119](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36660362119)
  y [36660356662](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36660356662)
  aprobaron los cuatro trabajos, incluido análisis, pruebas Flutter y builds de
  desarrollo Android/iOS. Codemagic Android
  [6abc771aec8422516e05ee18](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc771aec8422516e05ee18)
  publicó **2.3.3 (283)**; Play confirmó `Available to internal testers`, bundle
  283 activo y 281 desactivado. Codemagic iOS
  [6abc7724e5d014fada0172c5](https://codemagic.io/app/6ab062cf7e534c19e9884a3b/build/6abc7724e5d014fada0172c5)
  publicó **2.3.3 (284)**; App Store Connect confirmó `Finalizado`, `En pruebas`
  y `DopMi Inner Team`. Falta instalar 283/284 y repetir carga/reintento de fotos
  en ambos dispositivos antes de cerrar el defecto y H11.
- Nuevo defecto H11 reproducido en código: una sesión con consentimiento vigente
  podía mostrar `Antes de continuar` durante el intervalo entre Auth restaurado
  y perfil cargado. El gate ahora distingue la consulta en curso y muestra
  `Restaurando sesión`; si la consulta falla continúa bloqueando con el aviso,
  por lo que no se debilita la protección de mayoría de edad. Se agregó una
  prueba con carga deliberadamente demorada que prohíbe el destello. Por decisión
  del titular, esta corrección se agrupa con los siguientes cambios y el QA
  físico/visual final de Irlanda; no se pide otro recorrido manual completo.
- Android 283 quedó instalado desde Play Internal Testing y verificado por ADB
  en un Samsung SM-S938B con Android 16. Conservó la sesión durante la
  actualización, mostró `Versión 2.3.3 (283)` y cargó la foto del catálogo tras
  suspensión superior a 60 segundos. Una apertura en frío sin Wi-Fi ni datos
  cerró de forma segura; tras restaurar la red, dos pulsaciones de reintento
  recuperaron la misma sesión y la foto sin duplicados. La ausencia de
  recuperación automática y la aparición temporal del consentimiento vigente
  quedan como fricción media, no como pérdida de identidad. Texto ampliado
  1.30, etiquetas semánticas y orientación horizontal conservaron las acciones
  esenciales; se restauraron los ajustes del dispositivo. Falta TalkBack,
  correo/retorno, iOS 284 y revisión visual externa para cerrar H11.2/H11.3.
- TalkBack de Samsung se activó temporalmente sobre Android 283, conservando el
  servicio de accesibilidad existente. El lector recorrió por foco controles
  etiquetados y activó una ruta Guardián identificada como prueba; después se
  restauró exactamente la configuración previa. Un callback inválido
  controlado abrió el estado recuperable y el regreso conservó la sesión, sin
  acreditar entrega desde correo.
- Decisión del titular, 30/9: concluir H11 con toda la evidencia autónoma
  disponible en Android y trasladar a H12 la entrega real de correo, regresión
  iOS del candidato final y revisión visual de Irlanda. No quedan defectos
  críticos/altos en lo ejecutado; la recuperación de red que requiere reintento
  permanece como fricción media. H12 será el último hito previo al MVP e inicia
  con un candidato conjunto que integre el parche de consentimiento y los
  cambios finales de Irlanda. Este avance no acepta visual/iOS pendientes, no
  publica las tiendas y no autoriza dinero real.


Continuidad360–361, 2/10/2026: recuperación de cambios de tarjeta muestra «Continuar actualización» si sólo conoce la solicitud del servidor; no adivina tarjeta ni promete Checkout.35pruebas dirigidas aprobadas7s y analyze limpio31.9s sobre cambios4ad75e4. Full504/5043:45 sobre0c4dbee precede360;210archivos probados coincidentes. Referencia Irlanda a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada360.

Fixture Stripe361c real cero, servicio Guardian de producción con adaptador de checkpoints local explícito: Mastercard predeterminada confirmada, calendario idéntico, respuesta aceptada perdida y recuperada sin segunda actualización (calls1), cargos/PaymentIntents0, limpieza verificada. No equivale a Auth/SQL/worker integrado ni revisión instalada. Commit0e487e3; primerfixture361 rechazópause_collection encreate y quedólimpio, corregido preparando pausa enupdate. Eliminar/alta independiente/billeteras y matrizglobal/aceptación siguen pendientes. Sin Codemagic/push; único candidato final según titular. Objetivo activo.


Loop362, servidor local20db360: eliminación de tarjeta no activa comparte trabajo/owner/revisión/lease/expiración/idempotencia de Guardian, consulta usos en Stripe y conserva default/calendario. Recupera detach aceptado con respuesta perdida sin segunda escritura; cancelar anteswrite bloquea detach.475/475 backend22.44s y Deno3entrypoints limpio. PreflightDEV confirmó migration51924 y columna remove_saved ausente; no deploy/Stripe realremove/UI/CM/push. Siguiente: comparar/aplicar migración y overlays de tres consumidores, conectartrash/confirmación/retry/200% yfixturezero. Progreso técnico, no cierre de paridad. Registro detallado en parity-loops.md.


Loops363–364, 3/10/2026: eliminación disponible en DEV(guardian-client17/payment-worker24/stripe-webhook24), migraciónlocal60000/remota55326; overlays0dif y18smoke5.61s. Cliente8b7798a conecta SVGtrash Source, confirmación blanca/roja, intención duradera y recuperación incluso sin targetlocal.42dirigidas9s/analyze31.5s,HTTP4extra válido y4capturas3s inspeccionadas,314/37 inventario. Card sólo desaparece tras estado/lista propietario fresco; in_use no acusa éxito. Hallazgo200%overflow corregido; coloresMaterial corregidos tras captura. NoStripe réelremove/Authintegración/teléfono niCM/push acreditados. Próximo: fixtureStripezero de detach/perdidarespuesta, toastSource2600ms, altaindependiente/billeteras ymatrizglobal. Preservarobjetivo completo.


Loops365–366, 3/10/2026: Stripe test detach real una sola llamada con respuesta perdida, default/calendario intactos y limpieza comprobada (b2706d1); checkpoints locales, no integración Auth/SQL atribuida. Feedback Source inmediato2600ms sólo tras lista confirmada, sin replay/histórico;44dirigidas8s/analyze limpio/capturas2nuevas,316/37 inventario. Véase parity-loop366. Full504 anterior requiere gate final. SinCodemagic/push: preferencia del titular candidato único al completar objetivo. Altaindependiente/billeteras/matrizglobal/aceptación siguen abiertas.


Loop367, 3/10/2026: base local de alta de tarjeta independiente (sin cobro/cambioGuardian) en migración70000 y saved-card.mjs.19casos nuevos SQLPGlite/servicio; gatebackend494/49426.50s handle62271exit0, Node/Deno limpios. PreflightDEVlatest55326/tablasnuevasausentes; NO migración/deploy/Stripe real/CM/push. Pendiente conectar cliente compartido con altaGuardian para evitar doblecustomer, lectura nonsuscritos, endpoint/runtime/webhook/worker y UI/aceptaciónreal. No es función completa aún ni cierre de objetivo. Referencia a3c969c sin cambios; detalle parity-loops367.


Loop368, 3/10/2026: integración LOCAL de alta independiente en endpoint/runtime/worker/webhook/reader nonsuscrito; migration71000 comparte/snapshotcustomer con nuevaaltaGuardian y bloquea dos altas simultáneas.503/503backend24.41s handle89380exit0 y Deno3entrypoints7.45s limpios. No migration70000/71000 ni EdgeDEV nuevos todavía; UI/capturas/fixtureAuthStripe y default/remove nonsuscrito/billeteras/matrizglobal pendientes. NoCM/push/goalcomplete. Siguiente preflight remoto/overlays; no interpretar gatelocal como publicación/aceptación instalada.


Loop369, 3/10/2026: alta independiente DEV aplicada una vez, local70000/71000→remote65211/65233. Worker25/webhook25/cliente18ACTIVE, overlays17/16/16archivos0dif yguards/ACL/RLS verificadas;21smokeremoto5.77s b935fbexit0. No Authmutación/StripeCheckoutreal/UI/device aceptados aún; sinflags/PROD/CM/push. Siguiente UIAgregar/retorno yfixtureAuthStripe; generaldefault/remove/billeteras/matrizglobal pendientes. Evidencia parity-loops369/migration-history-audit. Objetivoactivo.


Loop370, 3/10/2026: UIAgregar independiente (noactivar/cobrar/cambiardefault), key propia persistida/consentimiento y recuperación porowner; saved+cardlistaFresh anuncia y confirma, no historical/replay.58/58dirigidas11s40889exit0, analyze19.1s78738limpio,4capturas4s56682inspeccionadas normal200%,320/37. READMEparity-loop370 detalla límites. PR6MCPabiertodraft/refsunchanged; gh no disponible. Sin AuthCheckoutpositivo/Stripe real/device/CM/push ni objetivo completo. Siguen billeteras/composiciónauxiliar/default-remove sinGuardian/apoyopuntualsavedcard/matrizglobal; próximofixtureAuthStripe real.


### Loop371 — Auth y Checkout reales para Agregar tarjeta, 3/10/2026

Referencia remota a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Fixture desechable Auth confirmada en DEV y customer Stripe test, sin cuenta humana: login real, consent/allowlist inválidos400, RPC privado403/42501, lista vacía antes de alta, mismo key devuelve la misma sesión pendiente. Checkout hosted completado por UI con Visa sintética4242; SetupIntent succeeded/off_session, sesión setup/test sin payment_intent ni subscription. Endpoint real devuelve saved/card_id y ownstate coincide; methods una tarjeta4242, defaultfalse y siete campos minimizados. Replay saved idéntico. Gate acceptance verify exit0/b2c4f0 5.46s; charges/PaymentIntents/invoices/subscriptions0.

Chrome volvió a payment-return pero mostró ERR_BLOCKED_BY_CLIENT; PNG checkout-return-blocked conserva evidencia. GET independiente200/textplain/no-store y CSP sandbox no demuestra retorno visible correcto ni identifica la causa. No se desactivaron protecciones/extensiones. Corregir/investigar retorno antes de cerrar recorrido; alta server integrada probada, no aceptación instalada.

Limpieza Stripe verificada deletedtrue (cleanup exit0/869d9f), SQL propia protegida por UUID/email/job/key y ausencia de filas financieras: Auth/identidades/sesiones/refresh_tokens/jobs/wallet0. Profiles no cascada desde auth.users: se observó1 y eliminó explícitamente sólo UUID fixture; comprobación final0. Journal externo limpio, contraseña retirada; ningún secreto/captura con tarjeta real comprometido. No producción/flags/cobros/CM/push. Objetivo completo sigue pendiente: retorno, default/remove sin Guardian, billeteras, apoyos con tarjetas y matriz/aceptación global.


### Loop372 — diagnóstico de representación y retorno de tarjetas, 3/10/2026

Previo371 progreso e38a59c: Auth+Checkout Stripe test confirmado y fixture limpio. Referencia a3c969c reconsultada sin cambios. Reproducción local en Chrome controlado: text/plain CSPdefaultnone+sandbox bloqueado; mismo texto con sandbox allow-same-origin bloqueado; mismo texto sólo defaultnone también bloqueado. HTML con sandbox/defaultnone abre y muestra contenido. Esto contradice atribuir el fallo exclusivamente a sandbox; apunta a manejo de MIME en este entorno, sin identificar extensión/causa exacta ni demostrar defecto en Android. No se desactivaron protecciones, no se cambió CSP y no se afirmó retorno instalado aceptado. Tres servidores locales terminados por sus handles29963/35069/44564.

Retorno agrega instrucciones reales Perfil > Métodos de pago, consultar el mismo intento y guardar sin cobro/activar Guardian. Supabase dominio estándar continúa text/plain, sin HTML/deep-link inventado ni confiar en parámetros. Deno check exit0/dbdf48 3.06s. Preflightpayment-return9ACTIVE únicoarchivo coincidefuente; deploy sólo éste en DEV a10ACTIVE, verify_jwtfalse previo conservado, cuerpo posterior coincide CRLFnormalizado. HTTPsmoke21/21 exit0/a9ab24 5.82s incluyendo copia nueva/CSP/no-store/nosniff. No schema/flags/Stripewrite/PROD/CM/push. Loop371 confirmaalta servidor, retorno visible en browsercontrolado queda limitado; aceptación teléfono y resto objetivo pendientes.


### Loop373 — actualización por gesto en Métodos de pago, 3/10/2026

Previo372 progresof654bbf: retorno10DEV y diagnósticoMIME. Referencia remota a3c969cd9103fd46dc5cd886999912526ce75efb sin cambios. Métodos agrega RefreshIndicator negro/blanco sobre listaAlwaysScrollable: permite consultar el estado propio deslizando incluso lista corta/vacía, bloquea lectura desde gesto mientras busy/confirming o identidad obsoleta. Reusa load existente, no crea Checkout/consent/key ni anuncia éxito optimista. Composición en reposo, confirmaciones y feedback permanecen; botónActualizar y enlaceGuardian extrasSource aún pendientes junto billeteras, default/remove sinGuardian y uso tarjeta en apoyo puntual. Es adaptación de actualización al teléfono, no prueba de un gestoidéntico del mockup web.

Primer comando fue lanzado desde scratch con rutas relativas de repo incorrectas: format/copy fallaron, test viejo detenidohandle93736 y no computado. Sincronizados los dos archivos propios, test50 primero49pass/1fail porque drag400 bajo viewport artificial2400 no alcanzaba umbral;900 pasó50/50 10s handle96816/exit0. Prueba final usa390x852/drag400 y comprueba una lectura adicional, calls0/opened0/emptyreal; focused1/1 1s handle48447/exit0. Analyze limpio41.4s61658/exit0 sobre mismo códigoapp. No captura visual nueva/aceptacióndevice/fullnuevo, suite504/359 antecede373. Sin backend/schema/flags/Stripe/CM/push. Goal completo sigue abierto.


### Loop374 — composición de tarjetas contra Source, 3/10/2026

Previo373 progreso45de3ab. Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada; CSS content-pad20/16/32 y list-stackgap10, PaymentMethods sin enlaceGuardianextra. Cliente ajusta heading/filas/Agregar a10 y paddinginferior32; elimina enlace secundario Guardian sólo en Métodos, acceso real Perfil > Suscripción y pagos conservado. Actualizar estado aún extraSource; billeteras/default-remove sinGuardian/apoyo cardguardada pendientes, no pantalla completa declarada.

50/50guardian10s handle18944/exit0 despuésespacios antesquitarenlace. Capturador final filtro payment-methods-cards exit0/80981 6s; normal377x852 y320/text200% guardadasparity-loop374 y ambas inspeccionadas. Lista realwidget condatos sintéticos, íconos/acciones/consent/feedbackcapturados por filtro sinoverflow; no teléfono. Capturas muestran billeteras faltantes y Actualizar extra, no ocultar brechas. Analyze final limpio25.9s handle47417/exit0. Sin backend/flags/dinero/CM/push. Continúa objetivo completo.


### Loop375 — base de acciones independientes de tarjeta, 3/10/2026

Previo374 progreso030bb70. Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. Nuevo saved-card-method.mjs local: jobserverpropio/claimlease/snapshot/writeauthorization/prooffresh/release, rechaza subscription_id para conservar flujoGuardian. Default actualiza sólo customer.invoice_settings.default_payment_method; remove desvincula únicamente cardtestpropia sin uso/default. Suscripciones activas bloquean default; facturasdraft/open y PaymentIntentsen curso bloqueanuso, factura con método heredado aún no resuelto bloquea eliminación. Listadospaginados/incoherentes fallan cerrado; live/foreign/noncard rechazan. No crea ni paga facturas/PaymentIntent/subscriptions ni Checkout. Key estable porjob; trasrespuesta aceptada perdida consulta propiedad/default/detach y no repite write.

13tests nuevas adaptadorcheckpoint yStripefake: exactmutation, lostresponse/replay, owned/live/noncard, cancelanteswrite/expired, uso/sub/invoice/PI, incompletepage y rechazoGuardian. Primer12/12 dirigido6058bc antesguardinvoiceheredada; fullfinal516/51627.23s3050/exit0 incluye13 y todasmigracionesSQL previas. Deno check móduloexit0/22e0f1, no entrypointruntime nuevo porque aún no importado.

Esta base NO está conectada/desplegada y no acredita acciones de cuentas sinGuardian enapp. Siguiente contratoPostgreSQL con registryowner/confirmed/RLS/ACL/sharedlock ambasdirecciones/intentstable/lease/expiry23h, endpoint allowlist/minimizedstate yreaderfresh, workerreconcile/UI/capturas/AuthStripeacceptance. Nada de dinero real/flags/migración/PROD/CM/push. Móvil full504/359 continúa anterior; objetivo global abierto.


### Loop376 — reservas privadas SQL para acciones sin Guardián, 3/10/2026

Previo375 progreso7696c1d. Referencia a3c969cd9103fd46dc5cd886999912526ce75efb sin cambios. Migración local20261003080000_saved_card_methods nueva: registrycustomer derivado delpropietario, jobsprivados RLS/ACL, key/action/targetimmutable y replay; consentexplicit versionada, owneractivo/emailconfirmada, no cliente browser. CualquierregistryGuardian usa flujoGuardian existente; altas/activacionespendientes bloquean reserva. Locksdopmi-saved-card compartidos y guards añadidos enambossentidos: savedsetup/activación no avanzan sobre methodpending/attention. Rate10/h, lease2min, snapshotanteswrite, autorizaciónjustoantesmutación, comprobaciónde cuenta nuevamente, targetproofexacto para applied/removed. Expiraciónsinwrite y ventana23h despuéswrite→attention, no repetir mutación incierta. Stateauthowner minimizado key/action/status/card_id, sincustomer/session/secret.

Seis testsSQL nuevos: key/targetreplay/browserdenial/otherstaffstate; lease/snapshot/proof; expired/attention23h; methodbloquea setup/activation; reverseguards; confirmaciónrevocadaanteswrite. Toda migración cargada enPGlite. Primer comando ruta incorrecta no contó; filtroNode provocó PGliteclosed enbootstrap y no se usa como gate. Ejecucióncompleta425 primero424pass/1fail por helpersavedCardCall inexistente, corregido a savedCardRpc/activationPrepare. Gate520/52022.39s86352 con4casos; final522/52222.95s19548/exit0 incluyeseis nuevos. gitdiffcheck limpio. No stackDocker/pgTAPnuevo ni aceptaciónremote.

NO aplicada remotamente/endpoint/worker/UI conectado. ServicioStripe375 tiene checkpointadapterfake; SQL376 aún necesita integrarse con servicio y pruebasrespuestaperdida desde RPCreal local, luego preflightdefinicionesremotas/deployautorizado/cliente y fixtureAuthStripe. No migración repair/replay/PROD/flags/CM/push/dinero. Objetivo global sigue abierto, dinero test-only.


### Loop377 — integración SQL/Stripe/endpoint de acciones independientes, 3/10/2026

Previo376 progreso89c9e0e. Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. savedCardMethodService.submit preparaSQL owner/key/consent/action/target y run; devuelve sólo key/action/status/card_id, sincustomer/lease. Reconcile usa candidatesRPC25 y contabilizaapplied/removed/fail. Runtime importa módulo y RPC privado con erroresprepare409tipados; worker invoca sólo bajo flagchangesexistente y cuenta saved_methods_applied. Guardian-client añade acciones saved_card_default/remove, allowlistexactasinrevision/owner/customer, Authconfirmada y nueva consentversion; flujoGuardianaceptado conserva susacciones/revisión/consent. Entrycliente usa mismafunciónruntime testkey/API/flags.

Dos pruebas nuevas integran servicio con RPCPostgreSQL/PGlite real y Stripefake: default/remove aceptados conrespuesta perdida, pendingpersistido, lease liberada, recuperarporlectura y replay sin segunda escritura. ConfirmaciónSQLexacttarget y receiptminimizado; customerbalance0 y cero filasdonación/activación. Otrasdos HTTP cubren allowlist/consent/card/op y cuenta no confirmada sinwrite. Full526/52626.00s75727/exit0; Deno tres entrypoints limpio6.39s192b57 despuésmaperrorprepare. No aceptaciónStripe/Authreal deestasacciones, ni UI nueva.

Migraciónlocal80000 y overlays aún NO desplegados. Próximo preflightfuncionesdefiniciones/historialremoto y aplicar80000una vez, preservarbundlesremotos/flags y verificarRPC/Edge, después accionesmóvil nonsuscrito/default/remove/capturas/fixtureAuthStripe. Sin schema/flags/cuentas/Stripewrite/PROD/CM/push; dinero test-only y objetivo global conservado.


### Loop378 — acciones independientes desplegadas en DEV, 3/10/2026

Previo377 progreso3ffc721 (backend526/52626s/Deno3entrypoints6.39s). Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. PreflightDEVohqxranynackjignryep latest20261003065233/tablemethodausente, fragmentossetup/activationpresentes. Bundlesworker25/webhook25/client18 recuperados, archivosareemplazar coincidenbase89c9e0e normalizandoCRLF. Migraciónlocal20261003080000_saved_card_methods aplicadauna vez como remote20261003075406/saved_card_methods. Post RLStrue/serveranon-authfalse/service_roletrue/stateauthtrue/anonfalse/guardssetupactivationtrue. No repair/replay/rename/dbpush/PROD.

Overlay mínimo yordenworker→webhook→client: worker25→26 runtime reemplazado+saved-card-method nuevo/16otrosconservados/18archivos; webhook25→26 mismo/15otrosconservados/17; client18→19 runtime+handler+indexreemplazados/módulonuevo/13otrosconservados/17. TodosACTIVE verify_jwtfalse previo conservado, autenticacióngetUser/worker-secret/firmadewebhook sigue enentrypointspreservados. GetEdge posterior18/17/17 coincideoverlay0mismatches/0extras. No publicarotroscambiosajenos.

Smokeampliado dosRPC nuevos23/23real7.84s41ac01/exit0: cliente401/worker401/webhook400sinfirma,return200 yserver/stateanónimos401/42501 explícito. No RPCmissing. No Authpositivo/Stripewrite/reconcilepositivo/device acreditados. No flags/cuentas/dinero/CM/push/goalcomplete. Siguecableadoclientepropietario/consent/key/retry/listaconfirmada/accionesnonsuscrito/capturas/fixtureAuthStripe y restoobjetivoglobal.


### Loop379 — repositorio móvil de acciones sin Guardián, 3/10/2026

Previo378 progresoaa9531d; servidorDEV RPC75406/client19/worker26/webhook26. Fuentea3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. GuardianRepository.savedCardMethodState consulta ownerRPC sin identificadorbrowser; receipt exigeUUID/actiondefault-remove/statuscompatible/pmopaque y conserva sólo key/action/status/card_id. submit saved_card_method usa accionesendpointnuevas/key/target/consentversion exacta, sinrevision/owner/customer; response200 ykey/action/cardmatching requeridos, no éxitooptimista. RutasGuardianprevias sincambios.

Trespruebas nuevas HTTPdefault/remove y validaciónreceipt: AuthBearer, bodyallowlist, misma keyreplay, camposprivados descartados y RPCowner sinparams (JSONnull). Primer9test7pass/2fail por MockResponse sinrequestrequiredPostgrest, corregido; luego2expectations{}erróneas para RPCsinparams corregidas a null. Gatefinal59/59(9HTTP+50Guardian)21s96565/exit0, analyze limpio40.3s47892/exit0; scratch dosarchivos propios sincronizados. No fixtureAuthrealnuevo/captura/device/globalfullnuevo.

Esta capa NO habilita todavía botonesnonsuscrito: siguiente loopstateowner/keypersistida/consent/confirmaciones/retry y lista fresh antesfeedback/pérdida de fila. Billeteras, apoyo puntual con tarjeta y matrizglobal siguenpendientes. Sin backend/schema/flags/dinero/CM/push; objetivoactivo.


### Loop380 — acciones reales de tarjetas sin Guardián en el cliente, 3/10/2026

Previo df7c276. Referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada al cierre sin cambios. Ruta Métodos de pago sin registro Guardian habilita predeterminar/eliminar tarjeta no predeterminada mediante endpoint existente de loop378. Consentimiento explícito, UUID y destino conservados por propietario antes de enviar; mismo intento en reintento, recuperación del receipt propietario pendiente y bloqueo de nueva escritura si no se puede consultar el estado. Nunca elimina la fila ni anuncia éxito por respuesta optimista: exige receipt propio terminal y lista fresca compatible. Rutas Guardian aceptadas conservadas. Terminal histórico no repite feedback; rechazo/expiración libera intento con aviso.

Gate final 64/64 (55 Guardian+9 HTTP), 11s, handle25127/exit0; analyze limpio29s handle88099/exit0. Pruebas nuevas default/remove con respuesta perdida y misma key, estado indisponible, recuperación servidor sin almacenamiento local y lista fallida sin éxito prematuro/repetición. Una invocación se lanzó por error desde root sin pubspec; otra nombró archivo HTTP inexistente (55 widgets pasaron pero gate exit1); corregidas, no se cuentan como aprobación. Analyze previo señaló9infos de llaves, corregidos, sin errores. Capturer cuatro estados/3s handle71941/exit0; normal377x852 y320/text200%, sin overflow. Inspección visual detectó palabra partida/título y acciones desalineadas en texto grande; título más corto y acciones centradas, recapturadas/revisadas. Inventario324 estados/37URLs.

No aceptación Auth+Stripe real nueva de default/remove, ni dispositivo. Cuentas con registro Guardian cancelado no cubiertas por rama independiente; wallets reales, tarjeta en apoyo puntual, composición completa y matriz global siguen pendientes. Full móvil504/359 antecede estos cambios; siguiente gate regresión completa. Sin schema/backend/flags/dinero real/CM/push; Codemagic únicamente al completar objetivo global.


### Loop381 — regresión móvil completa y sincronización de recuperación, 3/10/2026

Código probado b03d3a2ff9af2df7608dd8a301ae94957a2b1154, que incluye cliente380/909ea45. Primer full:537 aprobadas/1 fallida en3:18 (99126), case_photo_recovery_test asumía lectura y recuperación terminadas tras100ms; pumpAndSettle agotado, archivo aún abierto al cleanup/router dispuesto antes de finalizar. Dos intentos de esperar listener de ruta/lectura dentro de runAsync agotaron10s por coordinación de zonas de flutter_test; descartados. Corrección final únicamente en test: espera Future real del callback de recuperación dentro de runAsync, conservando archivo real, validación owner/status y navegación. No cambia producción ni autorización. Gate dirigido4/4 en1s,26693/exit0.

Full final538/538 en3:35, flutter test --no-pub --reporter compact,47954/exit0, log externo Temp/dopmi-full-mobile-loop381-final.log. Analyze limpio199.3s77273/exit0; configuración12/12 en0.090s78c4c6/exit0.220 archivos tracked lib/test/tool coinciden scratch normalizandoCRLF; pubspec/lock y assets coinciden salvo licencia NOTO-EMOJI-LICENSE EOL. Inventario recontado324estados/37URLs, no nuevas capturas381. Supersede full504/359 y cubre cambios360–380. Sin CI nuevo, no dispositivo/aceptaciónIrlanda/Stripe remoto nuevo por este gate.

Backend526/377, Deno3entrypoints y smoke23/378 mantienen alcance independiente. Próximo: aceptación Auth+Stripe de default/remove independientes, capacidades reales de wallets/uso tarjeta en apoyo y cierre de matriz global visual/motion/gestos. No recomponer funcionalidades ya verificadas por historial viejo. Guardián cancelado no está cubierto por rama independiente. No push/CM/flags/dinero real; objetivo activo, Codemagic únicamente cuando el objetivo global esté completo.


### Loop382 — default/remove autenticados contra DEV y Stripe test, 3/10/2026

Base b92ffb2. Fuente irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Preflight DEV latest75406/private.dopmi_saved_card_method_jobs y trigger perfil presentes. Cuenta sintética confirmada3ab27777-7306-4bcb-aac6-369ff923ba27@example.invalid (prefijo parity-methods-382), creada con trigger normal/perfil activo, cero Guardian/wallet previo. Password aleatoria se regeneró tras fallo del parser local de respuesta MCP; no exposición ni otra cuenta. CLI saved-card-methods-acceptance.mjs nuevo, journal sólo Temp. Stripe customer test cus_VN8g7ldAdGhIMC con metadata fixture/owner, dos PM reales desde tokens test Visa/Mastercard y default inicial preparado por SDK; wallet privado se insertó como preparación explícita de fixture. NO se presenta esta preparación como alta hostedCheckout ni uso móvil.

Auth real/login confirmado, lista propia2tarjetas/default inicial, consent false/version incorrecta/owner/customer/revision rechazados400, anónimo401, serverRPC403/42501, ownRPC inicialnull. Primer verify falló porque el script envió selected_method_id (campo interno) en lugar de payment_method_id (contrato HTTP), sin jobs ni mutación; corregido. Verify final98899/exit0: default key72133ffe-336d-40a7-8883-7a2cf4420992 applied, ownRPC idéntico y lista fresca/default Stripepm_1UMOOp2ZjyMOQ0uLyiCX8a8Y; replay idéntico y cambio de destino misma key409. Remove keyd6278f76-e967-46ed-8743-29f6e5970e25 removed sobrepm_1UMOOp2ZjyMOQ0uLMa2GtwCM, customer null/ausente de lista, default nuevo intacto y replay idéntico. SQL jobs3754e2ff-a04a-4e9e-a09d-e29a661137b0/3902e8b1-1c2b-46f0-a01f-e5542476ae27: attempts1 cada uno, snapshot/write_requested true, selected=confirmed target y lease_untilnull. No recibos terminales sembrados.

Stripecharges/PaymentIntents/invoices/subscriptions0 antes y después. Cleanup customerdeleted comprobado; SQLtransacción limitada al id/email/customer de fixture y dos jobs terminales, sin registros Guardian. Post users/identities/sessions/refresh_tokens/profiles/wallet/jobs0. Journal cleaned/sqlCleaned/stripeCleaned true, password/publishable retirados. Script node--check aprobado. Ningún recurso humano/PROD/flag/esquema/dinero live/CM/push cambiado.

Prueba remota positiva de operaciones independientes acreditada; no pérdida TCP real, dispositivo ni aceptación visual por estas llamadas. Regresión móvil538/381 permanece vigente porque no hay app nueva.324capturas/37URLs sin nuevas. Próximo wallets reales/uso tarjeta en apoyo/cuentas Guardian canceladas y matriz global de paridad/motion/gestos. Objetivo activo y Codemagic sólo al completar todo.


### Loop383 — base de guardado nativo de billeteras, 3/10/2026

Base0c6e806. Fuentea3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. PaymentMethodsSourcewallet-grid gap12, botones56/r18/blancos/borde/icon18/gap8, toast vinculado simulado. Cliente productivo no tiene flutter_stripe ni merchantIdentifier/configPK; no se copió simulación. Documentación primaria confirma GooglePayLauncher SetupIntent y ReadyCallback, Apple Pay nativo requiere MerchantID/certificado/capacidad/chequeo dispositivo; Checkout hosted tiene disponibilidad propia y no garantiza billetera elegida. Se pidió por pregunta asíncrona MerchantID/nombre de variable PK test existente en Codemagic, sin credenciales. No respuesta ni configuración acreditada, no bloquea SQL/servidor.

Módulo nuevo native-saved-wallet.mjs, aún no expuesto/integrado: SetupIntentcard/off_session/test y metadatajob/provider/consent; primera billetera comparte keycustomer con alta de tarjeta existente, checkpoint durable antesde SDKsecret. Receipt mínimo, no clientsecret terminal/expirado; native_ready previsto revalida autorizaciónSQL al entregar secret. Sólo confirma PaymentMethod real con customer/test/card/wallet.type elegido exacto; nuncaPI/cargo/default/Guardian. Leasefinally, creación idempotente ante respuesta perdida; vencimiento cancela SetupIntent, resuelve carrera por estado fresco antesde marcar expired/saved. Operaciones futuras native_setup/native_saved/native_ready requieren contratoSQL real, no existen aún.

12pruebas nuevas factory/Stripefakecubren ambosproviders/proof/replay/mismatch/owner/live/consent/lease/cancelrace/customerinicial. Primer npm526 no incluía módulo porque el script para package.json usó ruta root desde verification y falló; corregido y gate536 aprobado, después2tests/customer inicial añadidos justifican gatefinal538/53822.37s83615/exit0. Deno checkmódulo exit0/85e0e4. No pruebas de disponibilidad SDK ni Stripewalletreal remoto; no migración/Edge/app/flag/dinero/CM/push. Fullmobile538/381 independiente;324capturas/37URLs sin nuevas.

Siguiente loop: SQL sobre jobs existentes wallet_type/native_setup/native_saved/native_ready, replay inmutable provider y cliente compartido, RLS/lease/locks/guards bidireccionales/ownerreceipt, pgtests antesde integración endpoint/runtime. Checkout normal y Guardian aceptados conservados. Ver native-wallet-execution-2026-10-03.md. Objetivo global activo, Codemagic únicamente final.


### Loop384 — persistencia y permisos SQL de billeteras nativas, 3/10/2026

Base6125101, referenciaa3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Migración local20261003090000_native_saved_wallet, NO desplegada: wallet_type nullable apple_pay/google_pay enjobs existentes, SetupIntent único, constraints distinguen sesión Checkout de nativo y exigen evidencia terminal. Replay provider inmutable, customer/key/consent/guards compartidos. RPCserver privado service_role solamente, ownerRPC mínimo/key/status/provider/card_id sinsecret y normalOwnerRPC filtra sólo Checkout. Queues separadas. native_setup sólo con customer y lease válidos/SetupIntent inmutable; native_saved exige SetupIntentpersistido+PM y lease; native_ready revalida cuenta activa/confirmada/proveedor reservado/customercoherente/deadline/sinlease y conflictos antesde autorizar exposición del secret en servidor.

Sharedsaved-card transitions adquierenadvisoryowner antesdefilarow; claim conserva autorización nativa persistida trasdeadline para cancelación/confirmación frescas, sin inventarexpiración. Guardiánmethodprepare usa mismo lock y rechaza walletpendiente; wrapperwalletprepare/claim/ready rechazan methodGuardian pendiente, pruebas ambasdirecciones sin cambiarplan. Guardssetup/métodoindependiente/altaGuardian existentes cubren todoslosjobs nativos. Se corrigió guardia de lease compartida/nativa para rechazar explícitamente lease_untilnull trasrelease; test conservaUUIDliberado y demuestra escrituras rechazadas.

11tests PostgreSQL/PGlite nuevos registrados desde native-wallet-sql-cases.mjs en payments.test.mjs: provider/replay/colas/owner/RLS/anon/staff/lease/setupmismatch/flows/deadline/confirmation/suspensión/customercoherence/SetupIntentcrossowner/guards y2integraciones SQL+Stripefake apple/google con acceptedsetupresponseloss/mismakey/customer1/replayterminal/ceroobligaciones. Gate final549/54925.75s64090/exit0. Gate547 anterior precede2tests finales; anteriores538 sincasos nuevos no se cuentan como cierre. Una ejecución filtrada produjo PGliteclosed y una adición porPython ruta equivocada desdeverification no añadiócasos; corregido y pruebas registradas/importadas explícitamente en gatefinal.

Dockerdaemonreconsultado no disponible (namedpipeDockerDesktopLinuxEngineausente), no supabase testdb nuevo. No PG concurrente2conexiones ni migración/Edge/App/flags/Stripe real/device/CM/push nuevos. Backendportable538/383 + SQL11=549; fullmobile538/381 independiente,324capturas/37URLs sin nuevas. ConfigPKtest/MerchantID pregunta pendiente no se presume resuelta. Próximo integraciónendpoint/runtime/worker, preflightremoto/historial/constraints/definiciones antesdeaplicaruna vez; luego cliente/capacidades/aceptación real. Objetivo global activo, Codemagic únicamente final.


### Loop385 — endpoint y conciliación de billeteras nativas, 3/10/2026

Base75407c8; referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. add_wallet autentica cuenta confirmada y deriva owner de Auth; allowlist key/provider/consent/version rechaza owner/customer/SetupIntent/secret/importe/returnURL del caller. Nueva bandera DOPMI_NATIVE_WALLETS_ENABLED apagada por defecto controla solicitudes nuevas. Factory submit valida reserva SQL contra actor/key/provider antes de Stripe. Runtime conecta RPC privado y URL del servidor, worker concilia candidatos y webhook firmado recupera evento y SetupIntent frescos. Conciliación continúa para autorizaciones existentes aunque se deshabiliten solicitudes nuevas, bajo las guardas Guardian existentes; no cargo/default/activación ni cambios de dinero real.

Pruebas dirigidas20/20 y Deno check limpio en guardian-client, payment-worker y stripe-webhook. Backend completo557/55725.9189576s, sesión75053 exit0; log externo AppData/Local/Temp/dopmi-native-wallet-endpoint-loop385.log. Incluye11casos SQL y20factory/API; dos casos SQL usan submit real contra PGlite con Stripefake. Rechazo de identidad ajena/inyección/anon/no confirmado, bandera separada, worker sinsecret y webhook con prueba fresca. No migración/Edge/app remotos ni SDK/billetera/dispositivo verificados. Móvil538/381 permanece como evidencia independiente. Config PK/MerchantID pendiente; próximo preflight remoto y aplicación única de90000, después integración móvil. Objetivo global activo; Codemagic sólo al completarlo.


### Loop386 — billeteras nativas desplegadas en DEV, 3/10/2026

Base9df629e. Preflight remoto ohqxranynackjignryep: latest75406/saved_card_methods, wallet_type/RPC nativos ausentes, cero grupos SetupIntent duplicados, constraint original compatible y13anchors exactos en tres definiciones reales. Local20261003090000_native_saved_wallet aplicado una vez por MCP como20261003092721/native_saved_wallet. Postflight confirma columna, índice único, RLS, separación receipt normal y guardia lease liberado; server anon/authfalse/service_roletrue, ownstate anonfalse/authtrue. Sin repair/rename/replay/dbpush/PROD.

Overlays conservan bundles remotos: payment-worker26→27/19files, stripe-webhook26→27/18files, guardian-client19→20/18files ACTIVE. Sólo runtime/native-module y entrypoints afectados/clienthandler; resto de archivos preservados y verify_jwtfalse previo, AuthgetUser/worker-secret/firma intactos. GetEdge posterior:0mismatch/0extra normalizando CRLF en cada bundle. Smoke actualizado incluye dos RPC nativos;25/25real6.6366561s,061747exit0. Backend557/385 y Deno tresentrypoints previos cubren código idéntico. No flags/secrets/usuarios/Stripewrite/app/device/CM/push nuevos. No wallet real ni autorizaciónSDK acreditadas; configuración PK/MerchantID pendiente. Sigue cliente nativo y aceptación; objetivo global activo, Codemagic sólo final.


### Loop387 — contrato móvil de billeteras nativas, 3/10/2026

Base824672d; referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. NativeWalletRepository nuevo: ownerRPC mínimo y add_wallet con allowlist key/provider/consent/version; no owner/customer del caller. Rechaza proveedor/clave/consent incorrectos, receipt ajeno a key/provider, status/card incompatibles y secretos fuera de pending o de formato SetupIntent. nativeWalletReceipt descarta secretos/customer/campos adicionales; submit conserva secreto sólo en resultado transitorio para SDK futuro, aún sin persistencia/UI.

3/3 tests HTTP/parser pasan para apple/google, replay misma clave/cuerpo/Authheader/ownerstate y rechazo outcomes inventados;27770exit0/c824c2+4cb4ad. Primer fixture omitía http.Response.request y PostgREST falló al analizar respuesta; corregido en mock, sin cambio producción. Flutter analyze limpio49.3s25473/29d3d5. Scratch contiene archivos finales formateados. No SDK, capacidades, consentimiento visual, intentstore o pantalla integrados; tampoco wallet real/dispositivo/CM/push. Config Android actual requiere FragmentActivity/AppCompat, PK/MerchantID aún pendiente. Próximo SDK/config nativa y cliente visual/reanudación, después aceptación real. Servidor386 ya desplegado, dinero test-only, objetivo global activo; Codemagic sólo final.


### Loop388 — SDK nativo y requisitos Android, 3/10/2026

Base6bd1f7d; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Fuente primaria https://pub.dev/packages/flutter_stripe reconsultada:14.1.0, FlutterFragmentActivity/AppCompat/proguard/iOS13. Paquete fijado14.1.0 y lock sólo cinco dependencias nuevas; Android activity cambia a FragmentActivity, temas normal/noche a AppCompat sinActionBar y reglas oficiales Proguard incluidas en release. Identity com.mycompany.dopmi y signing Codemagic preservadas. iOS deployment existente15 cumple mínimo; no inventar MerchantID/entitlement.

Pubget scratch aprobado7.946s/c5ef05. Flutter analyze limpio42.7s77636/ced660;12/12 tests repository nativo+Guardian pasan71109/0f9bbf; configuración Python12/120.019s03f46a. No prueba de compilación Android/iOS ni plataforma instalada: plugin usa Kotlin/Compose2.4.10 y StripeAndroid23.17.1, por lo que compatibilidad real AGP9.1/Kotlin app2.4 debe verificarse antes de afirmar build listo. SDK aún no inicializado, sin UI/availability/confirmación ni cambios flags/secret/CM/push. Siguiente adapter test-only/config y compilación nativa, recuperación y sección visual, aceptación real. PK/MerchantID sigue pendiente. Objetivo global activo; Codemagic sólo final.


### Loop389 — adapter de disponibilidad y autorización SDK, 3/10/2026

Basec6e94c9; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. NativeWalletSdk provider habilitado sólo ENABLE_NATIVE_WALLETS_TEST+pk_test, AndroidGoogle/iOSApple conMerchantID válido/noWeb. Inicialización lazy compartida y reintentable ante error, disponibilidad real SDK antes de confirmar, Google testEnv/existingPaymentMethodRequired. Confirmación sólo confirmPlatformPaySetupIntent/MX/MXN, Apple guardar sincargo resumen0.00. Rechaza PIsecret/proveedor ajeno/no disponibilidad; no resultado guardado ni persistencia/secreto/logs. Callback seams permiten probar params exactos sin inventar SDK/device proof.

7/7 adapter+repository tests pasan16173/ca1c80 (cuatro nuevos). Analyzer final limpio12.2s22364/d84701; anterior detectó un lint de llaves corregido sin cambio comportamiento. Fuente primaria SDK/docs.page AppleGoogle y API instalada14.1.0 reconsultadas. No SDK nativo ejecutado/compilación/device/Appleentitlement/configbuild/UI/intentrecovery nuevos; PK/MerchantID pendiente. AndroidSDK ruta conocida, Java noPATH observado, revisar runtime real antesdecompilar. Próximo configbuild/adapter UI y recuperación, compilación nativa y aceptación. Dinero test-only; objetivo global activo/Codemagic sólo final.


### Loop390 — configuración del build de billeteras, 3/10/2026

Base8f76256; Source irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. write-mobile-config añade ENABLE_NATIVE_WALLETS_TEST sólo cuando guardian_test explícito y envtrue; standard siemprefalse/sinvalorescopiados. Clave pública STRIPE_PUBLISHABLE_KEY_TEST sólo pk_test, rechaza secret/restricted/live/missing sin eco; MerchantID opcional Android pero validado si presente. Valores vacíos con featureoff, no copia credenciales ajenas. Ninguna bandera remota/envCodemagic ni workflows activados.

Configuración16/160.035s5241b1exit0 (cuatro tests nuevos: gate workflow/flag, credenciales inválidas, metadatamerchant/normalización, featureoff sin copia). SDK389 usa exactamente esos dartdefines. No SDK/dispositivo/compilación nativa/UI nuevos. PK/MerchantID pregunta pendiente y certificado/entitlementApple no acreditados. Próximo sección visual/conservación intento y compilación, aceptación real separada. Objetivo global activo; Codemagic sólo final.


### Loop391 — recuperación mínima del intento nativo por cuenta, 3/10/2026

Based2b731d; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. NativeWalletIntentStore usa SharedPreferences con namespace propietario y allowlist key/provider/consentversion; nunca SDKsecret/customer/owner recibido. Replay conserva misma clave/proveedor y rechaza sustituir autorización pendiente; JSON corrupto no se borra para crear otra automáticamente. finish sólo acepta receipt terminal saved/expired coincidente, nunca cancelaciónSDK/pending/attention/otrokey/provider. Caller UI aún debe comprobar propia identidad y lista fresca antesde finalizar; no store como autorización SQL.

10/10 targeted pasan85227/3dde27 (tres nuevosstore+SDK4+repository3); analyzer limpio26.4s55393/652edb. Scratch archivos finales formateados. UI aún no conectada; inspeccionado punto de inserción Métodosde pago trasAgregar/listavisual. No flujo instaladonativo/compilación/capacidadApple nuevos niCM/push. Config reales pendiente, dinero test-only. Próximo integración visual+consentimiento+guardbusy/identity/freshreceipt/lista y capturas/pruebas, compilación nativa y aceptación. Objetivo global activo; Codemagic sólo final.


### Loop392 — botones visuales nativos de billeteras, 3/10/2026

Base029abd7; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. NativeWalletButtons componente preparado con dos columnas/gap12/min56/r18/white/borderSource#e6e2dd/icon18/gap8/Inter14weight500. Iconos AppleGoogle copiados de Sourcepublicassets, proveedor soportado único activable y resto disabled real, sin fakevinculación/hover. Flexible permite texto200% sin overflow, altura crece. NO componente insertado ni flujoUI concluido aún.

2/2 widgettests 320text100/200 pasan63591/d855b3; analyzer limpio6.3s759ea4. Prueban provider habilitado/sólo su callback/minheight/nooverflow, no pixelcaptura/gestoSDK/aceptación instalada. Próximo integrar sección/consent/owner-intent/serverreceipt+freshlist enGuardian pantalla y regresiones/capturas. ConfigPK/MerchantID/compilaciónnativa pendiente, dinero test-only; objetivo global activo y Codemagic sólo final.


### Loop393 — sección nativa conectada en Métodos de pago, 3/10/2026

Base9e1c86a; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. GuardianScreen carga ownerstate/store/SDKavailability cuando configurado; recupera pending/attention remoto sin nueva clave, botones Source y secciónBilleteras digitales. addWallet requiere current/verified/fresh/nootrosintentos, consentimiento confirmSavedCard antes de primera reserva, busy/confirming y ownerchecks despuésdecadaawait. Guardaintent antes de HTTP, abre SDK sólo con SetupIntentsecret y reconsulta server al retornar. load reconcilia ownreceipt y sólo retira saved al aparecer cardid en lista fresca o expired; éxito mínimotoast Apple/Google sin replayhistórico. Cancel/error conserva intent y botónContinuar, sin nueva autorización. AgregarTarjeta bloqueado walletIntent.

67/67 targeted existentes Guardian55+native12 pasan9855/3ce4b5 en15s; cubren regresión Guardian y componentes/repositorio/SDK/store, NO nuevos recorridos completos de pantalla wallet. Analyzer final limpio7.6s89881/3e76fb; cuatro lintsllaves previos corregidos. Sección aún requiere pruebas específicas ownerchange/lostreply/nativecancel/freshlist/error/attention y capturas normal/200 antes de aceptar paridad. No SDK/dispositivo/compilaciónnativa/CM/push nuevos; configuración realPK/MerchantID pendiente. Próximo pruebas UI específicas y correcciones de guards/feedback, capturas y compilación/aceptación real. Objetivo global activo; Codemagic sólo final.


### Loop394 — recorridos de billetera y guards en pantalla, 3/10/2026

Base80c0194; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. GuardsUI walletIntent bloquean default/remove independientes y agregar tarjeta; rows noofrecen default/remove con walletpendiente. Tres pruebas específicas native_wallet_screen_test con app/router/identity/store reales y repositorios/SDK sustitutos: consentantesHTTP, cancelaciónhojanativa/respuestaperdida conserva mismo key/provider trasreintento sinreconsent, nofakeéxito y Agregar disabled; ownerreceipt saved sincard enlista conserva intent/noaviso, freshmatchingcard retiraintent/avisa unavez y refreshnohistoryreplay.

3/3screen tests pasan88796/f7edcd, analyzer limpio6.8s66763/ba115f. NoSDK real/StripeAuth real/dispositivo ni capturasnuevas; no atribuir nativeacceptance a callbacksfake. Continúan ownerchange/mismatch/attention/SDKsuccess/listfail/200capturas/regresiónglobal/compilaciónnativa/configreal. Objetivo global activo, dinero test-only, Codemagic sólo final.


### Loop395 — estado de revisión nativa visible y bloqueado, 3/10/2026

Base998c0db; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. attention restaura intento remoto y muestra aviso explícito, sinContinuar; botonesSDK y handler bloqueados anteattention/errorconsulta. Nuevo test descubrió callbackGoogleactivo visualmente peseaguardiahandler; parche deindentación noaplicado inicialmente y testfalló, corregido conapply_patchexacto.

4/4screen tests final89299/0b42c1 pasan, analyzer limpio28.8s39736/316e60. Mantiene consent/cancel/lostreply/freshlistfeedback. Noefectoremoto/Stripe/CM/push/device/capturas/compilación nuevos. Pendientes ownerchange/casos adicionales/capturas/nativeacceptance/configPK/MerchantID ymatrizglobalparidad. Objetivo global activo; Codemagic únicamente al terminar.


### Loop396 — capturas nativas normal/200 y assets compartidos, 3/10/2026

Base1beb95c; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. capture_native_wallet_test renderiza app/router Métodosdepago con fontsreales/SDKreposfake a377x852normal y320x852text200, ready/review. CuatroPNGs revisadas en docs/design-reviews/parity-loop396. Inicialmente SVG ausentes: warmupestricto detectó profileicons no empaquetados en assets de scratch; mismos assets yaexistían onboarding, hashesidénticos comprobados. Producción reutiliza onboarding y elimina dosduplicados añadidos392. WarmupSVG yfontsantescapture impiden atribuir screenshot incompleta alresultadofinal.

4/4capturas finales38004/9782ee pasan, analyzer limpio27.1s86738/312134. Lints capturetool corregidos: visible_for_testing dentrotooltest anotado y llaves. Ready muestraGooglehabilitado/Appleinactivo; reviewambosdisabled/avisoreal. Text200 crece/wrap sinoverflow; review excede viewport y requiere scroll, no afirmar inspección delbottom ni accesibilidad instalada. No Sourcebrowsernuevo/pixelidentity niSDKnative/compilación/device. Capturas328/37URLs total sólo inventario, no328aceptadas. Continúan ownerchange/flujos/configPK/MerchantID/compilación/matrizglobal/finalacceptance; Codemagic sólo final.


### Loop397 — identidad tardía y preflight de compilación nativa, 3/10/2026

Base08e6686; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Nuevo testUI cierra sesión con respuestaWallet en vuelo y completa respuesta después: no abreSDK/avisofalso y conservaintent sólonamespaceowner.5/5screen tests28246/6aa101 pasan; analyzer limpio61.7s95893/971651.

Build local scratch debug con configFirebaseCI ficticia/testflags/pk_test_fixture (sinserviciosreales, noinstalación/distribución) iniciósesión5720. Falló terminalexit1 tras296.9s: pluginregistrant16packagesausentes yAppCompatstylesnoencontrados. Scratch copióAndroid despuésdepubget y no tenía.flutter-plugins-dependencies; no falloStripe aislado demostrado. Pubgetposterior genera19plugins inclstripe_android; copiada.metadata realdelproyecto. Reintento43821 no: handlecorrecto43721 está confirmadoen ejecución d2c091; logexterno AppData/Local/Temp/dopmi-native-build-loop397-retry.log. Retomaresehandle, no reiniciarsólo porque nohayoutput. Primerlog dopmi-native-build-loop397.log conservaerrores. Compilación aún NO verificada; noAPK/device/CM/push nuevos. Objetivo global activo, Codemagic sólo final.


### Loop398 — desplazamiento200 y configuración Codemagic sólolectura, 3/10/2026

Baseb0daaec; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Capturetool añade scrollUntilVisible sobrelista lazy y captura bottomreview200; ensureVisible anteriorfalló porque widget fuera deviewportaún no construido, corregido prueba sinproducción.4/4captures45532/ff7863 pasan, bottomPNG docs/design-reviews/parity-loop398 revisado: aviso entero y Actualizarestado visibles, sinsobreflujo. Analyzer limpio78.2s44155/3d74f6. Inventario329states/37URLs, no aceptación global.

Codemagic APIreadexistingtoken comprobada GETapp6ab062cf7e534c19e9884a3b appName dopmi-app. Sólo keys/grupos/metadatos impresos; ningúnvalor/secreto/config mutado ni build/remotepush. Appvariables9: SupabaseURL/publickey, AppleGoogleAuth, Playserviceaccount, FirebaseAndroid/iOS, GoogleServer/iOSclient; grupos dopmi_google_play/dopmi_supabase/dopmi_firebase. No STRIPE_PUBLISHABLE_KEY_TEST/APPLE_PAY_MERCHANT_ID/ENABLE_NATIVE_WALLETS_TEST en esta respuesta; team-level aún noinspeccionado, no asumir ausencia global. FuenteAPIprimaria https://docs.codemagic.io/rest-api/applications/ consultada.

Nativebuild reintento43721 siguevivo18cfe8; log dopmi-native-build-loop397-retry.log yaassembleDebug/pluginsloaded, instala SDKPlatform34 y advierte KGPFirebasecompatfuture. Java563.98CPU confirmado, sinresultadoterminal. Mantener mismohandle, compilaciónnoverificada, noAPK/device/CMpublication. Continúa compilación/configteam/nativeacceptance ymatrizglobal; Codemagic sólofinal.


### Loop399 — compatibilidad JVM de Stripe, 3/10/2026

Base29b92a1; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Build43721 terminó exit1 tras634.5s: stripe_android Java17/Kotlin21. SDK14.1.0 sólo fija Kotlin17 cuando AGP<9; Flutter opta fuera de built-in Kotlin con AGP9, de modo que Kotlin usa JDK21. RootGradle configura únicamente tareas KotlinJvmCompile de stripe_android a JVM17, coincidiendo con compileOptions del proveedor; no modifica pubcache ni deshabilita validación. Fuente https://kotlinlang.org/docs/gradle-compiler-options.html.

16/16config pasan0.031s, diffcheck limpio. Primer intento399 session65593 no recibió parche por Copy-Item relativo al cwd scratch incorrecto; copia absoluta posterior corregida, ese intento terminó mismoerror29s. Reintento corregido40473 activo, log externo Temp/dopmi-native-build-loop399-fixed.log. No atribuir compilación hasta resultado terminal, retomarhandle sin reiniciar sólo por falta de output. ConfigFirebase/PK ficticios sólo compilación, sin servicios/instalación/distribución. Localenv contiene sólo nombre STRIPE_SECRET_KEY_H4_TEST, ningunaPK localizada; no valor impreso. Objetivo global activo, Codemagic sólo final.


### Loop400 — retorno nativo sin éxito supuesto, 3/10/2026

Basefec01e7; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Nuevo testUI permite retorno exitoso del callbackSDK sustituto, mientras serverreceipt siguepending: confirma una invocaciónSDK, dosHTTP conintentidéntico, noaviso vinculado, continuación disponible y storepreservado.6/6screen tests pasan17515/d26c69 en1m42s; no SDK/Stripe/device real acreditado. Dartformat aplicado, scratch sincronizado; diffcheck limpio.

Analyzer97876 final1a618f exit0, limpio147.3s. Build40473 aún confirmadoactivo1aa300/logTemp dopmi-native-build-loop399-fixed.log; supera salida anterior con compilaciónJavaAPIdeprecated sinresultadofinal. Retomaramboshandles, no reiniciar por observacióntimeout. Cambio399 no tiene compilaciónvalidada todavía. Próximos: resultadosanalyzer/build, despuésconfigreal ymatrizglobal/finalacceptance. SinCM/push/instalación, Codemagic sólo objetivo completo.


### Loop401 — compilación Android y proveedor de la tarjeta, 3/10/2026

Base6637729; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Build40473 terminó exit0/5dacc3, assembleDebug556.2s; confirma ajuste JVM17 de Stripe399 y requisitos Android nativos388. APK externo Temp/dopmi-parity-20260930/mobile/build/app/outputs/flutter-apk/app-debug.apk,212447336bytes/SHA256fc36309762a7b19b89df4ba32af45786e429f464e7c243505fd0727e1ea84e01. FirebaseCI/PK ficticios, sinserviciosreales/instalación/publicación. Scratch no es candidato exacto Git: prueba400 y cambio401 sincronizados mientras Gradle ejecutaba; no atribuir APK al HEAD final ni aceptación nativa/device/paridadglobal.

finishWallet requiere freshcard.id Y wallet.type iguales alreceipt antesde quitarintent/avisovinculado. Prueba savedwallet añade listado con mismoid/providerApple incorrecto para solicitudGoogle: conservaintent/sinéxito, y luegoGooglecorrecto confirma una vez.16/16targeted screen/repo/SDK/store pasan43740/438063; format aplicado/diffcheck limpio. Analyzer34524 final5e691d exit0, limpio95.4s. No nuevosCM/push, únicamenteobjetivocompleto. Continúanconfigreal/SDK/device ymatrizglobal; no reducir objetivo a wallets.


### Loop402 — reinicio de galería al cambiar mascota, 3/10/2026

Basecd387f0; referencia remota y checkout a3c969cd9103fd46dc5cd886999912526ce75efb comprobados. Auditoría actual SourceApp1703 AdoptionDetail usa hero estático y dots decorativos; CaseDetail2081 cambiafoto instantáneo por dots/thumbnails, sin onTouch implementado. Galería productiva conserva swipe real y fotos aprobadas, no inventar CSSmotion/hover. Adoptar didUpdateWidget sólo reiniciaba porphotosjoin: con nueva publicación que compartepaths podía conservar índice/página anteriores. Ahora indexreset y PageViewkey incluyenpost.id, manteniendo estado al actualizar misma publicación y reiniciando al cambiar identidad de contenido.

Nuevo testwidget conserva mismoState confirst→second/photosidénticas: dragprimer a foto2, cambiopublicación muestraFoto1 y scrollpixels0.5/5detalle pasan80724/aa42e0; analyzer limpio28.6s87991/fe7dc9, diffcheck limpio. Repositorio/fotos offline fake; no navegacióninstalada/SDK/servidor real ni aceptaciónvisualglobal atribuida. Source/app rutas/diseño revisados en alcancegalería, matrizglobal265 todavía requiere cierrefamilias. Lecturas inicialespaths inexistentes corregidas a .tools/design-reference/src/App.tsx con rg--hidden--no-ignore; snapshotcheckout confirmado, nocambioSource. Sin builds nuevos/CM/push, Codemagic sóloobjetivocompleto.


### Loop403 — ciclo de galería pública de casos, 3/10/2026

Base0ced199; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. CaseDetailLayout añade record.id a condición de reinicio: nuevo caso vuelve a primerafoto aunque compartepaths. Conserva PageController/índice al actualizar mismo caso sin cambiar fotos; cambiodefotosaprobadas sigue reiniciando a0. No cambia dot/thumbnailsinstantáneos Source ni inventa animación/hover.

Nuevo case_gallery_lifecycle_test reutiliza mismoState/controller y photosfake: swipe→377px, refreshmismocaso→377, nuevocaso→0, swipe+shrinkfotos→0 sinexcepción.27/27suitecon rescue_test pasan48795/dbfc3b, incluye swipe/reintentos/geometry/dots/miniaturas normal200/renewresume/cierre/paginaciónprivacidad. Analyzer limpio39.5s47658/b3653f; format/diffchecklimpios. Sólo widgets/repositoriosfake, no runtimeSource niAndroidinstalado/aceptaciónvisualglobal. SinCM/push/buildnuevos; configSDKreal/dispositivo/cierrefamilias globales pendientes. Codemagic sóloobjetivo completo.


### Loop404 — regresión móvil completa sobre código actual, 3/10/2026

Base65ffc3145b40a71f794e2aef1e673fbbc64da390; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Fluttertest full558/558 pasan3m59s41550/1037f9; log externo Temp/dopmi-full-mobile-loop404.log. Comparación223archivosDart lib/test repo→scratch normalizandoCRLF sin diferencias82289/30536f, acredita alcance de código bajo prueba en lugar de asumir scratchactual. Último analyzer39.5s403 mismo código sin cambios404. No Dartproducción modificado en404.

MensajesSource App2773: input+send, composer40px/gap8/padding16/colores diferenciados styles3807 y7714; cliente mantiene repositorio/idempotencia/estadosreales. community_test cubre colores donante/rescatista, viewInsets300 composer/Enviar visibles, borrador al abrirDetalle y regreso, respuestaambigua sameid+logout privado. Fullactual incluyetests, no sólo búsqueda como prueba. No tecladofísico Android/runtimeSource nuevo ni comparaciónpixelperfect/aceptaciónglobal. No inventar necesidad de rehacer mensajes por tener funcionalidades reales extra. Matriz265/globalfamilias/capturascomparadas/configSDKreal/device/final gates siguenpendientes. SinCM/push/buildnuevos; Codemagic sóloobjetivocompleto.


### Loop405 — comparación renderizada y espaciado de texto en caso, 3/10/2026

Base39723a0; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Capturas259 antiguas no justificaban retoque porfuentes; Source nuevo Edgeagent-browser CLI aislado dopmi-parity405/Vite5176 a377x852, fonts.ready+checkIntertrue ycomputed headingInter700. No CDPplatformfontsnuevo, no extender prueba344 a todoSource. Browsermetrics título28/32.2/letterSpacing-.56; tags13/600/normal y story14/21.7/normal. Fluttercase heredaba letterSpacingMaterial porque styles no lo fijaban; ajusteInter explícito0 y título-.56. No alterar tamaño/colores/flujo/privacidad ni añadirhover.

Capturadoractual filtrado case-detail pasa1/1final54839/f5d70e11s (primero30332/a0392914s antescambio); renderiza todosstates conprefijocase-detail/fontsreales. Nuevas capturasSource/topFlutter/largeFlutter y source-text-metrics.json guardadas/revisadas en docs/design-reviews/parity-loop405. Topmejora anchoRocky/chips/texto frenteSource; SourcebadgeModo prueba no se copia. Large320x640text200 mantienefooterDonar yscroll, no comparaciónSource200nueva ni identidadpixelglobal. Analyzer limpio46.5s4802/777ca7; diffcheck limpio. Full558404 antecede sóloesteajustevisual, no repetirfullsinindiciofuncional.

Skillvercel:agent-browser aplicada; npxCLI verificadoconhelp/Edgecustom, noCLIglobalenPATH; comandos eval inicialdevolviófunción{} sinmedición, corregidoIIFEantescaptura. Browsercerrado52645/679778; Vite47325 CtrlCexit1esperado. NoCM/push/SDK/deviceaceptación, configSDKreal/matrizglobalpendientes. Codemagic sóloobjetivocompleto.


### Loop406 — tipografía y alto de líneas en detalle de adopción, 3/10/2026

Base0cbacf5; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. SourceRocky /adoption/rocky Edgeagent-browser aislado406 a377x852, fonts.ready/Interchecktrue/computedInter700/28/32.2/-.56. ClienteAdoptionDetailLayout heredaba espaciadoMaterial: todosInterletterSpacing0/título-.56. MediciónSourceadicional location20.15/verified18.6, stats68/value19/label15; cliente fija altura1.55 ubicación/verificado y19/15,15/12 estadísticas, evitando diferenciaacumulada2px. Datos equivalentesRocky/Patricia/Macho/Grande/3.4km/story/fotofixture; favoritoappguardado vsSourcenoguardado difiere legítimamente porstate, no copiarcorazónvacío contra servidor.

Capturasfinales normal377x852/large320x640200 ySource/metrics enparity-loop406 revisadas. Finalcaptureprefijoadoption-detail1/1pasa21803/4044874s; primera28327/5d0fd73s antesalturas. Analyzerprimero57.6s65447 limpioantesalturas; final43.5s34698/42da8f limpio sobrecambiofinal, diffcheck limpio. NoSource200nuevo/pixelidentity/deviceaceptación; footerQuieroadoptar accesible ytexto200wrap/scroll. Browser25583 ysesióncerrada691a2a; Vite7980 CtrlCexit1esperado. Skillagent-browser yaaplicada405. Full558404 antecedeajustesvisual405/406, nofullrepetidosinindiciofuncional. SinCM/push/configrealSDK, matrizglobal/device/finalacceptancependientes; Codemagic sóloobjetivo completo.


### Loop407 — espaciado común de Inter, 3/10/2026

Base562c0a5; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. El CSS raíz usa espaciado normal; cuerpos y etiquetas Flutter heredaban tracking positivo de Material. dopmiTheme ahora fija letterSpacing0 en bodyLarge/Medium/Small, labelLarge/Medium/Small y titleLarge/Medium/Small. Las medidas particulares explícitas de los componentes (por ejemplo h1-.56 y eyebrow) prevalecen; no cambia tamaño, color, alto de línea ni funciones. No generalizar que todos los títulos Source usan spacing0.

Full móvil558/558 pasa4m09s40186/657b8d; log Temp/dopmi-full-mobile-loop407.log. Analyzer limpio184.6s96733/4aeb06; format y diffcheck limpios. Ambos sobre base más este cambio común y ajustes405/406. Capturador COMPLETO sin filtro iniciado20132, log Temp/dopmi-full-capture-loop407.log; todavía sin resultado terminal. Retomar el mismo handle, no atribuir generación completa ni comparación visual por prueba funcional. No nuevo Source runtime, Android instalado ni aceptación global.

Próximo: recuperar resultado20132, inspeccionar capturas actuales por familias y compararlas con Source. ConfigSDKreal, matriz de estados/gestos y comprobación instalada siguen pendientes. Sin Codemagic/push: publicación únicamente al completar el objetivo íntegro.


### Loop408 — espera verificable de imagen en el capturador, 3/10/2026

Base9c6bb8b; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Capturador completo20132 falló exit1/911011 en1m27s: pumpAndSettle timeout línea1600 después de adjuntar foto a soporte. 176PNG nuevas antes del fallo, no colección completa. chooseImage real usa compute(prepareMedia); capturador sólo cedía500ms reales y luego intentaba estabilizar spinner mientras isolate aún pendiente. No defecto de app demostrado por ese timeout.

Tool ahora cede tiempo real en pasos50ms/pump hasta observar Cambiar imagen, máximo200pasos, y exige esa señal antes de settle/precache/captura. No desactiva spinner, no simula preparación ni relaja asserts de imagen. Filtrado help-center-support pasa80489/99e4d2 en11s, resultado terminal39ba2f; incluye normal/large, imagen realfixture y recepción. PNGphoto normal/200 copiadas y revisadas en parity-loop408; formulario/imagen/Enviar alcanzables, captura200 desplazada al final. Analyzer limpio39.0s27456/56fa49, format limpio. App no modificada408.

Reintento completo26793 confirmado activo/e26137, log Temp/dopmi-full-capture-loop408.log. Retomar mismo handle; no afirmar colección/aceptación completa hasta resultado e inspección. Full558/analyzer407 prueban temaactual; capturas parciales no aceptación global ni dispositivo. Próximo resultado y revisión por familias. SinCM/push, Codemagic únicamenteobjetivo completo.


### Loop409 — capturador completo y medidas de conversación, 3/10/2026

Base1924517; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Reintento completo26793 terminó exit0/9f4309,2m35s, log Temp/dopmi-full-capture-loop408.log; acredita ejecución del capturador sobre tema407 y corrección408, no aceptación de cada imagen ni servicios reales. Capturas actuales de mensajes se compararon con Source Edge377x852, fonts.ready/Interchecktrue. Dos mensajes sintéticos iguales a fixtures Flutter se sembraron sólo en localStorage Source. Primer intento version0 migró a mensajes base; detectado por screenshot/lectura y corregido a version15 vigente antes de comparación, sin modificar archivos Source.

Browsermetrics .bubble76.375/p43.375/time12 y composerinput46. Cliente hora10 heredaba altura1.5→15 y acumulaba ~3px por burbuja; se fija1.2. Compositorfont16/hintheight1.25 y botón46; última captura detectó campo44 bottom-aligned por InputDecorator y se añadió minHeight46 escalable para alinear con botón/Source sin impedir multiline. Ajustes no cambian envío, selección de texto, fechas reales ni idempotencia. Header menú real y badgeModo prueba son diferencias funcionales conocidas, no copiarbadge.

32/32community tests87745/be91df pasan14s antesconstraint; capturechat1/128131/20bc71 pasa6s. Final community+capturechat33/33 pasan98514/9d9b0e13s sobreconstraint; analyzerfinal21980/d85528 limpio26.4s (primero18837/40450d54.8s antecedeconstraint). PNGequivalentes Source yFlutter donor/rescuer/keyboard200 y metrics guardados/revisados parity-loop409. Normal muestra mejora burbuja/compositor, rescuer mantienepaleta ytextoselectable;200composer accesible coninset simulado. NoSource200nuevo/SDK/hardware/identidadpixelglobal. Full558407 antecede sólo ajustes409; captura completa408 antecede409, dirigidachat actual pasa.

Browser409 cerrado9d1ab0; Vite24212 CtrlCexit1esperado. SinCM/push/configrealSDK, matrizglobal/dispositivo/finalacceptancependientes. Próximo revisar publicación/verificación y otrasfamilias con capturas actuales; Codemagic únicamenteobjetivo completo.


### Loop410 — paleta de rescatista en selector de publicación, 3/10/2026

Base5f2dc56; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Capturasactuales408 publish-choice normal/200 revisadas; Source nuevo Edgeagent-browser410 /rescuer/publish377x852, fonts.ready/Interchecktrue, DOM ycolorescomputed registrados. Composición/títulos/cards/cancel/navbar corresponden; diferencia concreta: clientehardcodeaba donorink15110d/muted554e48/linee6e2dd pero Source.rescuer-theme usa151423/4f4e5c/e3e4ed. Ajuste sóloesasconstantes en publish_choice_screen, sin tamaños/rutas/estado/permisos/hovernuevo. Sombras específicas ycoloresgradientes preservados.

7/7targeted publish_choice+captureprefijopublish-choice pasan89007/ed96b1 en7s: estadosverificación/rutas/bloqueotardío ycapturasnormal200. Analyzer limpio47.0s94617/ff6a0d, diffcheck limpio. PNGequivalentesSource/Flutter normal200 ysource-colors.json guardadas/revisadas parity-loop410. SourcebadgeModo prueba no se copia; avisoUnicode⚠️ Source vsIconwarningamber cliente permanece diferencia visible pendiente de revisar, no declarar selectoridéntico ni familiaPublish cerrada. Source200nuevo/nohardware noacreditados.

Browser410 cerrado bcd8ae; Vite97298 CtrlCexit1esperado. Full558407+captercompleto408 antecedencambioschat409/paleta410, dirigidosactuales cubrenal alcance. Próximo aviso/intakeverificación y formulariosPublicación, manteniendoobjetivoglobal/configSDKreal/device/finalacceptance. SinCM/push, Codemagic sóloobjetivo completo.


### Loop411 — símbolo de verificación como texto de referencia, 3/10/2026

Base7d67901; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. SourceApp usa span literal ⚠️ Requiere verificación. Selector reemplaza IconMaterial warning_amber+gap+Text por el mismo textoUnicode inline con12/16 ycolorc2410c; preserva señal ypaleta real, sin cambiar autorización/estado ni copiar simulación. ParentcardSemantics ya describe verificación, ExcludeSemantics no duplica lectura.

7/7publishChoice+capture pasan42243/097a81 en4s, incluye destinos según estado, errores, lateverification y320/200+cancel. Analyzer limpio32.1s77976/f90118, diffchecklimpio. PNGnormal/200 actualizadas enparity-loop411; normal inspeccionada: glyphwarningmonocromático enrendererFlutterfixture, noequivalenciapixelconemojiamarilloEdge410. EltextoSource coincide; forma/colorEmoji dependenfallbacknativo y requieren revisión instalada, no declarar paridadglyph aceptada ni selector/familiaPublish completos. SinSDK/device/CM/push nuevos, configSDKreal/matrizglobal/finalacceptancependientes. Próximo intake/formulariosverificación/publicación y revisión nativa pendiente; Codemagic sóloobjetivo completo.


### Loop412 — paleta de rescatista en el formulario de verificación, 3/10/2026

Base03968d7; referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. El formulario Source usa rescuer-theme, cuya paleta se midió en loop410. Se sustituyen los grises de donante por ink151423/muted4f4e5c/linee3e4ed en el marco, títulos, campos, documentos y progreso del formulario real. Los otros editores no cambian. Se preservan privacidad de identidad/teléfono, revisión real, perfil público aprobado y Connect; no se copian aprobación simulada, conexión Meta ni CLABE del mockup.

31/31 comprobaciones pasan en11s: rescue_test, verification_state_test, verification_intro_test y capturador con CAPTURE_FILTER=verification. Reejecución observable86660/ad472a→caa089 tras pérdida del resultado anterior; no proceso Flutter test activo antes de ejecutarla. Log externo dopmi-loop412-tests.log. Analyzer26688/e1dc10→d79aa9 limpio36.8s, log externo dopmi-loop412-analyze.log. Dart format dos archivos sin cambios; diffcheck limpio. Capturas normal y200 actualizadas y revisadas en parity-loop412; el título se adapta a tres líneas con200. No nueva comparación Source renderizada del formulario ni aceptación física/global; el alcance verificado es la paleta y regresión dirigida.

Objetivo global sigue abierto: comparación de otras familias, gestos/animaciones, configuración SDK real y aceptación instalada/final. Codemagic únicamente al completar el objetivo, reiterado por el titular; sin push ni build intermedio.


### Loop413 — composición de la introducción de verificación, 3/10/2026

Base665db78; referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Source ejecutado en Edge agent-browser sesión413 a377x852, fonts.ready; fixture local versión15/unverified, sin editar referencia. DOM medido: h2 22/28.6/700, títulos y requisitos16/20/700, aviso14/17/700. Flutter corregido: heading1.3, títulos/tamaños/pesos/alturas medidos, margen20 tras copy, SVG check-circle de referencia, iconos negros en tarjetas y morado sólo en chip/checks. Paleta donor global del modal preservada: Source intro no tiene rescuer-theme. Texto de evidencia real sin videos ni aprobación simulada preservado. CSS del modal no declara animación; no se inventa una.

Primera edición usó codificación predeterminada Windows y dañó acentos: prueba falló al no encontrar Después. Se restauró desde HEAD con UTF8 explícito y reaplicó el cambio. Resultado final75765/79bbfc→bc9528:2/2 pasan4s, incluye cerrar/Después/regreso a origen, continuar/documentos reales con200 y capturas. Analyzer final59578/47dbf6→0f81ad limpio37.3s. Dart format y diffcheck aprobados. Capturas Source normal y Flutter normal/200 revisadas/guardadas, métricas en source-metrics.json. Normal ya reproduce composición; copys difieren por alcance real, cierre Material conserva hit target accesible. Texto200 envuelve palabras largas y desplaza contenido; botones accesibles mediante scroll probado. Sin Source200 nuevo ni aceptación física/global.

Browser413 cerrado58945/cb59ad; Vite36758 detenido CtrlCexit1 esperado. Objetivo completo sigue pendiente para otras familias/moción/gestos/configSDK/device; siguiente revisión de formularios y estados de publicación con Source vigente. Sin push ni Codemagic intermedio.


### Loop414 — regresión actual del formulario y revisión de casos, 3/10/2026

Baseb30fee9; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Source PublishFlow/ScreenShell rescuer, etapas/fotos/needs/revisión y CSS del picker consultados; PublicationFrame ya usa paleta rescatista. No cambio de producción en este loop.17/17 case_publication_test+publication_frame_test+capture CAPTURE_FILTER=case-publication pasan22s:43167/eb608e→6b1415, log externo dopmi-loop414-publication.log. Cobertura leída: envío confirmado vs rechazado, datos conservados al editar desde revisión, navegación de pasos, necesidades, foto privada y bloqueo sin foto real, footer/teclado y texto ampliado. Repositorios de prueba no acreditan servicios/dispositivo.

Capturas actualizadas de toda familia case-publication generadas; información básica y revisión normal inspeccionadas/guardadas en parity-loop414. Footer y campos alcanzables; no afirmar identidad visual con Source porque este loop no renderizó sus etapas equivalentes. Siguiente: ejecutar Source donation etapas1/2 con fixture equivalente y comparar sus medidas/capturas con estas evidencias actuales; no repetir sólo análisis de colores. Analyzer413 limpio mismo código de producción. Matriz global, animaciones/gestos/config SDK y aceptación instalada continúan; sin Codemagic/push.


### Loop415 — alturas de campos en información del caso, 3/10/2026

Basee786ca8; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. Source ejecutado Edge sesión415 a377x852, fixture donation/verified versión15; ruta draft abre fotos y Continuar abre Información básica. fonts.ready/Interchecktrue y DOM: heading18/28/600, inputs38px, textarea78px. Screenshot Source guardada; fixture name quedó vacío y especies sin selección frente Mora/dog/unknown Flutter, así que no comparación pixel de estado idéntico. Source no incorpora Por determinar ni campos privados/operacionales reales; preservados.

CaseInformation fija lineHeight20/16 y constraints38 (78 historia), antes19.2/36. Títulos ya600/28 correctos. Captura Flutter normal final revisada, grandes generadas; medición del rectángulo real Flutter aún pendiente, no afirmar 38px medidos sólo por constraint.11/11 case_publication_test+capture prefijo case-publication-information pasan8s25165/840958→4ac999, analyzer61469/ff4dc3→c10ba6 limpio73.5s. Logs externos dopmi-loop415-tests.log/dopmi-loop415-analyze.log. Format/diffcheck limpio. PNGnormal/200 y métricas en parity-loop415.

Browser415 cerrado51049/32f6a9; Vite3172 CtrlCexit1esperado. Próximo medir rectángulos Flutter y revisar necesidades/revisión con fixtures realmente equivalentes; sin aceptación visual global/servicios/dispositivo. Codemagic sóloobjetivo completo, sin push/build.


### Loop416 — medidas Flutter confirmadas y tarjetas de necesidades, 3/10/2026

Baseb1591a6; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Capturador registra rectángulos reales de información: nombre345x38, edad345x38 e historia345x78; coincide con medidas Source415, no sólo constraints. Capturador information87848/8caf38→f264ba pasa6s; JSON guardado. Tool agrega salida métricas para siguientes comparaciones sin alterar datos/servicios.

Source Edge sesión416 en377x852, fixture versión15 donation/verified con petName Mora, navegación fotos→información→necesidades ejecutada. DOM fonts.ready: nota94/14/20/padding16, tarjetas98/padding16/gap12, título16/24/600, copy14/20/400. Source normal y Flutter normal comparados: copy cliente heredaba peso500 de OutlinedButton. CaseNeeds fija400, notaRichText preserva frase real y destaca Nota700, icon slot36 y separación vertical16. CopyFood real se conserva porque catálogo simulado no existe; necesidad/cuidados privada también. SVGs siguen diferentes del emoji Source y queda por revisar primitive nativa/medidas horizontales; no identidadpixel ni familia cerrada.

11/11 case_publication+capture needs pasan12s78452/8d714d→8f02b1, analyzer54296/e22b97→d99164 limpio68.3s. Logs externos dopmi-loop416-tests.log/dopmi-loop416-analyze.log. Format/diffchecklimpio. Capturas needsnormal/200 generadas y normal inspeccionada; Source/métricas guardadas enparity-loop416. Browser cerrado372751; Vite79142 CtrlCexit1esperado. Próximo revisión con datos equivalentes e iconos/espaciado horizontal de necesidades, además de matrizglobal/configSDK/device pendientes. SinCodemagic/push.


### Loop417 — símbolos nativos en necesidades, 3/10/2026

Base3da71c4; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. CaseNeeds reemplaza SVGs fijos por los mismos símbolos Unicode del Source (comida, medicina, veterinario), font30/36 y peso400. ExcludeSemantics conserva etiqueta accesible de la tarjeta.10/10 case_publication pasan9s89335/b241e2; analyzer63884/113cbe limpio35.5s. Format aprobado. Renderizado/color y ancho del emoji dependen del sistema: captura final y Android aún pendientes, no paridad nativa acreditada. Próximo medir tarjetas/capturar cambio y continuar revisión equivalente. Sin Codemagic/push; objetivo global abierto.


### Loop418 — espacio estable para iconos de necesidades, 3/10/2026

Base04d8eb1; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada sin cambios. Captura35208/a21a4f pasa11s y revela glifos faltantes (renderer fixture sin fuente emoji), con slot reducido a ancho de fallback. Se fija SizedBox36x36 alrededor del texto Unicode para preservar distribución aun sin fuente. No se atribuye identidad/color nativo ni resolución del fallback Android. Capturas final normal/200 guardadas; normal inspeccionada conserva posiciones de copy, glyph faltante todavía visible y aceptación pendiente.11/11 case_publication+capture pasan11s68230/70ce00; analyzer28817/35cb15 limpio39.3s, format aprobado. Source review CSS consultado: heading16/500, cardvalue16/24/500 coinciden con constantes actuales; faltan comparación renderizada/estado equivalente. Próximo revisión actual y comprobación de fuente nativa autorizada; matrizglobal/configSDK/device pendientes. Sin Codemagic/push.


### Loop419 — tipografía del resumen de revisión, 3/10/2026

Base7351bae; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. Source ejecutado Edge419 a377x852, fixture donation/verified/Mora, pasos fotos→información→necesidades→revisión y fonts.ready. DOM medido: heading20, botónEditar17, photo110, labels15. CaseReview corrige heading16/20 y etiquetas12/15, antes1.55. Valores16/24/500 ya coinciden. No se cambia envío real a revisión ni se copia publicación simulada; campos reales adicionales preservados. Source/edit target17 frenteFlutter48 aún expande filas y resta fidelidad, pendiente resolver gesto/visual; fuentes/foto/enumfixtures difieren, sinpixelidentity.

11/11 case_publication+capture review pasan12s62461/bdede3; analyzer95186/814d69 limpio65.9s. PNGSource yFlutter normal/200 guardados, normalFlutter inspeccionada. Browser419 cerrado848e1b; Vite5871 CtrlCexit1 esperado. Próximo resolver composición/touch áreaEditar y comparar servicios/estado reales; objetivo global/configSDK/device siguen pendientes. SinCodemagic/push.


### Loop420 — filas compactas y activación de Editar, 3/10/2026

Basee196bd6; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. CaseReview reduce minimumHeight48→20 y tapTarget shrinkWrap para reproducir heading20 medidoSource419; textoEditar14/17/400 explícito. Ancho48, Semantics y callbacks existentes preservados; área táctil vertical es20, no afirmar target48 accesible. Text200 conserva adaptación de texto, práctica física pendiente.

11/11 case_publication+capture review pasan10s26036/0afbe3. Analyzer91549/b6b44a limpio44.5s antes del cambio adicional sólo test. Test existente de revisión agrega medida real20 y activación Enter desde foco del Text; fotos/necesidades conservan taps y datos.10/10 finalcase_publication pasan7s23776/fe0eb3, sin excepciones. Format aprobado, capturas normal/200 guardadas y normal inspeccionada: foto alineada153 comoSource; campos reales adicionales extienden card, no ocultados. No equivalenciapixel/Androidaceptado. Próximo ampliar auditoría de publicación/adopción y animaciones/gestos; matrizglobal/configSDK/device pendientes. SinCodemagic/push.


### Loop421 — auditoría de movimiento y navegación vigente, 3/10/2026

Base540efe3; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. Se leyeron CSS y implementación/test de onboarding, descubrimiento, rutas y switch de perfil. Onb-in450ms/Cubic(.22,1,.36,1)/opacity0→1/translateY10→0 coinciden; dots350ms/ease, switch180ms/ease/13px también coinciden por lectura. DISC salida280ms y retorno250ms misma curva, umbral estricto110px, seguimiento inmediato. Source onPointerCancel llama onPointerUp y podría guardar; cliente cancel nunca guarda, preserva intención real y evita favorito por interrupción del sistema. No copiar efecto persistente simulado por cancel.

21/21 onboarding_motion_test+discovery_motion_test+route_motion_test pasan4s39955/f3522f: interpolación a mitad/final, delays/reduced motion, retorno/interrupción/swipe/errores de persistencia, regreso inmediato Android/iOS y borrador de registro. Se inspeccionó cobertura antes de usar resultado: son widgets/repositorios falsos, no gestos físicos ni frame pacing real. Switch coincidencia sólo código, no timeline verificada en este loop. Sin cambios de producción ni aceptación global por este gate.

Siguiente: ampliar matriz de movimiento a galerías, paneles/modales y cambio de modo; confirmar timelines y recorridos faltantes con runtime, manteniendo revisión nativa/SDK y candidato final pendientes. No hover requerido. SinCodemagic/push.


### Loop422 — recorridos de modales, galerías y modo, 3/10/2026

Baseeba6d59; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. Se inspeccionaron entradas reales: modos/adoptStart/report usan noAnimation; necesidades/montosGuardian/contribution transitionDuration0. Corresponden a overlaySource sin declaración CSS de transición. Confirmaciones sólo reales (cerrar conversación, recuperación/borrador, privacidad) y filtrocatálogo heredado conservan componentes nativos; no se les atribuye un equivalente Source.

Suite42443/6754cf→9b4db2:35 pruebas ejecutadas pasan17s, pero comando exit1 por ruta mal nombrada adoption_detail_test.dart inexistente. Se corrigió sólo la invocación a adoption_detail_layout_test.dart;38111/986ee8:5/5 pasan2s. No se oculta primer error ni se afirma primer gate verde. Cobertura comprobada: modo sólo cambia tras éxito servidor y conserva origen/datos; cancelación/confirmación/back/barrier en modales, filtros descartan draft o aplican claves reales, galerías responden swipe/selección/reintento aprobado y reinician otroregistro sin perder refresh. Son widgets/fakes, sin dispositivo/backend ni visual global aprobados. Sin cambios de producción.

Siguiente: verificar estado actual del acceso Android y resolver evidencia nativa de fuente/gestos; después gates del candidato final y demásfamilias pendientes. La revisión física no se sustituye por estas40 pruebas. Codemagic sólo objetivo completo, sin push/build.


### Loop423 — acceso físico y regresión integral actual, 3/10/2026

Base8baaa39dc9a9ef7dd6268f1ba61ca6c844564e45; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. ADB devices -l desde SDK externo devuelve lista vacía31c048: no Android conectado visible ahora. No instalación/captura/toque ni aceptación atribuida. Ledger235 conserva pregunta pendiente de autorización específicaADBUI; no se interpreta USB como respuesta ni se repite pregunta. Comparación223Dart lib/test workspace/scratch normalizadaCRLF confirma0diferencias.

Se inicia regresión móvil completa sobre ese SHA, log externo C:/Users/betoq/AppData/Local/Temp/dopmi-full-mobile-loop423.log. Handle90488 confirmado vivo mediante write_stdin62d0ba; NO resultado terminal todavía. Retomar MISMO handle/log en siguiente turno, no lanzar otro Flutter test hasta terminal. No afirmar full558/greenactual. Analyzer420 precede sólo ediciones de prueba y ledger posteriores; verificar alcance final al cerrar suite.

Mientras teléfono no visible, continuar familias/validaciones independientes. ConfigSDKreal/matrizglobal/acceptance física siguen pendientes; Codemagic sólo objetivo completo, sin push/build.


### Loop424 — regresión integral cerrada y siguiente familia, 3/10/2026

Suite móvil completa iniciada423 termina90488/9c5da9 exit0:558/558 en3m59s sobre8baaa39dc9a9ef7dd6268f1ba61ca6c844564e45. Log externo C:/Users/betoq/AppData/Local/Temp/dopmi-full-mobile-loop423.log.223Dart lib/test root/scratch idénticos verificados423; commits423/424 sólo ledger. No reinicio ni tests concurrentes. Esto acredita regresión técnica actual, no identidadvisualglobal/runtimeSDK/Play ni aceptacióninstalada.

Referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. Siguiente familiaNotificationListSource y notification_tile/frame cliente leídos: borde/sombraunread, chips40, gap12 ycard24 ya corresponden. Title14/500 ytime12 usan normalSource vs1.2Flutter: medir render antes de ajustar. ClickSource marca leída y navega, app debe preservar navegación autorizada real y no copiar destinos simulados. Próximo comparar Source renderizado con fixtures equivalentes/read yKinds, no dar pantallaaceptada por lecture. ADB último423 vacío; no nuevasaccionesfisicas niCodemagic/push.


### Loop425 — altura de texto en notificaciones, 3/10/2026

Basee8019e3; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. Source Edge425 /notifications377x852/fonts.ready/DOM medido título14/17, hora12/15, cuerpo12/19.2; tarjetas/chips/bordes previos corresponden. Cliente fija height17/14 y15/12, antes1.2. Semántica leído/no leído y repositorio/destinos reales sin cambios. FixtureSource tres avisos conbody difiere Flutter uno sinbody: no comparaciónpixel de mismo estado.

10/10 notifications_test+captureprefixnotifications pasan6s37527/8020a4→063889. Cobertura inspectada: fecha exacta accesible, header teclado/fallback, kindreal, paginación200, fallo/success lectura y destino. Analyzer85967/5bec6f limpio82.5s. CapturasSource/Flutter normal/200/read/kinds y métricas guardadas, normalFlutter inspeccionada. Browser cerrado2e3f9c; Vite67425 CtrlCexit1 esperado. Full558424 antecede sóloheight425; testsdirigidos cubrenalcance. Objetivo global/configSDK/device pendientes; siguiente comparación confixtureSource equivalente, resto de estados/history/matriz, sinCodemagic/push.


### Loop426 — geometría de aviso equivalente, 3/10/2026

Basebe308fa; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge426 /notifications377x852, fixture local15 con mismo títuloPatricia/horaAyer/bodyvacío/kindmessage/unread. fonts.ready y DOM: card74/y88, chipx33/y105. Cliente Padding16 enDecoratedBox no reservaba borderCSS1; cambiado17 para dimensiones/offset equivalentes. Fuente/capturas normal Source yFlutter inspeccionadas: tarjeta corresponde, badgeModo prueba excluido; no identidadpixel/global atribuida.

10/10 notifications+capture pasan5s64705/aff286→0ad20c, analyzer49164/b4c3b1 limpio49s. Normal/200/read ySource/métricas guardadasparity-loop426. Browser cerrado1b0acd; Vite63620 CtrlCexit1 esperado. Semántica/read/destinos reales preservados. Próximo histórico real de pagos y restantes estados/matriz, sin repetir sólo prueba de tarjeta; SDK/device/finalacceptance pendientes. SinCodemagic/push.


### Loop427 — texto del historial real, 3/10/2026

Base0334e5f; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge427 /history377x852 inicialmenteempty, fixture15 emptyStatesfalse habilita historialSource. DOM fonts.ready mide date15/title17/method15/amount16/pill20 (14texto+6padding). PaymentHistoryRow fija esas alturas, mantiene expand/evidence/ownership y estados reales. Source simula suscripción yVisa4242: no copiados, fixturesnoequivalentes ni pixelidentity atribuidos.

8/8 row/screen/capture pasan28s53213/c728a6: montos reales200, evidenciafaltante noinventada, ciclosconfirmados vsomitidos/processing, filtrosrecibidos/ownership tardío. Analyzer13904/fce181 limpio49.7s. Format aprobado; PNGnormal/200/empty ySourceguardados, normalFlutter inspeccionada. Browser cerrado5fdb2a; Vite4619 CtrlCexit1esperado. Próximo revisión actual de familias restantes con matriz ygestos/configSDK/device; dinero continúa test-only. SinCodemagic/push.


### Loop428 — contrato funcional de métodos guardados en aportación puntual, 3/10/2026

Basef52ff21; se cambia prioridad de refinamientos menores a brecha funcional real pendiente. Lectura payments.mjs.checkout85–107: sesión modepayment no tienecustomer; runtime.ts sólo ofreceRPCpayment_server, por tanto lista guardada no llega a checkout. No usar endpoints legado410. RPC privada dopmi_saved_card_owner_server(uuid), migrationlocal20261003071000, ya obtiene customercoherenteGuardian/saved_cards poractor confirmado/activo yrechaza clientes divergentes; guardian-runtime la reutiliza. Puede servir lookupservidor paracheckout sin nueva colección ni confiar en customer_idsupuesto porcliente. Se preservará no guardar nuevas tarjetas/no off_session adicional sinconsentimiento y dinero test-only.

Baseline node --test --test-name-pattern checkout|saved.card payments.test.mjs pasa6/6 en2.844s96ee73, logexterno dopmi-loop428-payment-baseline.log. Son las pruebas quecoinciden conpatrón, no fullbackend ni pruebaStripe real. No implementación/deploy/schema/flag todavía. Supabase skill consultada; legacy-retirement y migration-history-audit leídos antes trabajo remoto, pero no conexión/migración hecha. Stripe docindex save-during-payment verificado; varianteMarkdown ySupabasechangelog no legibles porwebtool (errores), verificar mediante otra vía antes implementar convenciones.

Siguiente concreto: resolvercustomer opcional sólo servidor, comprobar customerStripe test/owner, sesionesexistentes e idempotencia estable bajo cambio de vínculo; probar negativos y respuesta perdida. Verificar presentación de métodos guardados según versiónStripe/allow_redisplay, no prometer selección por sólo añadircustomer. Cliente/testreal/SDKconfig/native siguenpendientes; paridadglobal no completa. SinCodemagic/push.


### Loop429 — cliente Stripe privado en checkout puntual, 3/10/2026

Base70ce592. paymentService recibe lookupCustomer servidor opcional; runtime usa RPCprivada existente dopmi_saved_card_owner_server(actor confirmado), nunca customer de input. Antescrear sesión, valida cus_id y CustomerStripe mismoid/no eliminado/livemodefalse; agrega customer sólo si existe, no crea nuevo/no setup_future_usage/no consentimiento de guardado añadido. Reintento sesiónexistente conserva ruta anterior/idempotencia dopmi-checkout-donationID. No esquema nuevo, cambio sólo local, no deploy ni dinero real.

Nueva checkout-customer.test.mjs integrada npmtest:7 casos owner/test/deleted/live/mismatch/invalid/inputforjado/customerless/reuso de sesión. Invocación primera desde raíz no encontró archivo; corregida workdir.7pasan y npmtest completo564/564 pasa29.944s59517/561ca9, log externo dopmi-loop429-backend.log. Deno check primeroTS2322 por aridad defaultlookup0: corregida default_actor1, final Deno payments check y7tests pasan95778f, aridad no altera runtime. Full564 antecede sólo esa corrección de firma; recheck dirigido final aprobado.

Documentación primariaStripe save-during-payment y APIcheckout fetched porurllib tras webtool fallido; confirma customer y allow_redisplay/consentimiento de volver a mostrar. Supabase changelog fetch97503bytes sin mencionesbreaking-changeRPC/Edge/supabase-js; no cambioAPI cliente. Consulta existentepermite reuse pero sólo métodos elegibles redisplay; no declarar tarjetasSetup/off_session disponibles ni flujo final completo. Siguiente: probar respuesta perdida/cambio vínculo y resolver redisplay conconsentimiento guardado, luego preflightDEV/deploy/testStripe autenticado y cliente. Matriz visualglobal/SDK/device siguenpendientes. SinCodemagic/push.


### Loop430 — recuperación de checkout puntual, 3/10/2026

Base80fd89e; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado sin cambio. Fixture checkout ahora conserva created_at como SQL real y simula caché idempotente del proveedor con rechazo de parámetros distintos. Tres pruebas nuevas cubren respuesta Stripe perdida, checkpoint SQL fallido después de crear sesión, y cambio de vínculo customer tras fallo: misma clave/cuerpo en reintento compatible, una sesión lógica, reuso persistido; cambio de cuerpo rechazado sin generar otra clave, recuperación al restaurar vínculo.

10/10 checkout-customer pasan149ms, handlecaa99c exit0. Es evidencia de contrato con proveedor simulado, no respuesta perdida realStripe ni despliegue. No producción modificada en este loop; full564/429 antecede estos tests. Continúa redisplay con consentimiento explícito, preflightDEV y recorrido auténtico; objetivo global pendiente, Codemagic sólo al completarlo.


### Loop431 — redisplay consentido al guardar tarjeta, 3/10/2026

Base68d79f9; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Documento primario Stripe https://docs.stripe.com/api/payment_methods/update confirma allow_redisplay always para mostrar método guardado en checkout. Consentimiento móvil existente autoriza guardar para futuros apoyos que el titular autorice; no implica cobro/Guardian/default. savedCardService exige consent_version y consent_at persistidos antes proveedor; después de sesión/SetupIntent/card verificados, actualiza sólo allow_redisplay con clave por job y relee identidad/customer/test/card/always antes receipt saved. No filtros globales limited/unspecified, cambios en tarjetas Guardian ni wallets nativas en este loop.

Tests nuevos: respuesta perdida de update recupera estado proveedor sin repetir escritura; respuesta optimista no basta sin lectura fresca; owner cambia tras update rechaza receipt; consentimiento persistido ausente no toca proveedor y libera lease. Negativos existentes de session/setup/card prueban cero updates redisplay. Primera invocación filtrada payments.test falla29 con PGlite is closed: no gate aceptado. Suite completa observable pasa569; luego dos negativos añadidos y npmtest final571/571 pasa22.958s83406/3333a3, log externo Temp/dopmi-loop431-backend-final.log. Deno check payments yguardian-client exit0/00307a; sólo tests añadidos después de ese check. diffcheck limpio.

Cambios locales, sin deploy/esquema/flags/dinero real/Codemagic/push. No se acredita selección realStripe ni métodos antes guardados ni wallets nativas; siguiente preflightDEV y prueba auténtica de redisplay/checkout con cuenta sintética y limpieza. Objetivo global visual/movimiento/SDK/dispositivo permanece abierto.


### Loop432 — preflight remoto y acceso Stripe, 3/10/2026

Basedb8d749; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. La clave STRIPE_SECRET_KEY_H4_TEST no existe en Process/User/Machine actuales; inventario sólo registra nombres, nunca valores. Stripe MCP list_available_accounts_or_orgs devuelve UNAUTHORIZED/requires reauthentication. Solicitud async concreta para reconectar Stripe test enviada; no solicitar secretos en chat. No API financiera escrita ni sesión de prueba creada; redisplay real continúa sin demostrar.

Supabase DEV ohqxranynackjignryep conexión verificada: existen dopmi_saved_card_owner_server(uuid) y dopmi_saved_card_server(text,jsonb); owner RPC grant service_role=true/anon=false/authenticated=false. get_edge_function payments ACTIVE10, tres archivos payments/index.ts,_shared/runtime.ts,_shared/payments.mjs: bundle sin lookupCustomer ni dopmi_saved_card_owner_server. Confirma cambio429 sigue local y requiere overlay/despliegue y postflight; no schema replay/repair. Legacy-retirement y audit leídos, sin mutacionesremotas.

Brecha Guardian cancelado confirmada en códigoactual, no con recorrido real: guardian_screen.changeIndependentMethod rechaza cualquier plan y sólo muestra acciones con active o plan==null; saved_card_method_server prepare/write_mutation rechazan cualquier registry Guardian, aunque cancelado. Servicio proveedor saved-card-method ya contempla subscriptions canceled/incomplete_expired pero no basta para liberar SQL/UI. Siguiente loop debe definir elegibilidad con cancelación comprobada, pendientes/leases/uso de método y pruebas de carrera antes ampliar disponibilidad; no borrar registro ni reinterpretar canceled por intención. Goalglobal activo, no CM/push.


### Loop433 — autorización SQL para métodos tras cancelación, 3/10/2026

Base73205b7; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Migración local20261003110000_canceled_guardian_saved_methods añade helperprivada y sustituye exactamente2guards del RPCexistente (prepare/write_mutation), bajo lockporowner ya establecido. Conserva registry/evidence canceled y requiere canceled_at; bloquea statusactive, leasevivo, customerincoherente, schedule nocancelado, requestpending ymethodpending/attention. Activaciones/setup/walletpendientes mantienen guardas existentes; serviceproveedor ya revalida subscription/invoices/intents anteswrite. No se infiere canceled por intencióncliente ni borra registro.

Nueve pruebasSQL nuevas: default/remove con cancelaciónconserva registry; reactivación/lease/customer tras snapshot impiden write ymutation_requested_at sigue null; reconciliationattention inicial bloquea prepare; request/methodtardíos bloquean write; helper noaccesibleparaowner/ajeno/adminbrowser. npmtest completo primero577/57724.590s5895/cf5366; tresnegativos añadidos, final580/58024.388s13733/74aba1, logexterno Temp/dopmi-loop433-backend-final.log. diffcheck limpio.

Local sólo: migración no aplicadaDEV, UI aún requiereplan==null y nohabilita canceled; no declarar brecha completa. Próximo conectar UI/RPCavailability y testsFlutter, preflightdefinitionremota antes aplicarlocal patch; StripeMCP pendiente reautenticación. Dinero test-only/goalglobalvisualSDKdevice abierto, sinCM/push.


### Loop434 — acciones móviles de billetera tras Guardián cancelado, 3/10/2026

Baseaba1230; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. GuardianScreen centraliza independentWallet: plan ausente o statuscanceled del state servidor; statuscancel_requested nohabilita acciones. Tarjetasconservan componentes visuales, predeterminar/eliminar de canceled usan saved_card_method sin revision/Guardianmutation; callback yretry permiten canceled, active continúa rutapropia. Identity/freshness/consent/busy/intentpersistido y prueba receipt+cards anteséxito preservadas. SQL433 permaneceautoridadfinal y bloquea pending/lease/incoherencia; UI no concede autorización.

Dos recorridosWidget completos adicionales canceled(default/remove) ejercitan autorización, lostresponse, persistkey+target, mismo retry, receipt+cards frescas ycleanup sin cambiar estado canceled. Testcancel_requested comprueba ausencia de botones ywrites. Guardian suite58/58 pasa10s78164/e38cae en scratch sincronizado (dosarchivos propios); analyzer65845/c5a7a9 sinissues48.4s. Format/diffchecklimpios; logs externos Temp/dopmi-loop434-mobile.log y dopmi-loop434-analyze.log. No fullmóvilnuevo/captura/sourcepixel/device atribuidos.

Código local; migración433/deploycheckout/redisplay y Stripe auténtico siguen pendientes. No changeschema remoto, no dinero real/CM/push. Siguiente preflightRPCremoto y overlayconpostflight, validar estadoscancelados en backendreal y métodos guardados conStripe test trasreautenticación. Scopeglobalvisual/motion/native sigueabierto.


### Loop435 — cancelación y métodos desplegados en DEV, 3/10/2026

Base14d8350; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Preflight MCP DEV ohqxranynackjignryep: latest20261003092721/native_saved_wallet, helperausente, definiciónsaved_card_method_server contiene2anchors exactos, servicegranttrue/browserfalse. Aplicada una vez migraciónlocal20261003110000 como remota20261003130559/canceled_guardian_saved_methods, success verificado. No replay/repair/rename/dbpush. Postflight2guardsnuevos, helperpresente, server service=true/anon=false/auth=false yhelperbrowser=false. Se conserva definiciónexistente incluyendo textosprevios, no otrosmódulos/esquema/flags.

Prueba PostgreSQL remota enBEGIN/DO/ROLLBACK conUUIDsintético: Authfixtureconfirmado/wallet/customer/registrycanceled; helperpermite, RPCprepare+claim+snapshot funcionan. Cambioactivoanteswrite provoca null ymutation_requested_at sigue null, validado mediante excepcionessiincorrecto. Rollback completo; consultaindependiente confirma0usuarios/0wallets/0plans/0jobsloop435. No tokenAuthcliente/StripeAPI/recorridoinstalado acreditado.

Revisión plan_view identifica payment_in_flight basado en collectionpay_requested_at/status no paid/skipped: siguiente loop debe comprobar si elegibilidadSQL debe incorporar también esa conciliación antespermitirmétodos trascancelación; no declarar todosestadoscerrados. Checkout429/redisplay431 siguenlocales, StripeMCP reautenticación pendiente. GoalglobalvisualgestosSDKdevice yCodemagicfinal pendientes; noCM/push/dinero real.


### Loop436 — cobro en conciliación y activación histórica, 3/10/2026

Basebf50857; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Migración local20261003131000_canceled_wallet_collection_guard extiende helper433 para collectionpay_requested_at/statusno paid/skipped; pending/attention siguen bloqueo incluso registrycanceled. Nueva helperprivada activation distingue pendiente/attention de settledhistórico: excepción sólo con schedulecanceled yregistrycanceled+fecha, mismoowner/cycle, settlement payment_intent+charge coincidentes con registro. Parche exacto2activationguards enRPCprepare/write, no se modifica status/evidencia del primerpago.

Primer full585:582pasan/3fallan porque fixture completa mantiene activationsettled histórico, reveló bloqueo real que fixture433 sinprimeraactivación no cubría. No falsepass: corregida regla SQL con vínculo comprobado. Full585posterior pasa24.438s8291/64db77; dosnegativos añadidos, final587/58724.401s25135/2bc9c1, log externo Temp/dopmi-loop436-backend-final2.log. Siete pruebas nuevas: pending/attention rechazan prepare; paid/skipped permiten sin modificarcollectionrecord; pay_requested tardío bloquea write sinmutationtimestamp; activationpending/comprobanteajeno no se eximen ni creanjob. diffcheck limpio.

Sólo local; migración no aplicadaDEV aún. Próximo compararhelper/activationanchors remotos y aplicarúnicavezconpostflight, más UI payment_in_flight. No afirmar flujo completo porSQL ni fullmobile; Stripe reauth/checkoutdeploy/redisplay/SDK/device yparidadglobal pendientes. SinCM/push/dinero real.


### Loop437 — bloqueo visible de conciliación y despliegue SQL, 3/10/2026

Base2f944e9; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. GuardianScreen independentWallet excluye canceled con payment_in_flighttrue; conserva tarjetas visibles y Notice explica apoyo pendiente. Test nuevo comprueba ausencia de predeterminar/eliminar mientraspendiente, Actualizarestado confalse restaura ambos yquitamensaje, cero submit. SuiteGuardian59/59 pasa13s60838/9675f6; analyzer6060/84e683 limpio34.5s en scratch condosfuentes sincronizadas. Format/diffchecklimpios; logs externos Temp/dopmi-loop437-mobile.log/analyze.log. Sin fullmobile/captura/device nuevos.

Preflight DEVohqxranynackjignryep: latest20261003130559, helper433 md5exacto5a9e2efc5850b565baf355354c548716, activationhelperausente y2anchorsRPC. Aplicada una vez local20261003131000 porMCP como remota20261003131548/canceled_wallet_collection_guard. Postflight ambos prosrcmd5 coincidenlocal probado587: collection939ccd4012f6a0d977d788ce2bb79a2c; activationf59fc9925e6e5b045df51b29892626d6. DosguardasactivationRPCactualizadas; serviceexecute true/browserfalse, helpers anon/authfalse. SQL yprivilegios reales verificados, no prueba nuevaAuthREST/Stripe positive ni nueva fixtureSQL remota de ciclo completo atribuida. No replay/repair/rename/dbpush.

UIservidor estadosdeconciliación implementados/SQLdesplegado, no cerraraceptación financiera/visualglobal con estaspruebas. Checkout429/redisplay431 overlayspendientes, StripeMCP pide reauth. Continúa objetivo completo/nativo/dispositivo yCM sólocandidatofinal, sinpush/dinero real.


### Loop438 — checkout con customer privado desplegado, 3/10/2026

Base0e22658; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. paymentsDEV ACTIVE10 tenía3archivos; comparacióncontra local: entrypointidéntico, runtime sólolookupCustomerRPC, payments sólo callback/validacióncus/test ycustomercheckout. Guardado backup externo Temp/dopmi-loop438-payments-before.json. RPC owner realexistente serviceexecute=true/browserfalse confirmado; no nuevoesquema. Deno payments check y10checkouttests pass101.689ms72451/2b1e83 sobrecódigo actual antesdeploy; gatebackend587/436 antecede sólomobile437, móduloscheckoutidénticos.

Deploy MCP payments10→11 ACTIVE, bundlehash731b3beb46c005137e25633c388a48bc5e9cd2d535d06dfb7f636676d6e1b56b. Preserva3files yverify_jwtfalseprevio, AuthgetUser/token/emailconfirmado guardasentrypointintactas. GetEdgepostflight0mismatch/0extra normalizandoCRLF vs fuenteslocalesprobadas. HTTP real GET405 method_not_allowed yPOSTsinAuth401 sign_in_required (3ea42d). No Stripewrite/ownerfixturecheckout/redisplayselecciónreal niaceptacióndevice atribuidos. Dinero test-onlysinflagsnuevos.

Checkout429 ya remoto; redisplay431 aún requiereoverlaysworker/webhook/client ypostflight. StripeMCP reauthsiguependiente. Laspruebasdeboundary no sustituyen checkoutautenticado ni selecciónreal/SDK; objectiveglobalvisual/motion/device continúa. SinCodemagic/push.


### Loop439 — redisplay consentido desplegado en DEV, 3/10/2026

Base0814808; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. GetEdgeworker27/19files,webhook27/18,client20/18: saved-card.mjs idéntico en los tres. Comparacióndeterminística localquitando sólo guardconsent_version/consent_at ybloqueredisplay devuelvebaselineexacto; no diferenciasnoautorizadas. Backupsexternos Temp/dopmi-loop439-{slug}-before.json. Deno check tresentrypoints exit0b88348; backend587/436 cubre módulosaved-cardlocal sin cambios después.

Deployoverlay sólo _shared/saved-card.mjs, demásarchivosremotos yverify_jwtfalseprevio preservados: worker28 ACTIVEhash75b132db770f713fd06acec6a34f3db0f6d81c70385e0c89c16a6c53c5d77624; webhook28 ACTIVEhash31c9392915d7827078cd5083292a2b35a4b19d0e203b529c111498f0ee53d133; client21 ACTIVEhashcac9b4a1e31cdf60f412b87a89afeeeedd150b848defb3aba2d4705a1868437f. GetEdgeposterior0mismatch/0extra en19/18/18files por CRLFnormalizado. POSTsincredencial realworker401access_denied/webhook400invalid_signature/client401sign_in_required46b36d. Auth/secreto/firma/testkeys guardasintactas.

No schema/flags/secrets/Stripewrite ni usuariosnuevos; redisplay431 ya remoto. Estaspruebas comprueban despliegue/boundaries, no SDK ni tarjeta realdeprueba/configuracióndeCheckoutselección. StripeMCP reauthpendiente ytarjetasprevias/nativewallets no se habilitan retrospectivamente por esteupdate. Sigue aceptaciónAuthStripe ymatrizglobalvisual/motion/device, noCM/push/dinero real.


### Loop440 — capturas de billetera cancelada y conciliación, 3/10/2026

Basef41f83e; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Capturer añade5estadosfixture de /settings/payment-methods: cancelednormal/200%, waitingnormal/200% ywaitingfooter200%. Fixturesconservan cardsVisa4242/Mastercard5556, method_change_availablefalse, statuscanceled ypayment_in_flight variable. Assertionsvalidan acciones sólo sincobropendiente, Notice sóloenwaiting y0submit. Footer scroll confirmaActualizar estadoaccesible; sin nuevo producción.

Primera corrida4capturas pasa1/1sinlayoutException pero bloqueasserts quedóerróneamente dentro adoption-drag, no se ejecutaba; detectadopor lectura y corregido moviéndolo a rama finalgeneral. No atribuirasserts aprimera corrida. Corrida finalobservable65092/79ef4c pasa1/1en3s con5estados yasserts ahoraactivos. PNGnormalwaiting/200waiting/200canceled/footer200 inspeccionadas: textorefluye, segundo método bajo viewport inicial200 accesiblepor scroll; Actualizarestado sinrecortehorizontal. Artefactos docs/design-reviews/parity-loop440, fontsInter/Fraunces empaquetadas delcapturer, nofontemoji/device. Format/diffchecklimpios.

LecturaSourceApp3623/card-row yCSS nav-row-text gap2/inline-linksmall12 muestra comparación de medidas actualpendiente; no igualdadpixel afirmada, ni5pantallasaceptadas ni fullmobileactual. No walletSDKconfig/Stripe real/remotechanges; Nativewalletbuttons noaparecenfixture porcapacidadtest no disponible, no paridadfinal atribuida. Siguiente mediciónrenderSource/cardtitle/action/muted ygestosfamilias, ademásacceptanceStripe/device; sinCM/push.


### Loop441 — medidas renderizadas de tarjetas y tipografía, 3/10/2026

Base4b39a07; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge441 runtime377x852 /settings/payment-methods, fonts.ready conInterloaded, DOMcardheight70/padding14/gap12, título16/20w700, small12/15w400 congap2; action12/30w600 ancho92.328125. SnapshotPNG ymetricsJSON guardados. Nativecard tenía título14/action500/lineheightinherited: cambiado16height1.25, secondary12height1.25/gap2, action600height1.25/letterSpacing0. Buttons shrinkWrap mínimo40 acordeCSSaltura40; requiere aceptaciónfísicadegesto, no afirmar44/48tapminimum.

SuiteGuardian+feedback+capture63/63 pasa12s32896/c08cb3; analyzer1456/9052aa limpio46.7s antecede sólo ajuste finalletterSpacing0 yanchomedido. Nuevoassertcapturerheight70 inicial falla actual75 enfilaconacción porwrap3líneas; corregidospacing ywidth92.328125. Recheckcapturerfinal28771/de316c pasa1test/5estados4s incluyendo altura70ambasfilasnormal, acciones/Notice/scroll200 y0writes. Format/diffchecklimpios; JSONSource yPNGnormal/200/footerfinales inspeccionados. Sinfuenteigual/igualdadpixelglobal: SourceMastercard1881 vsfixture5556, badgeModo prueba excluido; walletsSource simuladas no se copiancomoSDKdisponible.

Sourcefirstcardy121.39 vsFluttercapturayaprox125: encabezado/separaciónvertical continúa mediciónpendiente; no declarar pantallaidéntica porrowheight. Browsercerrado60e9d8; Vite97946CtrlCexit1esperado9329d4. Artefactos docs/design-reviews/parity-loop441. NoStripe/device/fullmobilerun/CM/push nuevos; próximoheadingy layoutglobal yaceptaciónfuncional/nativa.


### Loop442 — posición vertical del título Métodos, 3/10/2026

Base726eb6c; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. CSS h2line1.3/settingsheading18 ycontentpadding20/list-stackgap10 explicanposiciónfirstcard121.390625 medida441. Flutterheading heredaba1.55; fijado1.3. Assertgeométrico inicial observa121.0 (diferencia.390625 porredondeoText). ConstrainedBoxminHeight23.4 (=18×1.3) preserva fracción sinaltura máxima/recorte200. Primera compilaciónconconstConstrainedBox incorrecta falla; corregido constenconstraints/child, no se atribuyeverde a fallos.

FinalGuardian+capturer60/60pasa11s99586/b40248: ambasfilas70px, top121.4/201.4 dentro.1px deSource121.390625/201.390625 a377×852; cinquefixturesincluyennormal/200/waiting/footer, assertionsmessage/actions/0writes. Analyzer74704/b6ca0c limpio32.8s código final; format/diffchecklimpios. PNGnormalfinal inspeccionado y5artefactosparity-loop442 guardados; SourcePNG/metricsvigentes441 sirvenreferencia deSHAidéntico.

Posiciónvertical438/441 pendiente resueltaen esta geometría377; no pixeligualdadglobal/múltiplesanchos ni NativeSDK/wallets/fingerdevice aceptados. Sourcewalletsimulada/fixture55xx difieren intencionalmente de datoreal; no inventar disponibilidadnativa. Continúa matrizglobal/gestos/Stripeautenticado ydevice; noCM/push/schema/flags nuevos.


### Loop443 — regresión móvil integrada vigente, 3/10/2026

Basebcbb520aa883ee819332916e3c389c67e6ce29cf; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Comparación223Dartlib/test root/scratch0diferencias trasnormalizarnewline. Sin cambios de app durante ejecución. flutter test --no-pub completo562/562pasa3m13s7254/16999dexit0; logexterno Temp/dopmi-full-mobile-loop443.log. Supersede full558/423–424 parafuentesmóvilesactuales, no UIdevice/Stripe/Play/visualglobal atribuidos. No repetirgate sin nuevos cambios oincertidumbre concreta.

ADB read-onlyinventory29b85e vacío: no teléfono accesible ni comandosUI/envíoinstalación. Continúa requisitoAndroid físico/gestos, no confundir USBhistóricoconconexiónactual. Stripe reauthpendiente ySDKPK/MerchantID aún verificaciónefectiva. Últimoanalyze442final limpio32.8s, backend587/436 vigenteparaSQL/Savedcarddeploysinchangesposteriores.

RevisiónSourceSettings3458: cambioexperiencia actualizaestado+navigate inmediatamente, no añadir transiciónglobal/hover de testpanel. Clienteactual _SettingsHeading(profile_overview1570) height1.2; Source settings-heading18 hereda h2line1.3. Próxima comparaciónrenderizada Configuración donor/rescuer debe medircomposición/paleta ycorregir diferencia, antes declararparidad. Fullgate verde es evidenciafuncional local, matrizglobal/estados/nativo/gestos permaneceabierta. SinCM/push.


### Loop444 — etiquetas y encabezados de Configuración, 3/10/2026

Base4a3d07b; Source irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado al cierre. Edge377x852, Inter/fonts.ready, /settings en ambos modos: Métodos de pago y subtítulos medidos; h2 Ayuda/Cuenta18px line23.4/color15110d. Actualizadas etiquetas y subtítulos de pago/suscripción en ambos modos; encabezados donor1.3/color15110d. Rutas y funciones reales preservadas.

Pruebas profile_experience/profile_guardian/capturer finales19/19 aprobadas7s, handle92373 exit0. Analyzer42120 limpio55.9s exit0. Capturas normal/200/footer guardadas; inspeccionada200 sin desborde horizontal, contenido inferior requiere scroll. No equivalencia global de composición ni rescuer render acreditada; rows/iconos/paleta y geometría continúan pendientes. Full562/443 antecede estos cambios; backend587/436 vigente. Sin Codemagic/push/deploy; usuario ratifica envío sólo al completar objetivo.


### Loop445 — geometría y paleta de filas de Configuración, 3/10/2026

Base905ca44; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; referencia renderizada444 vigente. Variante standardSettings del componente compartido conserva estilo previo por defecto y usa border e6e2dd, título15110d, muted554e48, título16/20 y secundario12/15. Aplicada al menú donor y su cambio de cuenta; ayuda rescuer usa variante común, sin alterar verificación. Dos primeras corridas19 verdes preceden implementación efectiva de variante: script inicialmente sólo cambió constructor y luego falló al buscar clase siguiente al último State; corregido ámbito antes corrida final, no atribuirles verificación final.

Final19/19 aprobadas6s41795exit0; analyzer87746 limpio20.9s producciónfinal. Capturer adicional65148exit0 pasa1/1en3s con aserciones activas: a377x852 filas iniciales y88/170/264 y alturas70/82/82, tolerancia.1 frenteSource444. Cuatro capturas normal/200/footer guardadas; normal inspeccionada. Capturer modificado tras analyzer, sólo añade asserts. No pixeligualdadglobal: acceso a funciones reales debajo de cuenta y footer activo difierefixtureSource. Encabezados fraccionarios/paleta header/composición rescuer ygestos físicos siguen pendientes. SinCM/push/Stripe/schema/deploy.


### Loop446 — ruta correcta de Configuración rescatista, 3/10/2026

Base1a2b8c8; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. AuditoríaApp7572/7590 confirma dos rutas diferentes: /settings(Settings común) y /rescuer/settings(RescuerSettings verificación/redes/banco). Cliente /settings selecciona correctamente segunda por modo; capturas446 deben comparar /rescuer/settings, no Source444/general con accountMode cambiado. No sustituir menú real rescuer por donor. Rectificado standardSettings aplicado porerror445 a ayudarescuer; conserva tema151423/4f4e5c/e3e4ed confirmado DOM runtime. Donor variante445 permanece.

Edge377x852 /rescuer/settings verificada fuente, fonts.ready; heading/menú/switch/ayuda/cerrar métricas yPNG guardados. Flutter16/16 profile_experience+capturer40859exit0 aprobadas7s, incluyendo siete estados rescuer normal/200/scroll/footer/foco y cambio experiencia conpersistencia real simulada sólofixture. Analyzer11017 limpio33.4s final. Imágenes normales inspeccionadas: datos y textos backend difieren por funciones reales (Stripe seguro en vezCLABE simulada, publicaciones sujetas revisión), no borrar guardas para acercarfixture.

Diferencia pendiente concreta switch-card Sourceheight71; cliente InkWell48x48+padding16+border fuerza82. También disponibilidadfila bancaria/longitudtexto varía porbackend; no comparar posicionesabsolutas decontenido noequivalente. Siguiente corregir geometría switch manteniendo gesto accesible/semántica/180ms ytests persistencia. Browsercerrado2395e6, Vite67812CtrlCexit1esperado940148. SinCM/push/deploy/Stripe/device.


### Loop447 — geometría del cambio de experiencia sin reducir área táctil, 3/10/2026

Base3545f66; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado, métricas runtime446 switchcard71/track32x19 vigentes. RescuerDonorModeCard settings separa espacio de track32x19 de overlaytáctil48x48 centrado; overlay queda dentro Stack/card, right9 produce trackright17 respecto borde. Título16/20 y secundario12/15+gap2 conpadding16/border1 dan71px normal. Sin altura máxima: texto ampliado puede crecer. Perfil fuera Settings conserva estructura/layout previo. Semántica toggled/enabled, focusoutline y AnimatedContainer180ms/reducedmotion preservados; cambio confirmado por repositorio antesnavigate.

Final16/16 pruebas6s21054exit0. Capturerasserts nuevos comprueban card71, track32x19, margen17, área48x48 ycentrocoincidente. Pruebas profile_experience ahora tocan20px a derecha del centro (fuera track16 y dentro touch24): éxito/fallo ambosmodos sin alterar datos personales, fracaso conserva modo/ruta. Capturas sieteestados guardadas; foco normal y200 inspeccionadas. Analyzer86614 limpio34.9s producciónfinal, precede sóloaserts/nuevo punto de toque deltest. Primera16/16 antecede nuevosasserts; corrida final los ejecuta. Diffcheck limpio.

No teléfono/Stripe/nueva aceptaciónvisualglobal. Las fuentes reales siguen generando contenido/alto distinto deSourcefixture; objetivo entero sigue abierto. Próximo obtener fixture social equivalente ycomparar campos/hints/gestosdiálogo, continuar resto matriz. SinCM/push/deploy; envío sóloobjetivo completo.


### Loop448 — edición social modal con guardado real de borrador, 3/10/2026

Basecbc8c54; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. SourceRescuerSettings6170 abre diálogo porcampo; cliente sóloabría editorcompleto. Nuevo RescuerSocialDialog ycallbackopcional SettingsDataRow conservan editorcompleto para perfil no creado/banco. Modal social centra/tapbarrier/cancelar/cerrar/input autofocus; usa repository.save con siete campos preservados yexpected_version, sin transiciónpublicada ni autoaprobación. Instagram @handle se normaliza ahttps; Facebook requiereenlacehttps válido porcontratoservidor, no guardar nombres simulados. Propiedadcapturada validada contra identidad yrepo antes/despuéswrite; ListenableBuilder ocultacampossi cambia sesión. Busy impideguardar/cerrar repetidamente; traswrite sehabilitapop yawaitendOfFrame antescierre. Refresh yToast borrador/revisión enéxito.

Primera compilaciónfalló porimportNotice omitido; corregidocore/ui. Dos pruebas posterioresfallaron porfixtureidentityowner-one/profileidone: rectificadofakeuseridone sinrelajarguarda. Siguiente saveassertfalló0writes por tapantesrebuild delonChanged conbotónpreviamentedisabled; añadido pumpaltest, no atribuir falloaSQL. Captureinicial tapeditorbajoappbar porensureVisiblealignment0: cambiado.35, nocódigoUI alterado parafixture. Analyzer inicial advierteimportunused+curly: corregidos. Últimoanalyzer88483 clean28s producciónfinal; modificaciones posteriores sólotests/capture.

Final24/24pasa9s93597exit0/log Temp/dopmi-loop448-security.log. Cobertura: cancelar0writes, éxito preservanombre/bio/otrared/version3→4/draft; owner privado no expuesto; dominioFacebook impostor disabled0attempts; falla1attempt/0save conserva modal, retry2attempts/1save; logout escondetextfield sinwriteextra. Editorcompleto yswitchregresión siguenpassing. Capturer añade3estados modalInstagram normal/200 yFacebook normal; normal/200inspeccionados yguardados. NoSource modalruntime medido448 aún, no igualdad visual atribuida: foco input aúnheredacolortema ydisabledgrey necesitancomparaciónSource; letras/buttons ykeyboardreal pendientes. La aceptación PostgreSQL/usuario real de nuevo acceso noejecutada en448 (RPCexistente sinchanges); noStripe/schema/deploy/CM/push. Continuar mediciónmodal/gestos yrestomatriz.


### Loop449 — medidas renderizadas del diálogo social, 3/10/2026

Base9f8fc4e; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge377x852 /rescuer/settings abreInstagram, fonts.ready ymediciónDOM: dialogy279.90625/h292.1875/w345; input44/border e3e4ed/outline3rgba7841f2.3 offset2; Guardar36/font14/Cancel48/font16. Cliente448 tenía foco dorado/buttons48 yCancelradius14: scopeinputFocuscontorno3+offset2, border1gris/radius14, guardar36padding8font14 ydisabledpúrpura, cancelar48pill/font16. Nohovernuevo.

7/7 pruebas iniciales pasan6s54492; analyzer94668 limpio62.8s antes últimosajustes. Assertgeometry falla input42 vs44, no marcarigualdad porcardheight; mediciónFlutter title29/label18/hint19. Label17 conformeSource normal14 ypaddinginputvertical13 compensan decoraciónFlutter sinborderheight: inputfinal44. Final7/7pasa5s78979exit0 incluyendo aserciones activas: cardtopwithin.5/heightwithin1 deSource, input44/guardar36/cancel48 tolerancia.1. Cardcliente293 vsSource292.1875 diferencia.8125 porlineboxesTitle29 yHint19 redondeados; siguependiente, no paridadpixeldeclarada. Sourcefixture@Mariarescata enabled vsFlutteremptydisabled, no comparacióndatosidénticos atribuida. Nativefocus/normal y200 inspeccionadas,3PNGguardadas conSource/metrics. Analyzerfinal83851 limpio37.1s, diffcheck limpio.

Funcionalcancel/save/retry/hostinvalido/sessionhide siguenpassing en rescuer_settings_details; no remoteRPC/keyboardphone nuevo. Pendiente lineboxfraccionario/paletaheredadalabel-input/barrier ycomposicióndisabled equivalente, comparacióndelFacebookreal ygestosrestomatriz. Browsercerrado904545; Vite15468CtrlCexit1esperadoe07dac. SinCM/push/deploy; sóloenvíocuandoobjetivocompleto.


### Loop450 — paleta modal y cancelación con teclado, 3/10/2026

Base93a76eb; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. ReferenciaDOM/PNG449 siguevigente; CSSmodalbarrier rgba15110d.48/disabledopacity.5 ylabel/input151423. Cliente explicita coloreslabel/input, barrierwarm exactalpha.48 yOpacidad.5 sobrebuttonenteropurple/fbfbff (antes doscoloresalpha distintos); semántica ydisabledonPressed se conservan. No nuevohover.

Capturer añade validfixture @maria.rescata para mismo contenidoSource449, Guardarenabledassert, ademáskeyboard320 normal/200. Afirmacioneskeyboard compruebanCancel encimaheight−320 trasScroll.ensureVisible yScrollViewpresente; postcapturatoquepointer real delwidget enCancelar cierraModal yFake.saves0. Framekeyboard simulaInsets únicamente: no teclado Android real ni dispositivo aceptado.200inspection muestra contenido superior desplazado peroaccionesaccesibles. ValidPNG inspeccionado: card/botones/focusytexto comparables, underlay difiereporbackendURL/stripe/verification yscroll, no igualdadpixelglobal.

Inicial7/7 pasa7s51391; final7/7pasa6s13512exit0 con6fixturesModal(normal/valid/200/Facebook/keyboard/keyboard200). Analyzer31361 limpio30.7s producciónfinal, luego sólotests/capture añadidos. Capturegeom449 sigueactiva44/36/48/cardtolerancia1; diferencia.8125lineboxes no resuelta450. No cambiosSDK/schema/backend/Stripe/CM/push. Próximo mostrarhandlederivadodeURLenSettings conservandoURLreal ycomparargeometríaredes, lineboxes/keyboardfísico/restomatriz.


### Loop451 — usuario compacto de Instagram conservando enlace real, 3/10/2026

Base9b1f8b5; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado, SourceRescuerSettings muestra@usuario. Nuevo rescuerSocialDisplayValue extrae usuario sólo HTTPSinstagram.com/www.instagram.com sinuserInfo/puerto ysegmentoperfil permitido; Facebook/publicaciones/URLajena se mantienenliterales. Settingsfila yeditor usan presentacióncomún, persistencia sigueURLcompleta deRPCnormalizado. Sin datos deFacebookinventados ni nombrepúblico asumido.

Final8/8pasa7s19898exit0 incluyendo widgetcancel/save/owner/retry/logout ycapturer8fixtures (modal6 yfila normal/200). Fixture@Maria rescata produceInstagramrow70px assertactivo377; normalfila inspeccionada. Saveassert conserva URL https://www.instagram.com/updated_profile yotroscampos/version/borrador. Unit testhostimpostor/userinfo/rutapublicación/Facebook noenmascarados. Capturasguardadasparity-loop451; Source446/449 vigentes. DatosbancariosStripe/reviewhint yFacebooksinagregar sonrealfixture, no igualdadglobaldecontenido.

Analyzerinicial2info curlyenhelper; trascorregir detecta1info curlyencapturer: corregido. Final18345clean26.3s; cambiossóllaves desde8pass sin comportamientoalterado. Comparación224Dartlib/test root/scratch0diferencias bd978c. Full562/443 antecedemodal/menú444–451; siguiente fullregresiónmóvil para integración actual. Cardmodal.8125pxlinebox, keyboardfísico/Stripe/SDK/restomatriz siguenpendientes; sinCM/push/schema/deploy.


### Loop452 — regresión móvil integrada en ejecución, 3/10/2026

Fuenteexacta426f8743292ba673880c4c09a8ceb6f143917981;224Dartlib/test root/scratch0diferencias yconjuntosidénticos sinextras f2e96d. flutter test --no-pub full iniciado trascommit451, handle78989 confirmadoACTIVO985fee, logexterno Temp/dopmi-full-mobile-loop452.log; observado+48 a32s, noresultadofinal atribuido. No editarproducción ni reiniciarporobservacióntimeout; retomar mismohandle. Analyzer451clean26.3s ybackend587/436 vigentes; full562/443 sigue último completo hasta terminal452. SinCM/push/deploy.


### Loop452 — fallo integrado de animación y corrección de continuidad, 3/10/2026

Full78989 terminaexit1 fc06a2:563aprobadas/1fallo3m20s sobre426f8743292ba673880c4c09a8ceb6f143917981, log Temp/dopmi-full-mobile-loop452.log. Únicofallo rescuer_mode_control_test mode thumb180ms normal, esperaba0 alrebuild yrecibe13. Cambio447 retornabaContainer enprofile/Stackensettings y movía targetentreRow/Positioned: AnimatedContainer perdíaState y saltaba alfinal. No afirmarfullverde.

Corregido ProfileModeCard conStack/Positionedestable enambosmodos; Rowreserva32x19Settings/48x48Perfil, right9/17 conserva posiciones yaltura71/82 yárea48. MismoAnimatedContainer continúaEstado entreboolsettings. Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado d313a2. Target20/20pasa12s39493exit0(incluye15fixturesSettings ygeometría); testmovimiento ampliado retorno13→0 conmid90msEase y180endpoint, reducedmotion instantáneo ambasdirecciones:4/4pasa85375exit0. Analyzer96931 limpio28.7s producciónfinal, precede sóloasserts inversos. SourceRoot/scratch224idénticos antes primerafull; producciónnuevo sólo2archivoscopiados.

ADB d313a2 lista vacía, no UIAndroid/instalación. Card/modal/fracciones/SDK/Stripe/restomatriz permanecenabiertos. Siguiente repetirfullporfalloreal yfixproducción, no extrapolartarget20 a564integradas. NoCM/push/deploy.


### Loop452 — regresión integrada final aprobada, 3/10/2026

Recheck5996 terminalexit0 58648d:564/564 aprobadas3m47s, logexterno Temp/dopmi-full-mobile-loop452-recheck.log, códigoexactoaea2e21b7936ed5f2cc65728f223c4d4ec043409. Sin cambioslib/test durante corrida.224Dartroot/scratch idénticos después de terminar; fuentes yconjuntoscomparados previamente. Resuelve único fallo inicial deAnimatedContainer perdiendoState al cambiarContainer→Stack; mismaestructura ahora verifica180ms/reducedmotion ambossentidos en gatecompleto. Supersede full562/443 yprimerafull452563/1fallo; no aceptaciónvisualglobal/device/Stripe atribuida.

Últimoanalyzer452clean28.7s producciónfinal; testinverso añadido trasanalyzer pasótarget4 yfull564. Backend587/436 vigente sinchangesbackend en444–452. ADB452 vacío, no teléfono accesible; noCM/push. Próxima familiaready: revisar diálogo sociallineboxes/otrosestados ygestosrestomatriz, conservando fullverde comobase técnica.


### Loop453 — cajas de línea fraccionarias y cierre tipográfico, 3/10/2026

Base3e1e150; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado fdc585. MétricasSource449 vigentes: card292.1875/y279.90625, título28.59375/hint18.59375. Flutterredondeaba29/19 dando293. Nuevo _SocialLineText scopedtítulo/hint mide número real de líneas conTextPainter/estiloresuelto/textScaler/ancho disponible, reserva alturaCSSfraccionaria (fontsize×height×líneas), OverflowBoxpermitepintar glyphsenteros sinclip ni altura fija de una solalínea. Campo/acciones intactos. Actualcard292.2/y279.9 dentro.1 deSource, diferencia.8125 resuelta encaja/layout; no afirmar igualdad de todos los píxeles/glyphantialias.

Cierre reemplazaMaterialIcon porInter×22/w400/color4f4e5c/NoScaling; área48/IconButton/tooltipCerrar conservadas. right5.28125 derivaSource buttonwidth26.5625/right16 para mismo centro331.71875 y303.90625, asserts dentro.1. Primer8/8pasa9s53823; final8/8pasa9s34924exit0 conposiciónaltura exactas yclosecentro nuevosasserts. Capturer8fixtures conserva normal/valid/200/Facebook/keyboard320normal/200/fila normal200; keyboardCancelar pointer0writes ynoexceptions siguenpassing. PNGvalidfinal/200keyboard inspeccionadas;8artefactosguardados. Analyzer79944 clean45.5s final;format/diffchecklimpios.

Full564/452 correspondeaea2e21 anteriora453, no fullactualatribuir; último cambio estrecho tiene8targetfinal. No teléfono/Stripe/NativeSDK/config/schema/CM/push nuevo. Nativecaret/underlayfuentesreales difierenSourcefixture, no igualdadglobal de pantalla ni aceptación física. Siguiente continuar familias/gestos abiertos de matriz; no repetirgatefullsin nuevas razones.


### Loop454 — gestos de cierre y escritura pendiente del diálogo, 3/10/2026

Baseb52f538; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado ca617f. SourcecardstopPropagation/backdropclose y× yaimplementados; agregadas pruebascomportamiento realwidget, sin cambiosproducción. Nuevafakegate controlaRPCpendiente paraprobarinterleavings yduplicados, no simulaaceptaciónremota.

12/12pasa4s89758exit0: toque dentro mantieneModal; fuera/back deFlutterBinding/× cierra0attempt/0save. Pendiente: botónsave disabled, intentosrepetidos/barrier/back/close no cierran yproducen1attempt/0savehastarespuesta. Alcompletar1save cierra; logoutduranteawait ocultaTextField yrespuesta tardía no reapareceenotra sesión, elwriteoriginalpuedeterminar (no afirmar cancelaciónservidor). TestsURL/owner/retry/guardados previos siguenpassing. Analyzer5910clean22.6s ydiffchecklimpio. SinAndroidfísico/Sourcebrowser nuevo ni fullactual (564/452 previo453/454).

Siguiente diferenciaNAV concreta identificada lecturaSource158: BottomNav activa sólo item.path prefix; /rescuer/settings y/settings no coincidenPerfil. ClienteCommunityNavfallback /profile mantienePerfilactivo, visibleSource446nonevsNative453purple. Medir/confirmarSource ycorregir estado seleccionado sóloenSettings sinperdernavegadores/gestos/datos reales. Objetivoglobal/SDK/Stripe/device siguenabiertos, noCM/push/deploy.


### Loop455 — selección de pestañas en Configuración, 3/10/2026

Base5da686e; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado553350. CódigoBottomNav158 seleccionaporprefix de tabpath: Settingsgeneral/rescuer no coincideperfil; SourcePNG444donor/446rescuer revisadas yvigentes sinSourcebrowsernuevo. CommunityNav fallback /profile dabaPerfilactivo enSettings. ProfileFrame ahora selectedPath /settings sólo rescuerSettings flag (ambosmodos); demásframes/fallbacks/rutas/tabState noalterados. Ningúntabselected enSettings, Perfilse activa alabrirrootreal.

Testsnuevossemánticaambosmodos compruebanno selectedtrue dentroDopmiBottomBar, toquePerfil→/profile→sóloPerfilselected preservanombre/modo. Primera invocación18pasan/1fallocargatest/navigation_test inexistente: localizadoarchivo realdesign_navigation_test, nocambioapp parafallotool. Final27/27pasa12s89806exit0 (profile_experience/design_navigation/capture15rescuerstates). Analyzer11575clean24.4s final. Capture donor57594 1test/4statespasa3s; primerPNGnormalheadervacío detectadovisualmenteaunqueassertspasan, descartadoparaevidencia. Repeticiónsinchanges64280exit0 pasa4s yPNGnormalheadercompletoinspeccionado; no defectoApp atribuido ni renderingfísicoverificado. SóloPNGfinalesrevisadasguardadas8artefactos.

Full564/452 antecede453–455, targetsgreennofullactualglobal. RestoSettingschild (/settings/payment-methods/Sourcebilling/basicinfo) yheaderdonorwarm deben revisar suFooter/estilosporroute, sin cambiar globalfallback antes comparar. Semántica/rutas testwidget noAndroidreal. SDK/Stripe/device/restomatriz permanecenabiertos;sinCM/push/deploy.

### Loop456 — paleta del encabezado donor, 3/10/2026

Base707a27e; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. ProfileFrame standardSettings sólo mainSettingsdonor: título15110d/divisore6e2dd segúnCSS fuente; rescuer permanece151423/e3e4ed. Back.svg ya15110d como AssetIconSource. DetallesBasicInfo/PaymentMethods/BillingSource sinBottomNav, cliente también sinbarra; no cambiofallbackglobal.

18/18 pruebas perfil+capturador pasan8s92306exit0; analyzer4320exit0 limpio28.4s. CuatroPNG widgets normal/200%; normalygrande inspeccionadas, evidencia docs/design-reviews/parity-loop456. Diferencias datos/accesos reales/badge no copiadascomo simulación. Diffcheck limpio. Full564/452 antecede453–456. Objetivoglobal/StripeSDK/device pendientes;sinCodemagic/push.

### Loop457 — tarjeta de soporte HelpCenter, 3/10/2026

Base44562f9; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. /help usaHelpCenterScreen, noHelpScreenantiguo. SourceDOM377fontsready botón44/font16; tarjetaheading16/1.3/shadow0-8-22/.05. Clienteajustado botón44/font16/w600/padding11x18/ink0d0d0d +heading1.3+sombra aproximadaBlurRadius22. Repo/envíoreal/actions intactos.

PrimerFlutterroot noPubspec fallóprevio carga; retry scratch11/11pasa20s72566exit0;analyzer8072 limpio50.7s. Capturador11fixturesno11pantallasaceptadas;4PNGguardadas normal/200/modal. SourcePNG/DOMyclientnormal/large inspeccionados docs/design-reviews/parity-loop457. Full564/452 previo453–457; backend587/436 sin cambios. FooterSource puntosseparadores/espaciado y métricaschips siguencomparaciónpendiente, nomarcaigualdadglobal. Browserclosed/ViteCtrlCexit1esperado;sinCM/push/device.

### Loop458 — enlaces legales y footer HelpCenter, 3/10/2026

Base4a0c7cc; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; Source457render/DOM+App6550 vigentes. AvisoprivacidadHelp erróneo abría/account-privacy, corregido/privacy-notice legalexistente; accióneliminarcuenta mantieneadministración. Puntos·ExcludeSemantics, runSpacing6/paddingtop4 ybackcenter36/target48 segúnSource;nohover.

Primer test/analyzer importfaltante corregido; segunda5pass/2fail por tocar chipfuera viewport200% centro713>640. Tests ahora scroll/hittestprimertoque yscrollinverso alregresar. Rechecknuevo2/2pasa2s61220exit0; soporteycapturador5pasaron52421 pese2fallostestnuevo, producciónsinchangesposteriores. Analyzer10440clean36.5s previo sólo fixes tests. Tresenlacesabout/terms/privacy-notice ambosmodos a200%, vuelvencontemaseleccionado. Capturador13fixtures/4PNGconservados normal/grandefooter inspeccionados docs/design-reviews/parity-loop458. Full564/452previo453–458; noaceptacióninstalada/global niCM/push.

### Loop459 — ruta/modal soporte sin fade y gestos busy, 3/10/2026

Base2076fa0; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. App6567 conditional modalcenter sinCSStransition;3021warmbarrier48. Helper showHelpSupportDialog showGeneralDialog0ms/warm48 ybarrierlabel, HelpCenter yfixturesphoto/receipt compartenruta; guardasbusy/PopScope/repositorios intactos.

Format rechazóFuture<void?>, corregidoFuture<void> previo pruebas. Final11/11pasa12s60914exit0; analyzer40089clean35.5s.4casosruta prueban animation1primerframe/durationzero/color, insidepermanece youtside/back/× idle0writes; pendingno3dismiss/duplicate,1RPC+recibo+cierreposterior.4dialogretry/photo+2nav+capturador8fixtures;4PNGconservadosnormal/grandeinspeccionados. FixtureRPCnoentregacorreo/phone. Sourcebrowsernone;codigoSHAactual. Full564/452previo453–459. Próximo medirvisual soporteSourcepadding/campos/×/botones; objetivoSDKStripe/device/matrizglobal abierto. SinCM/push.

### Loop460 — soporte campos/close/color en ambosmodos, 3/10/2026

Base3638567; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. SourceViteEdge377fontsready SourceDOMcard505.59375/y173.203125,select45/input44/textarea96/closecenter331.71875/relative24; paddingcoincide. Native45/44/96 corregidos paddingdropdown10.5/case13, adjuntarwhite/bordere6e2dd, ×Inter22/w400/noScaling/right5.28125/hit48. SoporteHelpcontact/send/receipt yellow/ink0d0d0d explícito ambosmodos segúnHelpplainSource.

Capturador añade rescuer normal/200 ygeometría normalambosmodos campos±.1/card±.5(closeactual506vs505.594 títuloceil)/closecenter/color. Primera fallóassertyellow undefined, corregidoconColorfuente. Final11/11pasa9s18087exit0;analyzer57741clean42.4s.10fixtures,6PNGsourceJSONguardados docs/design-reviews/parity-loop460;normaldonor/rescuer/granderescuer inspeccionados. SourcePNGblur vsnativefoco explícito, noigualdadglobal. Próximo focusSourceoutline3offset2 vsnativepurpleborder2 + teclado/selectorreal. Browserclosed/ViteCtrlCexpectedexit1. Full564/452precede453–460; SDKStripe/device/matrizglobal abierto;sinCM/push.

### Loop461 — outline inputs soporte y teclado, 3/10/2026

Base57abd9d;Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. ReferenceFocusOutline optinshowForTouchFocus defaultfalse; sóloCaso/Mensaje soporte true, outline3/alpha.3/offset2/extrectinflate5/radio19;focusedBordergray1 reemplazapurple2. Sinlayout/hit/semanitic changes.

Target5427:13pass/2fail por dragcentrocampo contralímitekeyboardstillvisible. Cambiogestotestmargin+downscroll, noregresiónproducción para forzarpass; finalruta6/6 pasa2s49757exit0.4dialog+4modecontrols+capturador12fixtures(support10prev+2keyboard),1test pasóoriginal.15casosúnicoscubiertosseparados no15suitetotalgreen. Analyzer10595clean36.5s antes sólofixgesturetest. Nuevosnormal/200 muestranoutlineexactRect,sendaboveinset300,dragdismissTestTextInput,retaintext+1RPC+receipt.5PNGconservadasnormal/large/keyboard/keyboardlarge/rescuer inspecciónnormal/keyboard200 docs/design-reviews/parity-loop461. viewInsets no teclado físico niSourcefocusruntime; CSSsourceevidenciaactual.

Full564/452antes453–461; siguiente fullgateactual porcomponentcore optin;objetivomatrizglobal/StripeSDK/device abiertos. SinCM/push.

### Loop462 — regresión móvil integrada actual, 3/10/2026

Fuente exacta2bba0c25345e701d8b76e2933ae5969db989218d incluye453–461;226Dart lib/test root/scratch mismo conjunto+contenidoSHA256 normalizandoEOL,0differences antes/después. Sin cambiosproducción duranteejecución. flutter test --no-pub scratchfull579/579 pasa3m43s;handle11575terminalexit0/27c854, logTemp/dopmi-full-mobile-loop462.log. Supersede full564/452 anteriorAEA2E21 para códigoactual. Analyzer461 limpio36.5s fuenteactual, sólofixgestotestposterior; backend587/436 vigentesinbackendchanges.

ADB devices-l otra vezlista vacía97785d; no instalación/gestosfísicos verificados. Fullgate noaceptación visual/completionglobal niStripeactual. LecturaConsent no nuevoerrorprivacy: enlace Privacidad y eliminación de cuenta intencionalmente/account-privacy, noAvisolegal;no alterar como si fuerafooterHelp. Objetivoactualpermaneceparidad todaspantallas/gestos reales; próximaSourcefocusruntime/selector/estados de ayuda yrestomatriz. SinCodemagic/push.

### Loop463 — selector de temas soporte y preservación del borrador, 3/10/2026

Base693fb9b, producción2bba0c25345e701d8b76e2933ae5969db989218d sinchanges. Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; Appselector onChange sólotema yenvío IDs. Doschecks nuevos normal377x852/200320x640: menú outside/back cierranlista noHelpSupportDialog, conservanmensaje/caso0RPC; selecciónGuardián conservaambos ysubmitpayloadguardian/message/case_name correctos1RPC+recibo. Todos8ruta pasan2s33021exit0;analyzer40313clean23.2s. Repositoriofixture/rutanativaFlutter no selectorAndroidfísico ni aceptación visual SourceOS.

Full579/462sobreproducciónactual siguevigente;doschecks nuevos posteriores noatribuir581full. ADBvacío previo462/StripeSDKglobalpendientes. Próxima diferencia interacciónSourceCSS: Helpbotones no:active/splash; nativeMaterialripple/overlaydefaults posible, capturarpressheldSource/native antes modificar scoped. Nohoverrecrear. SinCM/push.

### Loop464 — held/cancel/tap en chips HelpCenter, 3/10/2026

Base84dfaaf; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. CSSchip blanco sinactive/hover;isactiveposteriorselection. Capturador2fixturesheldnormal/200: startGesture150+frame,InkWellstatescontrollerpressed comprobado antesPNG, cancelblanco/rutaHelp, tapcompletofff8e0. Baseline59917exit0 yheld66505exit0;imagenprimerconsultaanteshandleterminalfaltaba,seesperómismohandle norestart. Comparación cropnormal20..210/195..223 con458:0changedpixels/4335whiteambos;hipótesisvisualripple noconfirmada,nocambiarproducción por suposición.

Final75330exit0 capturador1test/2fixtures2s;analyzer37819clean28.1s. Normal/grandeinspeccionados docs/design-reviews/parity-loop464 conbefore/final. NoSourcepressruntime niAndroid/todointervaloanimación aprobado. Full579/462 vigente producción2bba0c2sinchanges;Fuentehelper/capturador posterior463/464nofull581. Matrizglobal/StripeSDK/device pendientes;sinCM/push.

### Loop465 — auditoría coberturaactual y GuardianHistory directo, 3/10/2026

Base5b35c52;Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. InventarioregexRoute/path/specs literalesmultilínea:55Source/51Flutter,349fixtures/34URLsinquery,relativeupdateIdconparent. Primeraextracción328ignorótuplasmultilínea; archivo finalcorregido, no328atribuidoinventariototal. Rutasacceso capturadorseparado; extensiónproducto sincapturadirectanoimplicadefecto. Auditoríaactual docs/parity-route-audit-2026-10-03.md yroute-inventory465 mantienenobjetivocompleto.

GuardianHistory new4fixtures normal/200/datos/empty /guardian/history;HistoryCaptureGuardianpreservafinancerealcliente.11/11pasa5s5128exit0(10history+capture1), analyzer52112clean35.7s. Normalyempty200inspeccionadosPNG465:marcologoHeadingFraunces/eyebrowgenérico vscomposicióncompactafinancialdetalle. Es extensiónrecibosprivadosnocontrapartidaSourceURLexacta;próximoadaptarframe coherente/preservarreceipt/checkreturn/refresh/errors. Myadoptions/updatesmanagement/editorotrosreadycaptures. Producciónsinchanges/full579/462 fuente2bba0c2vigente, nonewfull. Matrizglobal/SDKStripe/device aúnabierto;sinCM/push.


### Loop466 — marco compacto del historial de ciclos, 3/10/2026

Producción c9bd74c; referencia a3c969cd9103fd46dc5cd886999912526ce75efb. ContributionFrame reemplaza marco genérico; conserva etiquetas de prueba, recibos, propiedad, paginación y devoluciones. Regreso al origen o /guardian. Capturador cuatro estados pasó; normal inspeccionado. flutter analyze limpio 33.4 s; 12/12 guardian_history_test.dart verdes en 3 s (dopmi-loop466-history-final2.log). Primera prueba esperaba asentamiento de consulta Guardian fuera de alcance; bombeo acotado corrigió sólo la prueba. Full579 anterior en 2bba0c2 no acredita cambio466. Sin aceptación instalada, push ni Codemagic; envío al completar objetivo según usuario.


### Loop467 — publicaciones propias, nueve estados de captura, 3/10/2026

Base b9495d3/producción c9bd74c; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Fixture mine sólo capturador con borrador/revisión/correcciones/publicada, vacío/error. Nueve estados normal200+contenido desplazado200 verifican acceso al contenido/reintento. Final14330 exit0,1test/9capturas5s. Analyzer65499 limpio35.3s antes adición scroll/assert; final compila. Primera aserción sobre lazy fuera de viewport corregida desplazando sólo estados content. Normal/vacío200/contenido datoserror200 revisados. Source integra adopciones en Mis Casos, no /my-adoptions literal. Encabezado slogan Fraunces domina viewport; siguiente alinearlo con composición Inter de listado sin reconstruir lifecycle. Sin cambios producción/aceptación instalada/Codemagic/push.


### Loop468 — cabecera de publicaciones propias alineada al listado, 3/10/2026

Base fcc561b; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. MyAdoptionsScreen pasa de logo/slogan Fraunces a cabecera Inter24/1.25/-.48 e introducción12/1.5, SVG regreso origen o perfil. Al200 cabecera a ancho completo, base20 escala40 para conservar palabras completas; resto escalador intacto. Acciones, estados, propiedad, comentarios, paginación y refresh conservados. Capturador añade regreso perfil normal/200.

Primer const Semantics inválido corregido, captura título al200 partía palabra y se corrigió composición antes cierre. Final77171 exit0,40/40 en14s community/publicationframe/personality/capture9estados; analyzer79129 exit0 limpio34.7s. PNG before/final docs/design-reviews/parity-loop468, normal/grande/error inspeccionados. Ruta extensión sin SourceURL literal; Source Mis Casos/CSS h1 guían composición, no aceptación equivalente total. ADB inventario vacío; full579 anterior2bba0c2 no prueba nueva producción. Próximo administración/editor avances. SinCM/push; objetivo sigue activo.


### Loop469 — captura administración/editor de avances, 3/10/2026

Base8bdb7c4; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado.12fixtures reales de rutas administración/editor con listado draft/submitted/changes_requested/approved, vacío/error y editor nuevo/correcciones/error, normal200. Capturador87475 exit0,1test/12capturas6s; analyzer13933 exit0 limpio26.3s. Lista/editornormal yerror200 revisados docs/design-reviews/parity-loop469. Source no tiene editoravances independiente; EditCaseModal distinto. Marco genérico domina200; siguiente detallecompacto con funciones privadas preservadas. Inspección restore/save sugiere readerror permite saveupdate=null creando nuevo en vezrecuperación: probar/bloquear/reintentar siguiente, no inferir RPC aceptada. Sinproducción/Codemagic/push.


### Loop470 — marco y recuperación de avances, 3/10/2026

Base4f30e12/Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. ContributionFrame opt-in rescuer conserva defaults; administración/editor compactos18/divisor e3e4ed/SVG/padding16-20-16-32, cards margen sólobottom8, chevron sóloeditable. Editor bloquea campo/fotos/save/submit si restorefalla o submitted/approved, reintenta cargando mismo id/version, descarta late afterdispose; nuevo permitido. SQL/repo/ownership sinchanges. ListView onDrag dismiss keyboard.

8/8 editor final18418 exit0/3s, log dopmi-loop470-editor-gesture-final2.log; normal200recuperaciónmisma versión7, readonly2estados, nuevo, late ydragconinsets400sinwrite.19otros (history12/publichistory6/capture1 con12PNG) pasaron conjunto42048 donde2nuevos tests fallaron scroll; no27suite única. Analyzer19717clean30.8s antes últimos cambios sólotests. Correcciones test importprovider, selectorScrollViewvsTextField, finderlastlazy ysimulaciónkeyboard/finderdespuésscroll. Producción noforzadaporfallostest. PNG470/before inspecciónnormal/editor/error200. Extensión sinSourceeditorliteral. Full579 anterior2bba0c2 no prueba producción nueva; próxima regresión completa acumulada. SinCM/push/aceptación física;objetivo activo.


### Loop471 — regresión móvil integrada actual, 3/10/2026

Fuente exacta0b40f0c3e094cc1dd4560ed613a2ae635e7cfdf9;227Dart lib/test root/scratch conjuntos+SHA256 normalizandoEOL idénticos antes/después,0differences. flutter test --no-pub full591/591 pasa3m12s,handle62464 terminalexit0/c5438c, Temp/dopmi-full-mobile-loop471.log. Supersede full579/462 e incluye466/468/470 y nuevas pruebas. Analyzer470 limpio30.8s antes últimos ajustes sólo de test/scroll; full compila/ejecuta finales. Producción no cambió durante gate.

Source localHEAD a3c969cd9103fd46dc5cd886999912526ce75efb y App.tsx/styles.css unmodified. Refs remotas Dopmi ba9f897f3fa418e952b98e4c604cffe468a8aa95/design-foundation e4f4e8585612389e7193310c7fdfe137b61c7762; PR6 GitHubMCP open/draft/unmerged/mergeable mismohead/base. gh no disponiblePATH, sinlecturaCLI atribuida. Auditoría de rutas actualizada con467–470, mantienefamilias/global/StripeSDK/device pendientes; siguiente cuenta/consent/privacy/Connect/archivo privado. Noaceptación visual global por591widgettests;sinCM/push/basechange.


### Loop472 — cuenta/consentimiento/privacidad, captura directa, 3/10/2026

Base297a512/producción0b40f0c3e094cc1dd4560ed613a2ae635e7cfdf9/full591; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado.9fixtures normal200/contenido final200 tres rutas settings/account, consent, account-privacy. Primer consentimientofixtureyaaceptado volviócorrectamentehome; se corrigiófixtureterms/privacy null/adultfalse yseexigeURIexacta. Capturas finales realesreemplazan inicialesincorrectas. Final67159 exit0,1test/9capturas5s; analyzer89506clean45.3s antesfixture/URIassert, finalcompila.

Opcionesnormal/grande/contenido yconsent/priva normal revisados docs/design-reviews/parity-loop472. TítuloCuenta yprivacidad se trunca200; próximoencabezadocompactoadaptable conservandofilas/nav. Consent/priva marcosgenéricos pendientesextensiones sinSourceURLliteral. Términos sí incluyeresumen/enlaceAvisoexternal, no enlace roto atribuibleporlabel. No eliminación/aceptación real ni cambiosproducción/Codemagic/push.


### Loop473 — título completo cuenta/privacidad, 3/10/2026

Base611569f; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. RescuerAccountOptions cambia a ContributionFrame rescuer con title18 adaptable200, padding16-20-16-32 y mismoCommunityNav4/filas. Frame añade bottomNavigationBar opcional null, defaults financieros intactos. Capturador normal/200abreprivacidad, vuelveopciones, regresaperfil ycompruebamodorescuer; FakeRescue sólocapturador, noServerWrites.

42/42 directed75793 terminalexit0/10s (profileexperience/settingsdetails/guardianhistory/capture9), analyzer37081 limpio44.7s. Opcionesnormal/grande/contenido revisados PNG473+before; títuloelipsis200resuelto. ProfileRowpalabraslargas200todavíaparten; noaceptaciónglobal. SourceCSSBackbutton40/slot44/padding16 centro36 vsContributionleading60/padding16 centro38, candidato2px para contrastecomún siguiente, nomediciónbrowsernueva. Full591471fuente0b40f0c3e094cc1dd4560ed613a2ae635e7cfdf9 anterior, no fullnuevo. PróximoConsentPrivacy/encabezadocomún/Connectarchivo/matrizglobal. SinCM/push/deviceacceptance.


### Loop474 — privacidad compacta y errata de navegación473, 3/10/2026

Basef811904; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. AccountPrivacyScreen usa ContributionFrame title18/padding16-20-16-32/paletaexperiencia/regresoalorigenoperfil sinbarra, preserva medición/proveedores/eliminación/guardas/mensajes. NoSQL/repo/SDK/deletereal.

Supersede atribución473 de navegación: bloque estaba dentro adoption-drag, accountcondition imposible;42tests/PNG válidos pero no probaban ese recorrido. Corregido README473 y código; movido al final común, contadores expected/actual exigen2/2 seleccionados. Primer intento ejecutado falló hitTestable por ensureVisible sin pump; corregido sólo capturador. Final46585 exit0,1test/9capturas7s dopmi-loop474-capture-final3.log: opciones→privacidad→opciones→perfil modorescuer normal200 realmenteejecutados.10otros identidad/social pasan44373 (bundle11/11 concapturadorprevio). Analyzer68820clean33.6s antes cambios sólo de instrumentacióncapturador, compilaciónfinalcompleta. Privacidadnormal/grande/contenido inspeccionadosPNG474/before. Full591 anterior0b40f0c3e094cc1dd4560ed613a2ae635e7cfdf9 no nuevofull. Consent/encabezadocomún/Connectarchivo/matriz pendientes;sinCM/push/deviceacceptance.


### Loop475 — consentimiento y escala de enlaces, 3/10/2026

Base6cc7d1b; Source a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. ConsentScreen reutiliza marco/encabezado/casilla de acceso, términos y aviso separados de gestión privada de cuenta. Lectura conserva casilla y no acepta; confirmar envía una aceptación. WidgetSpan ya escala al hijo: se elimina la segunda escala interna del enlace, conservando texto200. Heading optativo24 grande evita cortar palabras. Extensión sin SourceURL independiente, no aceptación literal atribuida.

Final57841 exit0,27/27,15s (authsheet/consent/identity/capturador3), dopmi-loop475-mobile-final3.log; analyzer38149 limpio24.1s, dopmi-loop475-analyze-final4.log. Error previo de argumento context en withNoTextScaling corregido. PNG normal/grande/contenido final revisados, baseline472 conservado. Full591471 anterior a473–475; pendiente nuevo gate integrado. Sin aceptación/eliminación real, push ni Codemagic. Próximo encabezado común/Connect/archivo privado/matriz global y gestos/animaciones/Android; envío sólo al completar objetivo.


### Loop476 — regreso compartido medido, 3/10/2026

Baseaa46a62; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge377x852/settings fonts loaded: TopBar377x68, back40x40 x16/y13.5, icon20 centro36/33.5; título Inter70018/22.5 centro188.5/33.5. ContributionFrame padding16→12 conserva leading60 y aumenta hitarea44→48, centra SVGx36. Final45405 exit0,1capturador/2estados2s, normal200 revisados. Primer comando raíz sinpubspec no ejecutó tests; cwd corregido. Sin nuevo test redundante para ajuste2px; análisis pendiente siguientegate. Browser cerrado/Vite59600 detenido; no push/Codemagic. Próximo Connect/archivo privado y matriz de gestos global.


### Loop477 — cuenta de cobro, captura directa, 3/10/2026

Base52eebe5; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado.9fixtures /connect habilitada/pendiente/error normal200/contenido200, URI exacta y CTA alcanzable/hittest; fixture sólo autoriza lectura sintética connect_status. Final49761 exit0,1test/9estados dopmi-loop477-capture-final.log. Analyzer55578 clean42.7s antes tresfixtures/URI/hittest finales, cubre producción475/476. Capturas inspeccionadas, marco logo/Heading genérico pendientecompacto; no SourceURL literal independiente. Sin backend real/Stripe/onboarding/depósitos/push/Codemagic. Siguiente ConnectFrame y archivo privado/matriz global.


### Loop478 — cuenta de cobro compacta, 3/10/2026

Base77c8640; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. ConnectFrame compacto rescatista18/List16-20-16-32/introducción14, pop al origen o /settings/account; conserva estados/depósitos/refresh/onboarding y corrige monedaMXN duplicada.13/13 payments/capture93672 exit0/6s; final29501 exit0,1capturador/9estados6s con seis regresos normal200 y modo rescatista conservado, contadores6/6; moneda normal/contenido200. Checkgrande inicial buscaba depósito aún no construido por ListView: se desplazó antes del assert, no cambio producción. Analyzer6649 clean29.9s antes sólo ajusteassert. PNG finales/before477 inspeccionados. Sin SQL/Stripe remoto/push/Codemagic; no SourceURL literal independiente/fullnuevo. Siguiente gate integrado/archivo privado/matriz global/gestosAndroid.


### Loop479 — regresión móvil integrada, 3/10/2026

Fuentee11eb8dd1389b5d92d8d36d8d56ddc5ec33727a6; fullfluttertest17646 exit0,592/592,4m23s dopmi-full-mobile-loop479.log.227Dart lib/test raíz/scratch SHA256 normalizadoEOL idénticos antes/después y sin cambios durante run, evidencia mobile-consistency.json. Incluye producción473–478 y nueva regresión escala475; toolcapturadores aparte. Configpython16/16, analyze478clean29.9s misma producción. Sourcea3c969cd9103fd46dc5cd886999912526ce75efb App/stylesclean; untrackedcapture-access.mjs conservado. Remotosbaseba9f897f3fa418e952b98e4c604cffe468a8aa95/heade4f4e8585612389e7193310c7fdfe137b61c7762 yPR6open/draft/unmerged/mergeable comprobadosGitHubMCP. ADB vacío. Auditoría rutas actualizada cuenta/consent/privacy/Connect; archivo privado yfamilias/gestos/Android siguenpendientes. Sin push/Codemagic/aceptaciónvisualglobal; no cerrar objetivo por592tests.


### Loop480 — archivo privado y recarga, 3/10/2026

Base41a87ab; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado.9fixtures abren Verarchivo1 desde solicitud sintética/path extra, URI privada exacta, recarga renueva acceso mismo path y regresan a solicitud sin saves, counters9/9. Capturador47609 pasó1/9; bug real setStatecallback retornabaFuture corregido con request sync/async observado/bloquevoid/keyFutureBuilder descartaimagenprevia durantevalidación.6tests finales81497 exit0/1s normal200 prueban pendiente/revocación/reintento/freshPDF antes launchMethodChannel simulado. Fallos previos scrollambiguo y montajegrande lazy corregidos sólo capturador/test; analyzer34810clean26.9s antesmontajefinal. PNG revisados marcosgenéricos pendientes481. Full592479 anterior a este fix; no nuevofull/device/nativePDF/SQL/push/Codemagic. Próximo marco visor privado yfamiliasglobales/gestos.


### Loop481 — visor privado compacto, 3/10/2026

Base9b160f1; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. VisorContributionFrame rescuer18/List16-20-16-32/intro14.45/backpopoperfil, conserva seguridad/recargaPDFimagen480.58648exit0,7/7,12s seis pruebas+capturador9, counters9regresos y tresrecargas; analyzer16729clean27.5s. PNG final/before480 revisados. Extensión sin SourceURLliteral; no launchPDFnativo/Storage/Android/fullactual atribuido. Full592479 anterior480/481. Sin SQL/push/Codemagic. Próximo familias Source/gestos/movimiento.


### Loop482 — movimiento y galería real, 3/10/2026

Base225f983; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; Edge377x852/case/rocky Foto2src cambia/activo1/ceroanimaciones; Foto3observerclickreal delta7.8ms, transition/animationDuration0s. CapturaSource inspeccionada. Fortalece rescue_test ruta real selección teclado y touch:377/0pixels primerpump e isScrollingfalse; final94784exit0,1/1,2s. Gate34673exit0,36/36,9s rutas/onboarding/discovery/nav/Guardian/gallerylifecycle actuales; analyze4410clean34.7s. No producción modificada/fullnuevo/gesto físico. Browsercerrado/Vite14151detenido. Switch180CSS sólo paneltestSource excluido. Auditoría rutas incluye480/481; full592479 anteriorvisor. Alcanceglobal/matriz/Android pendientes; sin push/Codemagic.


### Loop483 — perfil público contra Source ejecutado, 3/10/2026

Base94d9d8c; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge377x852/rescuer-profile/luna fontsloaded medidas yPNG actuales: avatar96y104/bio42/redes42/pestañas40/actividad39. Nativeperfil completo capturadonormal200: redes41→42, paddinghorizontal+1porbordeCSS, pestañas línea1.2/reservabordeContainer; finalfila40(tabwrapper72incl32margen)/actividad39y465, Sourcey464.578. IG139.9648vs140.5469; diferencia.5821 permanece y redondeo líneas de identidad <1px documentado, noigualdadabsolutaatribuida. No cambio conteos/enlaces/RPC/privacidad.33/33 community/capture71342exit0/12s antes últimosajustes; final66096exit0,1capturador/2estados3s conJSONmedidas; analyze91123clean31.1s antes sóloContainerfinal, compilación finalverde. PNG before/final/Source inspeccionados. Browsercerrado/Vite53256detenido. ADBvacío, reconexión solicitadaasync, sigue trabajoindependiente. Full592479 precede480/481/483; sinfullnuevo/push/Codemagic/aceptaciónglobal. Siguiente pestañas/estados públicos ymatrizglobal/gestosAndroid.


### Loop484 — perfil público y cobertura actual, 3/10/2026

Basece65628da765ec9cd48753ff2c6a0196a4526e89; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado.6capturas coldloading/error/no disponible normal200, sin identidad antes de datos; cuatro recuperaciones reales dewidget/provider normal200 mismas lecturas owner, contadores4/4. Final77247exit0,1test/6estados5s; analyzer2404clean25.7s antes sólocleanupduplicados/assertnombre, finalcompila. PNG inspeccionados, no Sourceequivalencialiteral de estados de servicio.

Inventarioactual401fixtures únicas/55Source51native/44paths capturados/38patrones normalizados. Primerparse403 fallóunicidad: case-detail-amount/large duplicadasidénticas, segundopar retirado sin perderestado; capturador evitaoverwritePNG. JSONdistingueinitial_uri/captured_path privado ytemplates; no401aceptaciones/diferencia55−51pantallas. Producción no cambia484, full592479 anterior480/481/483. Auditoríaactualizada; Androidreconexiónpending, SourcePUBLICtabs/matriz/gestos siguenpendientes. Sin backend/SQL/push/Codemagic.

### Loop485 — pestañas públicas y pasada global del capturador, 3/10/2026

Baseb3bbd7b; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Capturador completo6323 exit0,1test/401specs únicas,3m13s antes del cambio; perfil28 anterior6925 exit0,15s. Edge377x852/rescuer-profile/luna pestañas reales: adopción345x336/foto343x258/acciones343x76/save44/historia259x44; caso345x378/acciones151.5x38; reporte345x426.65625/campo297x112. Nativehistoria antes ajustado al texto, corregido Container reserva borde1 y minimumSize ancho infinito en columna finita. Final38676exit0,3/3,11s dos regresiones favoritos y capturador2normal200; PNG finales inspeccionados, palabras completas200. Analyze9033exit0 clean128.5s. Evidencia comparison.md/adoptions-final*.png. No401aceptaciones visuales ni fullposterior atribuidos; full592479 histórico precede esta corrección. ADBvacío; browsercerrado/Vite49950detenido. Sin backend/SQL/push/Codemagic; instrucción vigente envío sólo al objetivo completo. Continúan familias visuales/gestos y aceptación instalada.

### Loop486 — filas accesibles de cuenta, 3/10/2026

Basea6555bf; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Captura actualaccount-access-options200 mostraba Verificació/n por leading/trailingListTile. ProfileRow desde escala1.5 coloca icono/contador/flecha arriba y título/subtítulo a ancho completo, sin reducir fuente; normal misma composición y destinos intactos. Gate90723exit0,18/18,9s (17perfil/experiencia+1capturador3estados), counters2regresos opciones→privacidad→opciones→perfil. PNG normal/inicial200/final200 inspeccionados: Verificación una línea, demás palabras completas. Analyze94589exit0 clean44.2s. Evidencia parity-loop486 before/final/README. Extensión productiva sin Sourceliteral, noaceptación global por accesibilidad; pasada401485/full592479 preceden486. Sin backend/SQL/push/Codemagic; sigue objetivo completo/familias/Android y NativeStripe test pendiente.

### Loop487 — conversación y medidas de editor, 3/10/2026

Base55b831d; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; Edge377x852/messages/luna fontsready. Header70/editor79/input297x46x16y790/send40x46x321y790; texto14/21.7/hora10normal12. Envío realSourcebotones limpia campo/desactiva enviar/nuevaburbuja sinanimación269.09375x76.375. Capturador registra métricasnormal200/rescatista, native normal/rescatista editor exacto Source;200adaptable104/66. Gate12902exit0,33/33,13s (32community+capturador3), teclado simulado/emptydisabled/paging/ambiguoussameid/logout existentes incluidos. Sin producción cambiada: datosmedidos descartan corrección de altura/línea hora. JSONyREADMEparity-loop487; browsercerrado/Vite55094detenido. Full592479/pasada401485 no posteriores atribuidos; listaSourceyregreso chat siguenpróximo cruce, Android/NativeStripe pendientes. Sin backend/SQL/push/Codemagic.

### Loop488 — Mis match compacto, 3/10/2026

Base6db5ff3; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge377x852/messages emptyoff/MeGustaRocky víaUI: header341x46y78/h1line30.8, favorites341x32.796875y136/photo148y168.796875/chatsy332.796875. Native headerpadding/height46/font28.1.1/gaps20-12 yfavtitulo16.1.3/margin12/buttonvisualsinpadding/foto148+bottom4/gapChats12 corregidos. Preserva búsqueda real48, diferenciafilaChats sigue documentada; no declararlista equivalente/regreso nuevo. Headeronly39646exit0,33/33,14s antesfav; final85021exit0,33/33,13s (32community+capturador14estados home/all/empty/photos/search/focus normal200). PNGfinalnormal/all200/emptyinspeccionados. Analyze54870exit0 clean;browsercerrado/Vite85920detenido. Evidenciaparity-loop488 README/capturas; sinSQL/backend/push/Codemagic/aceptaciónglobal. Próximo preservar búsquedasin desplazarmarcoChats y comprobar regreso/scroll, Android pendiente.

### Loop489 — regreso de conversación con lista desplazada, 3/10/2026

Base90731a6; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Nueva regresión DopmiApp/router real con20threads sintéticos: scroll→thread12 porfila→borrador→handlePopRoute; URI/messages/mismaScrollPosition/offsetexacto/fila12hitTestable/zeroenvíos. Gate4205exit0,1/1,2s. Sin producción cambiada, no dedo/Android/tecladonativo/aceptaciónglobal. READMEparity-loop489; búsqueda/filaChats488 y demásfamilias siguenpendientes. SinSQL/backend/push/Codemagic; full592479 no actualizado por1test.

### Loop490 — fila Chats y búsqueda compacta, 3/10/2026

Based91a6ee; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado, DOM488 vigente sin nuevosruntimeSource. StackbloqueChats columna título16.1.3/margen12/searchPositioned48 eliminafila48+gap18, icono alineado sin reducirbutton. Query/foco/lista/paging/back preservados. Primer intento UTF8falló sineditar,63330verificóprevio no490; segundoanclajeifinteriorformatrejected, sóloarchivoownreconstruidoHEADycorregido. Gate20569exit0,34/34,16s (33community incluyeback489+capturador14) antesúnicoicontranslate; final60657exit0,1/14,8s. Analyzer96360exit0clean31.8s. PNGnormal/search200inspeccionados: etiqueta flotante200 truncada siguependiente, no globalacceptance. ADBvacío. SinSQL/backend/push/Codemagic. Full592479 precedeproducción; siguiente gateintegrado y familias sin reducir objetivo.

### Loop491 — búsqueda ampliada y full actual, 3/10/2026

Labelpropósito completo al200/headerexterno ycampoBuscar,normalunchanged;27410exit0,1/2capturas4s/PNGinspeccionada. Producción92473d8ed76412abef22b8f620ef69de304d015d. Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado;remotoba9f897f3fa418e952b98e4c604cffe468a8aa95/heade4f4e8585612389e7193310c7fdfe137b61c7762/PR6open/draft/unmerged/mergeable comprobados. Configpython16/16. Primerhashdiff sólo communitytestformato489, copiadoown:228iguales. Full8389exit1,598/1,3m43s búsquedagranderesultadonobuilt. Testlocalizaresultadoscroll+limpiarvisible;26860fallócierredirecciónarriba,diagnóstico91589close/field0 offset151.7379. Direcciónabajo localizacontrol trasconsulta ydiagretirado,89055exit0,2/2,2s,sin quitarassertsquery/results/close. Analyzer77292exit0clean193.9s sobre92473d8 antes sólo test.

Fullfinal74849exit0,599/599,3m29s exactoa8eb5a7fd375f020411a68c749f7edf69ff11423,228Dart lib/test raízy scratch hashEOLidénticosantes/después sinchanges duranteejecución. Evidenciamobile-consistency.json/README/searchPNG yactualiza parity-current-review. Supersede full592479; pasada401485 no actualposterior486–491. No nuevobackend/SQL/push/Codemagic/Androidnativeacceptance. Siguiente pasada401actual ycrucefamiliasSource/gestos, objetivo completo sigueactivo.

### Loop492 — estados actuales y contraste por familias, 3/10/2026

Base2f10ee1docs/produccióna8eb5a7fd375f020411a68c749f7edf69ff11423; Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Capturador71984exit0,1test/401fixtures únicas,2m58s; manifest401PNGexistentes/frescos/hash y228Dartroot-scratch idénticosal full599491 sin cambios. Supersede pasada401485, no401aceptaciones. Inspecciónactualnotificacionesnormal200 vsSource425datosdiferentes/426fixtureequivalente misma composición; historial vsSource427 preservaestadoreal/filas/evidence noVisa/resultadosfake. Aporte/Guardianhistoryactualesinspeccionadossinregresiónnuevadetectada;2%runtimeTEST sigue actualsegúndocsproductdecisions82/86 actualizacióneconómicaposterior3%/atribucióncostosindefinida no inventada. No nuevodiseñoproducción/SQL/backend/push/Codemagic/deviceacceptance. README/manifest/2PNG ycurrentreviewactualizados. PróximoAdoptar/Apoyar/navegación ymatrizgestos runtimeSource, nogatesrepetidos sin changes.

### Loop493 — entrada de tarjetas contra Source, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge377x852/puntero demuestra salida280 y siguiente entrada250 cubic(.22,1,.36,1), opacidad1; probe filtrado source-next-card.json. Cliente antes entraba instantaneo; adopcion/apoyo comparten entrada ±420/±18, reduced inmediato y arrastre directo. Tests9/9 handle2337exit0; expectativa delta local corregida por rotacion sin ampliar tolerancia. Full6893exit0,601/601,3m37s; analyzer90804exit0clean183.8s; fuente c57974a77c25745a5af0436ac8ea950727c088c9,228Dartroot/scratch iguales y hashes sin cambios. PNG SourceAdoptar/Apoyar comparados; ubicacion real preservada/fotosfixture distintas. Supersede599491. No backend/SQL/push/Codemagic; gestos fisicos/StripeSDK/paridad global pendientes.

### Loop494 — tarjeta de apoyo durante entrada, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Dos pruebas nuevas normal/reduced verifican llegada de oportunidad de apoyo, gesto durante entrada, delta local, cancelación, monto real y CTA. Gate10343exit0,44/44,11s. Fuente 22aa0da0375630f097b340abf3d20834b38491fa sólo tests; producciónc57974a/full601493 vigente, no603full. ADBvacío. README494/currentreviewactualizados; sin backend/SQL/push/Codemagic. Pendiente contraste global y teléfono/StripeSDK.

### Loop495 — apertura y descarte de filtros, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge377x852 diálogo345x586/x16y133/radio24/sin animaciones; selección Hembra cerrada fuera/reabierta no persistida. Cliente ya coincide; nueva prueba primerpump/routeanimation1, Atrás y fuera descartan sin query. Gate53912exit0,5/5,5s, fuente b91ff21f1510f8bc47b0054d2056ff1dfa8bb0a5 sólo tests. Full601493 sobre producciónc57974a vigente; tres tests494/495 posteriores no604full. Sourceprobe/README495; navegador/Vite cerrados. Sin backend/SQL/push/Codemagic/aceptación física.

### Loop496 — regreso por pestaña sin repetir entrada, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado, sin runtime nuevo. Prueba avanza a segunda adopción/Favoritos/Adoptar y conserva misma instancia Motion con traslado0 primerpump y125ms. Valida continuidad móvil establecida, no atribuye índice React persistente. Primer82346exit1 sólo SemanticsHandle al terminar; dispose explícito corregido. Gate25863exit0,21/21,5s, fuente 6e45b396b414c858c588377a6ab589ec80ffd793 sólo tests. Full601493 producciónc57974a vigente, no605full. README496; sin backend/SQL/push/Codemagic, físico/StripeSDK/global pendientes.

### Loop497 — indicador de Perfil renderizado al presionar, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. Edge377x852/rescuer/profile down real matriz0.98/timing120ease delay0; sombra hover excluida. Prueba existente fortalecida primerpump/ScaleTransition final120 normal200; cancelación/totales/destinos preservados. Gate88104exit0,4/4,1s, fuente a52bc936853546f737e0327caeefa74d23a20d0c sólo tests, sin fallo previo ni cambio producción. Full601493 vigente. JSON/README497, navegador/Vitecerrados. Sin backend/SQL/push/Codemagic; físico/StripeSDK/global pendientes.

### Loop498 — curva exacta de introducción, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; CSSonb-in450/cubic(.22,1,.36,1)/opacity0→1/Y10→0 ykeys por slide inspeccionados, sin runtime nuevo. Prueba existente fortalece midpoint225 opacidad/desplazamiento exactos sin quitarinicio/final; gate97218exit0,18/18,5s con navegación/intenciones/texto200/reduced. Fuente 4e14d63b20b6806ebc4327f096d871101c420e3d sólo test. README498; full601493 producciónc57974a vigente. No aceptación global/física, backend/SQL/push/Codemagic.

### Loop499 — Nuevo compacto Mis casos, 3/10/2026

CSS Sourcecompact34/padding8x12/radio14 y referencia histórica inspeccionados, sin Source runtime actual. Nuevo pasa de visible48 a34 y conserva padded48 con desplazamiento adaptable200.14060exit0,32/32,11s con6capturas; Ahem visible corregido con Inter explícita,91480exit0,1/6capturas,4s normal200 inspeccionados. Analyzer5176exit0clean48.6s antes sólo fontFamily. Fuente 6746ccd7a1f0f7a656c3dcdb4d272e84128ca20a. Full601493 anterior a cambio499 no gate vigente completo. README/PNG499; próximo geometría runtime/hitarea y gate integrado. Sin backend/SQL/push/Codemagic/físico.

### Loop500/501 — geometría actual y gate integrado, 3/10/2026

Recupera entrada500 no escrita por OSError22OneDrive sin pérdida de ledger. Sourcea3c969cd9103fd46dc5cd886999912526ce75efb; runtimeEdge377x852 Nuevo91.21875x34/x269.78125y20/radio14/Inter14w500. Test63919exit0,2/2,1s normal200 comprueba superficie y target≥48/toque inferior abrePublicar. Fuente8270386d3b531907d4618ebd4358ebd221a88146. Full16280exit0,607/607,3m54s; analyzer72747exit0sinincidencias; config14208exit0,16/16.229Dart raíz/scratch/hash iguales antes/después. Supersede601493. README/hash500/currentreview actualizados. Remotoba9f897/e4f4e858 reconsultado sin push. No backend/SQL/Codemagic/aceptación física o visual global; continúa contrastefamilias/StripeSDK.

### Loop502 — cobertura y movimiento vigentes, 3/10/2026

Auditorías route/motion tenían gates históricos592479/481341 como encabezado. Reconciliadas con fuente8270386/full607500,229Dart, config16/análisis y pruebas493–500; contratos/límites separados por interacción. No vuelve a ejecutar tests sin cambio ni atribuye401aceptaciones. RuntimeSource de apoyo494/onboarding498 no inventado; regreso496 es continuidad móvil no índiceReact. Próxima acciónlista CASE expansión/cierre realSource+Flutter primerframe/evidencia/foco. Sin producción/backend/SQL/push/Codemagic; objetivo/físico/StripeSDK/global abiertos.

### Loop503 — expansión/cierre de gasto público primerframe, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; Edge377x852/case/rocky clickreal cierra/abre y MutationObserverdetailsfalse/true/chevron90/270/sinanimaciones. Ruta DopmiApp apoyo→caso prueba primerpump cierre/apertura, RotatedBox1/3 y evidencia pública ausente real sin copiarfakeSource. Gate63057exit0,26/26,6s, fuente 85c5ec7a526423246842d21d0bb4bc229e12d1db sólo test. JSON/README503; browser/Vitecerrados. Full607500 vigente para producción, sinbackend/SQL/push/Codemagic/físico/global.

### Loop504 — carrusel Apoyar y regreso real, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. CSSrail overflowauto/gap16/sinsnap inspeccionado, no nuevo runtimeSource. Nueva pruebaDopmiApp8casos fake drag280noabre/offset>0,tapCaso4URIcorrecto/backmismaposition/offset/hitTestable.62652exit0,1/1,2s; fuente b7474d2801a55ee3f0a46cc40ec74150d9540f48 testformato posterior sin lógica. README504, full607500 producción vigente anterioratest. Sin backend/SQL/push/Codemagic/físico/globalacceptance.

### Loop505 — resumen rescatista gradiente/activo de marca, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado CSSwallet146 ySVGoriginal. CssLinearGradient146 reemplazadiagonalalignment, walletSVG20decorativo sustituyeMaterial y singular1casoactivo. Saldos/revisión reales preservados, no bolsillofake.80661exit0,27/27,7s antesprecargaSVG/iconoausente;16672exit1assetbundleobsoleto;archivo1556bytespresente,mtimepubspecscratch refrescado sincontenidocambiado.70874exit0,1/12fixtures,7s PNGicono visibleinspeccionado. Analyzer94451exit0clean36.1s antes sóloprecargacapturador. Fuente 7c656986ceb0381e1f25f4ba507675eca8e95469. Full607500 anteriorproducción505;integradoactualpendiente. Sinbackend/SQL/push/Codemagic/físico/global.

### Loop506 — resumen Source ejecutado y full608 vigente, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; Edge377x852/rescuer/fontsready146/radio28/padding20/wallet20x20/x36y112.1875 comprobados, no saldosfake. Browserclose77803os10060 luego31728exit0cerrado;Vite36110interrumpido esperado. Full49826exit0,608/608,3m49s fuente c1e18561e4717c5dacd13eaf3437b07630bb8170;230Dart/SVGwallet raíz-scratchhashiguales antes/después. Incluye503/504/505; supersede607500. Analyzer505clean36.1s misma producción anterior sóloprecargaSVGcapturador, no nuevaejecución506. README/hash/probe/currentreview. Sinbackend/SQL/push/Codemagic, global/físico/StripeSDKpendientes.

### Loop507 — pendientes mensaje icono/contador reales, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado, código/CSSpendingActions inspeccionado sin nuevo runtime. icon-chat-yellow.svg copiado exacto, unreadbadge amarillo reemplazaflecha; Rowintrinsiccentraextremo/iconarriba. No conteo3 ni conversaciónsinrespuesta simulados. Gate53044exit0,27/27,8s con12capturas; analyzer20509exit0clean37.6s. PNGnormal200 inspeccionados, pendientes200 fuera viewport noaceptadosporimagen. Fuente 3df438102d102af9d1b3706b225fc13e95f58112. Full608506 anteriorproducción507,integradoactualpendiente. README/PNG507;sinbackend/SQL/push/Codemagic/físico/global.

### Loop508 — pendientes200 y toque real de contador, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado sinruntime. PNGactions/evidencelarge507 ya desplazados a pendientes inspeccionados: título/CTA/counter completos, segundaevidenciafuera noaceptadacompleta. No nuevacaptura508. Pruebaexistentehome mantienefinanciero/pendientes/actividad y añade toque scopedbadge2→/messages.39516exit0,26/26,6s fuente 77633dd6b1cc18c46c0331c0c6ead054718b2755 sólo test/producción3df4381unchanged. README/PNG508, full608506 anterior507 integradoactualpendiente. Sinbackend/SQL/push/Codemagic/físico/global.

### Loop509 — símbolos pendientes/actividad y gate en curso, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado, códigoAssetIconalertcircle20/donationin20 inspeccionado. Assets existentes bytesexactosSource; reemplaza Materialalertblack/flecha genérica, decorativos.77565exit0,27/27,8s con12capturas,PNGhomeactual inspeccionado. Fuente 9e76c84fb1cc66e1dcf1c0c7ae6d770dc054c63c. Full87957/analyzer46356 iniciados no resultados terminales todavía;logs509,230Dart/cuatroSVG root-scratchiguales. README/hash/PNG509. Full608506 anterior507/509 no gateactualcompleto. Sinbackend/SQL/push/Codemagic/físico/global.

### Loop510 — gate actual608 y análisis terminal, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado;ADBvacío. Full87957exit0,608/608,3m54s; analyzer46356exit0clean205.7s exacto 9e76c84fb1cc66e1dcf1c0c7ae6d770dc054c63c.230Dart/cuatroSVG raíz-scratch/hashsinchanges antes/después. Supersede608506, incluye507/508/509. README/hash509/currentreviewactualizados. Próxima pasada401actual por cambios493/499/505/507/509 posteriores492; no401aceptaciones ni reabrirfinancieroH5yaaceptado. Sinbackend/SQL/push/Codemagic/físico/global.

## 3/10/2026 — Paridad loop511, capturas completas actuales

Capturador81489 exit0,2m57s:401fixtures únicas regeneradas,401PNG frescos/hashes registrados.230Dart y cuatroSVG idénticos raíz/scratch al gate509 sobre9e76c84fb1cc66e1dcf1c0c7ae6d770dc054c63c;full608/analyzer509 siguen vigentes. Inspección directa de owned-cases y rescuer-home-actions-large; no aceptación visual atribuida a401estados. Referenciaa3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. docs/design-reviews/parity-loop511. Objetivo activo, contraste global/Android físico/StripeSDK pendientes. Se conserva instrucción del titular: Codemagic sólo al completar, sin avances intermedios.

### Loop512 — contraste real del selector de publicación, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado; Edge377x852 /rescuer/publish inspeccionado con captura511. Fondo computado blanco sin imagen, aunque regla histórica define degradado: se conserva blanco. Tarjetas x24/ancho329/y298.203125 y417.59375; composición/iconos/navegación concordantes. Evidencia PNG/README512; emoji advertencia diferente por renderizador, no aceptación de formularios posteriores ni físico. Sin cambio producción/gates nuevos;608509 vigente. Sinpush/Codemagic hasta objetivo completo.

### Loop513 — paridad del contorno en acciones de fotos, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado/runtimeEdge377x852 inspeccionado. Botones CSS122.515625/179.203125x36 incluyen borde fuera del padding12; Flutterpadding13 reserva2px horizontales. Fuente88d7ffb.13786exit0,7/7,7s seispruebas+capturador2fixtures. NormalPNGinspeccionado;large muestra controlesfuera viewport,no aceptación atribuida. Analyzer38969 iniciado todavía pendiente. Full608509 anterior cambio. Evidencia513. Sinbackend/SQL/push/Codemagic/físico/global.

### Loop513 — resultado terminal del análisis

Analyzer38969 exit0, sin incidencias sobre88d7ffb; duración exacta en log513-analyze. Supersede la anotación pendiente513 anterior. Sin cambio adicional ni full nuevo.

### Loop514 — formulario en orden de referencia y fotos200%, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado/runtimeInformaciónbásica inspeccionado. d340113 reordenaHistoria/Salud/Social antes de tamaño/personalidad/raza/ubicación, conservados todos. Testpickerescala1/2,320x640,scroll/hitTestable/cancelación/draftprivado.24960exit0,7/7antesorden;87605exit0,8/8,8sposteriorcon2capturas.56471analyzerexit0clean. Nativeinformaciónnormalinspeccionadahistoriadespuésedad; iconografía/espaciado/camposreales noaceptadosglobalmente. README/PNG514. Full608509anterior513/514. Sinbackend/SQL/push/Codemagic/físico;objetivoactivo.

### Loop515 — símbolos de opciones y campos requeridos, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado/Appinspeccionado/runtime514previo.6875515 añade required y leading en sexo/especie adoptante con Material16/SVGspecies20 ya presentes en casos, preservesenums/lock/datos. Unicodeinicialsincaracteres descartado;PNGfinalnormalinspeccionadocorrecto.1533exit0,8/8,5s con2fixtures.62670finalanalyzerencurso;59005previo noanalysisfinal. README/PNG515;full608509anterior513–515. Identidadpixel/emojiAndroid/global/StripeSDKpendientes. Sinpush/Codemagic.

### Loop515 — análisis final terminal

62670exit0 sin incidencias sobre6875515; log515-final-analyze. Supersede anotación en curso515. Sin cambios adicionales.

### Loop516 — altura de campos contra runtime, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb runtimeEdge377x852 medido: nombre345x38/y190,textarea345x78,etiqueta17,h228. babb22a lineheights20/16,17/14,15/12/gaptítulo16/historia3 conservando4000;4e5240e paddingvertical9reservaoutlineinterior.83014exit0,18/18,11s final,2fixtures normalPNGinspeccionado.71787finalanalysisencurso,55264prepadding noanalysisfinal. Source-metrics/PNG/README516. Full608509anterior513–516;datosreales/counter/selección diferentes noaceptaciónpixelglobal. Sinbackend/SQL/push/Codemagic/físico.

### Loop516 — análisis final terminal

71787exit0 sin incidencias sobre4e5240e; log516-final-analyze. Supersede anotación pendiente516. Sin cambio adicional.

### Loop517 — título de revisión y gate completo en curso, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado/AppheaderTitleinspeccionado.4571644 títuloRevisatucasoenstep2;44173exit0,8/8,5s con2fixtures,normalPNGinspeccionado.230Dart/cuatroSVG raíz-scratch idénticos/hashantes. Full65835/analyzer45360 corriendo, sinresultadoatribuido todavía. Logs517/README/hash/PNG517. ADBvacío;noaceptaciónfísico/global/StripeSDK. Sinbackend/SQL/push/Codemagic. Full608509pre513–517hastaresultadonuevo.

### Loop518 — regresión integrada609 y corte actualizado, 3/10/2026

Full65835exit0,609/609,3m45s; analyzer45360exit0 limpio195.8s,fuente4571644.230Dart/cuatroSVG raíz/scratch/hashsinchanges antes/despuésverificados. Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado/App/styleslimpios. Supersede608509, incluye513–517/picker200. ManifestREADME517/currentreview/routeauditactualizados. Capturas401511 anteriores513másdirigidas, no401aceptaciones. ADB517vacío; resumenfinal/global/físico/StripeSDK pendientes. Sinbackend/SQL/push/Codemagic.

### Loop519 — resumen contra runtime actual, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb runtimeEdge377x852reviewinspeccionado,tarjeta345x214/4filas/label15/value24/padding17borde/gap8.5c67401 quitaheadingextraantesFotos/label15/padding17;conserva6filasreales yPorconfirmar, noListaadopciónsimulada.35358exit0,8/8,6s con2fixtures,normalPNGcompactoinspeccionado.98456analyzerencurso;full609517anterior519. README/source-metrics/PNG519. HeaderEditar/Salud/Social/global/físico/StripeSDKpendientes. Sinbackend/SQL/push/Codemagic.

### Loop519 — análisis terminal

98456exit0 sin incidencias sobre5c67401; log519-analyze. Supersede pendiente519. Sin cambios adicionales.

### Loop520 — encabezados de revisión compactos y target48, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado/CSSinspeccionado/runtime519previo.4c31cac heading20/16normalStack/touch64x48/textEditar17/14;largeRowancho84a200. Testreviewlinks toca bottom-2≥48/abre edición/conservadata/submittedocultaacciones.33127exit0,8/8,6s final2fixtures,normal/largePNGinspeccionados Editarcompleto.9937analyzerexit0clean. README/PNG520. Full609517anterior519/520;Salud/Social/global/físico/StripeSDKpendientes. Sinbackend/SQL/push/Codemagic.

### Loop521 — tarjetasSalud/Social con estados reales, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado/AppCSSinspeccionado/runtime519previo. b42cd9f summaryTraitCard/Checkreadonly títuloinside/padding17/label17/helper15/indicadortri preserveunknown ycaretexto. Test320/200true/false/nullguardado→reviewreadonlysinmutación→back;91537exit1headerlazy,testscrolluntilvisiblefix;38849exit0,8/8,7s con2fixtures;2515analyzerexit0clean25s. NormalPNGSaludinspeccionado;Socialfuera viewportnoaceptado,alineacióncasillapendiente. README/PNG521;full609517anterior519–521. Sinbackend/SQL/push/Codemagic/físico/global.

### Loop522 — Social capturado/alineación de casillas, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado/CSSgap8check16/runtime519previo. c92bc24 checkboxtranslate-4 conserva24leading/16marca/8gap y ciclos/readonly. CapturadorSocialnormal/largeañadidos, inventario522403unique/55Source/51native/38patterns/44paths, no403capturasfull.11462exit0,8/8,6s con4fixtures;96354analyzerexit0clean. NormalSocial3filascompletasinspeccionadas;largeprimerafila+segundaparcial,tercerafuera noaceptada. README/PNG/inventario522. Full609517anterior519–522,401capturer511anteriordosfixtures. Sinbackend/SQL/push/Codemagic/físico/global.

### Loop523 — Socialchildren200% alcanzable y gate integrado en curso, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado sinruntime nuevo. bb3cd91 test/capturer,productionc92bc24unchanged:320/200ensureVisibletercerafila rectlabeldentroScrollable/readonly/touchesnoconservedata,backscroll.17353exit0,8/8,6s con2fixtures; PNGlargeúltimafilacompletainspeccionado,complementa522. Inventario403522unchanged.230Dart/cuatroSVG/capturerraízscratchigualesantes. Full56544/analyzer48063encurso,noresultadoterminalatribuido. README/hash/PNG523/currentreviewactualizados;full609517pre519–522. Sinbackend/SQL/push/Codemagic/físico/global/StripeSDK.

### Loop524 — fallo de expectativa antigua corregido y repetición, 3/10/2026

Full56544exit1,608aprobadas/1fallo,3m38s; analyzer48063exit0 limpio183.1s sobrebb3cd91. Único fallo community_testliteralRevisaantesdeenviar removido519 conformeSource.17e59ee cambia aRevisatucaso, preserva assertsguardadofallo/authoredMora/reintento/draft/noexception,productionc92bc24unchanged.1189exit0,1/1,2s dirigido.230Dart/cuatroSVG raíz/scratch iguales/hashantes;full90121/analyzer79611encurso logs524, noresultadoatribuido. README523terminal/524/currentreviewactualizados;Sourcea3reconsultado523. Sinbackend/SQL/push/Codemagic/físico/global/StripeSDK.

### Loop525 — gate actual609 aprobado y capturas403 en curso, 3/10/2026

Full90121exit0,609/609,3m46s; analyzer79611exit0 limpio222.6s fuente17e59ee.230Dart/cuatroSVG raíz/scratch/hashsinchanges antes/despuéscomprobados. Supersede523608/1fallo y609517, incluye519–523 +literal524. Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultado sin cambio. ManifestREADME524/currentreviewactualizados. Capturadorcompleto403525 iniciado después delgate,noresultadoatribuido aún,log525-all-captures. Sinbackend/SQL/push/Codemagic/físico/global/StripeSDK.

### Loop526 — capturas403 actuales y base de gastos, 3/10/2026

Capturador58342exit0,1test/403fixtures únicas,3m05s;403PNG frescos/hashes/source230DartcuatroSVG unchanged respecto17e59ee/full609524. Manifest525/runREADME/currentreview actualizados,supersede401511,no403aceptaciones. Sourcea3 runtimeEdge377x852 EvidenceRockyVet dialog345x598.984375/radio28/drop295x148/icon28 inspeccionado conNativeexpense-evidencefresco525. OriginalUploadSVG/frame presentes; colores/lineheightEvidenceCard quedanparaajuste, no copiarcashback/Coins/video niDisponiblefundedsimulado. README/PNG/metrics526. Sin producción/backend/SQL/push/Codemagic/físico/global/StripeSDK.

### Loop527 — colores/tipografía EvidenceCard contra computedStyle, 3/10/2026

Sourcea3c969cd9103fd46dc5cd886999912526ce75efb reconsultada/runtimeEdge377x852:ink151423/muted4f4e5c (corrigeinfer616174526),helper12/16/label14alto17/hint12alto15/gap6/max240/drop148/radio24/icon28.41f53af EvidenceCard actualizaestilos/Columnmincentrada/nooverlay mantienecallbacks12files5MBprivado/public roles.91835exit0,13/13,6s con2fixtures;90487analyzerexit0clean67.8s. Normal3controlesPNGinspeccionado,largeparcialnoaceptacióntotal. Source-metrics/PNGREADME527 ycorreccióndoc526. Full609524/403525pre527. Sinbackend/SQL/push/Codemagic/físico/global/StripeSDK.

## 2026-10-03 — Loop 528: paleta de campos y resumen de gastos

Producción 37c5ecbb10c532494ad51c159ea1ac19a0974bb7. ExpenseField, ExpenseReview y ExpenseFrame usan ink151423/muted4f4e5c de rescuer-theme; evidencia Source527 y remote irlanda/apoyar-detalle-perfil a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Cambio exclusivamente de colores; importes, privacidad, controles y persistencia intactos. Test91880 terminal exit0:13/13,15s (12 pruebas de campos/archivos + capturador); 17 PNG expense-* generados. Analyzer31685 terminal exit0 sin problemas,50.8s. Captura information inspeccionada; capturas adicionales archivadas sin afirmar aceptación visual completa. Full609524 y capturador403525 preceden527–528. Objetivo global y dispositivo pendientes; sin push ni Codemagic, por instrucción final-only del usuario.

## 2026-10-03 — Loop 529: interlineado de campos de gastos

Producción 23515073c62ef71a8a91d273665a61bab89acf46. ExpenseField usa 14/17 para etiquetas y controles de una línea, frente al anterior14/19.6; multiline mantiene1.4 de unlock-textarea. CSS actual unlock-field/unlock-input y métricas normales de Source527; Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Sin cambio de contenido, privacidad, límites, importes ni persistencia. Test5981 terminal exit0:13/13,13s; 17 PNG expense-*; analyzer25325 terminal exit0 limpio30s. Captura information normal inspeccionada y archivada, no aceptación global ni de todos los estados grandes. Full609524/capturador403525 preceden527–529. Objetivo continúa; sin push ni Codemagic.

## 2026-10-03 — Loop 530: controles del diálogo de gastos

Producción 037754f1f81070aa021e9781329a7cb8540af93e. ExpenseFrame separa controles del padding24 del contenido, con inset4 y área48; desplazamiento visual vertical4 para back20 y2 para close16 corresponde a unlock-back/close top14+padding4, manteniendo targets móviles. El contenido conserva padding24 y header48. Source CSS7739–7786 actual y remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. No hover ni cambios a callbacks/privacidad/dinero. Test8171 terminal exit0:13/13,12s; capturador17 expense-*; analyzer72340 terminal exit0 limpio31.5s. Dialog normal y submitted normal inspeccionados; large archivado sin afirmar aceptación. Full609524/capturador403525 anteriores a527–530; objetivo global, gestos físicos y aceptación instalada pendientes. Sin push/Codemagic.

## 2026-10-03 — Loop 531: regresión integrada actual

Fuente 5799915dd2e8d1bb524d3076779080791ede69f5, producción037754f. Full54358 terminal exit0:609/609,3m48s; analyzer83628 terminal exit0 limpio217.7s.230Dart/cuatroSVG raíz-scratch iguales antes/después y sin cambios durante gate; manifest531. Incluye estilos de gastos527–530. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. ADB531 vacío. Capturador completo403525 precede527–530, complementado por17capturas de gastos530; no pasada completa nueva ni aceptación visual global. Sigue contraste de familias/gestos físicos/StripeSDK. Sin push ni Codemagic.

## 2026-10-03 — Loop 532: encabezado de verificación

Producción 3b4557f5838af8f84a38e7430d4159fd8545283b. VerificationFormFrame: título18/22.5 y tracking-.36, de h1 global1.25/-.02em + topbar font18 Source styles38/107, antes18/27.9. Source App4117 usa TopBar en formulario; remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Conserva área de regreso, privacidad y moderación real; no reproduce verificación/redes/banco simulados. Test57834 terminal exit0:5/5,10s (cuatro recorridos + capturador ochofixturesverification-*); analyzer68698 terminal exit0 limpio46.3s. Captura320/200 inspeccionada: título completo en dos líneas y regreso visible, no aceptación física/global. Full609531 precede este estilo; capturas completas403525 preceden527–532. Sin push/Codemagic.

## 2026-10-03 — Loop 533: texto de campos de verificación

Producción 0eee37a6ceb9b75511a3fd29052f6bb88fdfaa3b. Source form-stack labels12/600, input fontinherit/padding12,14/min44; textarea min112, CSS2210–2220, SHA remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. verificationField cambia texto16/1.55 a12/600/15 y etiquetas15; dropdown mismoestilo. InputDecoration constraints min44/112 no garantiza altura del borde: PNG normal inspeccionado muestra controles y textarea todavía menores que superficieSource (parte del espacio pertenece al layout de TextField). **Siguiente ajuste listo: altura visible del borde, no sólo minconstraint.** No declarar formulario completo equivalente. Callback/controladores/límites/privacidad/moderación intactos. Test95351 terminal exit0:31/31,14s; capturador8fixturesverification-*; analyzer85225 terminal exit0 limpio30.2s. Normal/320200 inspeccionados; large muestra sólo parte inicial del formulario. Full609531 anterior532–533. Sin push/Codemagic ni aceptación física/global.

## 2026-10-03 — Loop 534: altura visible de campos de verificación

Producción 7e1a04376c76434f9da31aacc24130154aa0f1b6. Resuelve diferencia detectada533: InputDecoration minconstraints ampliaba layout exterior sin ampliar borde. Retiradas y padding calculado según texto escalado: una línea mínimo44 centrado; multiline top12 y bottom restante hasta112, creciendo cuando el texto escalado requiere más. Source input min44/textarea min112 CSS2214–2218, remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. PNG normal inspeccionado y píxeles borde e3e4ed en x188: nombrey273..316=44, teléfonoy355..398=44, experienciay486..597=112. No cambio de líneas máximas, datos, validación ni privacidad. Test33193 terminal exit0:31/31,9s; capturador8verification-*; analyzer26465 terminal exit0 limpio25s. Large archivado, no afirmar revisión de campos fuera viewport. Full609531 anterior532–534. Objetivo global/físico pendiente. Sin push ni Codemagic.

## 2026-10-03 — Loop 535: edición y regreso de verificación320/200

Fuente fd8387bdb7507584a910c7d186c32f5b32ea4f9f. Prueba existente fortalecida: teléfono/experiencia autorados, scroll al multiline, InputDecorator>=112, resume sin lectura que borre borrador, salir y Seguir editando, scroll real de regreso y ambos valores conservados. Primera84250exit1,2pass/1fail: revela overflow real104px del AlertDialog y lookup de teléfono no construido al bajar; analyzer3413exit0 limpio24.1s anterior arreglo. Producción agrega scrollable:true al diálogo confirmLeave de verificación; test regresa con scroll al teléfono antes de leerlo, no debilita aserciones. Repetición68781 terminal exit0,3/3,3s; analyzer27125 terminal exit0 limpio24.4s. No nuevofixture ni captura; prueba de widgets/router reales con repos fake, no dedo físico/aceptación visualglobal. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Full609531 anterior532–535. Sin push ni Codemagic.

## 2026-10-03 — Loop 536: estilos de documentos de verificación

Producción f634c772830c4e004f72bc07dec8cdcff7af67f4. verificationDocument radio18, padding15(reserva borde1+CSSpadding14), strong16/19/700, helper12/15 y gap2 según card-row/styles4569 y nav-row-text6122 actual; remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Conserva privacidad, subida real, apertura/retirada y límite12. Test86611 terminal exit0:11/11,8s; cuatro verification recorridos,seisfilechecks ycapturador8verificationfixtures. Analyzer63845 terminal exit0 limpio18.7s. Capturas existentes formulario no enfocan Documentos: **no prueba visual nueva de esa sección**. Siguiente acción lista: capturas Documentos normal/200 y comparación de botón/disposiciónhorizontal Source frente a columna nativa. Full609531 anterior532–536. No aceptación global/física ni push/Codemagic.

## 2026-10-03 — Loop 537: captura directa de documentos

Fuente 27dd7dd5672c15c02485df066c6b8220d6dd3f4e, producciónf634c77. Capturador agrega verification-form-documents/large: abre flujo real, Continuar a verificación, scroll hastaDocumentos y ensureVisiblealignment0. 26134 terminal exit0,1test/2fixtures,3s; analyzer16973 terminal exit0 limpio25.9s. PNG normal y320/200 inspeccionados: radio/títulos/helpers536 visibles; botón nativo debajo/texto largo frente a Source card-row horizontal/Subir (App4153–4162), diferencia lista para siguiente implementación responsive con accesibilidad/rolesprivados intactos. Large muestra primera tarjeta incompleta; no aprobación de controles fuera viewport. Inventario405unique,55Source/51native/38capturedpatterns/44paths unchanged. Pasada completa403525 anterior; no405pasadafull/aceptaciones. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Sin push/Codemagic.

## 2026-10-03 — Loop 538: documentos con botón horizontal

Producción f92bb5820b33354a23e831cc1fcf423217e7bc9c. documentHeader: summary +gap12+Subir compacto en fila normal; escala14>21 columna gap12. Botón borderline/radio tema999/min34/padding8x14/text14/17/600 como secondary-button.compact; Semantics rol completo y keyverification-upload-role. Callbacks busy/límite12/carga real preservados, archivos existentes/retirar debajo yreadonly sin botón. Primera50265exit0,11/11,5s/analyzer18632exit0 limpio28.2s; PNG revela fallbackAhem en selector ybotón. Estilos del bloque verificación fijan Inter explícito. Repetición38609 terminal exit0,11/11,4s y analyzer89374 terminal exit0 limpio24.9s. PNG normal inspeccionado: INE/Subir legibles ydos tarjetas horizontales; large primera tarjeta ySubir completos. Segunda tarjeta large fuera viewport,no aceptación total. Source CSS221/4569/6122 yApp4153–4162, remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Inventario405537, full609531 ycapturador403525 preceden últimas correcciones. Sin push/Codemagic/físico/global.

## 2026-10-03 — Loop 539: targets de documentos y conflicto privado

Fuente 886e58243bbb1f04b143d57e2f8e4d6c22ebf701, producciónf92bb58. Dos pruebas nuevas320x640 normal/200 recorren ambos keysverification-upload-identity/address, scroll real, hitTestable, onPressed habilitado y área>=48. Toque inicia save real delcontroller con reposfakeconflict; saveCalls+1 yreads1 prueban stop antesselector y sin recargar/borrar solicitud. Continúa formulario/sin excepción; noapertura de archivo niupload real físico acreditados. Test87273 terminal exit0,5/5,3s; analyzer94659 terminal exit0 limpio27.7s. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Suiteesperada611 tras dosnuevas; full609531 anterior532–539, noatribuir611full. Inventario405537; capturas538 dosestados, full403525 anterior. Sin push/Codemagic ni aceptaciónglobal/física.

## 2026-10-03 — Loop 540: progreso de verificación

Producción 587f94b814ecdeee35d02a8b2d9477dda3a30ba3. VerificationProgress extraído: encabezado14/17 con estadoCompleto/Incompleto real captured==total, fila normal/columna escala>150%, padding17incluyeCSS16+borde, gap12, barra8purple/efede8/radio999 Source6378–6382. Conserva captured/total y nota aprobación equipo; Completo no cuenta aprobada. Primera51607exit1,4pass/3fail por semanticsValue de barra textual inválida introducida; analyzer78011exit0 limpio28.8s. Corregida: contadoren semanticsLabel y valorporcentual default. Repetición30103 terminal exit0,7/7,5s; analyzer97657 terminal exit0 limpio27.3s. PNG normal inspeccionado: títuloestado en fila, contadorreal1/11,barra ynota; large documentos no muestra progreso,noaceptación de eseestado. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Full609531 anterior532–540; inventario405537,completo403525anterior. Sin push/Codemagic/físico/global.

## 2026-10-03 — Loop 541: progreso enfocado normal/200

Fuente 46fc3e34f5ce6f03776d86852b3a27958eac8ce0, producción587f94b. Dosfixtures nuevasverification-form-progress/large: ruta realcontinúa aformulario yscrollheadingProgreso; asserts Incompleto/contador1de11 hitTestable yLinearProgress.value1/11. Test95475 terminal exit0,1test/2fixtures,3s; analyzer1411 terminal exit0 limpio35.4s. PNG normal y320/200 inspeccionados: título/estado/cuenta/barra/nota legibles; large borde superior tarjeta queda porencima viewport alalinear heading,no afirmar cuadrocompleto. Sinerrorsemántico actual; noTalkBackfísico. Inventario407unique,55Source/51native/38capturedpatterns/44paths iguales. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Full609531 anterior532–541; fullcapturador403525 anterior nuevasfixtures. Sinpush/Codemagic/aceptaciónglobal.

## 2026-10-03 — Loop 542: paleta de estado aprobado

Producción 67cb4a0b4319cab2fb8ed17c4d2ab4868eee1573. Source App4108 review usaStaticSimulatedplain-screen sinrescuer-theme (App961), mientrasapproved4109 sírescuer-theme; CSS6161–6164 hereda151423/4f4e5c. VerificationStateScreen ahora aplica paletafría únicamenteapproved, warmreviewpreservada. Heading24 mantiene1.25 con tracking-.48 deh1global-.02em. Datos/recarga/moderación/publicar reales intactos. Test82265 terminal exit0,6/6,5s con2approvedfixtures; analyzer75367 terminal exit0 limpio38.8s. PNGnormalapprovedinspeccionado: título/nota/botones/círculo; largearchivado sin nueva inspección. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Full609531 anterior532–542; inventario407541/completo403525 anteriores. Objetivopendiente físico/contrasteglobal. Sinpush/Codemagic.

## 2026-10-03 — Loop 543: composición de cuenta verificada contra runtimeSource

Producción acee19221614a039dc16af8f1bb6e5c62becaba9. Edge377x852 Source/rescuer/verification aprobado: topbar68,center520/padding28/gap10; circle64y198.265625,heading24/30y286.265625/marginbottom16.08,p14/21.7y342.34375/marginbottom14,primary321x48y409.71875/font16. Runtime/source-metrics ySourcePNG archivados e inspeccionados; SHA remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Native mueve acciones realesConsultar/Recargar/Retirar fuera center520 para no desplazar grupo, conservaacciones ycallbacks; gapstítulo26.08 ylead24 incorporan marginsSource, primary16/19/600/fbfbff; check20oscuro151423 deAssetIcondefault20. PNGnormalfinalinspeccionado: círculo198/botón410..457, contenido alineado; copyreal yaccionesextra debajo preservados. Headerback aún difiere horizontalmente, noaceptaciónpantallacompleta. Primera26603exit0,6/6,4s/analyzer78337exit0 limpio36.8s anteriorcheck20; final57528terminalexit0,6/6,4s/analyzer21220exit0 limpio34.3s. Largearchivado sin nueva revisión. Browser543cerrado,Vite46954CtrlCexit1esperado. Full609531anterior532–543; inventario407541/fullcapturador403525. Sinpush/Codemagic/físico/global.

## 2026-10-03 — Loop 544: regreso de verificación

Producción 48820c3f33b708a0d0f387f6305db7af17048c06. VerificationFormFrame cambiaMaterial24 aSVGback20deSource ytranslate(-4,-.5) dentro48: centro36/33.5 comoTopBar medido476 ySource543. No altera callback/target48 nireserva título; keyverification-header-back yoverlaytransparente. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Test54269 terminal exit0,7/7,5s con2approvedfixtures; analyzer40988 terminal exit0 limpio21.4s. PNGnormalinspeccionado: flecha alineaSource543; largearchivado,noinspección nueva. Full609531anterior532–544; inventario407541,capturadorcompleto403525anterior. Sinpush/Codemagic/físico/global.

## 2026-10-03 — Loop 545: regresión y corrección de toque de guardado

Fuente b049cf1:full14884terminalexit1,610pass/1fail,3m45s; analyzer8555terminalexit0limpio202.2s.230Dart/cuatroSVG igualesraíz-scratchantes;trasgate/reparaciónsólotest/rescue_test.dart difiere enambos,otras233sin cambios. Fallo único draft conflict:botón construido fueraviewport,tapmiss. c66230a corrige a scrollUntilVisible/ensureVisible/pumpAndSettle/hitTestable,conservando phoneauthored/saveCalls2/conflicto.89635terminalexit0,1/1,2s. No611full posterior aún. Primerregistromanifestf99ac99 conservóstatusrunning porerror deassertseparadoresWindows; este registrocorrige aterminalfailed ydocumenta reparación. ADB545vacío,Sourcea3c969cd9103fd46dc5cd886999912526ce75efbrevalidado. Inventario407541/fullcapturador403525anteriores. Sinpush/Codemagic.

## 2026-10-03 — Loop 546: regresión completa611

Fuente b7e988d82d7c9624a65a8778316e8f52d0be2dee,producción48820c3,testrepairc66230a. Full94132 terminalexit0,611/611,3m23s; analyzer98423terminalexit0limpio184.3s.230Dart/cuatroSVG igualesraíz-scratchantes/después,hashessin cambios. Manifest546supersede610pass/1fail545 yfull609531. Incluye532–544 ydospruebas539. Source remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. Inventario407541;capturadorcompleto403525anterior,dirigidasposterioresno407pasadafullniaceptaciones. ADB545vacío,físico/StripeSDK/contrasteglobal pendientes. Sinpush/Codemagic.

## 2026-10-03 — Loop 547: pasada completa407capturas

Capturador76923 terminalexit0,1test/407unique fixtures,3m00s.407PNG existen/frescos/formatoPNG/hashbytes conformeinventario541; manifest547.230Dart/cuatroSVG+capturer raíces-scratchiguales yhashessin cambios frentegate546 fuenteb7e988d82d7c9624a65a8778316e8f52d0be2dee. FuenteSourcea3c969cd9103fd46dc5cd886999912526ce75efbreconsultada. Supersede403525; incluyegastos527–530/verificación532–544/documentos/progreso541. Full611546 yanalysislimpio vigentes mismo código. **407capturasno407aceptacionesvisuales**; no nuevo contraste global/dedo/StripeSDK. ADB545vacío. Sinpush/Codemagic.

## 2026-10-03 — Loop 548: encuadre en revisión

Producción 3115ffbe05578dc12f40883b91d950a8fe839aae. Source App4108 StaticSimulated títuloVerificaciónenrevisión/content-pad20,16,32/CSS81; centro compartido4531/h1margin16.08/p14 medidos543 paraapproved. Native revisióntítulo correspondiente,paddingnormal20/16/32,gapstítulo26.08/lead24,secondaryfont16/19/600,min48/warmborder. Mantiene moderaciónreal/expediente/recarga/retirar,noSimulatedBanner. Primera64883exit0,6/6,5s/analyzer68803exit0limpio47.2s; PNG200revela información partida porpaddinghorizontaldoble. Ajuste bodyhorizontal0 sóloescala24>32 restaura palabra completa sin reducirtexto. Final6478terminalexit0,6/6,4s; analyzer8401terminalexit0limpio31.4s. Normaly200finalinspeccionados;título/lead/botón principal legibles; prueba regresohome200 mantieneacción. No nuevo runtimeSource review548,contraste específico aúnpendiente. SourceSHA remotoa3c969cd9103fd46dc5cd886999912526ce75efbrevalidado. Full611546/completo407547preceden548. Sinpush/Codemagic/físico/global.

## 2026-10-03 — Loop 549: runtimeSource revisión y encabezado

Producción 9034b0d65fb478f182c961adeca61693de6cc855. SourceEdge377x852/rescuer/verification, ModoPrueba selecciónreviewobservada. Computedtopbar68ink15110d;bannerSimulado52.34375 (excluidodeproducto),content20/16/32,center345x520/x16y140.34375,padding28. h1x44/y310.453125/289x60/font24/30/margin16.08; pSource21.6875pxuna línea,botónx44/y442.21875/289x48/font16. Ajuste de comparación: quitarbanner52.34375 y reemplazarparagraphSourceuna línea porleadreal43.4; yheadingesperado247.27/button400.73,coincidenPNGnative~247/401. Runtime métricas ySourcePNGarchivados/inspeccionados. Frame añadeboolrescuerdefaulttrue; estado pasaapproved parareviewheader15110d/e6e2dd exacto,approved/formcoolpreservados. Datos/recarga/retirar/moderaciónintactos. Test61902terminalexit0,6/6,4s; analyzer21558terminalexit0limpio40.3s. Source+native normalesinspeccionados; largearchivado. Sourcea3c969cd9103fd46dc5cd886999912526ce75efbrevalidado. Browser549cerrado,Vite11872CtrlCexit1esperado; primerreadhandoffenSourcecwdfalló yse corrigiórootantescomparación. Full611546/capture407547preceden548–549. Sinpush/Codemagic/físico/global.

## 2026-10-03 — Paridad loop 550: tarjetas de Mis casos

Fuente mockup `a3c969cd9103fd46dc5cd886999912526ce75efb`. Ajustados separación, reserva del borde, interlineado de título/edad y altura/fondo de progreso. Se preservan estados, asignación real y acciones privadas. Pruebas seleccionadas 34/34 (9125, exit 0); flutter analyze sin incidencias (62328, exit 0). Seis capturas generadas; normal y texto ampliado inspeccionadas directamente. Evidencia: docs/design-reviews/parity-loop550. No equivale a aceptación global ni física; 611/407 de loops 546/547 preceden este cambio. Codemagic solamente al terminar el objetivo, sin envíos intermedios.

## 2026-10-03 — Paridad loop 551: estados de Mis casos

Source local/remoto `a3c969cd9103fd46dc5cd886999912526ce75efb` revalidado. Indicadores con colores, mayúsculas, tamaño/peso y SVG de revisión originales; alineación central. Nota de revisión conserva estado real sin promesa de plazo, Ver envío y demás acciones permanecen. Etiqueta semántica natural. Inicial74600 33/1 fallo literal; expectativa corregida preservando aviso/acción. Final86403 terminalexit0 34/34, 8s; analyzer5850 terminalexit0 limpio19.3s. Seis capturas regeneradas, cuatro inspeccionadas (normal/ampliada y correcciones). Evidencia docs/design-reviews/parity-loop551. ADB vacío, gestos físicos pendientes; sin runtime web nuevo ni aceptación global. Full611/407 de546/547 precede cambio. Sin push/Codemagic hasta completar objetivo.

## 2026-10-03 — Paridad loop 552: tocar tarjeta y desplazar

Source `a3c969cd9103fd46dc5cd886999912526ce75efb` (remoto551). El área superior de tarjetas abre expediente privado/retoma edición real en estados distintos de revisión, y refresca al regresar. Conserva Ver envío y acciones reales; sin hover ni splash. Seis pruebas nuevas cubren borrador/correcciones/aprobado normal/200: desplazamiento no abre ni lee; toque carga ID exacto y no guarda. 11479 terminalexit0 40/40,9s; analyzer87146 terminalexit0 limpio20.9s. Seis capturas regeneradas idénticas bytes a551, comparación manifest552. No nueva aceptación visual directa ni Android físico. Full611/407 de546/547 precede552; no full617 aún. Evidencia docs/design-reviews/parity-loop552. Sin push/Codemagic.

## 2026-10-03 — Paridad loop 553: resumen del caso propio

Source local/remoto `a3c969cd9103fd46dc5cd886999912526ce75efb`. Runtime Edge377x852 /rescuer/cases/luna confirma summaryx16y276/ancho345/padding16+borde1/radio24/gap8; h1x33y293/font24/30/ink151423; p14/21.7; ubicación12/normal/alto27/padding5x9+borde1/muted4f4e5c/bordere3e4ed. Native corrige palette, reserva del borde, story1.55, gap12 de título y ubicación; gap a necesidades31.77 porgrid16+margen h2. Conservados datos/gastos/comprobantes/galería/regreso/cierre reales. Primera43100exit0 38/38,20s/analyzer25519exit0limpio53.6s; final87349exit0 38/38,14s/analyzer52234exit0limpio34.3s.14PNG regenerados; Source/normal/ampliado inicial y normal/bottom-large final inspeccionados, no14aceptaciones. Métricas y evidencia docs/design-reviews/parity-loop553. Browser43585 cerradoexit0,Vite12983CtrlCexit1esperado. Full611/407 de546/547 precede. Sin Android físico/push/Codemagic.

## 2026-10-03 — Paridad loop 554: tarjetas de gastos propios

Source local/remoto `a3c969cd9103fd46dc5cd886999912526ce75efb` revalidado. OwnedExpenseSummary adopta palette/borde/reserva17, símbolos emoji22 de categorías Source, interlineado y progreso8; acción soft radio14/font14/padding8x16/visual36 con objetivo48. Preserva estado/fundingserver/reversión/comprobantes/reintento, no umbral65/Comprar/Desbloquear simulado. Inicial89263exit0 41/41,12s/analyzer39314exit0limpio25.9s. PNGdetectótofu: fallback de plataforma y carga sólocapturadorWindows deSegoeUIEmojiinstalado, sin distribuirfuente. Final72634exit0 41/41,13s. Analyzer14148issueimportinnecesario corregido;67503exit0limpio23.9s. Eliminaciónimportúnicamentesinreruntest.14PNGregenerados,normalfinalsímbololegibleinspeccionado;sinaceptaciónvisualampliadadelgasto, pruebaacción320/200sípasa. Root/scratchpropiosiguales/evidencia docs/design-reviews/parity-loop554. Sinruntimewebnuevo/fullactual/físico/global/push/Codemagic.

## 2026-10-03 — Paridad loop 555: historia y coordenadas del borde

Source local/remoto `a3c969cd9103fd46dc5cd886999912526ce75efb`. Fechas visibles relativas derivadas del published_at real/calendario local (Hoy/HaceNdías); fecha exacta accesible, futuro absoluto e inválido vacío. Corrección: Container incluye decoration.padding; aumentos550/553/554 duplicaban1px. Restauradospadding14caso/16resumenygasto/14historia. Test nuevo contra runtime553 prueba texto x33/y293; supersede esasreservasmanualesprevias y requiereauditotrosContainers. Primera58753exit0 24/24,12s/analyzer10444exit0limpio19.7s.9095exit1 56/1 montaje sinProviderScope;14152exit1 56/1 sinGoRouterState; fixturecorregidosinrelajarcoordenadas/excepción. Final38152exit0 57/57,20s/analyzer54038exit0limpio20.8s.20PNGregenerados; storynormal/ampliado/detailnormalfinalesinspeccionados. Dospruebasnuevas; full619pendiente, full611546/407547anteriores. Evidencia docs/design-reviews/parity-loop555 y cortevigente actualizado. Sinpush/Codemagic/físico/global.

## 2026-10-03 — Paridad loop 556: borde de progreso de verificación

Source local/remoto a3c969cd9103fd46dc5cd886999912526ce75efb revalidado. ContainerProgress padding16+borde1 automático; supersede17manual540. Documents DecoratedBox+Padding15correcto, preservado. Auditoría dirigida de17/21/15 enperfil/rescate sinotroincrementosimilar. Dospruebasnormales/200 contrastanorigen33/37/estadoIncompleto/ratio1de11.37003exit0 15/15,11s/analyzer42081exit0limpio27s.SeisPNGregenerados,progressnormal/ampliadoinspeccionadossinaceptacióndebordesuperiorfueraViewport.232Dartinclcapturerraíz-scratchiguales. Evidencia docs/design-reviews/parity-loop556. Full621pendiente,611546/407547anteriores. Sinpush/Codemagic/físico/global.

## 2026-10-03 — Loop 557: regresión completa621

Fuente d435f33,232Dart inclcapturer raíz-scratch iguales antes de lanzamiento/durante/final y hashes sin cambios.72124terminalexit0 621/621,3m48s; analyzer42081 de556 limpio27s misma fuente. Supersede full611546, no aceptación global/visual por testcount. Source a3c969cd9103fd46dc5cd886999912526ce75efb revalidado556.407capturas547 precede548–556;20casos555/6verificación556dirigidas posteriores. ADB557vacío; emulator.exe y AVD Dopmi_API_35 comprobados (-list-avds), aúnsinarranqueinstalacióngestos. Evidencia docs/design-reviews/parity-loop557, cortes vigentes actualizados. Sinpush/Codemagic.

## 2026-10-03 — Loop 558 en curso: Android nativo disponible

AVD Dopmi_API_35 verificado, WHPX usable (-accel-checkexit0). Emulator iniciadooculto/headless/read-only/no-snapshot-save PID70556. ADB emulator-5554device,sys.boot_completed=1. pm list packages com.mycompany.dopmi vacío: sinappinstaladaactual, sinbuild/gestoverificado. Próximo paso candidato local actual, manteniendoidentidad/config/test-only. Evidencia docs/design-reviews/parity-loop558. NoAndroidfísico/push/Codemagic.

## 2026-10-03 — Loop 558 en curso: DEV verificado y build nativo activo

Supabase skill/changelog consultados sin feature/SQLnuevo. Config local existente DEVohqxranynackjignryep/clavepublishable/Guardiantesttrue; authsettingsHTTP200,catálogo públicoHTTP200/5casos, sin mostrarcredenciales. Pubspec/Androidversionadosraíz-scratchiguales. Builddebugandroid-x64configlocal sesión95153 sigueactiva, diagnósticoGradleRUNNABLE/R8; conservarproceso yrevalidarhandle antes decontinuar, sinrestartportimeout. APKviejoscratchnoinstalado. AVDemulator-5554API35/720x1520/density300,boot1; timezoneGMT→America/Mexico_CityQAread-only. NoAPKactualinstalado ni gestosverificados. Evidencia docs/design-reviews/parity-loop558/native-build.json. Full621557/analyzer556vigentescódigosincambios. Sinpush/Codemagic.

## 2026-10-03 — Loop 558: resultado Android local

Sustituye pendientes558: build debug android-x6495153 exit0/1112.1s, instalación75429 Success. Fuente d435f33,232Dart verificados iguales raíz/scratch y hashes557 tras QA. APK SHA2569A2E0FACC184F39B59BFAB70B78AAB3D785FD710A8403E706957BC76185DDF5E, com.mycompany.dopmi, versión local0.2.0+2. En emulador API35: selección Adoptar, scroll footer, entrada anónima, detalle Rocky Demo/foto cargada y Back4 preservando tarjeta/filtro; sin escrituras/pagos. Evidencia docs/design-reviews/parity-loop558. Arranque -W inicial timeout con UI visible; segunda salida no recuperable, PID2499/topResumedActivity verificados. Rendimiento/animaciones/gestos físicos/paridad global sin aceptar. Sin push/Codemagic, conforme indicación de enviar sólo al completar objetivo.
