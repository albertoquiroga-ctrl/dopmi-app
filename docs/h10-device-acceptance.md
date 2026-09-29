# H10 — aceptación en dispositivos

Esta hoja registra exclusivamente resultados observados en instalaciones de
Internal Testing y TestFlight. No anotar contraseñas, tokens, correos privados
completos, UUID ni referencias de Stripe. Para una identidad desechable basta
un alias como `google-a`, `apple-a` o `apple-relay-a`.

## Candidato

| Campo | Android | iOS |
|---|---|---|
| SHA | `af8027a47ddd6c94caebdcc3b2672033baf2c29e` | `af8027a47ddd6c94caebdcc3b2672033baf2c29e` |
| Workflow | `android-guardian-internal` | `ios-testflight` |
| Codemagic | build 16 (`6abb1b18a7c0e10e9a05069e`) | build 5 (`6abb1b1832bd8882759214f4`) |
| Versión disponible | `2.3.3 (264)` | `2.3.3 (265)` |
| Dispositivo / SO | pendiente | pendiente |
| Tienda disponible | Internal Testing desde 28/9/2026 20:15 | TestFlight, grupo `DopMi Inner Team`, estado `En pruebas` |

El candidato anterior quedó **superado** para la aceptación de cuenta: Android 262
mostró pantalla negra al abrir **Información básica**, no expuso la eliminación
desde Configuración y conservó el texto obsoleto **Aviso de desarrollo**. La
cancelación inicial de Google sí quedó comprobada sin crear una identidad. Los
demás recorridos deben ejecutarse en el candidato 264/265 descrito arriba.

## Recorrido Android

1. Instalar o actualizar desde Google Play Internal Testing y comprobar la
   versión del candidato.
2. Con Analytics y Diagnóstico apagados, cancelar Google antes de autorizar.
   Confirmar que no se creó una identidad Dopmi.
3. Entrar con Google usando `google-a`, aceptar mayoría de edad y términos,
   cerrar y volver a abrir la app. Comprobar sesión persistente, cierre de sesión
   y acceso repetido al mismo perfil.
4. Desde una sesión existente, vincular Google explícitamente. Comprobar que el
   proveedor regresa al mismo perfil. Un correo distinto nunca debe fusionarse
   automáticamente.
5. Repetir cancelación y acceso con Apple en navegador. Comprobar el regreso a
   la app y el mismo aislamiento de identidades.
6. Habilitar Analytics, completar una acción real permitida y comprobar su evento
   en Firebase. Retirar el consentimiento y confirmar que cesan los envíos.
7. Habilitar Diagnóstico, usar **Enviar diagnóstico de prueba** y comprobar el
   error no fatal fijo en Crashlytics. Retirar el consentimiento y confirmar que
   no se envían diagnósticos posteriores.
8. Solicitar eliminación de `google-a`. Repetir la solicitud y comprobar bloqueo
   inmediato, rechazo de la sesión anterior y ausencia de publicaciones públicas.
   Confirmar que la cuenta Google externa sigue funcionando.

## Recorrido iPhone

1. Instalar el mismo SHA desde TestFlight y comprobar la versión del candidato.
2. Repetir cancelación, alta, aceptación, reinicio, cierre y acceso repetido con
   Google usando una identidad desechable.
3. Cancelar Apple nativo antes de autorizar y confirmar que no se creó cuenta.
4. Entrar con Apple nativo usando **Ocultar mi correo** (`apple-relay-a`), aceptar
   mayoría de edad y términos, reiniciar la app y comprobar el mismo perfil.
5. Vincular Apple desde una sesión existente y comprobar que regresa al perfil
   original. No intentar unir correos diferentes por inferencia.
6. Repetir las pruebas de Analytics y Diagnóstico, incluida la retirada inmediata
   de cada consentimiento.
7. Probar confirmación, recuperación y comunicación de eliminación hacia el alias
   privado de Apple. Registrar sólo recepción y hora aproximada, nunca el alias.
8. Eliminar `apple-relay-a`; comprobar bloqueo, rechazo de sesión, revocación de
   Apple y ausencia de la credencial cifrada en servidor. Repetir la solicitud
   para acreditar idempotencia. La cuenta Apple externa debe permanecer intacta.

## Evidencia de servicios

| Comprobación | Resultado | Evidencia mínima |
|---|---|---|
| Sin Analytics antes del consentimiento | pendiente | DebugView o eventos del dispositivo sin actividad Dopmi |
| Eventos permitidos con consentimiento | pendiente | nombre del evento y hora; sin parámetros privados |
| Sin Analytics después de retirar | pendiente | intervalo observado sin eventos nuevos |
| Crashlytics apagado | pendiente | ausencia antes del consentimiento |
| Diagnóstico interno habilitado | pendiente | no fatal `dopmi_diagnostics_test` |
| Crashlytics retirado | pendiente | ausencia después de retirar |
| Private Relay | dominio registrado; entrega pendiente | `dopmi.org` aceptado por Apple con SPF; falta prueba al alias |
| Eliminación Google | pendiente | estado final y sesión antigua rechazada |
| Eliminación Apple | pendiente | estado final, grant revocado y credencial ausente |

## Resultado

H10 sólo se acepta cuando las dos columnas del candidato corresponden al mismo
SHA, cada recorrido anterior tiene evidencia observada y no quedan defectos
críticos o altos. Una compilación o carga a la tienda no sustituye la instalación
ni las pruebas físicas.
