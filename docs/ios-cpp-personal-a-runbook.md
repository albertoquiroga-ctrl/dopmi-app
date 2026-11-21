# Operación de la prueba iOS CPP personal-a

Corte de preparación20/11/2026, CDMX. Este documento guía la aceptación futura;
no acredita por sí mismo el recorrido instalado. El estado y
los recibos vigentes se registran en [candidato](candidate-release-current.md) y
[progress](progress.md). Alcance en el [plan](superpowers/plans/2026-11-20-ios-cpp-personal-a.md)
y fundamento en la [investigación](ios-direct-attribution-research.md).

## Preparación registrada

| Objeto | Corte conocido |
| --- | --- |
| Base de integración vigente | `e48a653bbd0d58bc8d7913ebbb67a048f4eabc34`, rama `codex/production-attribution-restored-20261120`, tras inventario acotado del avance remoto. Conservar visor/carrusel, compartir HTTPS de ficha y perfil, Tienda, detalles opcionales, navegación, sello y correctivo de perfil público. |
| CPP | Borrador `f72ab3bc-1cd0-49b7-9220-cff726c86ffd`, guardado desde la ficha2.3.8(419). No enviado a revisión. |
| Destino | Únicamente `io.dopmi.app://acquire/personal-a`. No códigos ni login antes de descargar. |
| Landing | El nuevo `ppid` no está activado. Las rutas publicadas mantienen el alcance agregado `pt/ct` anterior. |
| Validación y servidor | Fuente55061f99, CI44860327579 cuatroSUCCESS; SQL PROD20261121034107 aplicado y cotejado, historia71/prefijo70 y333funciones previas intactos. Recibos en candidato/progress. |
| Candidato del ensayo |2.3.9(421) mediante `ios-testflight`, PROD/adopciones/AmazonON, sólo carga. Handle único6b0112f68d36bd30d38e3998/15SUCCESS; IPA cotejado y Apple procesado/Lista para enviar/DopMi Inner Team confirmado22:03CDMX. La continuación posterior de favoritos/424 está registrada en candidato; no sustituye la versión421 de este ensayo. Sin revisión pública ni aceptación del recorrido CPP/App Store. |
| Dispositivo | iPad Pro12.9″/5.ªgeneración, iPadOS26.6.1,421/TestFlight reportado por titular. Safari abrió la URI con su sesión. PROD coteja el mismo actor: sin fuente20nov22:44→personal-a/ios_cpp_open22:53:37CDMX. Primera ficha real enviada21nov16:37:27CDMX, referencia exacta en la fuente original, estado submitted, dos fotos privadas y AnalíticaON/revisión3. Sin aprobación/publicación ni eventos de mensajes. No hay lectura USB/control remoto ni prueba de muerte del proceso. |

La existencia del borrador no demuestra aprobación ni disponibilidad. Apple exige
iOS/iPadOS18+ y pulsar **Abrir en esa CPP** para entregar su deep link. No promete
la misma entrega al abrir desde el icono o la ficha predeterminada.
[Contrato Apple](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions/).

El corte inicial `1a9a83e3335698375768f7c32c818d3fb5444e15` queda como referencia
histórica. El avance revisado incorpora `b278540d`, correctivo de compartir perfil
HTTPS y sus pruebas; no construir el candidato iOS desde el corte antiguo.

## Puertas antes de activar personal-a

1. Congelar el SHA del cliente integrado sobre esta base y comprobar los arreglos
   conservados. Identificar pruebas, CI y revisión independiente de ese SHA;
   no sustituirlas por resultados del419 ni incorporar ramas antiguas.
2. Cotejar historia remota y objetos reales antes de la migración aditiva. Seguir
   [migration-history-audit](migration-history-audit.md); no repetir SQL ni reparar
   timestamps para alinearlos. Verificar después funciones, permisos, triggers,
   aislamiento y guardas financieras. Este runbook no afirma que se haya aplicado.
3. Cargar el candidato con identidad/firma `com.mycompany.dopmi` existentes.
   `ios-testflight` tiene ambos `submit_to_*` enfalse: carga un build elegible,
   sin envío automático a App Review o Beta App Review. Conservar Supabase,
   Firebase y Maps PROD, adopciones/AmazonON y finanzas/billeterasTESTOFF.
   Fijar `DOPMI_APP_STORE_SUBMISSION=false` para esa carga. Comprobar IPA,
   fuente, versión, entorno, carga y procesamiento por separado.
4. Conservar la revisión del419 durante la preparación. El workflow
   `ios-app-store` sí envía automáticamente; no usarlo como simple carga.
   Comprobar el estado actual antes de crear una versión nueva: Apple exige
   Ready for Distribution. [Versiones](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version/).
   Al preparar2.3.9, actualizar las notas de revisión al421 y sus funciones:
   las notas heredadas del419 todavía mencionan2.3.3(369)/Tienda no disponible.
   Esta prueba no editó esa revisión pendiente ni sus credenciales.
5. Presentar cliente compatible y CPP por la ruta de revisión adecuada. La CPP
   puede acompañar una versión o revisarse por separado; su destino debe existir
   en el cliente que se entregue. [Revisión CPP](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-a-custom-product-page).
6. Sólo con cliente público y CPP aprobada, activar el `ppid` oficial en el destino
   iOS de personal-a. Copiar su URL de App Store Connect, sin inventarla. Mantener
   las otras variantes y Android; comprobar GET/HEAD, salto directo, `ppid/pt/ct/mt`
   y fallback de crawlers. No añadir formularios, códigos ni autenticación web.

TestFlight sirve para comprobar recepción de enlaces, inicio de sesión,
consentimiento y transporte. No prueba la instalación limpia desde una CPP de
App Store ni sustituye esa puerta.

En el iPad confirmado, primero comprobar la instalación de2.3.9(421) y su UI.
Conservar sin envíos/contactos/mensajes la cuenta reservada para la instalación
definitiva. Un ensayo opcional de URI/consentimiento usa otra cuenta QA,
se registra como TestFlight/enlace directo y se excluye del experimento; no
necesita consumir una primera ficha ni se presenta como instalación desde CPP.

El transporte TestFlight421 + Safari ya tiene evidencia positiva del20/nov:
registro automático consentido para la sesión correcta. Notas no reconoció el
texto como enlace; el titular usó la barra de direcciones de Safari. No se
atribuyó el fallo de detección de Notas al cliente. Recibo privado
`ipad421-safari-registration.verified.private.json`. Consulta operativa con
exclusión QA: bruto1/técnico1/noQA0; el reporte bruto sigue incluyendo el ensayo.

El21/nov el titular confirmó una mascota real sin publicar y completó desde el
iPad **Mis publicaciones → Publicar una adopción → Continuar → Ir a vista previa
→ Enviar a revisión**; informó «Enviado a revisión». Preflight16:31CDMX:
misma cuenta activa, fuente original y cero fichas. Readback16:37:58CDMX:
una ficha propia submitted a16:37:27.809, y la fuente apunta exactamente a ella
con `first_submitted_at`16:37:27.856, dentro de336h. La inscripción original
personal-a/ios_cpp_open del20nov22:53:37 permanece intacta. Las dos fotos existen
en el bucket privado, con rutas del dueño/ficha y archivos válidos no vacíos.
Sin publicación, aprobación, revisiones ni eventos de mensajes; ninguna escritura
SQL, reasignación o backfill por el operador. Recibo privado
`ipad421-first-listing.verified.private.json`, revisado independientemente.
Consulta16:41:48CDMX: fuentes bruto1/QA1/noQA0 y primeros envíos bruto1/QA1/noQA0;
la exclusión es un filtro privado, sin borrar ni modificar datos.

Este resultado verifica **la primera ficha automática en421/TestFlight + Safari**.
Aprobación, saludos y mensajes continúan pendientes, al igual que la instalación
real desde CPP/App Store con una cuenta reservada. No volver a consumir esta
primera ficha ni presentar el ensayo como QA de iPhone o del424 posterior.

## Recorrido físico y evidencia requerida

Usar un iPhone con iOS18+ o un iPad con iPadOS18+, y una cuenta QA autorizada
sin envíos/revisiones anteriores
observables. El usuario completa acceso y aceptación legal personalmente. Registrar
versión/build instalado, origen App Store y método de apertura. No consumir de
nuevo fixtures anteriores ni limpiar historia para volver elegible una cuenta.

Probar por separado Safari y el navegador interno de Facebook: personal-a → CPP
correcta → instalar → **Abrir en esa misma página** → login habitual en DopMi →
Analítica de uso. Antes de enviar, comprobar por lectura privada que existe una
única fuente del actor, variante personal-a y método `ios_cpp_open`.

| Hito separado | Evidencia de aceptación |
| --- | --- |
| Primera ficha enviada | Ficha privada enviada por ese actor; misma referencia en la fuente, `first_submitted_at` posterior a inscripción y sin publicación automática. |
| Aprobación | Sólo la aprobación ordinaria de esa misma primera ficha puede completar `first_approved_at`; no aprobar una ficha sintética para cerrar QA. |
| Saludo automático | Contacto legítimo produce un saludo y un único evento `automatic_greeting`; abrir un hilo existente no lo reenvía. |
| Primer envío humano como adoptante | Texto o foto válidos desde el compositor producen `first_user_message`; lectura y saludo no cuentan. |
| Primera respuesta del dueño | El actor es dueño y hay entrada previa del adoptante; su envío desde compositor produce `first_rescuer_reply`. No atribuirle el envío de la contraparte. |

Los mensajes requieren dos participantes QA legítimos y un escenario contactable
permitido. Una cuenta con fichas antiguas no sirve para una nueva inscripción.
La aprobación y la respuesta como dueño pueden requerir una mascota real y su
moderación normal; si falta ese escenario, mantener esos gates pendientes. No
publicar mascotas sintéticas ni contactar desconocidos para forzar resultados.

Comprobar reintento/deduplicación, enlace caliente después de opt-in, reinicio,
OFF con RPC pendiente, cambio de cuenta, reinstalación, URI inválida y apertura
desde icono/ficha genérica. Una apertura sin contexto no debe inventar una fuente.
Guardar IDs y recibos QA fuera de Git; no capturar contenido de mensajes ni datos
de contrapartes. Excluir QA del análisis agregado sin borrar la prueba.

## Cohorte y criterios de salida

CPP entrega contexto estático autodeclarado, no recibo autenticado de Apple,
fecha fiable del clic, prueba de instalación nueva ni origen Facebook. No otorga
beneficios o permisos. Pendiente local: hasta24h desde recepción; eventos iOS:
14d desde inscripción en servidor. La aprobación posterior sigue a la misma ficha.
OFF o eliminación retiran la fuente/eventos conforme al contrato.

Mantener separados descargas Apple, cuentas consentidas iOS, resultados iOS y
Android14d desde clic. No inferir `new_account`, repartir fuentes desconocidas ni
sumar cohortes. El [reporte iOS](../tools/verification/ios-cpp-acquisition.sql) es
operativo y bruto: requiere exclusión privada de QA y cohortes maduras.

Cerrar aceptación sólo con la unión exacta de actor/variante/ficha y los eventos
permitidos, sin backfill ni reasignación. La falta de un recorrido físico
comprobado deja ese cierre pendiente aunque las verificaciones técnicas y la
carga estén aprobadas.

## Recuperación

Ante pérdida de CPP o defecto de inscripción, detener únicamente el uso nuevo
del `ppid` y conservar el destino agregado Apple `pt/ct` anterior. Mantener RPC y
tablas aditivas compatibles con clientes ya cargados; no borrar fuentes, revertir
historia o revocar consentimientos globalmente como rollback. No cambiar firma,
entorno, finanzas ni Android. Conservar recibos para diagnosticar el recorrido;
la medición opcional nunca debe impedir publicar o enviar un mensaje permitido.
