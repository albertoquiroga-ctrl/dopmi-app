# Prueba de Meta en Samsung del 22 de noviembre de 2026

El Samsung SM-S938B ejecutó Dopmi 2.3.6 (435), Android 17, instalado desde
Google Play por la pista cerrada `samsung-meta-qa`. El candidato usa DEV,
con la integración Android de Meta activa. La prueba utilizó dos cuentas
ficticias controladas y la ficha privada «Nube Meta QA 17».

La compilación corresponde a Codemagic `6b03456147e5658aabda40e9`,
workflow `android-meta-samsung-private-qa`, fuente congelada
`dda575c1a00da14483d156a5c7767f90627ab0ba`. El recibo de compilación
conservado en [el registro de progreso](progress.md) identifica el AAB con
SHA-256 `ef687135d852543c192d07e9c35dca2e4a347078d62e09c76914874e746acd39`.

Todas las horas de esta secuencia son UTC del 22 de noviembre.
En Ciudad de México corresponden a seis horas menos.

| Hora | Comprobación |
| --- | --- |
| 21:21:25 | Lectura de DEV. Dos cuentas QA activas y confirmadas, ficha privada `draft` v2 con una foto existente en Storage y conversación vacía. Gate apagado, cero permisos y cero eventos. |
| 21:23:17 | Se verificó la preparación legal de la cuenta ficticia adoptante mediante `accept_current_legal`, con términos del 1 de noviembre y aviso de ubicación vigente en DEV. La sesión auxiliar quedó cerrada. Esta preparación corresponde a la cuenta de QA. |
| 21:24:52.588 | El adoptante envió un mensaje desde el compositor nativo. DEV guardó un mensaje en la conversación privada. La preferencia de Meta estaba activa y Analítica de uso permanecía apagada. |
| 21:24:52.595 | DEV capturó un `first_adoption_message`, que el worker transmite como `Contact`. La lectura anterior a la entrega comprobó contexto presente, build 435, app 2.3.6 y Android 17. |
| 21:27:26.561 | El rescatista tocó «Enviar a revisión» y el Samsung mostró la confirmación. DEV capturó un `first_adoption_submission`, que el worker transmite como `SubmitApplication`. El operador comprobó antes del POST contexto presente, build 435, app 2.3.6 y Android 17. |
| 21:27:53.911 | DEV registró el reconocimiento de entrega de `Contact`. |
| 21:27:54.230 | DEV registró el reconocimiento de entrega de `SubmitApplication`. |
| 21:29:11.996 | Postflight independiente de DEV. Gate apagado, cero permisos, dos eventos entregados, cero contextos publicitarios retenidos y cero leases. |

La invocación autenticada de `meta-ads-worker` devolvió HTTP 200 con
`{"delivered":2,"skipped":0,"failed":0}`. El worker v5 confirma cada
entrega cuando Meta responde `events_received=1` y el reconocimiento de
la cola termina correctamente. Cada evento acumuló un intento y una
entrega. El identificador publicitario y las versiones del contexto se
eliminaron al completar cada entrega. Se conservaron las marcas internas
de deduplicación.

La ficha quedó en `submitted`, versión 6, con fecha de envío y sin fecha
de publicación. La consulta de detalle público siguió devolviendo ausencia.
La conversación conservó un único mensaje del adoptante. El recorrido
utilizó exclusivamente la ficha y los participantes ficticios de QA.

| Resultado al cierre | Contact | SubmitApplication |
| --- | --- | --- |
| Capturas | 1 | 1 |
| Intentos de entrega | 1 | 1 |
| Entregas reconocidas | 1 | 1 |
| Contextos publicitarios retenidos | 0 | 0 |

La recepción visible se comprobó posteriormente el mismo día en el conjunto DopMi
`1839761860506617`, vinculado a la app `1156849688851390`: «Contactar» y «Enviar
solicitud» activos, API de conversiones, una recepción cada uno. Esa lectura sigue
correspondiendo a esta prueba DEV.
La atribución a anuncios requiere una interacción publicitaria atribuible.
Este ensayo acredita las acciones nativas de QA en DEV, su captura y el
reconocimiento de recepción de la API.

El seguimiento de producción requiere portar la integración a una base
compatible con la versión 437 y verificar ese candidato en el teléfono,
además de completar las comprobaciones del aviso público, las declaraciones
de Play y la recepción visible de Meta antes de activar el piloto.
Los borradores de campañas mantienen su verificación pendiente.
El procedimiento de configuración y cierre está en
[Eventos de adopción para Meta Ads](meta-app-events.md).


La base identificada para la incorporación posterior a producción es
`codex/analytics-quality-20261122@48d3cb8d732224b5b5834d6ca5198cc4dbe34e84`.
El inventario de solo lectura detectó dos contratos que deben conservarse:
`registerPlayInstallReferrer` en Android y el resultado `message/signals`
de `dopmi_send_message_v3`, junto con `confirmedValueAction` y el token
atribuible. Copiar los repositorios o la actividad Android de 435 sobre
437 retiraría correcciones posteriores. No se realizó ese porte ni una
migración de producción durante esta prueba.

El Samsung volvió a 2.3.10 (437) de producción por Google Play. La
lectura independiente de ADB confirmó código 437 e instalador
`com.android.vending`. Otro chat de Dopmi completó la actualización en
el mismo teléfono. Al detectar la operación simultánea se detuvieron
los controles nativos de esta prueba. No se desinstaló Dopmi ni se
borraron sus datos. La comprobación de la sesión de producción corresponde
al recorrido de ese chat y no se da por verificada en este recibo.

## Continuación PROD — 439 disponible interna, aún sin prueba física

El porte aditivo b471bdaf conserva los contratos de437 y ya está desplegado en
PROD20261122232424/worker1, gateMetaOFF, preferencias0 y outbox0. Aviso público
publicado y declaraciones Play preparadas/en revisión. CI45080438018 cuatroSUCCESS;
CM6b037b2b3b42a788f941ec41/14SUCCESS, 2.3.11(439), disponible a testers internos.
AAB/firma/pin/perfilPROD/Meta/InstallReferrer verificados estáticamente.

No se instaló439 ni se generaron eventos PROD: el Samsung no aparece por USB.
Se pidió al titular conectarlo y dejarlo desbloqueado. Se conserva la sesión437;
no borrar datos ni reinstalar. Analítica y diagnóstico deben permanecer como los
dejó el titular; para QA autorizada de Meta, mantener GAOFF y cambiar sólo Meta.
La ficha ficticia debe quedarse privada/en revisión, nunca aprobarse públicamente.

El panel de Meta pide una aceptación adicional al abrir revisión de eventos;
confirmación de ese acuerdo en el momento pendiente. No se cambió el handler por
el aviso de Ads Manager «Acaba de configurar tu aplicación»: app1156849688851390
y cuenta773207924311457 están vinculadas al conjunto; categoríaNinguna y ajuste
básicoOFF. Las lecturas del inventario Graph con tokenCAPI devolvieron permisos
100/3000 y no prueban ausencia de eventos. Falta revisar estado/diagnóstico tras
la aceptación y seleccionar los eventos antes de publicar los pilotos.
