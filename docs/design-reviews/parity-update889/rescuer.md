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
