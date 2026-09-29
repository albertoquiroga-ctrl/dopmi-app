# H10 — aceptación en dispositivos

Esta hoja registra exclusivamente resultados observados en instalaciones de
Internal Testing y TestFlight. No anotar contraseñas, tokens, correos privados
completos, UUID ni referencias de Stripe. Para una identidad desechable basta
un alias como `google-a`, `apple-a` o `apple-relay-a`.

## Candidato

| Campo | Android | iOS |
|---|---|---|
| SHA | `3472c5b4ba5785ab9ab695f4a5d96a3e0befd4a3` | `3472c5b4ba5785ab9ab695f4a5d96a3e0befd4a3` |
| Workflow | `android-guardian-internal` | `ios-testflight` |
| Codemagic | build 15 (`6abb04b63e1e341b2e6b97fb`) | build 4 (`6abb04b74427c92a169daabd`) |
| Versión disponible | `2.3.3 (262)` | `2.3.3 (263)`, procesamiento finalizado |
| Dispositivo / SO | pendiente | pendiente |
| Tienda disponible | Internal Testing desde 28/9/2026 18:30 | falta declaración de exportación y grupo interno |

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
| Private Relay | pendiente | entrega confirmada sin documentar el alias |
| Eliminación Google | pendiente | estado final y sesión antigua rechazada |
| Eliminación Apple | pendiente | estado final, grant revocado y credencial ausente |

## Resultado

H10 sólo se acepta cuando las dos columnas del candidato corresponden al mismo
SHA, cada recorrido anterior tiene evidencia observada y no quedan defectos
críticos o altos. Una compilación o carga a la tienda no sustituye la instalación
ni las pruebas físicas.
