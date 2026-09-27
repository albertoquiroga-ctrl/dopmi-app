# Dopmi — matriz de paridad

> Decisión vigente 27/9/2026: el titular admite las pantallas actuales para continuar; la fidelidad visual queda aplazada, sin aceptación atribuida a Irlanda. H9 autorizado: aceptación integrada y correcciones, con revisión final agrupada en Internal Testing. Ver [H9](h9-acceptance.md). Esta decisión supersede los bloqueos visuales históricos inferiores.

## Contrato vigente — 26/9/2026

H8 comprende todos los recorridos siguientes. La tabla histórica de rutas más abajo localiza pantallas, pero sus asignaciones anteriores a H9 quedan supersedidas por `h8-execution.md`. Estado por defecto de cada fila: **I pendiente / T pendiente / V pendiente** (implementación, comprobación técnica, aceptación visual). Ninguna fila está aceptada por Irlanda.

| ID | Pantalla/acción de referencia | Diferencia concreta a resolver en Flutter | Datos/dependencia | Prueba/evidencia requerida |
| --- | --- | --- | --- | --- |
| NAV | Barras donante/rescatista, cambio desde Perfil/Configuración | Cambiar preferencia sin guardar datos; Publicar abre selector; perfiles por modo | profiles.active_mode, sesión única | Persistencia/restauración, error de guardado, borradores entre pestañas, cambio de cuenta |
| AUTH | Splash, elección, introducciones, entrada, login/registro/recuperación | Revisar encuadres y espaciados existentes; confirmación real y OAuth gated | Auth existente | Cada intención, regreso, teclado y texto ampliado |
| DISC | Inicio Adoptar | Sustituir lista/título genérico por foto dominante, swipe y controles Pasar/Me gusta/contacto | Catálogo, favoritos, casos elegibles | Arrastre corto/largo, doble pulsación, fallo de favorito, fin, reintento y paginación |
| FILTER | Perros/Gatos; modal filtros/ubicación | Selector, chips sexo/tamaño/personalidad, ciudad/radio con aplicar/cancelar | Personalidad y zona aproximada nuevas | Filtro real, permisos denegados, sin ubicación, ninguna distancia inventada |
| PET | Detalle de mascota, galería y contacto | Jerarquía fotográfica, datos/historia/cuidados, responsable y barra de acciones | Adopción aprobada, chat actual | Imagen/galería, volver mantiene mazo; contacto confirmado, retiro público |
| MATCH | Mis match, búsqueda, chats y favoritos por tipo | Pantalla nueva; no es sólo lista de conversaciones | Threads/favoritos adopción/casos | Búsqueda propia, selección, vacío, errores, no simular reciprocidad |
| SAVED | Mascotas, casos y rescatistas guardados | Conteos y listas separadas sincronizadas | Favoritos de casos/rescatistas nuevos | Alta/baja idempotente; terceros no acceden; retirados no filtran datos |
| CHAT | Conversaciones de ambos modos, detalle y notificaciones | Rehacer presentación/badges conservando backend | Mensajes/lecturas/notificaciones actuales | Duplicados/red/reconexión, remitente auténtico, aislamiento |
| PROFILE | Perfil donante | Sustituir formulario principal por tarjeta amarilla, historial corto, accesos e interruptor | Perfil, pagos y estado Guardián reales | Sin datos simulados; actualizado al volver; vacío/error |
| SETTINGS | Configuración, información básica, pagos, ayuda | Pantallas separadas, regresos contextuales, acciones operativas | Perfil/Stripe existentes; FAQ por rol | Guardado fallido conserva edición; no pisa modo; cancelación/cierre sesión |
| SUPPORT | Apoyar / Ver todos | Círculos de casos, progreso y entrada Guardián en lugar de lista uniforme | Catálogo/objetivos aprobados | Sin gastos elegibles, recarga, abrir caso/Guardián |
| CASE | Caso público, gastos desplegables, galería/reportar | Foto principal, historia, categorías y gasto con evidencia pública aprobada | Casos/gastos/pagos actuales; reportes nuevos | Foto privada denegada, gasto agotado, share/deep link, reporte persistido |
| STORY | Avances / historia hasta ahora | Timeline/ciclo/Storage implementados; falta comparación visual y datos demo instalados | `dopmi_case_updates`, snapshot moderado y Storage privado | Borrador/corrección privados, revisión/publicación y edición posterior |
| PUBLIC | Perfil público: Actividad/En adopción/Casos | Avatar/bio/redes moderados; conteos verdaderos; guardar rescatista | Perfil público, agregados autorizados | Ciudad/chat públicos; ningún correo/documento; filtros por propietario |
| IMPACT | Impacto personal | Sustituir ejemplos por avances de casos realmente apoyados | Asignaciones privadas y avances publicados | Usuario A no ve atribuciones de B; cero asignaciones muestra vacío |
| RH | Inicio rescatista | Panel con saludo, casos, acciones pendientes y actividad | Resúmenes autorizados | Sin saldo ficticio; acciones abren entidad correcta; estados incompletos |
| RC | Mis casos/detalle/editar/cerrar | Tarjetas por estado, progreso y vínculo a adopción | Relación caso–adopción nueva | Interruptor no publica; cierre/revisión correctos; guardado de corrección |
| PUBLISH | Selector y formularios por pasos | Publicar deja de abrir Mis publicaciones; fotos/datos/revisión, recuperar borrador | Publicaciones/casos y archivos actuales | Cancelar selección, subir/interrumpir/reanudar, validar/enviar una vez |
| VERIFY | Introducción/verificación/estado | Flujo progresivo con expediente privado y correcciones | Verificación/moderación actuales | No autoaprobar; estado remoto, documentos sólo autorizados |
| EVIDENCE | Gasto veterinario/comida/medicina/otro | Pasos específicos y progreso persistido; evidencia antes de recibir aportaciones | Gastos pagados actuales | Adjuntos privados, fechas/importes, recibo duplicado, correcciones |
| RP | Perfil/configuración rescatista | Perfil propio distinto, editar público separado del expediente | Perfil moderado; Connect | Datos bancarios externos; cambio modo no confiere autorización |
| PAYMENT | Aportar, resultado/error/regreso | Diseño del resumen y estados reales en vez de éxito simulado | Checkout/conciliación test existentes | Abandono, pendiente, confirmado, devuelto, revisión; sin doble cobro |
| GUARD | Presentación/monto/consentimiento/impacto/gestión | Adaptar carruseles, tarjeta, cambios/cancelación e historial | Guardián H5 existente | Sin capacidad, mes omitido, monto futuro, tarjeta, cancelación y errores |
| REPORT | Reportar mascota/caso/rescatista; administración | Recepción/RPC/bandeja persistente creadas; conectar caso, perfil y panel visual | RPC/RLS implementados | Acuse sólo tras insertar, duplicados/reintento, denuncias privadas |
| LEGAL | Ayuda/términos/privacidad | Composición coherente sin presentar legal provisional como definitivo | Textos actuales; definitivo H10 | Regreso por modo y enlaces reales |

Evidencia por fila se anexará al completar cada ciclo con SHA de código/diseño, prueba y capturas de pantallas reales. No cerrar por una captura de componente aislado.

### Estado I/T/V vigente

La comprobación técnica significa que la ruta y su operación real están cubiertas; no equivale a aceptación visual. **V permanece en No para todas las filas hasta la revisión instalada de Irlanda/titular.** OAuth, eliminación de cuenta, analítica, legal definitivo, distribución iOS y dinero live pertenecen expresamente a H10–H12.

| ID | I | T | V | Evidencia o diferencia abierta |
| --- | --- | --- | --- | --- |
| NAV | Sí | Sí | No | Barras 3/5 destinos, cambio dedicado, restauración, borradores y aislamiento por cuenta; revisión instalada pendiente. |
| AUTH | Sí | Sí | No | Bienvenida/onboarding/acceso/confirmación/recuperación reales; OAuth oculto hasta H10. |
| DISC | Sí | Sí | No | Mazo, gesto/botones, bloqueo, contacto confirmado, soporte intercalado, paginación y final. |
| FILTER | Sí | Sí | No | Especie, sexo, tamaño, personalidad, ciudad y radio aproximado; permiso opcional/manual y sin distancia inventada. |
| PET | Sí | Sí | No | Galería, historia, salud, convivencia, cuidados, rescatista, favorito/share/reporte/contacto. |
| MATCH | Sí | Sí | No | Búsqueda, conversaciones, mensajes y acceso a guardados; no crea match recíproco. |
| SAVED | Sí | Sí | No | Adopción/Donación/Rescatistas, contadores, tombstones y baja privada; Perfil abre mascotas y rescatistas directamente. |
| CHAT | Sí | Sí | No | Lista/conversación/notificaciones con participantes, lectura, reconexión e idempotencia. |
| PROFILE | Sí | Sí | No | Tarjeta, membresía real, historial/vacío/error, mascotas/rescatistas guardados, impacto, configuración y modo. |
| SETTINGS | Sí | Sí | No | Información básica, medio/suscripción Guardián, historial, ayuda, legal provisional y cierre de sesión. |
| SUPPORT | Sí | Sí | No | Casos elegibles, progreso, Ver todos y hero Guardián con fotografía/estilo de referencia y reglas reales. |
| CASE | Sí | Sí | No | Galería pública aprobada, ubicación, responsable, historia, categorías, gastos, share/reporte/aporte. |
| STORY | Sí | Sí | No | Avances persistentes moderados con fotos y snapshot público inmutable hasta aprobación. |
| PUBLIC | Sí | Sí | No | Avatar/bio/ciudad/redes moderados y pestañas Actividad/En adopción/Casos. |
| IMPACT | Sí | Sí | No | Sólo asignaciones propias y avances públicos, sin identidades de terceros. |
| RH | Sí | Sí | No | Saludo, pendientes, actividad y Asignado/Transferido/En revisión, sin saldo bancario simulado. |
| RC | Sí | Sí | No | Estados, detalle, edición/cierre y vínculo caso–adopción con ciclos independientes. |
| PUBLISH | Sí | Sí | No | Selector Adopción/Caso, Fotos/Información/Revisión, guardado/reanudación y verificación requerida. |
| VERIFY | Sí | Sí | No | Introducción, archivos, información, revisión y estados remotos/correcciones. |
| EVIDENCE | Sí | Sí | No | Formularios de gasto, archivos privados, progreso, reintento y requisito pagado/aprobado. |
| RP | Sí | Sí | No | Perfil propio/moderado, Connect, ayuda, configuración y regreso a donante. |
| PAYMENT | Sí | Sí | No | Monto/revisión/Checkout y resultado persistido: pendiente, confirmado, asignado, transferido, devuelto/revisión. |
| GUARD | Sí | Sí | No | Alta, consentimiento, impacto, historial, monto, tarjeta y cancelación; reglas H5 preservadas. |
| REPORT | Sí | Sí | No | Mascota/caso/rescatista y bandeja administrativa restringida; acuse posterior a inserción. |
| LEGAL | Parcial | Parcial | No | Ayuda y aviso provisional coherentes; privacidad/términos definitivos permanecen H10. |

### Correspondencia de rutas vigente

| Referencia HTML | Flutter productivo | Estado técnico / excepción |
| --- | --- | --- |
| `/`, `/choose-account`, `/choose-intent` | `/welcome` | I/T; elección unificada de intención. |
| `/intro`, `/onboarding/donor`, `/onboarding/rescuer` | `/onboarding?intent=…` | I/T; pistas adoptar/apoyar/rescatar. |
| `/welcome/:mode`, `/login/:mode`, `/signup/:mode` | `/start`, `/login`, `/signup` con intención conservada | I/T; una identidad y sesión. |
| `/forgot-password` | `/forgot`, `/reset-password`, `/confirm-recovery` | I/T real; la simulación HTML no se copia. |
| `/terms…`, `/privacy…` | `/terms` | Parcial; documentos definitivos H10. |
| `/adoption` | `/adoptions` | I/T; mazo swipe productivo. |
| `/adoption/:petId` | `/adoptions/:id` | I/T. |
| `/donate`, `/case/:caseId` | `/rescue-cases`, `/rescue-cases/:id` | I/T. |
| `/donate/:caseId/:needId`, éxito/error | `/contribute/:id` con estado persistido | I/T; no existen pantallas de éxito simulado. |
| `/impact`, `/impact/support`, éxito/error | `/impact`, `/guardian` | I/T; alta/resultado dependen del servidor. |
| `/messages`, `/messages/:threadId`, `/notifications` | `/messages`, `/messages/:id`, `/notifications` | I/T. |
| `/history` | `/payments` | I/T. |
| `/profile` | `/profile` | I/T. |
| `/saved`, `/saved-rescuers` | `/saved?kind=adoption|rescuer` | I/T; Donación es la tercera pestaña. |
| `/settings`, `/settings/basic-info` | `/settings`, `/profile/basic-info` | I/T. |
| `/settings/payment-methods`, `/settings/billing` | `/guardian` | I/T según capacidad real de Stripe. |
| `/help` | `/help` | I/T; FAQ cambia por experiencia. |
| `/rescuer-profile/:caseId` | `/people/:id` | I/T con perfil por UUID. |
| `/rescuer` | `/rescuer` | I/T. |
| `/rescuer/verification` | `/rescue/new?kind=verification` | I/T. |
| `/rescuer/cases`, `/rescuer/cases/:caseId` | `/my-cases`, `/rescue/:id` | I/T. |
| `/rescuer/publish` | `/publish` → `/my-adoptions/new` o `/rescue/new?kind=case` | I/T. |
| `/rescuer/evidence…`, `/rescuer/food…` | `/rescue/:id?kind=expense` | I/T; formulario depende de categoría. |
| `/rescuer/messages` | `/messages` | I/T con barra rescatista. |
| `/rescuer/profile`, `/rescuer/profile/edit` | `/profile`, `/rescuer/profile/edit` | I/T. |
| `/rescuer/settings` | `/settings`, `/connect`, `/help` | I/T; banco permanece en Stripe Connect. |
## Estados transversales obligatorios

Cada fila necesita carga, vacío, error recuperable, reintento, interrupción, éxito y permisos cuando aplique. Adjuntar capturas del mockup/app con tamaño, SHA y datos de prueba equivalentes. Irlanda valida diseño, titular producto/dispositivo; el implementador registra evidencia.

- Autenticación: correo pendiente, recuperación, sesión expirada, OAuth cancelado y cambio de experiencia sin duplicar cuenta.
- Adopción/rescate: borrador privado, revisión, corrección/rechazo, publicación aprobada, retiro, cierre y suspensión.
- Archivos: selección cancelada, límite/tipo inválido, reanudación, acceso denegado y archivo aprobado inmutable; videos post-MVP.
- Mensajes: vacío, carga persistente, reconexión, duplicado evitado y acceso exclusivo de participantes.
- Aportaciones: capacidad agotada, Checkout abandonado, procesamiento incierto, pago confirmado, asignación, transferencia y devolución.
- Guardián: alta sin capacidad, consentimiento, mes omitido sin deuda, rechazo/3DS, tarjeta, cambio de monto futuro, cancelación, revisión e historial privado.
- No presentar transferencias como depósitos bancarios ni reservas como pagos. Nunca borrar estados necesarios porque no estén en el mockup.

## Diferencias de producto que prevalecen sobre el diseño

| Mockup | Tratamiento productivo |
| --- | --- |
| Fondo comunitario / Guardadito | Sustituir por asignación a gastos pagados y aprobados |
| Bono de $350 / cashback / Coins / compra antes de evidencia | Excluir promesas; evidencia y aprobación antes de recibir aportaciones |
| Éxito simulado / verificar con botón | Confirmación del servidor y moderación real |
| CLABE recolectada por formulario propio | Onboarding de Stripe Connect, sin duplicar datos bancarios |
| Videos | Post-MVP; rechazar hasta implementar pipeline y moderación |

H8 incorpora Adoptar/Apoyar/Perfil para donantes y las cinco pestañas de rescatistas, Inter/Fraunces locales, fondo blanco y púrpura #7841f2. La bienvenida usa las tres intenciones y sus iconos de referencia. Guardados, mensajes y publicaciones siguen accesibles desde Perfil. Los recorridos visibles antes asignados a H9 quedaron implementados y técnicamente comprobados dentro de H8; sólo su aceptación visual instalada permanece pendiente. Ver [evidencia H8](design-foundation.md). No se declara aprobación visual por aplicar un tema.
