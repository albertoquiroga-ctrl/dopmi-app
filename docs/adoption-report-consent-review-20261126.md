# Consentimiento de las métricas de Reportes: Apple y Google

Consulta: 26/11/2026, Ciudad de México. Investigación de requisitos de tienda con fuentes oficiales vigentes; no cambia el producto ni reabre la validación del contador.

**Conclusión:** no encontré una regla que imponga específicamente el interruptor global «Analítica de uso» o una pantalla independiente para este reporte. Tampoco se exige una casilla separada por métrica. Declarar datos, informar su uso, obtener consentimiento cuando corresponda y utilizar ATT son obligaciones distintas. No es correcto afirmar que toda medición propia obliga universalmente a un opt-in: las políticas actuales reconocen supuestos legales de tratamiento sin consentimiento, sin presumir que Dopmi ya reúne sus condiciones. Véanse A1 y G1.

## Hechos técnicos que delimitan esta consulta

Según el paquete y la auditoría del integrador: detalle guarda `post_id`, UUID de la cuenta y `first_viewed_at`, con unicidad mascota/cuenta, en Supabase. El panel recibe agregados. Favoritos, contactos y primeras respuestas se calculan de registros operativos existentes. El RPC nuevo no transmite esos registros a Firebase o Meta. Esto no excluye eventos consentidos de contacto/respuesta que ya existían en otro circuito; no son envíos nuevos del reporte agregado. Su cliente exige la elección previa compartida de Analítica de uso. Estos hechos son entradas del análisis; no se inspeccionaron cuentas, chats ni datos de producción durante esta investigación.

Auditoría directa del integrador sobre código de producto `280b3186d15db26d5641847cff9acdc694614602`, idéntico en el HEAD documental `8624b618`:

- [Registro y consulta agregada](../supabase/migrations/20261125222901_adoption_detail_reports.sql): campos nuevos en líneas4–8; servidor toma actor de sesión, comprueba consentimiento y guarda la primera vista; agregados en líneas76–87. No se consulta contenido de mensajes para el reporte.
- [Cliente de detalle](../apps/mobile/lib/features/adoption/catalog_screens.dart): `observeDetail`/`recordDetail` y su dependencia de `analyticsConsentCurrent`.
- [Transporte](../apps/mobile/lib/features/adoption/community_repository.dart): `recordAdoptionDetailView` llama directamente al RPC de Supabase; no entra en las rutas atribuibles del wrapper `rpc`.
- [Eventos previos](../apps/mobile/lib/core/confirmed_value_analytics.dart): el envío opcional de nombres de evento de contacto/respuesta pertenece a un flujo anterior, separado de la consulta de Reportes.
- [Pantalla anterior](../apps/mobile/lib/features/profile/usage_analytics_prompt.dart): trata Firebase, navegación y campañas; su alcance es mayor que el reporte nuevo. [Aviso actual](../apps/mobile/lib/features/identity/privacy_notice_screen.dart), sección «Medición y permisos»: declara Analítica opcional y dice expresamente que aceptar el aviso no la activa. Esto no permite considerar hoy la aceptación genérica del aviso como sustituto automático de esa elección. Se leyó el texto; no se emitió un dictamen de suficiencia jurídica ni se validó una base alternativa.

## Qué dicen las fuentes

**A1 — Apple, App Review Guidelines 5.1.1(i)/(ii) y 5.1.2(i)/(ii).** Exige explicar datos, finalidades y retirada; establece consentimiento para recopilar datos de usuario/uso, incluso anónimos. El mismo 5.1.1(ii) reconoce tratamiento por interés legítimo sin consentimiento conforme a GDPR o estatuto similar; 5.1.2 contempla usos permitidos por ley y limita cambios de finalidad. No especifica un checkbox por métrica. Una publicación en el aviso no demuestra por sí sola consentimiento ni la excepción legal. [Fuente oficial, sección Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy).

**A2 — Apple, App Privacy Details: Data collection, Data types, Data use y Data linked to the user.** Conservar datos fuera del dispositivo es recopilación aunque el servidor sea propio o el fin funcional. Un identificador de cuenta entra en User ID; interacciones entran en Product Interaction. Si el UUID permite relacionar actividad y cuenta, la recopilación sigue vinculada al usuario aunque el administrador vea un total. Sensitive Info es una categoría distinta: un dato no necesita pertenecer a ella para requerir declaración. Las finalidades App Functionality y Analytics se eligen por el uso real; evaluar comportamiento/interés puede encajar en Analytics. [Fuente oficial](https://developer.apple.com/app-store/app-privacy-details/).

**A3 — Apple, User Privacy and Data Use: Ask permission to track.** ATT se refiere al enlace con datos de otras empresas para publicidad/medición publicitaria o transferencia a corredores de datos. El flujo propio descrito no encaja, por sí solo, en esa definición. Esto no certifica otros SDK o flujos de la app ni elimina A1/A2. [Fuente oficial](https://developer.apple.com/app-store/user-privacy-and-data-use/#ask-permission-to-track).

**G1 — Google, User Data: Personal and Sensitive User Data; Prominent Disclosure & Consent Requirement.** Limita usos a funcionalidades y finalidades conformes razonablemente esperadas. Si recopilación/uso de datos personales o sensibles sale de esa expectativa, exige divulgación prominente dentro de la app y acción afirmativa previa; tocar Aceptar y marcar una casilla son ejemplos, no un formato único. También reconoce otras bases legales con cumplimiento y divulgaciones aplicables. La expresión conjunta personal/sensitive incluye información identificable; no equivale sólo a categorías especialmente sensibles. [Fuente oficial](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en).

**G2 — Google, Data safety: Data collection, Data sharing, Data types y Purposes.** Recopilar datos fuera del dispositivo incluye servidores propios y datos seudónimos. User IDs incluye cuentas; App interactions incluye visitas a páginas. Deben declararse tipos y finalidades reales, incluidos los usos posteriores de datos guardados. Analytics y App functionality son finalidades diferentes. Un proveedor de nube que procesa sólo por instrucciones del desarrollador puede estar exceptuado de declarar esa transferencia como sharing, sin eximir la collection; no se verificó aquí el contrato de Supabase. La etiqueta optional/required describe el control efectivo del usuario, no impone por sí misma un checkbox. [Fuente oficial](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).

**G3 — Google, Best practices for prominent disclosure and consent: Background.** Confirma el criterio de expectativa razonable. La divulgación prominente, cuando es necesaria, no sustituye la política de privacidad ni Data safety. En consecuencia, son incorrectas tanto la equivalencia declaración=consentimiento como la afirmación declaración=checkbox obligatorio. [Fuente oficial](https://support.google.com/googleplay/android-developer/answer/11150561).

## Aplicación por métrica

Las conclusiones de esta tabla son **interpretaciones del flujo descrito**, no dictámenes individuales de las tiendas. Aplican las fuentes anteriores; certeza alta respecto de sus distinciones y media respecto de la clasificación concreta sin revisar el aviso y las declaraciones vigentes.

| Métrica | Tratamiento relevante | ¿Checkbox nuevo por ese contador? |
|---|---|---|
| Personas únicas que abrieron el detalle | Recopilación nueva, pasiva y vinculable a cuenta. No se vuelve anónima por agregarla después. | No hay mandato de checkbox separado. Hay que cubrir recopilación/finalidad mediante consentimiento válido o una excepción realmente aplicable; no asumirla por ser estadística propia. |
| Favoritos actuales | Guardar/quitar es una acción funcional consciente; el total reutiliza esas filas. | No se identifica exigencia específica de otro checkbox para sumar registros. Evaluar si el uso del reporte ya está explicado y dentro de las finalidades cubiertas. |
| Personas que contactaron | El contacto consciente genera datos necesarios para mensajería; el reporte calcula un total. | No aparece permiso adicional por mostrar ese total. Las obligaciones del flujo de mensajería siguen aplicando; una finalidad nueva no queda autorizada automáticamente por tener ya los datos. |
| Primeras respuestas | Recuento derivado de la respuesta consciente y sus metadatos operativos; no nueva captura pasiva de detalle. | Misma distinción: no hay checkbox por agregado; comprobar cobertura de finalidad. El reporte no publica contenido del chat. |

## Respuesta precisa a la objeción y límite

La objeción al interruptor específico como requisito automático de las tiendas es fundada. El interruptor compartido actualmente aplicado es una elección de implementación; no demuestra que las tiendas impongan esa interfaz concreta. Para afirmar que se puede retirar toda elección previa y registrar vistas igualmente, faltaría establecer cómo queda cubierta la recopilación vinculada a cuenta: consentimiento informado válido en otro mecanismo o excepción legal aplicable. Un texto genérico de términos no demuestra ninguna de las dos cosas. La finalidad informada de los tres agregados operativos también debe mantenerse cubierta.

Sería excesivo concluir que el contador exige siempre checkbox, o que UUID + backend propio + ausencia de categorías especialmente sensibles permite medir siempre sin consentimiento. Elegir y sustentar una excepción legal queda fuera de esta consulta de tiendas. No se prescribe una auditoría jurídica multinacional ni se afirma una base jurídica válida para Dopmi. Tampoco se modificaron consentimientos, fichas, binarios o configuración.
