# Actualización889 — Rescatista y comunicaciones

Referencia fijada: `irlanda/apoyar-detalle-perfil@889c096ade9479b348530db7ba169f023b472ab9`.
Comparación estática realizada mediante `git show` contra `a3c969c` y `4c933189`;
no se cambia el checkout del prototipo. Los ajustes de ancho de889 pertenecen
a REF-12, sin abrir una familia adicional.

## Cambios implementados

| Grupo | Implementación | Evidencia de cierre pendiente |
| --- | --- | --- |
| REF-09 | Ayuda Rescatista blanca, selección/FAQ/soporte morados; regreso con historial y fallback real `/settings`. Notificaciones reciben modo explícito; fallback directo `/messages`, encabezado/bordes propios. | Dirigidos incluidos en 50/50 de la cola principal. Contraste visual normal a 377 px cerrado; Back Android y operación de destinos pendientes. |
| REF-12 | Logo/campana, grupos por ID real, tarjetas/fotos, contadores del servidor, badge9+, ancho completo, grupo sin conversaciones y vacío sin casos con CTA a Mis casos. Chevron200ms/ease, plegados conservados, páginas de grupos y carga adicional por grupo con reintento/deduplicación y descarte de respuestas tardías. | Contrato real DEV 42/42 y dirigidos incluidos en 50/50. Recaptura 74254 a 377×852 cierra composición visual de desarrollo; recorrido instalado pendiente. |
| REF-13 | Filas muestran adoptante/último mensaje/no leídos dentro de su grupo; abrir utiliza ID de conversación. Historial cerrado/retirado y Mis conversaciones siguen accesibles. | Cabecera Luna/adoptante/detalle comprobada en recaptura 74254; menú real de cerrar conservado. Regreso, destino autorizado y teclado instalados pendientes. |

Contadores `thread_count`, `unread_count` y `threads_total` provienen del
servidor; no se reconstruyen a partir de páginas cargadas. Una variación del
total al cargar más solicita un refresco del grupo. Error de consulta no se
presenta como vacío. Cerrar/abrir grupos no escribe datos ni crea mensajes.
El modo de experiencia sólo determina presentación; no concede permisos.

El acceso a `/my-conversations` conserva la experiencia y el historial de
participante. El principal integra esa ruta, la consulta autorizada del inbox,
el chrome compartido y los parámetros `rescuer` de notificaciones/campana.

## Dependencia real de backend y moderación

El cierre también requiere el contrato autorizado del inbox/contacto y la
moderación de los campos nuevos de adopción. El panel muestra `age_band`,
las seis preferencias de convivencia/hogar y las personalidades nuevas y
anteriores con las mismas etiquetas mexicanas del cliente. Una categoría
ausente se muestra sin seleccionar; no se infiere de meses históricos.
El tipo aditivo y sus etiquetas viven en `adoptionReviewTraits.ts`; no se
modifican los cambios previos del usuario en `api.ts` ni `api.test.ts`.

La aprobación espera que **cada una de las seis imágenes** haya terminado de
cargar; el seguimiento es por imagen, no por URL compartida. Una foto fallida
o ausente mantiene la aprobación bloqueada y el reintento reinicia la carga.
Preparados 8 casos adicionales admin, junto con 4 existentes, para etiquetas
actuales/anteriores, categoría explícita/nula, cinco frente a seis imágenes,
reintento completo y ausencia de fotos. La cola principal ejecuta `npm test`
y `npm run build`; este subagente no acredita resultados aún.

## Comprobación real de backend DEV

4/10/2026 México: MCP `execute_sql` en DEV ejecutó una transacción de fixtures
controlados con dos actores operativos y un tercero activo para aislamiento.
Los identificadores estaban libres en el preflight; los correos sintéticos
usaron un dominio inválido, sin correo Auth ni contacto con personas reales.
**42 comprobaciones pasaron** y la transacción terminó en `ROLLBACK`.

- Contacto inicial y dos reintentos: una conversación, un saludo real y una
  notificación. Una conversación anterior no recibe saludo retrospectivo;
  reabrir una cerrada tampoco agrega mensajes ni notificaciones.
- Detalle permitido a ambos participantes; el actor ajeno recibe rechazo y
  no ve la conversación ni sus mensajes mediante RLS. El caso privado sólo
  aparece en el detalle de su dueño.
- Inbox propio: cuatro grupos, contadores anteriores a paginación, dos
  páginas sin duplicación, grupo sin conversaciones, historial cerrado y
  exclusión de conversaciones donde el actor participa como adoptante.
  El adoptante sin publicaciones propias obtiene cero grupos.
- Seis rutas de fotos y los campos nuevos persistieron; un payload anterior
  conserva categoría, convivencia y personalidad. Se rechazan una séptima
  foto y convivencia inventada. El borrador queda privado y fuera del
  detalle público. El tamaño del caso es explícito y persiste con cliente
  anterior; el servidor rechaza un valor inválido.
- Un gasto en borrador conservó sus dos referencias de evidencia y datos
  privados en el registro hijo; el caso padre quedó sin esos archivos/datos.
  La eliminación autorizada retiró el hijo.

Postflight después de `ROLLBACK`: **cero** fixtures en Auth, perfiles,
publicaciones, expedientes, conversaciones, mensajes, notificaciones e
historial de rescate. No se modificaron ACL, usuarios reales, dinero ni
configuración financiera. Las llamadas utilizaron el rol `authenticated`
con identidades controladas; **no acreditan sesiones Auth/REST, subida o
lectura física de Storage, concurrencia entre conexiones ni dispositivo**.
Esos límites permanecen en la cola de aceptación principal.

Preparación independiente para QA nativa: se creó **una cuenta adoptante
controlada** mediante Auth REST (200). MCP confirmó únicamente el correo de
esa fixture, condicionado a su ID y correo exactos (una fila). Login Auth REST
(200) devolvió la misma identidad; `dopmi_accept_legal` REST (200) confirmó
`terms-2026-09-28`, `privacy-2026-09-28` y mayoría de edad. No se cambiaron
guardas, flags globales ni cuentas reales. Credenciales y sesión se guardan
sólo en `.tools/update889-native/adopter.json`, ignorado por Git; no incluir
ese archivo en evidencia compartida. Esta fixture permanece para QA
nativa y debe retirarse al terminar. Esto acredita Auth/consentimiento real,
sin extenderlo todavía a contactos, Storage ni aceptación instalada.

Se preparó además un **owner QA889 nuevo**, sin reutilizar el demo anterior:
alta Auth REST 200, confirmación acotada a su ID/correo exactos (una fila),
login 200 de la misma identidad y consentimiento legal REST 200. Se sembró
únicamente una verificación sintética aprobada de harness, con nombre
`DEMO QA889` y snapshot explícito `synthetic/update889-native`. **No acredita
verificación de una persona real.** No se crearon ni aprobaron casos o
gastos, ni se añadieron Connect, membresías administrativas o flags.

El cambio de modo Rescatista pasó por el mismo recorrido del cliente:
PATCH REST de `profiles.active_mode` filtrado por el owner y autorizado por
RLS (200). El contrato actual usa esa actualización, sin RPC de experiencia.
`dopmi_rescuer_dashboard` REST 200 confirmó verificación `approved` y cero
casos en sus cuatro estados al realizar la comprobación. Credenciales y
sesión sólo en `.tools/update889-native/owner.json`; el manifest privado
`.tools/update889-native/manifest.json` registra la identidad y el ID exacto
de la verificación para cleanup. Ambos están ignorados por Git. Las dos
cuentas QA y la verificación sintética deben retirarse al cerrar la pasada.

5/10/2026 México: se preparó **una adopción sintética propia** de esas mismas
dos cuentas QA para el primer contacto nativo. Auth REST verificó ambas
identidades; `dopmi_save_adoption` creó el borrador y persistió categoría,
convivencia, personalidad y seis rutas de fotos. Se normalizaron seis
imágenes de referencia como JPG de prueba y se subieron como seis objetos
reales, con rutas UUID propias, al bucket privado `dopmi-adoption-photos`.

Lectura física del borrador: **6/6** bytes coinciden como owner; **6/6**
solicitudes del adoptante quedaron denegadas. `dopmi_transition_adoption`
envió la publicación a revisión por REST. MCP publicó **una fila exacta**
acotada a ID de publicación, owner/correo QA, estado `submitted`, versión,
etiqueta sintética y seis objetos existentes. La preparación queda marcada
como fixture de harness y **no acredita aceptación de moderación humana**;
no se concedieron privilegios administrativos ni se simuló una sesión admin.

Después de publicar, el detalle real del adoptante devolvió las seis fotos
y campos nuevos. URLs firmadas y GET físico pasaron **6/6 como owner y
6/6 como adoptante**, comparando los bytes con los insumos de prueba.
Preflight de contacto: **cero conversaciones** para esta publicación;
el primer CTA se reserva a la pasada nativa. No se crearon casos, gastos,
mensajes, notificaciones de contacto ni operaciones financieras.

La identidad, publicación, seis rutas Storage, versión y preparación
sintética están registrados exclusivamente en el manifest privado y en
`.tools/update889-native/adoption-fixture.json`, ignorados por Git. Las
fixtures permanecen para Samsung hasta indicación de cleanup. La limpieza
debe archivar primero la publicación, retirar sus seis objetos exactos por
Storage, eliminar la publicación acotada y después retirar las identidades
QA/verificación cuando concluya la pasada completa. No borrar Auth antes
de Storage, pues se perdería la autorización del owner para retirarlos.

## Verificación de este frente

- Dart format ejecutado sobre los seis archivos propios; parseo/formato correcto.
- `git diff --check` de los cambios propios sin defectos de whitespace.
- Preparadas11 pruebas de inbox y7 de chrome: retry sin falso vacío, texto1/2,
  contador independiente de página, grupo cero chats, hold cancelado, plegado
  y giro, paginación/retry/deduplicación, regreso real del chat, historial/Back,
  respuesta tardía, páginas globales, Mis conversaciones, regreso de
  notificaciones y ayuda, y selección morada.
- La cola principal ejecutó los dirigidos propios dentro de su resultado 50/50.
  Ante el nuevo proveedor de identidad de notificaciones, se actualizaron sólo
  los fakes de `notifications_test.dart`: identidad donante controlada en los
  tres casos, conservando paginación al 200%, reintento y destino real. La
  regresión y su resultado corresponden a la cola principal.
- No se ejecutó Flutter, dispositivo ni publicación desde el subagente.
  Esta ficha **no acredita aceptación instalada**.

La cola principal verificó el gate CI del SHA exacto
`7401468268c69b46c82390d8c1c3d4f9323900e3`, run `37274003442`: cuatro
jobs en `SUCCESS`, incluida la prueba de contacto con conexiones PostgreSQL
concurrentes. Es evidencia CI del candidato; no sustituye la pasada nativa.

Preparación nativa con las dos cuentas QA existentes: el principal verificó
en emulador login real del adoptante, punto de galería6 → Foto6 y swipe de
regreso → Foto5. Después abrió el diálogo de contacto y eligió **Todavía no**.
La consulta DEV posterior, acotada a publicación y ambos actores exactos,
confirmó **0 conversaciones, 0 mensajes y 0 notificaciones**. El subagente
espera la confirmación del primer CTA nativo antes de consultar su resultado
y ejecutar los dos reintentos REST del mismo contacto. No se retiraron
fixtures ni se ejecutó contacto durante el preflight o tras la cancelación.

El principal confirmó después **Sí, contactar rescatista** en el emulador;
el chat abrió con mascota, rescatista y Ver detalle. La consulta DEV real
posterior confirmó **1 conversación, 1 saludo y 1 notificación al owner**
(una no leída). Los dos reintentos Auth/REST del mismo adoptante devolvieron
200 y el mismo ID de conversación. El postflight permaneció exactamente
**1 conversación, 1 mensaje/saludo y 1 notificación**; no se usó la RPC de
envío para fabricar mensajes adicionales. IDs y pruebas de contacto están
sólo en el manifest privado de la fixture. Esto acredita contacto iniciado
en emulador y persistencia real; aceptación Samsung continúa pendiente.

El owner respondió después **Respuesta nativa QA889** desde el emulador.
Inventario DEV de sólo lectura: dos mensajes en el hilo, cero no leídos para
el owner y ese texto como último mensaje. En el nuevo borrador creado por
el picker/formulario nativo persistieron Monterrey / Nuevo Leon,
hembra / adulta / mediana y **seis fotos, seis objetos Storage existentes**.
Al realizar el inventario seguía `draft`, versión14; no se publicó ni aprobó
ese segundo registro. La primera adopción sintética publicada permanece.

El manifiesto privado de cleanup incorpora las dos adopciones, la
verificación sintética, sus doce objetos Storage exactos, el hilo, IDs de
ambos mensajes y notificaciones. No había casos, avances ni perfiles
Rescatista adicionales del owner QA. El inventario es una instantánea y
debe refrescarse antes de cleanup si la pasada nativa crea más datos; no
autoriza retirar las fixtures antes de la comprobación Samsung.

El principal completó después la vista previa nativa del segundo registro:
swipe → Foto2/6; Alegre, Tranquilo y Cariñoso seleccionados; Nervioso como
cuarto rasgo rechazado por el límite3. **Enviar a revisión** mostró el
diálogo de envío. La comprobación DEV posterior confirmó `submitted`,
versión17, `published_at` nulo, cero revisiones y cero conversaciones para
esa segunda adopción. Persistieron categoría `adult`, convivencia
`children/apartment` y personalidad `alegre/tranquilo/affectionate`; el
cuarto rasgo no está guardado.

Sus seis rutas propias corresponden a seis objetos físicos. Auth/REST del
owner leyó **6/6 archivos JPG**, decodificados correctamente; el adoptante
recibió detalle público nulo y **6/6 solicitudes de fotos denegadas**. No
se publicó automáticamente ni se sembró una aprobación. La primera fixture
publicada y su conversación se conservaron para Samsung. Estado, versión,
campos, seis rutas y evidencia de aislamiento se añadieron al manifiesto
privado de cleanup; no se retiró ningún archivo o registro.

Pasada nativa final del candidato
`51cc7c150abb20adc0fc70ecaafe5ebe202817c5`: el principal comprobó
APK compilado y prueba dirigida Back/Continue **10/10** tras la corrección.
El caso nativo conservó datos después de force-stop y actualización del
APK. Back desde paso2 desplazado volvió al inicio de paso1 conservando el
nombre; Continue llevó al inicio de Necesidades y luego de la vista previa.
Enviar el caso mostró la confirmación de revisión y explicó que los gastos
siguen como borradores privados hasta la aprobación del caso.

Postflight DEV actual: **caso `submitted` v11 / gasto hijo `draft` v6**,
sin aprobación ni snapshot aprobado. Persistieron $250.00 MXN como
`amount_cents=25000`, fecha2026-10-05, proveedor y referencia sintéticos
exactos de QA. Una foto pertenece al caso; comprobante y evidencia (roles
`receipt/proof`) pertenecen exclusivamente al gasto hijo. El padre tiene
cero campos privados y cero archivos de gasto; el valor reembolsable sigue
en cero. No se sembró aprobación ni se ejecutó operación financiera.

Auth/REST real del owner leyó ambos registros y los **3/3 archivos físicos**,
decodificados correctamente. La otra cuenta QA, ajena al caso/gasto, vio
**0 filas mediante RLS, 2/2 detalles denegados y 3/3 archivos denegados**.
El manifiesto privado contiene los IDs y paths exactos de todas las
fixtures actuales: tres adopciones (incluido el borrador vacío de la prueba
de cámara con0 fotos/0 objetos), verificación/caso/gasto y quince objetos
Storage. La publicación inicial sigue publicada. Las fixtures se conservan
para Samsung; el inventario no autoriza cleanup. La comprobación instalada
de Samsung/Play queda a cargo del principal.

Cleanup posterior a Samsung preparado, **sin ejecutar**: script y handoff
ignorados en `.tools/update889-native`. Guardas fijan proyecto DEV, los dos
UUID/correos QA, tres adopciones, tres expedientes y quince paths completos.
Se retiran primero los estados submitted y se archivan las adopciones para
permitir el DELETE real de Storage; después se retira el gasto por su RPC,
se revocan sólo las sesiones QA y se ejecuta una transacción MCP acotada a
registros/identidades sintéticos. La publicación inicial sigue disponible
hasta finalizar Samsung. No se prepara borrado por prefijo ni DELETE SQL de
Storage. Los hilos de la publicación QA se retiran por sus FK; sus otros
participantes no son targets de Auth. Parseo Node y fase plan correctos,
cero requests remotos de esa fase. Preflight MCP adicional de sólo lectura
confirmó el allowlist2/3/3/15 y las dos entidades no aprobadas con valor
reembolsable cero; debe repetirse después de Samsung. Las fases destructivas
y sus postflights aún no se han ejecutado ni autorizado mediante recibo.

## Contraste perceptual de Source889

5/10/2026 México: Source aislado fijado en 889, con Inter/Fraunces locales,
ancho 377 px y alto 852 px, modo Rescatista y sin estados vacíos. Las capturas
quedaron en `Temp/dopmi-source889-adopt/capture889-rescuer`, con manifest de
dimensiones, fuentes y estado. Además de las tres capturas iniciales, se
obtuvieron sólo Ayuda inicial, selección Adoptar, primer FAQ abierto y chat
Rescatista; cero imágenes rotas y cero errores de página. No se ejercieron
envíos, dinero ni hover en el prototipo.

- Ayuda inicial: composición, tipografía, textos, chips, botón morado de
  soporte, radios y pie coinciden perceptualmente con `rescuer-help.png` a
  377×852. El FAQ seleccionado/abierto queda referenciado en Source; las
  pruebas dirigidas verifican selección morada y regreso contextual.
- Notificaciones: `rescuer-notifications.png` y Source usan las mismas tres
  tarjetas y dos no leídas a 377×852. Encabezado, jerarquía, iconos, chips,
  radios y borde no leído amarillo coinciden. Las diferencias menores de
  antialias se aceptan según el criterio acordado.
- Inbox: una comparación a 384 frente a 377 px causaba un desplazamiento
  aparente del FAB; al igualar ancho se descarta como defecto. Se corrigieron
  dos diferencias visibles propias: separación debajo del encabezado de 8 a
  20 px, conforme a `gap` más margen de Source, y nombres de adoptantes con
  peso 700. La recaptura 74254 ya muestra las mismas tres filas, fotos y dos
  no leídas: geometría del título, tarjetas, grupos, filas, badges y FAB
  coinciden perceptualmente. Los enlaces reales a historial y Mis
  conversaciones se conservan. La fixture no incluye `updated_at`; no se
  interpreta como defecto del renderizador. Las fechas siguen el formato
  real previamente aceptado del cliente, sin constantes del mockup.
- Chat: Source muestra Luna/Ana P./Ver detalle. La captura inicial del cliente
  omitía campos de participante/destino en su fixture; el principal reemplazó
  ese fake por el contrato de cabecera real para recapturar. En 74254 ya se
  ven Luna/Ana P./Ver detalle y su jerarquía/tamaño/acento coinciden; el
  menú real de cerrar conversación conserva su espacio junto al enlace,
  que queda desplazado respecto a Source. Se mantiene esa función real.
  Las burbujas y la foto simuladas del prototipo no acreditan mensajes o
  adjuntos reales, y no se copian al cliente para igualar datos.

La aceptación visual de Ayuda/notificaciones se limita al estado comparado;
no sustituye Back, teclado, permisos, contacto real ni lectura de Storage en
la pasada nativa. No se reabren componentes anteriores por diferencias
imperceptibles o por contenido distinto de los fixtures.

Se reutilizan las pruebas de las ocho mecánicas compartidas y los recorridos
intactos de la entrega290. Hover se excluye de la aceptación; no se añaden
simulaciones, mensajes automáticos al entrar ni cambios financieros.

Entrega instalada y limpieza 5/10: el coordinador comprobó Samsung
2.3.3 (291) y ocho recorridos físicos sobre el candidato
`51cc7c150abb20adc0fc70ecaafe5ebe202817c5`, después del gate
37278538360 (cuatro jobs aprobados, 846 pruebas móviles), Codemagic
6ac3570f3a34cf7c3070ed0f y publicación Play interno comprobada por separado.
El regreso a modo donante quedó restaurado; el formulario transitorio
del teléfono no creó registros remotos. Reabrir el contacto QA conservó
un único saludo. Esta entrada cierra los pendientes nativos e instalados
de la ficha; no amplía la referencia fija 889c096.

Después de esa revisión se ejecutó la limpieza DEV autorizada: preflight
exacto Auth2/adopciones3/expedientes3/objetos15, sin reembolsables ni
aprobación financiera. Las RPC del dueño retiraron los envíos y archivaron
las publicaciones; Storage API eliminó los 15 archivos exactos, después se
retiró el gasto borrador y se revocaron ambas sesiones QA. La transacción
acotada eliminó las tres publicaciones, caso, verificación sintética y dos
Auth. H10 conserva correctamente el perfil como sujeto contable al retirar
Auth; por ello se comprobaron las 30 dependencias del perfil, todas en cero
salvo dos consentimientos sintéticos, y se retiraron únicamente esos dos
consentimientos y los dos perfiles QA huérfanos. No hubo cambios de esquema,
reglas o datos financieros.

Postflight MCP final: Auth0, perfiles0, consentimientos0, publicaciones0,
expedientes0, hilos0, mensajes0, notificaciones0, historial0 y Storage0.
La cuenta participante real del Samsung conservó Auth1/perfil1. Después de
comprobar esos ceros se eliminaron únicamente los archivos privados locales
`owner.json` y `adopter.json`; la evidencia de conteos queda en el manifiesto
privado de limpieza. Hover sigue excluido y dinero continúa en prueba.
