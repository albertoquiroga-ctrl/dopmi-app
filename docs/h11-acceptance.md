# H11 — aceptación beta en Android e iOS

Fecha de inicio: 29 de septiembre de 2026. Referencia visual vigente:
`irlanda/apoyar-detalle-perfil@a246fa6f42ec517aae264d7fbd2358d647c4f840`.
El titular admitió las pantallas actuales para continuar; H11 busca defectos
funcionales, de usabilidad y accesibilidad críticos o altos, sin reabrir H8.

## Candidato fijado

| Plataforma | Versión | Distribución | Codemagic | Fuente | Estado |
| --- | --- | --- | --- | --- | --- |
| Android | 2.3.3 (283) | Google Play Internal Testing | `6abc771aec8422516e05ee18` | `94cb82e2496e4943065d6464962a111fa719bedd` | Disponible para testers internos |
| iOS/iPadOS | 2.3.3 (284) | TestFlight / `DopMi Inner Team` | `6abc7724e5d014fada0172c5` | `94cb82e2496e4943065d6464962a111fa719bedd` | Finalizado y En pruebas |

Los workflows aprobaron configuración, Firebase, dependencias, análisis,
pruebas, firma, artefactos y publicación. GitHub CI `36660362119` y
`36660356662` aprobó los cuatro trabajos en el mismo SHA. Play confirmó 283
disponible para testers internos y desactivó 281; App Store Connect confirmó
284 `Finalizado`, `En pruebas` y en `DopMi Inner Team`. Los anteriores 281/282
quedan como evidencia del recorrido inicial, no como candidatos finales.
Producción continúa sin cambios y Stripe permanece exclusivamente en test.

## Matriz de aceptación

Registrar plataforma, dispositivo, sistema, build y resultado. No registrar
correos completos, alias privados, tokens, documentos ni referencias Stripe.

| Recorrido | Android 283 | iOS 284 | Criterio |
| --- | --- | --- | --- |
| Instalar o actualizar desde la tienda interna | Aprobado | Pendiente | Configuración debe mostrar Android 2.3.3 (283) e iPadOS 2.3.3 (284) |
| Sesión existente, cierre/reapertura y cierre de sesión | Aprobado | Aprobado | Ambos conservan sesión al reiniciar y cerrar sesión retira el acceso |
| Google: cancelar, entrar y reutilizar perfil | Aprobado | Aprobado | En ambos, cancelar deja la app sin sesión; entrar vuelve al perfil Google existente sin repetir términos y persiste |
| Apple nativo: cancelar, entrar y reutilizar perfil | No aplica | Aprobado | Identidad nueva con Ocultar mi correo exigió 18+/términos; cancelar dejó la app sin sesión; reingreso persistió |
| Correo: confirmación, recuperación y enlace de retorno | Parcial; entrega diferida a H12 | Diferido a H12 | Android manejó un callback inválido con error recuperable y conservó la sesión; la entrega desde buzón se valida con el candidato final |
| Navegación por Adoptar/Apoyar/Perfil y cambio de modo | Aprobado | Aprobado | Pestañas, Configuración e Información básica abren/regresan sin pantalla negra ni pérdida de sesión |
| Catálogo, filtros, detalle y guardado | Aprobado | Aprobado | Filtro aplicar/limpiar, detalle y alta/baja de guardado funcionaron en ambos |
| Contacto, envío, reapertura y cierre de conversación | Aprobado | Aprobado | Contacto y cierre funcionaron; `Prueba H11` persistió una sola vez al reabrir |
| Publicación/caso: borrador, foto, interrupción y retorno | Aprobado | Aprobado | Android manejó rechazo/concesión; iPadOS acceso limitado; foto y borrador persistieron sin enviarse |
| Enlaces de términos, privacidad, ayuda y eliminación | Aprobado | Aprobado | Ayuda/FAQ/correo, términos y privacidad/eliminación abren y regresan; no se solicitó eliminación |
| Analytics y diagnóstico apagados/encendidos/retirados | Aprobado | Aprobado | Ambos persistieron encendidos, se retiraron y siguieron apagados tras reiniciar; sin diagnóstico de prueba |
| Aportación y Guardián en Stripe test | Aprobado | Aprobado | Monto/resumen, método, suscripción e historial cargan/regresan; sin operación nueva; evidencia económica H5 reutilizada |
| Texto ampliado, orientación y lector de pantalla básico | Aprobado | Diferido a H12 | Android conserva acciones esenciales con texto ampliado y orientación horizontal; TalkBack enfocó, anunció y activó controles etiquetados |
| Interrupción de red y reintento | Aprobado con fricción media | Pendiente de 284 | Android renovó la foto y restauró la misma sesión mediante reintento, sin duplicados; la recuperación no fue automática |

Los recorridos financieros pueden reutilizar evidencia H5 cuando el código no
cambió, pero H11 exige al menos abrir las pantallas del candidato y comprobar
que siguen identificadas como test. No se generan cobros adicionales para
repetir evidencia ya aceptada.

## Severidad y cierre

- **Crítico:** acceso indebido a datos, dinero real, pérdida irrecuperable,
  bloqueo general, identidad cruzada o publicación privada. Detiene H11.
- **Alto:** recorrido principal imposible, cierre persistente, eliminación o
  recuperación inutilizable, o accesibilidad que impide una acción esencial.
- **Medio/bajo:** diferencia visual o fricción con alternativa segura. Se
  registra para priorización y no cierra H11 por sí sola.

H11 cierra con los dos builds instalados, matriz funcional aprobada, cero
defectos críticos/altos abiertos, revisión externa registrada y reversión de
distribución ensayada. La ficha pública Apple y el aviso histórico de Google se
atienden después, con el candidato final acordado.

### Corte autorizado para continuar a H12

El 30/9 el titular autorizó cerrar el trabajo autónomo disponible en Android y
trasladar al candidato final H12 la entrega real de correo, la regresión iOS 284
y la revisión visual de Irlanda. No hay un defecto crítico o alto abierto en la
evidencia ejecutada; la recuperación no automática de red queda como fricción
media. Este corte permite iniciar H12, pero no convierte las filas diferidas en
aceptación de iOS ni visual y no autoriza dinero real o publicación pública.

## Reversión de distribución

Esta reversión retira un candidato defectuoso de prueba; no revierte pagos,
migraciones ni datos. No se reutiliza un `versionCode` o `CFBundleVersion`.

1. Registrar build, SHA, defecto y alcance; cerrar nuevas invitaciones mientras
   se evalúa el incidente.
2. Android: no intentar un downgrade. Partir del último SHA conocido como bueno,
   ejecutar las puertas completas y publicarlo a `internal` con un código mayor.
   Verificar por separado compilación y disponibilidad antes de pedir la
   actualización a testers.
3. iOS: retirar el build afectado del grupo interno. Reasignar el build anterior
   compatible sólo como contención o cargar el SHA conocido como bueno con un
   número mayor. Confirmar `En pruebas` antes de notificar.
4. Si el defecto depende de un servicio, mantener producción cerrada y usar los
   flags servidor documentados; nunca borrar evidencia ni cambiar claves de
   idempotencia para forzar una recuperación.
5. Instalar la versión de contención y repetir únicamente los recorridos
   afectados. Conservar el candidato fallido y sus logs como evidencia.

El ensayo de H11 se realiza sin retirar 281/282: verificar que el SHA conocido
como bueno, los workflows, firma, canales y números monotónicos estén
identificados; la ejecución real sólo procede si aparece un defecto bloqueante.

### Ensayo registrado

El 29/9 se ejecutó el ensayo sin mutar las tiendas. Git confirmó disponible el
SHA conocido como bueno `d57aea8aef3fad2687b177d2f5ed3634c6672849` y el
candidato `0a25ba81fc39192c772ca0bbe4453697fb9ca905`. Entre ambos, el único
cambio de aplicación es el botón de correo del Centro de ayuda; no cambian
Supabase, configuración, firma ni workflows. La versión anterior conserva
`android-guardian-internal`, `ios-testflight`, `com.mycompany.dopmi`, Play
`internal` y `submit_to_app_store: false`. Resultado:
`ROLLBACK_REHEARSAL_OK`. Una reversión real recompilaría ese SHA con números
mayores; no se alteraron 281/282 porque no existe un defecto que lo justifique.

## Evidencia de dispositivo

- Android: captura `1000346499.jpg`, aportada por el titular el 29/9, muestra
  Dopmi abierto en Configuración con **Versión 2.3.3 (281)**. Se acredita la
  instalación del candidato exacto; la captura no acredita todavía persistencia
  de sesión, recuperación, accesibilidad ni los demás recorridos de la matriz.
- Android 281: el titular cerró Dopmi completamente y volvió a abrirla. La sesión
  se conservó y la app no volvió a pedir acceso ni aceptación de términos. Falta
  probar el cierre explícito de sesión y el nuevo acceso en este build.
- Android 281: **Cerrar sesión** volvió al acceso; cancelar el selector de Google
  conservó el estado sin sesión; repetir Google entró con la misma cuenta y el
  mismo perfil, sin volver a solicitar términos. Quedan aprobados cierre de
  sesión, cancelación y reingreso Google para este candidato.
- iPadOS: captura `Photo 1.jpg`, aportada por el titular el 29/9, muestra Dopmi
  abierto desde TestFlight en Configuración con **Versión 2.3.3 (282)**. La
  disposición horizontal conserva todas las acciones principales visibles. Se
  acredita instalación; los recorridos funcionales y accesibilidad siguen
  separados.
- iPadOS 282: el titular cerró Dopmi completamente y volvió a abrirla. La sesión
  se conservó sin volver a pedir acceso ni términos. Falta comprobar cierre de
  sesión y los proveedores sociales dentro de este candidato.
- iPadOS 282 / Apple: Apple volvió a ofrecer **Compartir mi correo** u
  **Ocultar mi correo**. El titular eligió ocultarlo; Dopmi mostró el gate de
  mayoría de edad/términos y creó la sesión sólo después de aceptarlo. Tras
  cerrar sesión, una cancelación de Apple dejó la app sin sesión. El siguiente
  acceso terminó correctamente y persistió al cerrar/reabrir Dopmi. No se
  registró el alias. El gate de cuenta nueva es evidencia compatible con la
  regla de no fusionar automáticamente correos distintos.
- iPadOS 282 / Google: cerrar la sesión Apple y cancelar Google mantuvo la app
  sin sesión. Repetir Google regresó al perfil Google existente sin volver a
  pedir términos y conservó la sesión después de cerrar/reabrir Dopmi.
- Android 281 e iPadOS 282: Adoptar, Apoyar, Perfil, Configuración e Información
  básica abrieron y permitieron regresar sin pantalla negra, bloqueo o pérdida
  de sesión. Centro de ayuda desplegó su contenido y el botón de soporte abrió
  el compositor sin enviar correo. Términos/privacidad y
  Privacidad/eliminación abrieron y regresaron correctamente; no se inició una
  eliminación.
- Android 281 e iPadOS 282: se aplicó y limpió un filtro, se abrió el detalle de
  una publicación demo y el guardado se activó/desactivó correctamente. Contactar
  abrió la conversación; el mensaje `Prueba H11` apareció una sola vez después
  de salir y reabrir, y la conversación pudo cerrarse. No se registró otro
  contenido del chat.
- Android 281 e iPadOS 282: en modo Rescatista, Publicar → Adopción permitió
  seleccionar una imagen no personal y conservar el borrador al cerrar/reabrir.
  Android explicó el permiso rechazado y funcionó al concederlo; iPadOS funcionó
  con acceso limitado. El borrador no se envió a revisión.
- Android 281 e iPadOS 282: Aportar llegó al monto/resumen y regresó antes de
  Checkout. Método de pago, Suscripción y pagos e Historial cargaron o mostraron
  su estado y permitieron regresar, sin pantalla negra, dato productivo ni
  operación nueva. H5 conserva la aceptación de alta/cancelación/devolución en
  Stripe test; entre su SHA aceptado y este candidato no cambió el motor
  financiero.
- Android 281 e iPadOS 282: Analítica y Diagnóstico persistieron al activarlos
  y navegar, se apagaron independientemente y continuaron apagados después de
  reiniciar Dopmi. No se pulsó el diagnóstico interno ni se atribuye un evento
  remoto nuevo; H10.3 conserva la comprobación de cero emisión tras retirada.
- Android 281 e iPadOS 282: el titular observó ocasionalmente una publicación
  con el marcador `Cargar foto` en ambas plataformas. La causa reproducible en
  código fue la URL firmada privada con sólo 60 segundos de vigencia: podía
  vencer durante una suspensión breve, navegación diferida o red lenta. Se
  conserva Storage privado, se amplía la vigencia temporal a diez minutos y la
  tarjeta solicita una URL nueva una sola vez antes de ofrecer el reintento
  manual. La corrección requiere candidatos conjuntos nuevos y repetición del
  recorrido de catálogo; 281/282 dejan de ser candidatos finales de H11.
- La corrección quedó en `94cb82e2496e4943065d6464962a111fa719bedd`.
  Dos ejecuciones completas de CI aprobaron análisis, pruebas, capturas, APK de
  desarrollo, iOS simulator, administración, PostgreSQL y backend. Codemagic
  publicó Android 2.3.3 (283) en Play interno e iOS 2.3.3 (284) en TestFlight.
  Play muestra 283 disponible y 281 desactivado; App Store Connect muestra 284
  `Finalizado`, `En pruebas` y asignado al grupo interno. Falta instalación y
  regresión física del catálogo en ambos candidatos.
- El titular reportó un destello ocasional de `Antes de continuar` al iniciar
  una sesión que ya tenía el consentimiento vigente. La capa de seguridad veía
  el perfil nulo durante su lectura y lo confundía por un cuadro con un perfil
  sin aceptación. La corrección conserva el cierre seguro si la lectura falla,
  pero durante la consulta muestra `Restaurando sesión`; una regresión con el
  perfil deliberadamente demorado comprueba que el aviso legal nunca aparece.
  Se integrará con los siguientes cambios antes del QA final agrupado de
  Irlanda, sin solicitar otro recorrido manual completo para este parche.
- Android 283 se actualizó directamente desde Google Play Internal Testing en
  un Samsung SM-S938B con Android 16. Configuración mostró **2.3.3 (283)**; la
  actualización conservó la sesión y abrió Adoptar sin repetir acceso ni
  consentimiento. La foto de Rocky cargó antes y después de una suspensión de
  más de 60 segundos, acreditando en este dispositivo la corrección de la URL
  firmada que fallaba en 281.
- La prueba de red desactivó temporalmente Wi-Fi y datos y abrió Dopmi en frío.
  La app cerró de forma segura mostrando el consentimiento mientras no podía
  leer el perfil; al regresar la conexión, el primer reintento mostró la ruta
  de recuperación y el segundo restauró la misma sesión, catálogo y foto. No
  hubo reingreso, duplicado ni mutación de mensajes, publicaciones o pagos. Se
  registra como fricción media: la recuperación requiere intervención y puede
  mostrar temporalmente un aviso legal ya aceptado.
- Con escala de texto aumentada de 1.15 a 1.30, Adoptar conservó visibles y
  operables ubicación, especie, filtros, tarjeta, Pasar, Contactar, Me gusta y
  la navegación inferior. Configuración funcionó en horizontal y el árbol de
  accesibilidad expuso nombres para las acciones esenciales. TalkBack de
  Samsung se habilitó temporalmente: recorrió por foco los controles, anunció
  sus etiquetas y activó una ruta Guardián marcada como prueba. Se restauraron
  TalkBack, escala y rotación a los valores originales.
- Un callback Android controlado con error abrió la recuperación segura, mostró
  acciones para reintentar o volver al acceso y, al regresar, conservó la
  sesión existente. Esto acredita el manejo del enlace inválido sin acreditar
  entrega de correo; el recorrido desde el buzón queda en H12.
