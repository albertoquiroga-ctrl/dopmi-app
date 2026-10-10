# Checkpoint Dopmi — cierre de conversación, 9/10/2026

**CHAT CERRADO; ENTREGA PENDIENTE. La siguiente conversación debe RETOMAR ESTA ENTREGA.**
Perfil ENTREGA_CONTINUA_EFICIENTE_VERIFICADA. Este archivo es la fuente de estado;
el [tablero](parity-current-review.md) organiza pendientes y el
[registro social](meta-social-verification.md) concentra su evidencia técnica.
Seguir el [protocolo estable](mock-sync-workflow.md), sin ampliar alcance.

## Cortes conservados por grupo

| Grupo | Último implementado | Último verificado / límite |
|---|---|---|
| Mock/paridad, incluida QA9ced | Referencia dde1bb9d01e5f4c427424bffed99bf1c3ed1beca; producto 84687bb873760b806be93b5645c7c930bb1af0a1 | FULLCI37967904270 y 19 dirigidas; Play2.3.3(308), Samsung desde Play. QA302/303/308 válida se reutiliza. SMS incorrecto/reenvío real y aceptación humana pendientes. |
| Verificación social autorizada después | f71c4440f261b10455eb38b9948fd3d68ef321ca; backend a9418154a964a02043ecb4f03f0b8c98b88c5aa2 | FULLCI38001865589 verde; candidato943dc1c773d87e85f97251db358b34902d7c5159; Play2.3.3(311) publicado e instalado. Instagram y Facebook reales, mismo actor/sesión, verificados. Negativos restantes y aceptación pendientes. |
| Backend/configuración social | DEV ohqxranynackjignryep, tres Edge ACTIVEv1, migración20261009210425 | Postflight RLS/ACL y OAuth real válidos; SOCIAL_VERIFICATION_ENABLED=false restaurado al cerrar QA. No activación general ni producción. |

Un commit documental no crea candidato: 943dc1c sólo añade documentación a f71c444;
HEAD anterior al cierre fbb2b61d1525289fdefa52b66c57a1efd4dad8d9 también es documental.
Rama codex/design-foundation / PR6 borrador abierto, base codex/Dopmi ba9f897.
El SHA de este cierre se obtiene de Git; no es otro build.
Mock posterior4369 observado, **no inventariado ni autorizado como referencia**.

## Estado separado y próxima acción

- Implementado: paridad846 y socialf71; código entregable ya remoto.
- Verificado técnicamente: gates anteriores y revisiones descritas en el registro social.
- Publicado: candidato943dc1c, Codemagic6ac9772639c0d173f3b4330a, Play internal/completed311.
- Verificado en dispositivo: Samsung SM-S938B/Android16, com.mycompany.dopmi,
  2.3.3(311), installer com.android.vending; entrada real al perfil y OAuth de ambos proveedores.
  Esto no sustituye toda la QA de paridad ni la QA SMS pendiente.
- Aprobado por titular/diseñadora: autorizaciones y consentimientos puntuales acreditados;
  **no hay aprobación humana global UI/UX de esta entrega**.

Siguiente acción exacta: retomar los pendientes del registro social con una ventana
de QA acordada para desconexión/revocación y denegación real del proveedor, preservando
la cuenta Dopmi; resolver compatibilidad de eliminación Facebook legado, retención/purga
y requisitos Meta antes de uso general. Si exige corrección, validar sólo lo afectado y
su candidato final de Play. Para SMS incorrecto/reenvío, obtener un número controlado
no vinculado (Irlanda fue propuesta, ejecución no acreditada), introducirlo directamente
en la app vigente y registrar error/reenvío/confirmación reales. No retirar el teléfono
personal ni reutilizar fixtures consumidas. Recabar aceptación UI/UX explícita.
No se ejecuta ninguna de estas acciones durante este cierre.

## Preservación y evidencia

QA anterior de perfil escritor/publicación moderada, contactos públicos, texto200%,
chat/foto, notificaciones e historial sigue válida donde consta en el tablero/ledger;
no repetirla por un commit documental. iOS304/TestFlight es evidencia histórica,
sin nueva aceptación funcional/visual acreditada en este cierre.
Dinero test, Guardian habilitado en android-guardian-internal, identidad/firma intactas.
Se mantiene la excepción de disputa de [H5](hito5-delivery.md); no hay excepciones
aprobadas para omitir los pendientes de esta entrega.

Evidencia GitHub: commits, CI y documentos versionados. Capturas/journals .tools/
son privados e ignorados, disponibles sólo en esta computadora, no en GitHub.
Hay cambios locales ajenos de admin, móvil, documentación legal/operativa y otros
archivos sin publicar; no revisados ni incluidos en este cierre. No reset ni limpieza.
Teléfono dejado en modo Rescatista, pantalla social con ambas conexiones; no se guardó
el editor ni se restauró el modo previo Adoptante. No operar el teléfono al cerrar.
