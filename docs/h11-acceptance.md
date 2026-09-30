# H11 — aceptación beta en Android e iOS

Fecha de inicio: 29 de septiembre de 2026. Referencia visual vigente:
`irlanda/apoyar-detalle-perfil@a246fa6f42ec517aae264d7fbd2358d647c4f840`.
El titular admitió las pantallas actuales para continuar; H11 busca defectos
funcionales, de usabilidad y accesibilidad críticos o altos, sin reabrir H8.

## Candidato fijado

| Plataforma | Versión | Distribución | Codemagic | Fuente | Estado |
| --- | --- | --- | --- | --- | --- |
| Android | 2.3.3 (281) | Google Play Internal Testing | `6abc62eb0f583f5c4835b814` | `0a25ba81fc39192c772ca0bbe4453697fb9ca905` | Disponible para testers internos |
| iOS/iPadOS | 2.3.3 (282) | TestFlight / `DopMi Inner Team` | `6abc62ec0f583f5c4835b816` | `0a25ba81fc39192c772ca0bbe4453697fb9ca905` | Finalizado y En pruebas |

Los workflows aprobaron configuración, Firebase, dependencias, análisis,
pruebas, firma, artefactos y publicación. El commit documental posterior no
cambia los binarios. Producción continúa sin registros, proveedores sociales o
secretos personalizados. Stripe permanece exclusivamente en test.

## Matriz de aceptación

Registrar plataforma, dispositivo, sistema, build y resultado. No registrar
correos completos, alias privados, tokens, documentos ni referencias Stripe.

| Recorrido | Android 281 | iOS 282 | Criterio |
| --- | --- | --- | --- |
| Instalar o actualizar desde la tienda interna | Aprobado | Aprobado | Configuración muestra Android 2.3.3 (281) e iPadOS 2.3.3 (282) |
| Sesión existente, cierre/reapertura y cierre de sesión | Aprobado | Aprobado | Ambos conservan sesión al reiniciar y cerrar sesión retira el acceso |
| Google: cancelar, entrar y reutilizar perfil | Aprobado | Pendiente | Android: cancelar conserva el estado sin sesión; entrar vuelve al mismo perfil sin repetir términos |
| Apple nativo: cancelar, entrar y reutilizar perfil | No aplica | Aprobado | Identidad nueva con Ocultar mi correo exigió 18+/términos; cancelar dejó la app sin sesión; reingreso persistió |
| Correo: confirmación, recuperación y enlace de retorno | Pendiente | Pendiente | El enlace vuelve a Dopmi y no expone una sesión incorrecta |
| Navegación por Adoptar/Apoyar/Perfil y cambio de modo | Pendiente | Pendiente | Sin pantalla negra, bloqueo o pérdida de estado inesperada |
| Catálogo, filtros, detalle y guardado | Pendiente | Pendiente | Carga, vacío, reintento y éxito son utilizables |
| Contacto, envío, reapertura y cierre de conversación | Pendiente | Pendiente | Sólo participantes leen; reintento no duplica mensajes |
| Publicación/caso: borrador, foto, interrupción y retorno | Pendiente | Pendiente | Permisos denegados se explican; borrador no se publica ni se pierde |
| Enlaces de términos, privacidad, ayuda y eliminación | Pendiente | Pendiente | Abren contenido vigente; eliminación exige confirmación explícita |
| Analytics y diagnóstico apagados/encendidos/retirados | Pendiente | Pendiente | No hay emisión antes o después del consentimiento |
| Aportación y Guardián en Stripe test | Pendiente | Pendiente | No usa dinero real; cancelación detiene ciclos futuros y conserva historial |
| Texto ampliado, orientación y lector de pantalla básico | Pendiente | Pendiente | Acciones esenciales siguen visibles, etiquetadas y operables |
| Interrupción de red y reintento | Pendiente | Pendiente | No duplica identidad, mensajes, publicaciones ni pagos |

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
