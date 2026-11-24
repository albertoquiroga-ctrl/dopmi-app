# Atribución para el chat de campañas

Corte:24/11/2026, CDMX. Destinatario: **Revisar campañas de Google y Facebook**.
Este es el contrato operativo compartido; los contactos orgánicos autorizados
se distinguen de las campañas pagadas y de su aceptación técnica.
Implementación autorizada21nov: consultar el [runbook de etiquetas y piloto](campaign-placement-pilot.md)
para el registro original y la [segunda ola de24](campaign-placement-wave2.md)
para su cohorte separada. Cliente público y aceptación real permanecen separados;
los apartados históricos inferiores no sustituyen el estado vigente de esos runbooks.
La [tercera ola](campaign-placement-wave3.md) añade un contraste de orientación:
48 etiquetas registradas, **4 envíos visibles y44 sin contactar** al corte24nov.
R2/R4 significan orientación v2 sólo en ese nuevo experimento; no mezclarlos con
el mensaje de facilidad anterior. Servidor24nov13:48:59CDMX mantiene0 fuentes
Android consentidas con colocación y0 hitos en las tres cohortes. No demuestra
0 clics/descargas: no se recuperaron métricas Vercel y la QA física p60 sigue
pendiente por falta de otra mascota real. Respuestas públicas se revisarán
manualmente a72h/7d, separadas de la primera ficha y sin vincular identidades
sociales con cuentas de la app. No hay ganador ni validación contra pagados.
El [protocolo experimental](superpowers/specs/2026-11-21-rescuer-acquisition-experiment-design.md)
define la hipótesis, las variables, el análisis y la cola de preparación.

## Instrucción vigente

Usar los resultados reales del servidor para evaluar adquisición de publicadores:
**primera ficha original enviada a revisión por cuenta elegible**. Las descargas,
clics, saludos y conversaciones son diagnósticos distintos; no sustituirlos por
publicaciones. El usuario quiere comparar comentarios a rescatistas independientes
de grupos de MTY con **las campañas pagadas de Meta/Google**.

No reconstruir la atribución con códigos manuales, login antes de descargar,
coincidencia de nombres, hora del comentario, portapapeles o fingerprinting.
Conservar la descarga directa, el login habitual en la app y los consentimientos.

## Qué está comprobado

| Recorrido | Evidencia real | Límite |
| --- | --- | --- |
| Android/Play → personal-a → primera ficha | Samsung, instalación limpia418 desde el enlace, fuente y primera ficha exacta en PROD; reinstalación conservó fuente/envío. | La fuente es consentida, primera elegible por cuenta; no identifica a la autora de Facebook ni a cada comentario. |
| iPad421/TestFlight + Safari → personal-a | Fuente automática20nov22:53:37; primera ficha21nov16:37:27; saludo16:58:58 y primer mensaje16:59:59CDMX, comprobados separadamente en PROD. | No es instalación desde CPP/App Store ni QA de iPhone o del424 posterior. |
| Primera aprobación y primera respuesta propia como rescatista en iPad | Pendientes. El usuario eligió dejar la respuesta pendiente y su ficha está archivada. | No afirmar que pasaron por analogía. El primer mensaje desde compositor **sí** pasó. |
| iOS desde enlace público de descarga | Las cuatro rutas mantienen enlaces de campaña Apple agregados. CPP personal-a guardada en borrador. | Sin ppid activo ni instalación pública CPP validada; no anunciar atribución individual iOS de campañas como disponible. |

Fuente instalada del ensayo421: `55061f99f48c0b0b8e54ee628bc8faab553d0763`.
El release posterior de favoritos/424 pertenece a otra verificación; conservarlo
en próximas integraciones. Para binarios actuales y tiendas, consultar
[candidato](candidate-release-current.md), no convertir este corte en estado vivo.
Detalles/recibos privados en [runbook iOS](ios-cpp-personal-a-runbook.md) y
[registro técnico](facebook-rescuer-experiment.md). QA se excluye del análisis
mediante filtro privado; nunca borrar fuentes/fichas o reusar fixtures consumidos.

## Contrato que debe preservar cualquier campaña

| Elemento | Android | iOS CPP piloto |
| --- | --- | --- |
| Transporte | Play Install Referrer de las rutas canónicas. | URI recibida por la app; Apple documenta Abrir desde la CPP en iOS/iPadOS18+. |
| Etiquetas admitidas hoy | Cuatro variantes históricas y tokens32hex registrados de los pilotos, con cliente público433 compatible. | Sólo personal-a/ios_cpp_open; tokens de comentarios con cobertura agregada separada. |
| Reloj de los hitos |336h desde el clic validado. |336h desde la inscripción servidor; no recupera la fecha del clic. |
| Requisitos | Cuenta activa, elegibilidad observable, Analítica consentida y revisión de consentimiento vigente. | Mismos principios de cuenta/consentimiento; captura local pendiente hasta24h y sin historia previa de envíos/revisiones observable al inscribirse. |
| Propietario/fuente | Primera fuente elegible aceptada por cuenta; no last-touch ni reasignación. | Primer contexto y propietario inmutables. |

El origen del evento se asigna en el servidor; no inferirlo leyendo mensajes.

| Resultado | Qué cuenta |
| --- | --- |
| Primera ficha enviada | Una cuenta elegible envía su primera ficha observable a revisión dentro de la ventana. Un borrador o vista previa no cuentan. |
| Primera ficha aprobada | Aprobación ordinaria de esa misma ficha; puede seguir correcciones y ocurrir después de la ventana. |
| automatic_greeting | Saludo de contacto nuevo iniciado por el actor como adoptante. |
| first_user_message | Primer texto o foto válidos enviados por ese actor desde compositor como adoptante. |
| first_rescuer_reply | Envío humano del actor como dueño de una ficha, tras una entrada de su adoptante. La respuesta de otro dueño no se atribuye al actor adoptante. |

Son primeros eventos observables posteriores a atribución, no necesariamente
primeros mensajes históricos de una persona. OFF/eliminación retiran los registros
conforme al contrato; no imputar conversiones que dejaron de ser observables.
Los denominadores pueden cambiar entre cortes por esas retiradas. Excluir QA
de numeradores **y** denominadores, conservar fecha/definición del corte y no
retener una identidad retirada para reconstruir atribución. Android e iOS pueden
registrar la misma cuenta en sus respectivos métodos: no sumar sus reportes como
si fueran personas distintas ni como un first-touch global.

## Variantes históricas y extensión del piloto

Las cuatro URLs de `/descargar/` sirven para la atribución agregada de sus variantes
Android existentes. No cambiarles significado mientras haya enlaces antiguos
publicados o cohortes abiertas. No añadir `?mensaje=...` o UTM y asumir que eso
se guarda: los parsers/allowlists no ofrecen un registro libre por campaña,
comentario o autora. Un enlace de biografía compartido tampoco identifica la variante.

El namespace dopmi_rescatistas_mty_p60_v1 y su registro finito por comentario ya
están implementados en fuente1544a852/CI44966371479 cuatroSUCCESS; SQLPROD
20261122004520 pasó31condiciones. Play público2.3.9(433), fuenteefc3277a,
conserva parser/enrollment p60; los60 tokens noQA se habilitaron22nov y su fase
de contacto cerró con60 envíos/59 visibles/1 pendiente. La QA física con token
p60 y primera ficha válida sigue pendiente; disponibilidad pública no la sustituye.

La [segunda ola](campaign-placement-wave2.md), `resc_mty_20261122_wave2_v1`,
tiene24 etiquetas distintas y24 envíos/22 visibles/2 pendientes,12personal/
12DopMi,12gatos/12perros y6porbrazo. Landing9f8cf944 conserva los enlaces
originales y añade los nuevos. Ambas olas usan el transporte Android
`dopmi_rescatistas_mty_p60_v1` para compatibilidad; separar sus resultados por
`experiment_id` del registro y ledger, sin cambiar los denominadores originales.
Los clientes anteriores rechazan esta gramática.

La etiqueta automática no requiere escribir códigos. Una vez validada, une la
fuente consentida y los recibos originales por mascota con experimento/brazo/token.
El ledger privado añade el comentario/post real; no demuestra que la cuenta que
convierte sea la misma autora de Facebook. Los identificadores sociales permanecen
fuera del backend. iOS conserva medición agregada por brazo y cobertura desconocida
a nivel comentario tras instalar; no imputar cero ni atribución individual.
El rendimiento de primeras fichas por token/contacto puede incluir lectores;
no presentarlo como tasa de conversión de las rescatistas contactadas.

## Meta y Google Ads son otra integración

Los hitos privados de Supabase **no se envían automáticamente** a Meta/Google.
Los tokens del piloto p60 y de la segunda ola pertenecen sólo a comentarios orgánicos. No colocarlos
en anuncios ni reutilizar personal-a como identificador de un anuncio: mezclaría
los orígenes. El chat de campañas debe conservar el transporte y contrato de
consentimiento, pero preparar un namespace pagado y verificar su recorrido antes
de atribuir resultados a Meta/Google/TikTok o compararlos con este piloto.
El chat destinatario conserva su integración Meta Android en otra rama:
permiso publicitario separado, trabajador/CAPI y eventos Contact/SubmitApplication.
Último registro revisado del18/nov: recepción instalada/publicitaria todavía
pendiente; duplicados de campañas apagados/en borrador. Consultar el estado nuevo
en su propio `docs/meta-app-events.md` antes de actuar. No se acreditó aquí una
importación de conversiones a Google Ads.

Para adquisición de publicadores, SubmitApplication/primera ficha es el objetivo;
Contact puede ser una acción de adoptante. No optimizar hacia saludos como si
fueran rescatistas captados. Cotejar en cada proveedor recepción, deduplicación,
permisos y ventana por separado; jamás sumar sus conversiones atribuidas a las
de Supabase ni sustituir la comparación por sus diferentes modelos de atribución.

## Entrega al operador

1. Leer este contrato y el protocolo experimental; usar métricas únicas por cuenta
   y cohortes maduras, con exclusión QA y desglose por SO/cobertura.
2. Conservar campañas, presupuestos, IDs, SDK, consentimientos y trabajo ajenos.
   No fusionar ramas antiguas ni publicar un candidato para leer estos documentos.
3. Preparar la instrumentación y el registro nuevos del protocolo sobre el último
   producto inventariado. Toda nueva ampliación debe validar el recorrido real
   antes de presentar esos brazos como medibles.
4. Auditar en paralelo las campañas pagadas vigentes con el mismo objetivo de
   primera ficha. La atribución interna sirve para evaluar; para optimizar los
   proveedores aún hacen falta sus puentes verificados.
5. No activar ppid, campañas duplicadas, gasto nuevo o cambios de asignación
   geográfica a partir de esta entrega documental. Preparar primero el cambio
   concreto y respetar la autorización operativa/presupuestaria vigente.

Documento compartido en Git: no contiene cuentas QA, cuerpos de chats, autores
de Facebook, fichas reales, credenciales ni números privados de los recibos.
